# LifeLens Server

Home server for LifeLens - a privacy-focused life tracking application.

## Prerequisites

- Docker and Docker Compose installed
- Ports 8000 (API) and 5432 (database) available

## Quick Start

1. Start the server:
```bash
cd server
docker-compose up -d
```

2. Verify health check:
```bash
curl http://localhost:8000/health
# Expected: {"status":"ok","version":"0.1.0"}
```

3. Check TimescaleDB extension:
```bash
docker-compose logs db | grep "TimescaleDB"
```

4. View logs:
```bash
docker-compose logs -f server
```

## Configuration

Environment variables (set in `docker-compose.yml` or `.env`):

- `DATABASE_URL`: PostgreSQL connection string (default: `postgresql+asyncpg://lifelens:lifelens@db:5432/lifelens`)
- `API_KEYS`: Comma-separated list of valid API keys (default: `test-key,dev-key`)
- `DEBUG`: Enable debug logging (default: `false`)

## API Endpoints

- `GET /health` - Health check endpoint
- `POST /api/v1/ingest/health` - Ingest health data
- `POST /api/v1/ingest/productivity` - Ingest productivity data
- `POST /api/v1/ingest/location` - Ingest location data

## Development

Run tests:
```bash
pytest
```

Run with hot reload:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Stopping

```bash
docker-compose down
```

To remove all data:
```bash
docker-compose down -v
```
