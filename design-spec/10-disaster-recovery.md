# 10. Disaster Recovery (Dev)

## 10.1 Backup Strategy

**Decision:** No formal backup strategy for dev environment

**Rationale:**
- Dev environment data not business-critical
- Test data can be regenerated as needed
- Infrastructure-as-code (Terraform) enables rapid rebuild

**Data at risk:**
- Postgres: Event store and projections (7-day retention)
- Redpanda: Message buffer (24-hour retention)
- EMQX: Session and configuration data

## 10.2 Recovery Procedures

**Recovery approach:**
1. Redeploy infrastructure using Terraform
2. Deploy latest application containers
3. Regenerate test data using seed scripts

## 10.3 Recovery Objectives

| Objective | Requirement | Notes |
|-----------|-------------|-------|
| RTO | No strict requirement | Several hours acceptable |
| RPO | No strict requirement | Data loss acceptable |

**Decision deferred (Production):**
- Automated snapshots, point-in-time recovery
- Backup retention policies
- Cross-region backup replication
- Automated failover mechanisms
- Blue-green deployment for zero-downtime recovery
- Runbooks for incident response
