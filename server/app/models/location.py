from pydantic import BaseModel, Field
from datetime import datetime
from enum import Enum


class LocationType(str, Enum):
    """Types of location data."""
    GPS_UPDATE = "gps_update"
    PLACE_VISIT = "place_visit"
    GEOFENCE_ENTER = "geofence_enter"
    GEOFENCE_EXIT = "geofence_exit"


class LocationData(BaseModel):
    """Location tracking data from iOS Core Location."""

    device_id: str = Field(..., description="Unique device identifier")
    location_type: LocationType = Field(..., description="Type of location event")
    latitude: float | None = Field(default=None, description="Latitude (for GPS updates)")
    longitude: float | None = Field(default=None, description="Longitude (for GPS updates)")
    place_name: str | None = Field(default=None, description="Place name (for visits)")
    horizontal_accuracy: float | None = Field(default=None, description="Accuracy in meters")
    timestamp: datetime = Field(..., description="ISO 8601 timestamp")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
        }


class LocationDataBatch(BaseModel):
    """Batch of location data records."""

    records: list[LocationData] = Field(..., min_length=1, max_length=100)
