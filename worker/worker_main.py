import os
import time
import traceback
from uuid import UUID
from worker.extractors.extract import extract_text_from_url

from app.db.client import db
from app.db.functions import (
    fn_list_registered_artifacts_live,
    fn_list_registered_artifacts_backfill,
    fn_claim_artifact_for_extraction,
    fn_finalize_artifact_extraction,
    fn_fail_artifact,
)

from dotenv import load_dotenv
load_dotenv()

import logging
logging.basicConfig(level=logging.INFO)

LANE = os.getenv("WORKER_LANE", "live")  # live or backfill
POLL_SECONDS = int(os.getenv("WORKER_POLL_SECONDS", "15"))
BATCH_LIMIT = int(os.getenv("WORKER_BATCH_LIMIT", "50"))


def extract_text(storage_uri: str | None, mime_type: str | None) -> tuple[str, dict]:
    if not storage_uri:
        raise ValueError("missing storage_uri")
    return extract_text_from_url(storage_uri, mime_type)



async def run_once() -> int:
    if LANE == "backfill":
        items = await fn_list_registered_artifacts_backfill(BATCH_LIMIT)
    else:
        items = await fn_list_registered_artifacts_live(BATCH_LIMIT)
    print(f"[{LANE}] found {len(items)} registered artifacts")

    claimed = 0
    for it in items:
        artifact_id = UUID(str(it["artifact_id"]))
        ok = await fn_claim_artifact_for_extraction(artifact_id)
        if not ok:
            continue
        print(f"[{LANE}] claimed {artifact_id}")
        claimed += 1
        try:
            text, meta = extract_text(it.get("storage_uri"), it.get("mime_type"))
            await fn_finalize_artifact_extraction(artifact_id, text, meta)
            print(f"[{LANE}] finalized {artifact_id}")

        except Exception as e:
            await fn_fail_artifact(artifact_id, f"{e}\n{traceback.format_exc()}")

    return claimed


async def main():
    await db.start()
    try:
        while True:
            n = await run_once()
            if n == 0:
                time.sleep(POLL_SECONDS)
    finally:
        await db.stop()


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
