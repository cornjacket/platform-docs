# 2. Dev Environment Task Architecture

## 2.1 ECS Task Composition

| Container | Purpose | Ports | Volume Mounts |
|-----------|---------|-------|---------------|
| **traefik** | API Gateway / Router | 80 (HTTP entry), 8180 (dashboard) | Config volume |
| **app** | Go Monolith | 8080 (ingestion), 8081 (query), 8082 (actions) | None |
| **mqtt-broker** | EMQX MQTT Broker | 1883 (MQTT), 18083 (dashboard) | EFS/EBS for persistence |
| **redpanda** | Message Bus | 9092 (Kafka API), 9644 (admin) | EFS/EBS for persistence |
| **postgres** | Event Store + TSDB | 5432 (internal only) | EFS/EBS for persistence |
| **ai-inference** | AI Inference Service (Python/FastAPI) | 8090 (HTTP, internal only) | None |

## 2.2 Communication Patterns

- External → Traefik (port 80) → App ports (8080/8081/8082)
- External → MQTT (port 1883) → EMQX
- IoT devices → EMQX → App (subscribes to MQTT topics)
- App → Postgres (localhost:5432) - event store reads/writes
- App → Redpanda (localhost:9092) - publish events
- App → MQTT (localhost:1883) - subscribe to device messages

## 2.3 Persistent Storage

| Container | Storage Required | Purpose |
|-----------|-----------------|---------|
| postgres | Yes (EFS/EBS) | Event store + time-series data |
| redpanda | Yes (EFS/EBS) | Message buffer |
| mqtt-broker | Yes (EFS/EBS) | Sessions/config |
| app | No | Stateless (uses Postgres for data) |
| traefik | No | Config from volume |
| ai-inference | No | Stateless |

**Decision deferred:** EFS vs. EBS for container data persistence

## 2.4 Resource Allocation (Dev)

| Setting | Value | Notes |
|---------|-------|-------|
| vCPU | 1 | Total task allocation |
| Memory | 2GB | Total task allocation |
| Rationale | Cost optimization | Acceptable slow performance for dev |

**Monitoring:** Watch for memory pressure/thrashing via CloudWatch, scale up if needed

**Decision deferred:** Per-container resource limits based on profiling

## 2.5 Access Patterns

| Service | URL Pattern |
|---------|-------------|
| HTTP API | `http://<task-ip>/api/v1/*` |
| MQTT | `mqtt://<task-ip>:1883` |
| Traefik Dashboard | `http://<task-ip>:8180` |
| EMQX Dashboard | `http://<task-ip>:18083` |
| Redpanda Admin | `http://<task-ip>:9644` |

## 2.6 Cost Estimate (Dev)

| Component | Estimated Cost |
|-----------|---------------|
| ECS Fargate (1 vCPU, 2GB, 24/7) | ~$30-40/month |
| EFS storage | ~$5-10/month |
| Logs/metrics | ~$5/month |
| **Total** | **~$40-55/month** |

## 2.7 Service Database Configuration

Each service receives its own database URL as configuration (see ADR-0010).

| Environment Variable | Service | Tables Owned |
|---------------------|---------|--------------|
| `INGESTION_DATABASE_URL` | Ingestion (incl. Worker) | outbox, event_store |
| `EVENTHANDLER_DATABASE_URL` | Event Handler | projections, dlq |
| `QUERY_DATABASE_URL` | Query Service | (none - reads from Event Handler) |
| `TSDB_DATABASE_URL` | TSDB Writer | timeseries tables, dlq |
| `ACTIONS_DATABASE_URL` | Action Orchestrator | action_config, dlq |

**Default (Dev):** All variables point to the same database:
```
postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable
```

**Migration Location:** Each service owns its migrations in `internal/services/<service>/migrations/`.

**Migration Execution (ADR-0016):** Migrations are embedded into the binary via `//go:embed` and auto-applied on startup using `pressly/goose/v3`. Each service uses a dedicated goose tracking table (`goose_ingestion`, `goose_eventhandler`) to avoid version collision when services share a database. SQL files require `-- +goose Up` annotation. The `make migrate-all` target is retained as a dev reset convenience only.

## 2.8 Docker Compose Layering

Two compose files in `platform-services/docker-compose/`, combined with `-f` flags:

| File | Services | Purpose |
|------|----------|---------|
| `docker-compose.yaml` | Postgres, Redpanda, Redpanda Console | Base infrastructure (always needed) |
| `docker-compose.fullstack.yaml` | Platform (container), Traefik, EMQX | Overlay for production-fidelity testing |

**Skeleton mode** (`make skeleton-up`): Base file only. Platform binary runs on the host, connecting to containerized infrastructure via `localhost`. Used for day-to-day Go development, integration tests, component tests, and skeleton e2e tests.

**Fullstack mode** (`make fullstack-up`): Base + overlay. Platform runs as a container on the Docker network. Traefik routes HTTP on port 80, EMQX handles MQTT on port 1883. Used for fullstack e2e tests and verifying the containerized deployment.

Both e2e test targets (`make e2e-skeleton`, `make e2e-fullstack`) must pass. See [DEVELOPMENT.md](../../platform-services/DEVELOPMENT.md) for commands.

## 2.9 Service Health & Startup Reliability

**Health Checks:** Every service must expose a `GET /health` HTTP endpoint, including background workers. Process liveness alone is insufficient — a container can be alive but deadlocked, disconnected from Kafka, or holding a hung database connection. ECS and Kubernetes health checks are HTTP-based; without an endpoint, the orchestrator has no way to probe service health.

| Service | Port | Health Endpoint | Status |
|---------|------|-----------------|--------|
| Ingestion | 8080 | `GET /health` | Implemented (shallow) |
| Query | 8081 | `GET /health` | Not yet implemented |
| Action Orchestrator | 8083 | `GET /health` | Not yet implemented |
| Event Handler | 8084 | `GET /health` | Not yet implemented |

Services that are primarily background workers (Event Handler) must still run a minimal HTTP server solely for health checks. The health endpoint should reflect actual readiness — not just "process is alive" but "I am connected and processing."

**Startup Error Propagation:** If any HTTP server fails to bind its port (or encounters any fatal startup error), the entire process must initiate graceful shutdown and exit with a non-zero code. Async goroutine errors must be propagated to the main goroutine — logging alone is not sufficient. See [Insight 008](../insights/development/008-propagate-async-server-errors.md).
