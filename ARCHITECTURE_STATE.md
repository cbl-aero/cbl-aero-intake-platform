# CBL Aero Intake Platform – Architecture State

## High Level Goal

Internal platform for candidate intake, artifact extraction, normalization, and future matching.

System must be:
- Reliable
- Low infrastructure
- Strict boundary enforced
- Ready for future sales + delivery expansion

---

## Locked Stack

Database:
- Supabase Postgres (Pro)
- Extensions enabled:
  - pgcrypto
  - postgis
  - pgvector

Compute:
- FastAPI (API)
- Python background worker
- n8n for orchestration (no SQL allowed)
- Render for deployment

Vector:
- pgvector inside Postgres
- No Pinecone

Ops UI:
- Airtable (read-mostly, never source of truth)

---

## Boundary Rules (Strict)

- n8n MUST NOT execute SQL.
- Python is the ONLY component allowed to talk to Postgres.
- Python may ONLY call stored Postgres functions.
- No direct table access from:
  - n8n
  - Airtable
- All business logic lives in:
  - Postgres functions
  - Python code
- No business logic in n8n.

---

## Database Schemas

Schemas in use:

- core
- delivery

`public` schema is NOT used for business logic.

---

## Core Tables

- core.concepts
- core.concept_aliases
- core.normalization_suggestions
- core.embeddings

Purpose:
- Canonical normalization system
- Human-in-the-loop approvals
- Vector storage

---

## Delivery Tables

- delivery.recruiters
- delivery.candidates
- delivery.candidate_intakes
- delivery.artifacts
- delivery.intake_candidate_links

---

## Artifact Lifecycle (Locked Vocabulary)

Artifacts move through states:

1. registered
2. extracting
3. extracted
4. failed

No alternative terminology allowed.

---

## Postgres Function Boundary Layer

Delivery:

- delivery.fn_ensure_recruiter
- delivery.fn_ingest_intake
- delivery.fn_register_artifact
- delivery.fn_finalize_artifact_extraction
- delivery.fn_fail_artifact
- delivery.fn_upsert_candidate
- delivery.fn_link_intake_candidate

Core:

- core.fn_resolve_concept_code
- core.fn_queue_normalization_suggestion
- core.fn_upsert_embedding

Python NEVER writes tables directly.
Python ONLY calls these functions.

---

## Artifact Processing Design

Flow:

API:
- Registers artifact via fn_register_artifact
- Sets status = registered

Worker:
- Polls DB for registered artifacts
- Moves to extracting
- Downloads bytes from storage_uri
- Extracts text
- Calls fn_finalize_artifact_extraction
- Status becomes extracted
- On failure calls fn_fail_artifact

---

## Supported Artifact Sources

### Public HTTPS
- Downloaded via httpx
- Works for public S3, direct links, Google Drive direct links

### Google Drive
Supported via:
- Direct download format:
  https://drive.google.com/uc?export=download&id=FILE_ID

Viewer links must be converted.

No OAuth required for public files.

### SharePoint / OneDrive
Supported via:
- Microsoft Graph API
- Client credentials flow

Env vars required:
- MS_TENANT_ID
- MS_CLIENT_ID
- MS_CLIENT_SECRET

Graph endpoint used:
- /shares/{shareId}/driveItem/content

Fallback:
- If env vars missing, system can fall back to direct HTTP where possible.

---

## Current Milestone Status

Completed:

- Intake ingest endpoint
- Artifact register endpoint
- Worker polling
- Worker claim logic
- PDF extraction (pypdf)
- DOCX extraction (python-docx)
- Public HTTPS downloads
- Google Drive direct download
- SharePoint Graph-based download
- Extraction metadata persisted

Not yet implemented:

- Worker-side SHA256 computation
- Retry with backoff
- Large file confirm-token handling for Google Drive
- Advanced metadata enrichment
