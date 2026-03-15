from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from datetime import datetime, timedelta
from typing import Optional
from app.db.connection import get_db
from app.core.security import verify_api_key
from app.models import HealthDataDB, ProductivityDataDB, LocationDataDB

router = APIRouter(prefix="/api/v1/query", tags=["query"])


# Pydantic models for query responses
class HealthSummary(BaseModel):
    """Summary of health metrics for a time period."""
    device_id: str
    date: str
    steps: int
    avg_heart_rate: Optional[float]
    min_heart_rate: Optional[float]
    max_heart_rate: Optional[float]
    sleep_duration_hours: Optional[float]
    active_calories: Optional[float]
    distance_km: Optional[float]

    class Config:
        from_attributes = True


class ProductivityBreakdown(BaseModel):
    """Productivity time breakdown by category."""
    device_id: str
    date: str
    work_seconds: int
    study_seconds: int
    leisure_seconds: int
    communication_seconds: int
    other_seconds: int
    total_seconds: int

    class Config:
        from_attributes = True


class LocationTrack(BaseModel):
    """GPS track data."""
    device_id: str
    timestamp: str
    latitude: float
    longitude: float
    location_type: str
    place_name: Optional[str]

    class Config:
        from_attributes = True


class PlaceVisit(BaseModel):
    """Place visit data."""
    device_id: str
    arrival_time: str
    departure_time: Optional[str]
    latitude: float
    longitude: float
    place_name: Optional[str]

    class Config:
        from_attributes = True


@router.get("/health/today")
async def get_health_today(
    device_id: str = Query(..., description="Device identifier"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> HealthSummary:
    """Get today's health summary for a device.

    Returns aggregated steps, heart rate stats, and sleep duration for today.
    """
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())
    end_of_day = datetime.combine(today, datetime.max.time())

    # Query today's health data
    query = (
        select(HealthDataDB)
        .where(
            and_(
                HealthDataDB.device_id == device_id,
                HealthDataDB.timestamp >= start_of_day,
                HealthDataDB.timestamp < end_of_day,
            )
        )
        .order_by(HealthDataDB.timestamp)
    )

    result = await db.execute(query)
    records = result.scalars().all()

    if not records:
        return HealthSummary(
            device_id=device_id,
            date=today.isoformat(),
            steps=0,
            avg_heart_rate=None,
            min_heart_rate=None,
            max_heart_rate=None,
            sleep_duration_hours=None,
            active_calories=None,
            distance_km=None,
        )

    # Aggregate data
    steps = sum(r.value for r in records if r.data_type == "steps")
    heart_rates = [r.value for r in records if r.data_type == "heart_rate" and r.value]
    sleep_records = [r for r in records if r.data_type == "sleep_analysis"]
    active_calories = sum(r.value for r in records if r.data_type == "active_energy")
    distance = sum(r.value for r in records if r.data_type == "distance") / 1000  # Convert m to km

    avg_hr = sum(heart_rates) / len(heart_rates) if heart_rates else None
    min_hr = min(heart_rates) if heart_rates else None
    max_hr = max(heart_rates) if heart_rates else None

    # Calculate sleep duration from sleep analysis records
    sleep_duration_hours = None
    if sleep_records:
        # Sleep records should have duration in metadata or we can calculate from time range
        # For now, return the first sleep record's value if available
        sleep_duration_hours = sum(
            r.meta.get("duration_seconds", 0) / 3600 if r.meta else 0
            for r in sleep_records
        ) or None

    return HealthSummary(
        device_id=device_id,
        date=today.isoformat(),
        steps=int(steps),
        avg_heart_rate=avg_hr,
        min_heart_rate=min_hr,
        max_heart_rate=max_hr,
        sleep_duration_hours=sleep_duration_hours,
        active_calories=int(active_calories),
        distance_km=round(distance, 2),
    )


@router.get("/productivity/today")
async def get_productivity_today(
    device_id: str = Query(..., description="Device identifier"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> ProductivityBreakdown:
    """Get today's productivity breakdown by category.

    Returns time spent in work, study, leisure, communication, and other apps.
    """
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())
    end_of_day = datetime.combine(today, datetime.max.time())

    # Query today's productivity data
    query = (
        select(ProductivityDataDB)
        .where(
            and_(
                ProductivityDataDB.device_id == device_id,
                ProductivityDataDB.timestamp >= start_of_day,
                ProductivityDataDB.timestamp < end_of_day,
            )
        )
        .order_by(ProductivityDataDB.timestamp)
    )

    result = await db.execute(query)
    records = result.scalars().all()

    # Aggregate by category
    categories = {
        "work": 0,
        "study": 0,
        "leisure": 0,
        "communication": 0,
        "other": 0,
    }

    for record in records:
        category = record.category or "other"
        if category not in categories:
            category = "other"
        categories[category] += record.duration_seconds

    total_seconds = sum(categories.values())

    return ProductivityBreakdown(
        device_id=device_id,
        date=today.isoformat(),
        work_seconds=categories["work"],
        study_seconds=categories["study"],
        leisure_seconds=categories["leisure"],
        communication_seconds=categories["communication"],
        other_seconds=categories["other"],
        total_seconds=total_seconds,
    )


@router.get("/location/recent")
async def get_recent_locations(
    device_id: str = Query(..., description="Device identifier"),
    limit: int = Query(100, ge=1, le=1000, description="Max number of records"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> list[LocationTrack]:
    """Get recent GPS tracks and place visits.

    Returns the most recent location records including both GPS updates and place visits.
    """
    # Query recent location data
    query = (
        select(LocationDataDB)
        .where(LocationDataDB.device_id == device_id)
        .order_by(desc(LocationDataDB.timestamp))
        .limit(limit)
    )

    result = await db.execute(query)
    records = result.scalars().all()

    # Convert to response format
    location_tracks = [
        LocationTrack(
            device_id=r.device_id,
            timestamp=r.timestamp.isoformat(),
            latitude=r.latitude or 0.0,
            longitude=r.longitude or 0.0,
            location_type=r.location_type,
            place_name=r.place_name,
        )
        for r in records
    ]

    return location_tracks


@router.get("/health/history")
async def get_health_history(
    device_id: str = Query(..., description="Device identifier"),
    days: int = Query(7, ge=1, le=365, description="Number of days"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> list[dict]:
    """Get daily health data for the last N days.

    Returns daily steps, heart rate, and other metrics for each day.
    """
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=days-1)

    daily_data = []

    for i in range(days):
        current_date = start_date + timedelta(days=i)
        start_of_day = datetime.combine(current_date, datetime.min.time())
        end_of_day = datetime.combine(current_date, datetime.max.time())

        query = (
            select(HealthDataDB)
            .where(
                and_(
                    HealthDataDB.device_id == device_id,
                    HealthDataDB.timestamp >= start_of_day,
                    HealthDataDB.timestamp < end_of_day,
                )
            )
        )
        result = await db.execute(query)
        records = result.scalars().all()

        steps = sum(r.value for r in records if r.data_type == "steps")
        heart_rates = [r.value for r in records if r.data_type == "heart_rate" and r.value]
        active_calories = sum(r.value for r in records if r.data_type == "active_energy")

        daily_data.append({
            "date": current_date.isoformat(),
            "steps": steps,
            "avg_heart_rate": sum(heart_rates) / len(heart_rates) if heart_rates else None,
            "min_heart_rate": min(heart_rates) if heart_rates else None,
            "max_heart_rate": max(heart_rates) if heart_rates else None,
            "active_calories": active_calories,
        })

    return daily_data


@router.get("/productivity/by-app")
async def get_productivity_by_app(
    device_id: str = Query(..., description="Device identifier"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> list[dict]:
    """Get today's productivity broken down by application.

    Returns time spent per app, sorted by duration.
    """
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())
    end_of_day = datetime.combine(today, datetime.max.time())

    query = (
        select(ProductivityDataDB)
        .where(
            and_(
                ProductivityDataDB.device_id == device_id,
                ProductivityDataDB.timestamp >= start_of_day,
                ProductivityDataDB.timestamp < end_of_day,
            )
        )
    )

    result = await db.execute(query)
    records = result.scalars().all()

    # Group by app name
    app_times = {}
    for record in records:
        app_name = record.app_name or "Unknown"
        if app_name not in app_times:
            app_times[app_name] = {
                "app_name": app_name,
                "duration_seconds": 0,
                "category": record.category or "other",
            }
        app_times[app_name]["duration_seconds"] += record.duration_seconds

    # Sort by duration descending
    sorted_apps = sorted(app_times.values(), key=lambda x: x["duration_seconds"], reverse=True)

    return sorted_apps


@router.get("/location/stats")
async def get_location_stats(
    device_id: str = Query(..., description="Device identifier"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> dict:
    """Get location statistics for today.

    Returns distance traveled, places visited, and time outside.
    """
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())

    query = (
        select(LocationDataDB)
        .where(
            and_(
                LocationDataDB.device_id == device_id,
                LocationDataDB.timestamp >= start_of_day,
            )
        )
        .order_by(LocationDataDB.timestamp)
    )

    result = await db.execute(query)
    records = result.scalars().all()

    # Calculate statistics
    unique_places = set()
    total_distance = 0.0
    last_coords = None

    for record in records:
        if record.location_type == "place_visit" and record.place_name:
            unique_places.add(record.place_name)

        if record.latitude and record.longitude:
            if last_coords:
                # Simple distance calculation (haversine would be better)
                lat_diff = abs(record.latitude - last_coords[0])
                lon_diff = abs(record.longitude - last_coords[1])
                total_distance += (lat_diff + lon_diff) * 111  # Rough km conversion
            last_coords = (record.latitude, record.longitude)

    return {
        "device_id": device_id,
        "date": today.isoformat(),
        "distance_km": round(total_distance, 2),
        "places_visited": len(unique_places),
        "time_outside_minutes": sum(r.duration_seconds for r in records if hasattr(r, 'duration_seconds')) // 60,
    }


@router.get("/stats/summary")
async def get_overall_stats(
    device_id: str = Query(..., description="Device identifier"),
    days: int = Query(7, ge=1, le=365, description="Number of days to summarize"),
    db: AsyncSession = Depends(get_db),
    api_key: str = Depends(verify_api_key),
) -> dict:
    """Get overall statistics summary for a device over the specified time period.

    Returns daily averages and totals for key metrics.
    """
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=days)

    # This is a placeholder - in production you'd use continuous aggregates
    return {
        "device_id": device_id,
        "period_days": days,
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "average_steps_per_day": 0,
        "average_screen_time_hours": 0,
        "average_sleep_hours": 0,
        "note": "Aggregated statistics not yet implemented - use continuous aggregates in production",
    }
