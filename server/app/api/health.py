from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.connection import get_db
from app.core.security import verify_api_key
from app.models.health import HealthData, HealthDataBatch
from app.models import HealthDataDB

router = APIRouter(prefix="/api/v1/ingest/health", tags=["health"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def ingest_health_data(
    data: HealthData,
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
):
    """Ingest a single health data record.

    Args:
        data: Health data record
        db: Database session
        api_key: Validated API key

    Returns:
        Confirmation message
    """
    # Create database record
    db_record = HealthDataDB(
        device_id=data.device_id,
        data_type=data.data_type.value,
        value=data.value,
        unit=data.unit,
        timestamp=data.timestamp,
        meta=data.metadata,
    )
    db.add(db_record)
    await db.commit()

    return {"message": "Health data received", "record_count": 1}


@router.post("/batch", status_code=status.HTTP_201_CREATED)
async def ingest_health_data_batch(
    batch: HealthDataBatch,
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
):
    """Ingest multiple health data records.

    Args:
        batch: Batch of health data records
        db: Database session
        api_key: Validated API key

    Returns:
        Confirmation message with record count
    """
    # Create database records
    db_records = [
        HealthDataDB(
            device_id=record.device_id,
            data_type=record.data_type.value,
            value=record.value,
            unit=record.unit,
            timestamp=record.timestamp,
            meta=record.metadata,
        )
        for record in batch.records
    ]
    db.add_all(db_records)
    await db.commit()

    return {"message": "Health data batch received", "record_count": len(batch.records)}
