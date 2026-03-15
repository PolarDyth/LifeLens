from sqlalchemy import Column, BigInteger, String, Float, DateTime, JSON, Integer, func
from app.db.connection import Base


class HealthDataDB(Base):
    """SQLAlchemy model for health_data table."""

    __tablename__ = "health_data"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String, nullable=False, index=True)
    data_type = Column(String, nullable=False)
    value = Column(Float, nullable=False)
    unit = Column(String, nullable=False)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    meta = Column("metadata", JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class ProductivityDataDB(Base):
    """SQLAlchemy model for productivity_data table."""

    __tablename__ = "productivity_data"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String, nullable=False, index=True)
    app_name = Column(String, nullable=False)
    window_title = Column(String, nullable=True)
    category = Column(String, nullable=True)
    duration_seconds = Column(Integer, nullable=False)
    input_activity = Column(JSON, nullable=True)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    platform = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class LocationDataDB(Base):
    """SQLAlchemy model for location_data table."""

    __tablename__ = "location_data"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String, nullable=False, index=True)
    location_type = Column(String, nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True, index=True)
    place_name = Column(String, nullable=True)
    horizontal_accuracy = Column(Float, nullable=True)
    timestamp = Column(DateTime(timezone=True), nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
