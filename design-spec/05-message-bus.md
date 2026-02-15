# 5. Message Bus Configuration

## 5.1 Topic Design

- **Pattern:** Per-event-type topics
- **Topics:** `sensor-events`, `user-actions`, `system-events`
- **Rationale:** Clean separation, consumers subscribe to needed types, avoids topic explosion

## 5.2 Retention Policy

| Environment | Retention |
|-------------|-----------|
| Dev | 24 hours |
| Staging/Prod | TBD |

## 5.3 Partition Strategy

| Environment | Partitions per Topic |
|-------------|---------------------|
| Dev | 1 |
| Staging/Prod | TBD (based on volume) |

**Rationale (Dev):** Simplest configuration, guaranteed ordering, sufficient for low-traffic dev
