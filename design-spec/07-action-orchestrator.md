# 7. Action Orchestrator Configuration

## 7.1 Webhook Retry Logic

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Max retry attempts | 3-5 | Subject to tuning |
| Backoff delays | 1s, 2s, 4s, 8s, 16s | Exponential backoff |
| After max retries | Log failure and continue | No blocking |

## 7.2 Timeout Handling

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Per-webhook timeout | 30 seconds | Subject to tuning |

## 7.3 Rate Limiting

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Global rate limit | 10 webhooks/minute | Subject to tuning |
| Implementation | In-memory tracking | Single-instance dev only |

**Decision deferred:**
- Per-endpoint rate limits for production
- Shared state management (Redis) for multi-instance deployments

## 7.4 Deduplication

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Deduplication window | 5 minutes | Subject to tuning |
| Key | event type + target identifier | |
| Implementation | In-memory cache | State lost on restart |

**Decision deferred:**
- Sophisticated deduplication logic (similarity matching, alert grouping)
- Persistent deduplication state (Redis) for production

## 7.5 Circuit Breaker for Webhooks

| Setting | Initial Default | Notes |
|---------|-----------------|-------|
| Failure threshold | 5 consecutive failures | Triggers blacklist |
| Cooldown period | 5 minutes | TTL-based expiry |
| Storage | Redis | Supports TTL |
