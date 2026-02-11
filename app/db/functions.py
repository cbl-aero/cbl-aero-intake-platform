from typing import Any
from uuid import UUID
from app.db.client import db
from datetime import datetime
import json



async def fn_ingest_intake(
    source: str,
    source_message_id: str,
    received_at: datetime | None,
    recruiter_email: str | None,
    subject: str | None,
    body_text: str | None,
    body_html: str | None,
    raw_payload: dict[str, Any],
) -> UUID:
    return await db.fetchval(
        """
        select delivery.fn_ingest_intake(
            $1,$2,$3,$4,$5,$6,$7,$8::jsonb
        )
        """,
        source,
        source_message_id,
        received_at,
        recruiter_email,
        subject,
        body_text,
        body_html,
        json.dumps(raw_payload),
    )

async def fn_register_artifact(
    intake_id: UUID,
    artifact_type: str,
    file_name: str | None,
    mime_type: str | None,
    storage_uri: str | None,
    sha256: str,
) -> UUID:
    return await db.fetchval(
        """
        select delivery.fn_register_artifact(
            $1::uuid,
            $2::text,
            $3::text,
            $4::text,
            $5::text,
            $6::text
        )
        """,
        intake_id,
        artifact_type,
        file_name,
        mime_type,
        storage_uri,
        sha256,
    )

