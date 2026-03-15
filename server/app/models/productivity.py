from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class ProductivityCategory(str, Enum):
    """Productivity categories inferred from app usage."""
    WORK = "work"
    STUDY = "study"
    LEISURE = "leisure"
    COMMUNICATION = "communication"
    OTHER = "other"


class ProductivityData(BaseModel):
    """Productivity tracking data from desktop apps."""

    device_id: str = Field(..., description="Unique device identifier")
    app_name: str = Field(..., description="Application name")
    window_title: str | None = Field(default=None, description="Window title")
    category: ProductivityCategory | None = Field(default=None, description="Inferred category")
    duration_seconds: int = Field(..., description="Duration in seconds")
    input_activity: dict | None = Field(default=None, description="Keystrokes/min, clicks/min")
    timestamp: datetime = Field(..., description="ISO 8601 timestamp")
    platform: str = Field(..., description="Platform: 'macos' or 'windows'")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }


class ProductivityDataBatch(BaseModel):
    """Batch of productivity data records."""

    records: list[ProductivityData] = Field(..., min_length=1, max_length=100)
