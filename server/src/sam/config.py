from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SAM_")
    database_url: str = "postgresql+psycopg://sam:sam@localhost:5432/sam"
    simulation_enabled: bool = True
    tick_seconds: float = 2.0
    link_idle_seconds: int = 300
    confirmation_seconds: int = 60
    session_seconds: int = 86400
    log_retention_days: int = 30
    audit_retention_days: int = 90


settings = Settings()
