from fastapi import FastAPI
from app.db.client import db
from app.api.intakes import router as intake_router
from app.api.artifacts import router as artifacts_router

from dotenv import load_dotenv
load_dotenv()


app = FastAPI(title="CBL Aero Intake API", version="0.1.0")

app.include_router(intake_router)
app.include_router(artifacts_router)


@app.on_event("startup")
async def startup():
    await db.start()


@app.on_event("shutdown")
async def shutdown():
    await db.stop()


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/health/db")
async def health_db():
    v = await db.fetchval("select 1")
    return {"db": "ok", "value": v}
