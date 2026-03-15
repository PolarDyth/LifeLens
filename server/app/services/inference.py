from datetime import datetime
from typing import list
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_


class UnproductiveTimeInference:
    """Infers unproductive time periods using negative space analysis.

    When PC is inactive + not moving + not sleeping = likely phone doomscrolling.
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def detect_unproductive_periods(
        self,
        device_id: str,
        start_time: datetime,
        end_time: datetime,
    ) -> list[dict]:
        """Detect unproductive time periods for a device.

        Uses negative space analysis: gaps in productivity data + unchanged GPS location
        + no sleep pattern = likely phone usage.

        Args:
            device_id: Device identifier
            start_time: Start of analysis window
            end_time: End of analysis window

        Returns:
            List of unproductive time periods with start/end timestamps
        """
        from app.models import ProductivityDataDB, LocationDataDB, HealthDataDB

        unproductive_periods = []

        # 1. Find gaps in productivity data (periods with no activity > 10 minutes)
        productivity_query = (
            select(ProductivityDataDB)
            .where(
                and_(
                    ProductivityDataDB.device_id == device_id,
                    ProductivityDataDB.timestamp >= start_time,
                    ProductivityDataDB.timestamp <= end_time,
                )
            )
            .order_by(ProductivityDataDB.timestamp)
        )

        result = await self.db.execute(productivity_query)
        productivity_records = result.scalars().all()

        # Detect gaps between records
        for i in range(len(productivity_records) - 1):
            current_record = productivity_records[i]
            next_record = productivity_records[i + 1]

            gap_duration = (next_record.timestamp - current_record.timestamp).total_seconds()

            # Only consider gaps > 10 minutes as potentially unproductive
            if gap_duration > 600:  # 10 minutes in seconds
                gap_start = current_record.timestamp
                gap_end = next_record.timestamp

                # 2. Check if location was unchanged during gap
                location_query = (
                    select(LocationDataDB)
                    .where(
                        and_(
                            LocationDataDB.device_id == device_id,
                            LocationDataDB.timestamp >= gap_start,
                            LocationDataDB.timestamp <= gap_end,
                        )
                    )
                    .order_by(LocationDataDB.timestamp)
                    .limit(2)
                )

                location_result = await self.db.execute(location_query)
                location_records = location_result.scalars().all()

                not_moving = len(location_records) <= 1 or (
                    len(location_records) == 2
                    and abs(location_records[0].latitude - location_records[1].latitude) < 0.0001
                    and abs(location_records[0].longitude - location_records[1].longitude) < 0.0001
                )

                # 3. Check if user was sleeping during gap
                sleep_query = (
                    select(HealthDataDB)
                    .where(
                        and_(
                            HealthDataDB.device_id == device_id,
                            HealthDataDB.data_type == "sleep_analysis",
                            HealthDataDB.timestamp >= gap_start,
                            HealthDataDB.timestamp <= gap_end,
                        )
                    )
                    .order_by(HealthDataDB.timestamp)
                )

                sleep_result = await self.db.execute(sleep_query)
                sleep_records = sleep_result.scalars().all()

                # Assume sleeping if sleep analysis data exists during gap
                not_sleeping = len(sleep_records) == 0

                # 4. Apply negative space logic
                if self.is_unproductive_window(
                    pc_inactive=True,  # Gap indicates inactivity
                    not_moving=not_moving,
                    not_sleeping=not_sleeping,
                ):
                    unproductive_periods.append({
                        "start": gap_start.isoformat(),
                        "end": gap_end.isoformat(),
                        "duration_minutes": int(gap_duration / 60),
                        "inference": "pc_inactive + not_moving + not_sleeping = likely phone usage",
                        "confidence": "high" if gap_duration > 1800 else "medium",  # >30 min = high confidence
                    })

        return unproductive_periods

    def is_unproductive_window(
        self,
        pc_inactive: bool,
        not_moving: bool,
        not_sleeping: bool,
    ) -> bool:
        """Determine if a time window indicates unproductive phone usage.

        Args:
            pc_inactive: No keyboard/mouse activity for >10 minutes
            not_moving: GPS location unchanged
            not_sleeping: Heart rate pattern shows awake OR reasonable hours (8 AM - 11 PM)

        Returns:
            True if likely unproductive phone usage
        """
        return pc_inactive and not_moving and not_sleeping
