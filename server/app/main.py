from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.health import router as health_router
from app.api.ingest import router as ingest_router

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """Health check endpoint for container orchestration."""
    return {"status": "ok", "version": settings.app_version}


# Include routers
app.include_router(health_router)
app.include_router(ingest_router)

# Import and include query router (must be after ingest to avoid circular deps)
from app.api.query import router as query_router  # noqa: E402
app.include_router(query_router)


@app.on_event("startup")
async def startup_event():
    """Initialize database on startup with retry logic."""
    import asyncio
    from app.db.connection import init_db

    max_retries = 10
    retry_delay = 2  # seconds

    for attempt in range(max_retries):
        try:
            await init_db()
            print("✓ Database initialized successfully")
            break
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"Database connection failed (attempt {attempt + 1}/{max_retries}): {e}")
                print(f"Retrying in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff
            else:
                print(f"✗ Failed to connect to database after {max_retries} attempts")
                raise


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    from app.db.connection import engine
    await engine.dispose()
