# 3. Data Flow

## 3.1 Service-Level View

Three services handle the event flow:

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Ingestion  │────────▶│ EventHandler │────────▶│    Query    │
│   Service   │  events │   Service    │  state  │   Service   │
└─────────────┘         └──────────────┘         └─────────────┘
       ▲                                                │
       │                                                ▼
    HTTP POST                                       HTTP GET
   /api/v1/events                              /api/v1/projections
```

| Service | Responsibility | Port |
|---------|----------------|------|
| **Ingestion** | Accept events, validate, ensure delivery | 8080 |
| **EventHandler** | Process events, update projections | (background) |
| **Query** | Read projection state | 8081 |

## 3.2 Implementation Details

The infrastructure details are hidden within each service:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INGESTION SERVICE                               │
│                                                                              │
│   HTTP ──▶ Validation ──▶ Outbox ──▶ Worker ──┬──▶ Event Store (audit)     │
│   (MQTT)                   Table              │                              │
│                                               └──▶ EventHandler Client       │
│                                                    (Redpanda publish)        │
└──────────────────────────────────────────────────────────────────────────────┘
                                                           │
┌──────────────────────────────────────────────────────────┼───────────────────┐
│                           EVENTHANDLER SERVICE           ▼                   │
│                                                                              │
│   Redpanda Consumer ──▶ Handler Registry ──▶ Projections Store              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                                           │
┌──────────────────────────────────────────────────────────┼───────────────────┐
│                              QUERY SERVICE               ▼                   │
│                                                                              │
│   HTTP ──▶ Validation ──▶ Projections Store ──▶ Response                    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 3.3 Write Path

1. **Entry:** HTTP request (or MQTT in Phase 2) arrives at Ingestion Service
2. **Validate:** Ingestion Service validates the event envelope
3. **Persist:** Event written to `outbox` table (durable, transactional)
4. **Process:** Ingestion Worker picks up entry (NOTIFY/LISTEN + watchdog)
5. **Fan-out:**
   - Write to `event_store` table (append-only audit log)
   - Submit to EventHandler via client (publishes to Redpanda)
6. **Complete:** Delete from `outbox` table

## 3.4 Read Path

1. **Consume:** EventHandler subscribes to Redpanda topics
2. **Dispatch:** Route event to handler based on event_type
3. **Project:** Update projection via shared projections store
4. **Commit:** Commit consumer offset (at-least-once delivery)

## 3.5 Query Path

1. **Request:** Query Service receives HTTP request
2. **Read:** Fetch from `projections` table (pre-computed state)
3. **Return:** Return projection data to client
