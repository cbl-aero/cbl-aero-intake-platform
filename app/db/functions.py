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

async def fn_list_registered_artifacts_live(limit: int) -> list[dict[str, Any]]:
    rows = await db.fetch(
        "select * from delivery.fn_list_registered_artifacts_live($1)",
        limit,
    )
    return [dict(r) for r in rows]

async def fn_list_registered_artifacts_backfill(limit: int) -> list[dict[str, Any]]:
    rows = await db.fetch(
        "select * from delivery.fn_list_registered_artifacts_backfill($1)",
        limit,
    )
    return [dict(r) for r in rows]

async def fn_claim_artifact_for_extraction(artifact_id: UUID) -> bool:
    v = await db.fetchval(
        "select delivery.fn_claim_artifact_for_extraction($1::uuid)",
        artifact_id,
    )
    return bool(v)

async def fn_finalize_artifact_extraction(artifact_id: UUID, extracted_text: str, extracted_json: dict[str, Any]) -> None:
    await db.execute(
        "select delivery.fn_finalize_artifact_extraction($1::uuid,$2::text,$3::jsonb)",
        artifact_id,
        extracted_text,
        json.dumps(extracted_json),
    )

async def fn_fail_artifact(artifact_id: UUID, error: str) -> None:
    await db.execute(
        "select delivery.fn_fail_artifact($1::uuid,$2::text)",
        artifact_id,
        error,
    )

async def fetch(self, sql: str, *args):
        if not self.pool:
            raise RuntimeError("DB not started")
        async with self.pool.acquire() as conn:
            return await conn.fetch(sql, *args)
