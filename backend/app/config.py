from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "mysql+pymysql://travel:travel@localhost:3306/travel_log"

    session_cookie_name: str = "session"
    session_lifetime_hours: int = 24 * 7
    # Set to True in production (HTTPS). Keep False for local HTTP development.
    cookie_secure: bool = False

    login_max_failed_attempts: int = Field(default=5, ge=2)
    login_failure_window_minutes: int = Field(default=15, ge=1)
    login_lockout_minutes: int = Field(default=15, ge=1)

    cors_origins: str = "http://localhost:5173"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
