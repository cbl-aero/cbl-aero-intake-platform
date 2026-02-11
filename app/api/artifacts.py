from fastapi import APIRouter
from pydantic import BaseModel, Field
from uuid import UUID
from app.db.functions import fn_register_artifact

router = APIRouter(prefix="/v1/artifacts", tags=["artifacts"])


class ArtifactRegisterIn(BaseModel):
    intake_id: UUID
    artifact_type: str = Field(..., description="resume, dl, faa, rtr, image, other")
    file_name: str | None = None
    mime_type: str | None = None
    storage_uri: str | None = None
    sha256: str = Field(..., description="hex sha256 of file bytes")


@router.post("/register")
async def register_artifact(payload: ArtifactRegisterIn):
    artifact_id = await fn_register_artifact(
        payload.intake_id,
        payload.artifact_type,
        payload.file_name,
        payload.mime_type,
        payload.storage_uri,
        payload.sha256,
    )
    return {"artifact_id": str(artifact_id)}
