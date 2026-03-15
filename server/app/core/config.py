from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    """Application configuration loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    database_url: str = "postgresql+asyncpg://lifelens:lifelens@localhost:5432/lifelens"

    # API - accept comma-separated string or use default
    api_keys: str = "test-key,dev-key"

    @property
    def api_keys_list(self) -> List[str]:
        """Parse comma-separated API keys into a list."""
        return [k.strip() for k in self.api_keys.split(",") if k.strip()]

    # Server
    app_name: str = "LifeLens"
    app_version: str = "0.1.0"
    debug: bool = False

    # CORS
    cors_origins: str = "http://localhost:5173,http://localhost:3000,http://localhost:8000"

    @property
    def cors_origins_list(self) -> List[str]:
        """Parse comma-separated CORS origins into a list."""
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
