# 12. Environment Variables

## 12.1 Naming Convention

All environment variables follow the pattern:

```
CJ_[SERVICE]_[VARIABLE_NAME]
```

| Component | Description | Examples |
|-----------|-------------|----------|
| `CJ` | Project prefix (Cornjacket) | — |
| `SERVICE` | Service or component name | `INGESTION`, `EVENTHANDLER`, `OUTBOX`, `REDPANDA` |
| `VARIABLE_NAME` | The configuration parameter | `PORT`, `DATABASE_URL`, `WORKER_COUNT` |

**Conventions:**
- All uppercase with underscores
- Project prefix ensures no collision with system or third-party variables
- Service name groups related configuration
- Defaults are set for local development (minimal config needed to run locally)

## 12.2 Service Ports

| Variable | Default | Local | Dev | Staging | Prod |
|----------|---------|-------|-----|---------|------|
| `CJ_INGESTION_PORT` | 8080 | 8080 | 8080 | 8080 | 8080 |
| `CJ_QUERY_PORT` | 8081 | 8081 | 8081 | 8081 | 8081 |
| `CJ_ACTIONS_PORT` | 8083 | 8083 | 8083 | 8083 | 8083 |

**Note:** Port 8082 is reserved for Redpanda Pandaproxy in local development.

## 12.3 Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_LOG_LEVEL` | `info` | Log verbosity (debug, info, warn, error) |
| `CJ_LOG_FORMAT` | `json` | Output format (json, text) |

**Per-environment values:**

| Environment | Level | Format | Notes |
|-------------|-------|--------|-------|
| Local | `info` or `debug` | `text` | Text format for readability |
| Dev | `info` | `json` | JSON for CloudWatch |
| Staging | `info` | `json` | JSON for CloudWatch |
| Prod | `info` | `json` | JSON for CloudWatch |

## 12.4 Database URLs

| Variable | Default | Service |
|----------|---------|---------|
| `CJ_INGESTION_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Ingestion + Ingestion Worker |
| `CJ_EVENTHANDLER_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Event Handler |
| `CJ_QUERY_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Query Service |
| `CJ_TSDB_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | TSDB Writer |
| `CJ_ACTIONS_DATABASE_URL` | `postgres://cornjacket:cornjacket@localhost:5432/cornjacket?sslmode=disable` | Action Orchestrator |

**Per-environment values:**

| Environment | Pattern |
|-------------|---------|
| Local | All services share one local database |
| Dev | All services share one RDS instance (cost optimization) |
| Staging | Separate databases per service (mirrors prod) |
| Prod | Separate databases per service (ADR-0010) |

## 12.5 Message Bus (Redpanda)

| Variable | Default | Local | Dev | Staging | Prod |
|----------|---------|-------|-----|---------|------|
| `CJ_REDPANDA_BROKERS` | `localhost:9092` | `localhost:9092` | TBD | TBD | TBD |

## 12.6 Ingestion Worker

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_OUTBOX_WORKER_COUNT` | `4` | Number of worker goroutines |
| `CJ_OUTBOX_BATCH_SIZE` | `100` | Max entries fetched per batch |
| `CJ_OUTBOX_MAX_RETRIES` | `5` | Max retry attempts before leaving in outbox |
| `CJ_OUTBOX_POLL_INTERVAL` | `5s` | Watchdog timer interval |

**Per-environment tuning:**

| Environment | Workers | Batch Size | Notes |
|-------------|---------|------------|-------|
| Local | 4 | 100 | Sufficient for testing |
| Dev | 4 | 100 | Same as local |
| Staging | 4 | 100 | Tune based on load testing |
| Prod | TBD | TBD | Tune based on throughput requirements |

## 12.7 Event Handler

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_EVENTHANDLER_CONSUMER_GROUP` | `event-handler` | Kafka consumer group ID |
| `CJ_EVENTHANDLER_TOPICS` | `sensor-events,user-actions,system-events` | Comma-separated topic list |
| `CJ_EVENTHANDLER_POLL_TIMEOUT` | `1s` | Poll timeout duration |

## 12.8 Feature Flags

| Variable | Default | Description |
|----------|---------|-------------|
| `CJ_FEATURE_TSDB` | `false` | Enable TSDB writer service |

## 12.9 Complete Reference

| Variable | Default | Service | Description |
|----------|---------|---------|-------------|
| `CJ_LOG_LEVEL` | `info` | All | Log verbosity (debug, info, warn, error) |
| `CJ_LOG_FORMAT` | `json` | All | Output format (json, text) |
| `CJ_INGESTION_PORT` | `8080` | Ingestion | HTTP server port |
| `CJ_QUERY_PORT` | `8081` | Query | HTTP server port |
| `CJ_ACTIONS_PORT` | `8083` | Actions | HTTP server port |
| `CJ_INGESTION_DATABASE_URL` | (see 12.3) | Ingestion | PostgreSQL connection string |
| `CJ_EVENTHANDLER_DATABASE_URL` | (see 12.3) | Event Handler | PostgreSQL connection string |
| `CJ_QUERY_DATABASE_URL` | (see 12.3) | Query | PostgreSQL connection string |
| `CJ_TSDB_DATABASE_URL` | (see 12.3) | TSDB | PostgreSQL connection string |
| `CJ_ACTIONS_DATABASE_URL` | (see 12.3) | Actions | PostgreSQL connection string |
| `CJ_REDPANDA_BROKERS` | `localhost:9092` | All | Kafka broker addresses |
| `CJ_OUTBOX_WORKER_COUNT` | `4` | Outbox | Worker goroutine count |
| `CJ_OUTBOX_BATCH_SIZE` | `100` | Outbox | Entries per fetch |
| `CJ_OUTBOX_MAX_RETRIES` | `5` | Outbox | Max retry attempts |
| `CJ_OUTBOX_POLL_INTERVAL` | `5s` | Outbox | Watchdog interval |
| `CJ_EVENTHANDLER_CONSUMER_GROUP` | `event-handler` | Event Handler | Consumer group ID |
| `CJ_EVENTHANDLER_TOPICS` | `sensor-events,user-actions,system-events` | Event Handler | Topics to consume |
| `CJ_EVENTHANDLER_POLL_TIMEOUT` | `1s` | Event Handler | Poll timeout |
| `CJ_FEATURE_TSDB` | `false` | TSDB | Enable TSDB writer |
