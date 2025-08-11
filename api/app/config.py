import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # MongoDB Configuration
    MONGODB_URL: str = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
    MONGODB_DB: str = os.getenv("MONGODB_DB", "rideshare")
    
    # JWT Configuration
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-here")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    
    # OSRM Configuration
    OSRM_URL: str = os.getenv("OSRM_URL", "http://router.project-osrm.org")
    
    # API Configuration
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "RideShare API"
    
    # CORS Configuration
    BACKEND_CORS_ORIGINS: list = ["*"]
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))
    
    # Environmental Impact Configuration
    DEFAULT_FUEL_EFFICIENCY: float = float(os.getenv("DEFAULT_FUEL_EFFICIENCY", "15.0"))  # km per liter
    CO2_PER_LITER_FUEL: float = float(os.getenv("CO2_PER_LITER_FUEL", "2.31"))  # kg CO2 per liter
    
    # Safety Configuration
    EMERGENCY_RESPONSE_TIMEOUT: int = int(os.getenv("EMERGENCY_RESPONSE_TIMEOUT", "30"))  # seconds
    PANIC_BUTTON_COOLDOWN: int = int(os.getenv("PANIC_BUTTON_COOLDOWN", "300"))  # seconds
    
    # Community Configuration
    DEFAULT_TRUST_SCORE_THRESHOLD: float = float(os.getenv("DEFAULT_TRUST_SCORE_THRESHOLD", "3.0"))
    MAX_COMMUNITY_DISTANCE: float = float(os.getenv("MAX_COMMUNITY_DISTANCE", "50.0"))  # km
    
    # Route Optimization Configuration
    MAX_ROUTE_OPTIMIZATION_STOPS: int = int(os.getenv("MAX_ROUTE_OPTIMIZATION_STOPS", "20"))
    OPTIMIZATION_TIMEOUT: int = int(os.getenv("OPTIMIZATION_TIMEOUT", "30"))  # seconds
    
    # Notification Configuration
    NOTIFICATION_RETENTION_DAYS: int = int(os.getenv("NOTIFICATION_RETENTION_DAYS", "90"))
    MAX_NOTIFICATIONS_PER_USER: int = int(os.getenv("MAX_NOTIFICATIONS_PER_USER", "1000"))
    
    class Config:
        env_file = ".env"
        case_sensitive = True

# Create settings instance
settings = Settings() 