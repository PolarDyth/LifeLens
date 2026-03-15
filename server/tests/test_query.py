"""Tests for query API endpoints."""
import pytest
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import HealthDataDB, ProductivityDataDB, LocationDataDB


@pytest.mark.asyncio
async def test_get_health_today_no_data(db_session: AsyncSession):
    """Test get_health_today returns zeros when no data exists."""
    from app.api.query import get_health_today

    device_id = "test-device"
    result = await get_health_today(device_id=device_id, db=db_session, api_key="test-key")

    assert result.device_id == device_id
    assert result.steps == 0
    assert result.avg_heart_rate is None


@pytest.mark.asyncio
async def test_get_health_today_with_steps(db_session: AsyncSession):
    """Test get_health_today aggregates step data correctly."""
    from app.api.query import get_health_today

    device_id = "test-device"
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())

    # Insert test data
    record1 = HealthDataDB(
        device_id=device_id,
        data_type="steps",
        value=5000,
        unit="count",
        timestamp=start_of_day.replace(hour=9),
        meta={},
        created_at=datetime.now(),
    )
    record2 = HealthDataDB(
        device_id=device_id,
        data_type="steps",
        value=3432,
        unit="count",
        timestamp=start_of_day.replace(hour=14),
        meta={},
        created_at=datetime.now(),
    )

    db_session.add(record1)
    db_session.add(record2)
    await db_session.commit()

    # Test
    result = await get_health_today(device_id=device_id, db=db_session, api_key="test-key")

    assert result.device_id == device_id
    assert result.steps == 8432  # 5000 + 3432


@pytest.mark.asyncio
async def test_get_health_today_with_heart_rate(db_session: AsyncSession):
    """Test get_health_today calculates heart rate stats correctly."""
    from app.api.query import get_health_today

    device_id = "test-device"
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())

    # Insert heart rate data
    for i, hr in enumerate([60, 65, 70, 75, 72]):
        record = HealthDataDB(
            device_id=device_id,
            data_type="heart_rate",
            value=hr,
            unit="bpm",
            timestamp=start_of_day.replace(hour=8, minute=i*10),
            meta={},
            created_at=datetime.now(),
        )
        db_session.add(record)

    await db_session.commit()

    # Test
    result = await get_health_today(device_id=device_id, db=db_session, api_key="test-key")

    assert result.avg_heart_rate == 68.4  # (60+65+70+75+72)/5
    assert result.min_heart_rate == 60
    assert result.max_heart_rate == 75


@pytest.mark.asyncio
async def test_get_productivity_today_no_data(db_session: AsyncSession):
    """Test get_productivity_today returns zeros when no data exists."""
    from app.api.query import get_productivity_today

    device_id = "test-device"
    result = await get_productivity_today(device_id=device_id, db=db_session, api_key="test-key")

    assert result.device_id == device_id
    assert result.work_seconds == 0
    assert result.total_seconds == 0


@pytest.mark.asyncio
async def test_get_productivity_today_aggregates_categories(db_session: AsyncSession):
    """Test get_productivity_today aggregates time by category correctly."""
    from app.api.query import get_productivity_today

    device_id = "test-device"
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())

    # Insert productivity data
    records = [
        ProductivityDataDB(
            device_id=device_id,
            app_name="VSCode",
            category="work",
            duration_seconds=7200,  # 2 hours
            timestamp=start_of_day.replace(hour=9),
            platform="macos",
            created_at=datetime.now(),
        ),
        ProductivityDataDB(
            device_id=device_id,
            app_name="Chrome",
            category="study",
            duration_seconds=3600,  # 1 hour
            timestamp=start_of_day.replace(hour=11),
            platform="macos",
            created_at=datetime.now(),
        ),
        ProductivityDataDB(
            device_id=device_id,
            app_name="YouTube",
            category="leisure",
            duration_seconds=1800,  # 30 minutes
            timestamp=start_of_day.replace(hour=13),
            platform="macos",
            created_at=datetime.now(),
        ),
    ]

    for record in records:
        db_session.add(record)
    await db_session.commit()

    # Test
    result = await get_productivity_today(device_id=device_id, db=db_session, api_key="test-key")

    assert result.device_id == device_id
    assert result.work_seconds == 7200
    assert result.study_seconds == 3600
    assert result.leisure_seconds == 1800
    assert result.total_seconds == 12600  # 7200 + 3600 + 1800


@pytest.mark.asyncio
async def test_get_recent_locations_no_data(db_session: AsyncSession):
    """Test get_recent_locations returns empty list when no data exists."""
    from app.api.query import get_recent_locations

    device_id = "test-device"
    result = await get_recent_locations(
        device_id=device_id,
        limit=100,
        db=db_session,
        api_key="test-key",
    )

    assert result == []


@pytest.mark.asyncio
async def test_get_recent_locations_returns_gps_tracks(db_session: AsyncSession):
    """Test get_recent_locations returns location data in correct order."""
    from app.api.query import get_recent_locations

    device_id = "test-device"
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())

    # Insert location data
    records = [
        LocationDataDB(
            device_id=device_id,
            location_type="gps",
            latitude=37.7749,
            longitude=-122.4194,
            horizontal_accuracy=5.0,
            timestamp=start_of_day.replace(hour=9),
            created_at=datetime.now(),
        ),
        LocationDataDB(
            device_id=device_id,
            location_type="visit",
            latitude=37.7749,
            longitude=-122.4094,
            place_name="Coffee Shop",
            timestamp=start_of_day.replace(hour=10),
            created_at=datetime.now(),
        ),
    ]

    for record in records:
        db_session.add(record)
    await db_session.commit()

    # Test
    result = await get_recent_locations(
        device_id=device_id,
        limit=100,
        db=db_session,
        api_key="test-key",
    )

    assert len(result) == 2
    assert result[0].latitude == 37.7749
    assert result[0].longitude == -122.4194
    assert result[0].location_type == "visit"  # Most recent first


@pytest.mark.asyncio
async def test_get_recent_locations_respects_limit(db_session: AsyncSession):
    """Test get_recent_locations respects the limit parameter."""
    from app.api.query import get_recent_locations

    device_id = "test-device"
    today = datetime.now().date()
    start_of_day = datetime.combine(today, datetime.min.time())

    # Insert 150 location records
    for i in range(150):
        record = LocationDataDB(
            device_id=device_id,
            location_type="gps",
            latitude=37.7749 + (i * 0.0001),
            longitude=-122.4194,
            horizontal_accuracy=5.0,
            timestamp=start_of_day.replace(hour=i // 24),
            created_at=datetime.now(),
        )
        db_session.add(record)

    await db_session.commit()

    # Test with limit=10
    result = await get_recent_locations(
        device_id=device_id,
        limit=10,
        db=db_session,
        api_key="test-key",
    )

    assert len(result) == 10
