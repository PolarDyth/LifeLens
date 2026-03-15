from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.connection import get_db
from app.core.security import verify_api_key
from app.models.productivity import ProductivityData, ProductivityDataBatch
from app.models.location import LocationData, LocationDataBatch
from app.models import ProductivityDataDB, LocationDataDB

router = APIRouter(prefix="/api/v1/ingest", tags=["ingest"])


@router.post("/productivity", status_code=status.HTTP_201_CREATED)
async def ingest_productivity_data(
    data: ProductivityData,
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
):
    """Ingest a single productivity data record."""
    db_record = ProductivityDataDB(
        device_id=data.device_id,
        app_name=data.app_name,
        window_title=data.window_title,
        category=data.category.value if data.category else None,
        duration_seconds=data.duration_seconds,
        input_activity=data.input_activity,
        timestamp=data.timestamp,
        platform=data.platform,
    )
    db.add(db_record)
    await db.commit()

    return {"message": "Productivity data received", "record_count": 1}


@router.post("/productivity/batch", status_code=status.HTTP_201_CREATED)
async def ingest_productivity_data_batch(
    batch: ProductivityDataBatch,
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
):
    """Ingest multiple productivity data records."""
    db_records = [
        ProductivityDataDB(
            device_id=record.device_id,
            app_name=record.app_name,
            window_title=record.window_title,
            category=record.category.value if record.category else None,
            duration_seconds=record.duration_seconds,
            input_activity=record.input_activity,
            timestamp=record.timestamp,
            platform=record.platform,
        )
        for record in batch.records
    ]
    db.add_all(db_records)
    await db.commit()

    return {"message": "Productivity data batch received", "record_count": len(batch.records)}


@router.post("/location", status_code=status.HTTP_201_CREATED)
async def ingest_location_data(
    data: LocationData,
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
):
    """Ingest a single location data record."""
    db_record = LocationDataDB(
        device_id=data.device_id,
        location_type=data.location_type.value,
        latitude=data.latitude,
        longitude=data.longitude,
        place_name=data.place_name,
        horizontal_accuracy=data.horizontal_accuracy,
        timestamp=data.timestamp,
    )
    db.add(db_record)
    await db.commit()

    return {"message": "Location data received", "record_count": 1}


@router.post("/location/batch", status_code=status.HTTP_201_CREATED)
async def ingest_location_data_batch(
    batch: LocationDataBatch,
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
):
    """Ingest multiple location data records."""
    db_records = [
        LocationDataDB(
            device_id=record.device_id,
            location_type=record.location_type.value,
            latitude=record.latitude,
            longitude=record.longitude,
            place_name=record.place_name,
            horizontal_accuracy=record.horizontal_accuracy,
            timestamp=record.timestamp,
        )
        for record in batch.records
    ]
    db.add_all(db_records)
    await db.commit()

    return {"message": "Location data batch received", "record_count": len(batch.records)}
