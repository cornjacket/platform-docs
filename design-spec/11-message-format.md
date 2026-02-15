# 11. Message Format

## 11.1 Current Format

| Aspect | Decision |
|--------|----------|
| Format | JSON |
| Scope | Outbox table, event store, Redpanda message bus |
| Serialization | Single path (Ingestion Service serializes once) |

## 11.2 Migration Path

| Phase | Format |
|-------|--------|
| Development | JSON |
| Production | Binary (Protobuf or MessagePack) |

**Decision deferred:** Protobuf vs. MessagePack based on schema stability needs and performance testing
