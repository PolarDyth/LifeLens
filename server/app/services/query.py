from datetime import datetime, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
from typing import list


class QueryService:
    """Service for querying raw and aggregated time-series data."""

    async def get_health_data(
        self,
        db: AsyncSession,
        device_id: str,
        data_type: str,
        start_time: datetime,
        end_time: datetime,
        aggregate: str = "raw",  # raw, hourly, daily
    ) -> list[dict]:
        """Query health data with optional aggregation.

        Args:
            db: Database session
            device_id: Device identifier
            data_type: Health data type
            start_time: Start of query window
            end_time: End of query window
            aggregate: Aggregation level (raw, hourly, daily)

        Returns:
            List of health data records
        """
        if aggregate == "hourly" and data_type == "steps":
            # Use continuous aggregate for hourly steps
            query = text("""
                SELECT bucket, device_id, avg_steps, max_steps, min_steps, total_steps
                FROM health_hourly_steps
                WHERE device_id = :device_id
                  AND bucket >= :start_time AND bucket < :end_time
                ORDER BY bucket DESC;
            """)
        elif aggregate == "daily":
            # Use continuous aggregate for daily summary
            query = text("""
                SELECT bucket, device_id, data_type, avg_value, max_value, min_value, record_count
                FROM health_daily_summary
                WHERE device_id = :device_id
                  AND data_type = :data_type
                  AND bucket >= :start_time AND bucket < :end_time
                ORDER BY bucket DESC;
            """)
        else:
            # Query raw data
            query = text("""
                SELECT device_id, data_type, value, unit, timestamp, metadata
                FROM health_data
                WHERE device_id = :device_id
                  AND data_type = :data_type
                  AND timestamp >= :start_time AND timestamp < :end_time
                ORDER BY timestamp DESC
                LIMIT 1000;
            """)

        result = await db.execute(query, {
            "device_id": device_id,
            "data_type": data_type,
            "start_time": start_time,
            "end_time": end_time,
        })

        return [dict(row._mapping) for row in result]

    async def get_productivity_data(
        self,
        db: AsyncSession,
        device_id: str,
        start_time: datetime,
        end_time: datetime,
        aggregate: str = "daily",
    ) -> list[dict]:
        """Query productivity data with aggregation.

        Args:
            db: Database session
            device_id: Device identifier
            start_time: Start of query window
            end_time: End of query window
            aggregate: Aggregation level (raw, daily)

        Returns:
            List of productivity data records
        """
        if aggregate == "daily":
            query = text("""
                SELECT bucket, device_id, app_name, total_duration_seconds, record_count
                FROM productivity_daily_screen_time
                WHERE device_id = :device_id
                  AND bucket >= :start_time AND bucket < :end_time
                ORDER BY bucket DESC, total_duration_seconds DESC;
            """)
        else:
            query = text("""
                SELECT device_id, app_name, window_title, category, duration_seconds, input_activity, timestamp, platform
                FROM productivity_data
                WHERE device_id = :device_id
                  AND timestamp >= :start_time AND timestamp < :end_time
                ORDER BY timestamp DESC
                LIMIT 1000;
            """)

        result = await db.execute(query, {
            "device_id": device_id,
            "start_time": start_time,
            "end_time": end_time,
        })

        return [dict(row._mapping) for row in result]

    async def get_unproductive_periods(
        self,
        db: AsyncSession,
        device_id: str,
        start_time: datetime,
        end_time: datetime,
    ) -> list[dict]:
        """Detect unproductive time periods using hourly activity data.

        Unproductive = no PC activity (hourly_active_seconds < 60)

        Args:
            db: Database session
            device_id: Device identifier
            start_time: Start of query window
            end_time: End of query window

        Returns:
            List of unproductive time periods
        """
        query = text("""
            SELECT bucket, device_id,
                   total_active_seconds,
                   app_switches,
                   unique_apps
            FROM productivity_hourly_activity
            WHERE device_id = :device_id
              AND bucket >= :start_time AND bucket < :end_time
              AND total_active_seconds < 60  -- Less than 1 minute of activity per hour
            ORDER BY bucket DESC;
        """)

        result = await db.execute(query, {
            "device_id": device_id,
            "start_time": start_time,
            "end_time": end_time,
        })

        return [dict(row._mapping) for row in result]
