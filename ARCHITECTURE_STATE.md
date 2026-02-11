\# CBL Aero Intake Platform – Architecture State



\## Repository

Owner: cblsolutions (GitHub org)

Repo: cbl-aero-intake-platform

Visibility: Public (temporary, free plan constraint)



\## Stack (Locked)

\- Database: Supabase Postgres (Pro)

\- Extensions: pgcrypto, postgis, pgvector

\- RLS: enabled

\- API: FastAPI

\- DB driver: asyncpg

\- Worker: Python background process

\- Orchestration (future): n8n

\- Vector storage: pgvector (inside Postgres)

\- No external vector DB

\- No SQL outside stored functions



\## Architecture Rules

\- Python is the ONLY client that talks to Postgres

\- Python calls ONLY stored Postgres functions

\- No direct table queries

\- No business logic in n8n

\- All business logic in:

&nbsp; - Postgres functions

&nbsp; - Python service layer



\## Implemented Endpoints

\- GET /health

\- GET /health/db

\- POST /v1/intakes/ingest

&nbsp; - Calls delivery.fn\_ingest\_intake

&nbsp; - Returns intake\_id



\## DB Connectivity

\- Using Supabase Session Pooler

\- IPv4

\- asyncpg connection pool

\- .env for DATABASE\_URL (not committed)



\## Worker Status

\- Worker skeleton exists

\- No extraction logic implemented yet

\- Multi-worker design planned with atomic claim function



\## Next Planned Work

\- POST /v1/artifacts/register

\- Implement claim + poller model

\- Implement artifact extraction pipeline

\- Upsert candidate endpoint

\- Concept resolution endpoint

\- Embedding integration



\## Design Notes

\- Backfill lane must be separate from inbound intake lane

\- Embeddings are generated from canonical text, not raw email body

\- Airtable is read-only review layer (not source of truth)





