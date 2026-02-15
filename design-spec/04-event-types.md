# 4. Event Types

Events flow through the system via the Ingestion Worker → Redpanda → Event Handler pipeline. The `event_type` field determines topic routing and projection handling.

## 4.1 Topic Routing

The Ingestion Worker routes events to topics based on `event_type` prefix:

| Prefix | Topic | Description |
|--------|-------|-------------|
| `sensor.*` | sensor-events | IoT sensor data |
| `user.*` | user-actions | User activity |
| `*` (default) | system-events | System/operational events |

## 4.2 Event Catalog

| Event Type | Payload Schema | Projection |
|------------|----------------|------------|
| `sensor.reading` | `{"value": float, "unit": string}` | `sensor_state` |
| `user.login` | `{"user_id": string, "ip": string}` | `user_session` |
| `system.alert` | `{"level": string, "message": string}` | (none) |

## 4.3 Example Events

```json
// sensor.reading — aggregate_id is the device
{"event_type": "sensor.reading", "aggregate_id": "device-001", "payload": {"value": 72.5, "unit": "fahrenheit"}}

// user.login — aggregate_id is the user
{"event_type": "user.login", "aggregate_id": "user-123", "payload": {"user_id": "user-123", "ip": "192.168.1.1"}}

// system.alert — aggregate_id is the source component
{"event_type": "system.alert", "aggregate_id": "cluster-1", "payload": {"level": "warn", "message": "High memory usage"}}
```

## 4.4 Projections

| Projection Type | Purpose | Updated By |
|-----------------|---------|------------|
| `sensor_state` | Latest sensor reading per device | `sensor.reading` |
| `user_session` | Last login info per user | `user.login` |

New event types and projections are added as features require them.
