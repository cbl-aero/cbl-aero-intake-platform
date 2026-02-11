\# CBL Aero Intake Platform – Architecture State



\## Repository

Owner: cblsolutions (GitHub org)

Repo: cbl-aero-intake-platform

Visibility: Public (temporary due to free org plan)

Branch Protection: Enabled (classic, PR required)



\## Stack (Locked)

\- Database: Supabase Postgres (Pro)

\- Extensions: pgcrypto, postgis, pgvector

\- RLS: enabled

\- API: FastAPI

\- DB driver: asyncpg

\- Worker: Python background process

\- Orchestration (future): n8n (no SQL execution)

\- Vector storage: pgvector inside Postgres

\- No external vector DB

\- No SQL outside stored functions



\## Core Architecture Rules

\- Python is the ONLY client that talks to Postgres

\- Python calls ONLY stored Postgres functions

\- No direct table queries

\- No business logic in n8n

\- Business logic lives in:

&nbsp; - Postgres functions

&nbsp; - Python service layer



\## Database Connectivity

\- Supabase Session Pooler

\- IPv4

\- asyncpg connection pool

\- Connection validated via /health/db

\- DATABASE\_URL stored in .env (not committed)



\## Implemented Endpoints



\### System

\- GET /health

\- GET /health/db



\### Intake

\- POST /v1/intakes/ingest

&nbsp; - Calls delivery.fn\_ingest\_intake

&nbsp; - Returns intake\_id

&nbsp; - Accepts datetime for received\_at

&nbsp; - raw\_payload handled as dict → JSON encoded for DB



\### Artifacts

\- POST /v1/artifacts/register

&nbsp; - Calls delivery.fn\_register\_artifact

&nbsp; - Idempotent via (intake\_id, sha256)

&nbsp; - Returns artifact\_id



\## Worker Status

\- Worker skeleton exists (worker/worker\_main.py)

\- No extraction logic yet

\- No claim function yet

\- Multi-worker polling model planned

&nbsp; - Group A (heavy documents)

&nbsp; - Group B (light images)

&nbsp; - Different polling intervals

&nbsp; - Atomic claim function required in DB



\## Data Model Status

\- candidate\_intakes implemented

\- artifacts implemented

\- intake\_candidate\_links not yet wired

\- candidates not yet wired

\- embeddings table not yet used



\## Pending Work (Next Phase)



1\. DB claim function for artifact extraction

2\. Multi-worker poller implementation

3\. Artifact extraction pipeline (PDF, DOCX, image OCR)

4\. delivery.fn\_upsert\_candidate endpoint

5\. delivery.fn\_link\_intake\_candidate endpoint

6\. core.fn\_resolve\_concept\_code integration

7\. Embedding generation + core.fn\_upsert\_embedding

8\. Backfill import lane (separate from intake)



\## Design Constraints

\- Backfill resumes must NOT go through intake lane

\- Embeddings generated from canonical text only

\- Airtable is review layer only (not source of truth)

\- Idempotency enforced at DB level

\- All edge cases handled in Postgres functions or Python





