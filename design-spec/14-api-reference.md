# 14. API Reference

API endpoints are defined using OpenAPI 3.0 specifications in `platform-services/api/openapi/`.

| Service | Spec File | Port | Description |
|---------|-----------|------|-------------|
| Ingestion | `ingestion.yaml` | 8080 | Event ingestion (POST /api/v1/events) |
| Query | `query.yaml` | 8081 | Projection queries (GET /api/v1/projections/*) |

**Viewing the specs:**

```bash
# Install a viewer (optional)
npm install -g @redocly/cli

# Preview Ingestion API docs
redocly preview-docs platform-services/api/openapi/ingestion.yaml

# Preview Query API docs
redocly preview-docs platform-services/api/openapi/query.yaml
```

The OpenAPI specs are the source of truth for API contracts. See individual spec files for:
- Endpoint paths and methods
- Request/response schemas
- Example payloads
- Error responses
