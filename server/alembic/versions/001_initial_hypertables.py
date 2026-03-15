"""Initial hypertables for health, productivity, and location data.

Revision ID: 001_initial
Revises:
Create Date: 2024-03-14 16:00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enable TimescaleDB extension
    op.execute("CREATE EXTENSION IF NOT EXISTS timescaledb;")

    # Create health_data hypertable
    op.create_table(
        "health_data",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("data_type", sa.String(), nullable=False),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("unit", sa.String(), nullable=False),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("metadata", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute("SELECT create_hypertable('health_data', 'timestamp', if_not_exists => TRUE);")
    op.create_index("ix_health_data_device_timestamp", "health_data", ["device_id", "timestamp"])

    # Create productivity_data hypertable
    op.create_table(
        "productivity_data",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("app_name", sa.String(), nullable=False),
        sa.Column("window_title", sa.String(), nullable=True),
        sa.Column("category", sa.String(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("input_activity", sa.JSON(), nullable=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("platform", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute("SELECT create_hypertable('productivity_data', 'timestamp', if_not_exists => TRUE);")
    op.create_index("ix_productivity_data_device_timestamp", "productivity_data", ["device_id", "timestamp"])

    # Create location_data hypertable
    op.create_table(
        "location_data",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("device_id", sa.String(), nullable=False),
        sa.Column("location_type", sa.String(), nullable=False),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("place_name", sa.String(), nullable=True),
        sa.Column("horizontal_accuracy", sa.Float(), nullable=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.execute("SELECT create_hypertable('location_data', 'timestamp', if_not_exists => TRUE);")
    op.create_index("ix_location_data_device_timestamp", "location_data", ["device_id", "timestamp"])
    op.create_index("ix_location_data_coords", "location_data", ["latitude", "longitude"])


def downgrade() -> None:
    # Drop tables (TimescaleDB will drop hypertable metadata automatically)
    op.drop_table("location_data")
    op.drop_table("productivity_data")
    op.drop_table("health_data")
