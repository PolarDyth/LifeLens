"""Continuous aggregates for hourly/daily/weekly summaries.

Revision ID: 002_continuous_aggregates
Revises: 001_initial
Create Date: 2024-03-14 16:30:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "002_continuous_aggregates"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Health data continuous aggregates
    # Hourly steps
    op.execute("""
        CREATE MATERIALIZED VIEW health_hourly_steps
        WITH (timescaledb.continuous) AS
        SELECT
            time_bucket('1 hour', timestamp) AS bucket,
            device_id,
            AVG(value) AS avg_steps,
            MAX(value) AS max_steps,
            MIN(value) AS min_steps,
            SUM(value) AS total_steps
        FROM health_data
        WHERE data_type = 'steps'
        GROUP BY bucket, device_id;
    """)
    op.execute("""
        SELECT add_continuous_aggregate_policy('health_hourly_steps',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 hour',
            schedule_interval => INTERVAL '1 hour'
        );
    """)

    # Daily summary
    op.execute("""
        CREATE MATERIALIZED VIEW health_daily_summary
        WITH (timescaledb.continuous) AS
        SELECT
            time_bucket('1 day', timestamp) AS bucket,
            device_id,
            data_type,
            AVG(value) AS avg_value,
            MAX(value) AS max_value,
            MIN(value) AS min_value,
            COUNT(*) AS record_count
        FROM health_data
        GROUP BY bucket, device_id, data_type;
    """)
    op.execute("""
        SELECT add_continuous_aggregate_policy('health_daily_summary',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 day',
            schedule_interval => INTERVAL '1 hour'
        );
    """)

    # Productivity data continuous aggregates
    # Daily screen time by app
    op.execute("""
        CREATE MATERIALIZED VIEW productivity_daily_screen_time
        WITH (timescaledb.continuous) AS
        SELECT
            time_bucket('1 day', timestamp) AS bucket,
            device_id,
            app_name,
            SUM(duration_seconds) AS total_duration_seconds,
            COUNT(*) AS record_count
        FROM productivity_data
        GROUP BY bucket, device_id, app_name;
    """)
    op.execute("""
        SELECT add_continuous_aggregate_policy('productivity_daily_screen_time',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 day',
            schedule_interval => INTERVAL '1 hour'
        );
    """)

    # Hourly activity level (for unproductive time inference)
    op.execute("""
        CREATE MATERIALIZED VIEW productivity_hourly_activity
        WITH (timescaledb.continuous) AS
        SELECT
            time_bucket('1 hour', timestamp) AS bucket,
            device_id,
            SUM(duration_seconds) AS total_active_seconds,
            COUNT(*) AS app_switches,
            COUNT(DISTINCT app_name) AS unique_apps
        FROM productivity_data
        GROUP BY bucket, device_id;
    """)
    op.execute("""
        SELECT add_continuous_aggregate_policy('productivity_hourly_activity',
            start_offset => INTERVAL '1 month',
            end_offset => INTERVAL '1 hour',
            schedule_interval => INTERVAL '1 hour'
        );
    """)


def downgrade() -> None:
    # Drop continuous aggregates
    op.execute("SELECT remove_continuous_aggregate_policy('productivity_hourly_activity', if_exists => TRUE);")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS productivity_hourly_activity;")

    op.execute("SELECT remove_continuous_aggregate_policy('productivity_daily_screen_time', if_exists => TRUE);")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS productivity_daily_screen_time;")

    op.execute("SELECT remove_continuous_aggregate_policy('health_daily_summary', if_exists => TRUE);")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS health_daily_summary;")

    op.execute("SELECT remove_continuous_aggregate_policy('health_hourly_steps', if_exists => TRUE);")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS health_hourly_steps;")
