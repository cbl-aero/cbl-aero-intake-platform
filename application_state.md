\# CBL Aero Intake Platform – Application State



\## Current Status

Local FastAPI + worker pipeline is functional end to end with Supabase Postgres.



\## Repo

\- Org: cblsolutions

\- Repo: cbl-aero-intake-platform

\- Branch protection: enabled (classic PR based)



\## Stack (Locked)

\- FastAPI API

\- Python worker process (multi worker supported)

\- Supabase Postgres Pro with: pgcrypto, postgis, pgvector

\- asyncpg for DB connections

\- n8n later for orchestration, no SQL in n8n



\## Connectivity

\- Supabase Session Pooler connection string is working

\- GET /health/db returns {"db":"ok","value":1}

\- DATABASE\_URL stored in local .env and is not committed



\## Implemented API Endpoints

\### Health

\- GET /health

\- GET /health/db



\### Intake

\- POST /v1/intakes/ingest

&nbsp; - Calls delivery.fn\_ingest\_intake

&nbsp; - Pydantic parses received\_at into datetime

&nbsp; - raw\_payload accepted as dict and encoded to json before DB call

&nbsp; - Returns intake\_id



\### Artifacts

\- POST /v1/artifacts/register

&nbsp; - Calls delivery.fn\_register\_artifact

&nbsp; - Idempotent via (intake\_id, sha256)

&nbsp; - Returns artifact\_id



\## Worker

Worker supports polling and atomic claim for multi worker scaling.



\### DB functions added for worker lane

\- delivery.fn\_list\_registered\_artifacts\_live(limit int)

\- delivery.fn\_list\_registered\_artifacts\_backfill(limit int)

\- delivery.fn\_claim\_artifact\_for\_extraction(artifact\_id uuid) returns boolean



Worker loop behavior:

\- List registered artifacts

\- Attempt atomic claim (registered to extracting)

\- Extract text

\- Finalize or fail

&nbsp; - delivery.fn\_finalize\_artifact\_extraction

&nbsp; - delivery.fn\_fail\_artifact



\### Extraction implementation

\- Supports public HTTPS storage\_uri only (current)

\- Uses httpx to download bytes

\- PDF extraction: pypdf

\- DOCX extraction: python-docx

\- Images and OCR not implemented yet



\## Known Limitation

SharePoint viewer links are not direct file downloads.

They return HTML and extraction fails.



To support SharePoint, choose one:

\- Option A: Copy artifacts into Supabase Storage and store public or signed URLs in storage\_uri

\- Option B: Add Microsoft Graph download support (auth) in worker



Recommendation: Option A or Hybrid, keep processing stable.



\## Next Work Items

1\. Decide artifact storage strategy (Supabase Storage vs SharePoint vs hybrid)

2\. Implement Supabase Storage signed URL handling if bucket is private

3\. Add image extraction lane (OCR) later

4\. Add candidate upsert endpoint calling delivery.fn\_upsert\_candidate

5\. Add intake candidate link endpoint calling delivery.fn\_link\_intake\_candidate

6\. Add concept resolution flow and normalization suggestion queue integration

7\. Add embeddings generation pipeline and core.fn\_upsert\_embedding



\## Test Artifacts

\- Public PDF URL extraction succeeds

\- SharePoint viewer URL extraction fails as expected



