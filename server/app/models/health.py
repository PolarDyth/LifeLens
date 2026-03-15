from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class HealthDataType(str, Enum):
    """Types of health data collected by HealthKit."""
    STEPS = "steps"
    HEART_RATE = "heart_rate"
    HEART_RATE_VARIABILITY = "heart_rate_variability"
    ACTIVE_ENERGY = "active_energy"
    RESTING_HEART_RATE = "resting_heart_rate"
    SLEEP_ANALYSIS = "sleep_analysis"
    WORKOUT = "workout"


class HealthData(BaseModel):
    """Health data record from iOS HealthKit."""

    device_id: str = Field(..., description="Unique device identifier")
    data_type: HealthDataType = Field(..., description="Type of health data")
    value: float = Field(..., description="Measured value")
    unit: str = Field(..., description="Unit of measurement (e.g., 'count', 'bpm', 'kcal')")
    timestamp: datetime = Field(..., description="ISO 8601 timestamp of measurement")
    metadata: dict | None = Field(default=None, description="Additional optional data")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }


class HealthDataBatch(BaseModel):
    """Batch of health data records for efficient ingestion."""

    records: list[HealthData] = Field(..., min_length=1, max_length=100)
