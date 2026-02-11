from fastapi import APIRouter
from pydantic import BaseModel
from typing import Any
from uuid import UUID
from app.db.functions import fn_ingest_intake
from datetime import datetime


router = APIRouter(prefix="/v1/intakes", tags=["intakes"])


class IntakeIn(BaseModel):
    source: str
    source_message_id: str
    received_at: datetime | None = None
    recruiter_email: str | None = None
    subject: str | None = None
    body_text: str | None = None
    body_html: str | None = None
    raw_payload: dict[str, Any] = {}


@router.post("/ingest")
async def ingest_intake(payload: IntakeIn):
    intake_id: UUID = await fn_ingest_intake(
        payload.source,
        payload.source_message_id,
        payload.received_at,
        payload.recruiter_email,
        payload.subject,
        payload.body_text,
        payload.body_html,
        payload.raw_payload,
    )

    return {"intake_id": str(intake_id)}
