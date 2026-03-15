import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_health_check():
    """Test health check endpoint."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_ingest_health_data():
    """Test health data ingestion endpoint."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = {
            "device_id": "test-device",
            "data_type": "steps",
            "value": 1000,
            "unit": "count",
            "timestamp": "2024-01-01T00:00:00Z",
        }
        response = await client.post(
            "/api/v1/ingest/health",
            json=data,
            headers={"X-API-Key": "test-key"},
        )
        assert response.status_code == 201
        assert response.json()["record_count"] == 1


@pytest.mark.asyncio
async def test_ingest_health_data_invalid_api_key():
    """Test that invalid API key is rejected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = {
            "device_id": "test-device",
            "data_type": "steps",
            "value": 1000,
            "unit": "count",
            "timestamp": "2024-01-01T00:00:00Z",
        }
        response = await client.post(
            "/api/v1/ingest/health",
            json=data,
            headers={"X-API-Key": "invalid-key"},
        )
        assert response.status_code == 403


@pytest.mark.asyncio
async def test_ingest_health_data_missing_api_key():
    """Test that missing API key is rejected."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        data = {
            "device_id": "test-device",
            "data_type": "steps",
            "value": 1000,
            "unit": "count",
            "timestamp": "2024-01-01T00:00:00Z",
        }
        response = await client.post("/api/v1/ingest/health", json=data)
        assert response.status_code == 403
