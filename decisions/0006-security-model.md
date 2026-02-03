# ADR 0006: Security Model

* **Status:** Accepted
* **Date:** 2026-01-29
* **Architect:** David

## Context

The platform handles data from multiple sources (HTTP clients, IoT devices) and requires a security model that balances "Security by Design" principles with development simplicity for a single-developer project.

## Decision

### HTTP API Authentication: JWT at the Gateway

| Aspect | Decision |
|--------|----------|
| **Mechanism** | JWT-based authentication |
| **Enforcement Point** | API Gateway (Traefik ForwardAuth middleware) |
| **Scope** | All HTTP API requests |

**Rationale:**
- Industry standard token-based auth
- Stateless (no session management needed)
- Centralized auth at the gateway keeps application code simpler
- Rejected requests never reach the application layer

**Deferred Decisions:**
- Authorization/RBAC policies (may require app-layer logic for fine-grained permissions)
- JWT token lifetime and refresh strategy
- Identity provider integration

### MQTT Authentication: Username/Password

| Aspect | Decision |
|--------|----------|
| **Mechanism** | Username/password authentication |
| **Enforcement Point** | EMQX built-in auth |
| **Scope** | All MQTT connections |

**Rationale:**
- Simple, sufficient for dev environment
- EMQX native support, no additional infrastructure

**Deferred Decisions:**
- Client certificate authentication (mutual TLS) for production
- Fine-grained ACL policies per device/topic

### Secrets Management: Hybrid Approach

| Environment | Approach |
|-------------|----------|
| **Local development** | Environment variables from `.env` files |
| **AWS dev environment** | AWS Secrets Manager |

**Secrets Managed:**
- JWT signing keys
- Database credentials
- MQTT broker passwords
- External service API keys

**Rationale:**
- Local dev remains simple without AWS dependencies
- AWS dev uses proper secrets management practices
- Same application code supports both environments with fallback logic
- Prepares migration path to production

**Deferred Decisions:**
- Secret rotation policies
- Access audit logging
- HashiCorp Vault evaluation for production

### Inter-Service Authentication

**Current State:** All containers share the same ECS task and communicate over localhost. No inter-service authentication required — services trust each other implicitly within the task boundary.

**Deferred (for microservices extraction):**
- Mutual TLS (mTLS) between services
- Service mesh (e.g., AWS App Mesh) for identity and traffic management
- IAM-based authentication for AWS-native service-to-service calls

### Input Validation: Boundary Enforcement

**Principle:** Validate all external input at the system boundary (Ingestion Service)

| Principle | Description |
|-----------|-------------|
| **Schema validation** | Reject malformed payloads before processing |
| **Size limits** | Enforce limits to prevent resource exhaustion |
| **Content sanitization** | Sanitize or reject unexpected/dangerous content |
| **Rate limiting** | Rate limit per client to prevent abuse |
| **Fail closed** | Reject uncertain input rather than accepting it |

**Rationale:**
- External data (HTTP, MQTT) is untrusted by default
- Validation at the boundary protects all downstream components
- Consistent with "Security by Design" goal

**Deferred Decisions:**
- Specific schema validation library/approach
- Exact size limits and rate limits per endpoint
- Sanitization rules based on payload content types

### Network Security (Dev Environment)

| Aspect | Dev Environment |
|--------|-----------------|
| **Public exposure** | HTTP (port 80), MQTT (port 1883), dashboards (Traefik 8180, EMQX 18083) |
| **Internal only** | Postgres (5432), Redpanda (9092) - no public internet access |
| **Security groups** | Allow broad IP ranges for testing flexibility |
| **TLS** | No TLS (plain HTTP and MQTT for simpler debugging) |
| **Encryption at rest** | Unencrypted EFS volumes |

**Rationale:**
- Development environment not exposed to production traffic
- Simplified debugging and testing
- Cost optimization (no certificate management)

**Deferred Decisions (Production):**
- TLS/HTTPS for all HTTP traffic
- MQTT over TLS
- Encryption at rest for persistent volumes
- Strict security group policies (least privilege)
- VPC isolation and network segmentation
- WAF and DDoS protection

## Consequences

### Benefits
- Simple, well-understood security model for dev environment
- JWT at gateway centralizes authentication logic
- Clear separation between dev-acceptable and production-required security measures

### Trade-offs
- Dev environment has intentionally relaxed security
- No TLS in dev means some security bugs only surface in production
- Multiple auth mechanisms (JWT for HTTP, username/password for MQTT)

## Related ADRs
- ADR-0001: Event-Driven CQRS Architecture
- ADR-0005: Infrastructure Technology Choices
- ADR-0007: Local and Cloud Development Strategy
