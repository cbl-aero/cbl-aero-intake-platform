CBL Aero Intake Platform – Architecture State
1. Objective

Internal platform for:

Candidate intake

Artifact extraction

Structured normalization

Canonical candidate creation

Future matching via embeddings

System must be:

Reliable

Deterministic

Strictly bounded

Low infrastructure

Expandable for Sales + Delivery workflows

This document defines:

Architecture boundaries

Processing model

Orchestration model

Storage model

Milestones

What is achieved

What remains

No speculative architecture allowed outside this document.

2. Locked Stack
Database

Supabase Postgres (Pro)

Extensions:

pgcrypto

postgis

pgvector

Compute

FastAPI (API layer)

Python background worker

n8n (orchestration only)

Render (deployment target)

Vector

pgvector inside Postgres

No Pinecone

No external vector DB

Ops UI

Airtable (read-mostly)

Never source of truth

Never writes to database directly

3. Boundary Enforcement (Strict)

These rules are locked.

n8n

MUST NOT execute SQL

MUST NOT compute sha256

MUST NOT classify document type

MUST NOT parse resumes

MUST NOT normalize concepts

MUST NOT perform business logic

MUST only call Python HTTP endpoints

MUST only orchestrate file movement and webhook events

Python

Is the ONLY component allowed to talk to Postgres

May ONLY call stored Postgres functions

MUST NOT perform direct table writes

Owns:

Artifact registration

Extraction

Classification

Normalization

Candidate upsert

Embeddings

Postgres

Enforces correctness via stored functions

Owns idempotency and integrity constraints

No layer may violate its responsibility boundary.

4. Database Structure
Schemas

core

delivery

public schema is not used for business logic.

Core Tables

core.concepts

core.concept_aliases

core.normalization_suggestions

core.embeddings

Purpose:

Canonical normalization

Human-in-the-loop approval

Vector storage

Delivery Tables

delivery.recruiters

delivery.candidates

delivery.candidate_intakes

delivery.artifacts

delivery.intake_candidate_links

5. Artifact Lifecycle (Locked Vocabulary)

Artifacts move through exactly these states:

registered

extracting

extracted

failed

No alternative state names allowed.

All orchestration and automation must respect this lifecycle.

6. Postgres Function Boundary Layer

Python may ONLY call these functions.

Delivery

delivery.fn_ensure_recruiter

delivery.fn_ingest_intake

delivery.fn_register_artifact

delivery.fn_finalize_artifact_extraction

delivery.fn_fail_artifact

delivery.fn_upsert_candidate

delivery.fn_link_intake_candidate

Core

core.fn_resolve_concept_code

core.fn_queue_normalization_suggestion

core.fn_upsert_embedding

No direct table inserts.
No direct updates.

7. Processing Architecture
7.1 Intake Layer (API)

Endpoint: /v1/intakes/ingest

Input:

subject (optional)

body_text

raw_payload

attachments[]:

file_name

mime_type

public_url

external_file_id

Python performs:

fn_ingest_intake

For each attachment → fn_register_artifact

Output:

intake_id

artifacts[]:

artifact_id

file_name

external_file_id

7.2 Artifact Processing (Worker)

Worker loop:

Poll for registered artifacts

Claim artifact

Set status extracting

Download bytes from storage_uri

Compute SHA256 (planned)

Detect file type

Extract text

Classify document type

Structured extraction

Normalization

Candidate upsert

Embedding upsert

fn_finalize_artifact_extraction

On failure:

fn_fail_artifact

Worker owns all intelligence.

8. Storage Model

n8n handles storage.

Folder Structure

Intake/Inbox

Intake/Processed

Intake/Failed

Flow

n8n downloads email attachment

n8n uploads to shared drive Inbox

n8n creates public link

n8n calls Python ingest

Python registers artifact

Worker processes

n8n polls artifact status

If extracted → move file to Processed

If failed → move to Failed

Move operation uses external_file_id, not public_url.

9. Supported Artifact Sources
Public HTTPS

httpx

Reject HTML responses

Google Drive

Viewer URL normalization

Direct download conversion

File-type sniffing

Confirm-token handling (planned)

SharePoint / OneDrive

Graph API preferred

HTTP fallback allowed

HTML rejection logic enforced

Required env vars:

MS_TENANT_ID

MS_CLIENT_ID

MS_CLIENT_SECRET

10. Extraction Hardening (Partially Implemented)

Implemented:

Viewer URL normalization

HTML detection rejection

File signature sniffing

PDF extraction

DOCX extraction

Metadata persistence

Planned:

Worker-side SHA256 verification

Retry with exponential backoff

Google confirm-token large file handling

Download + parse timing metrics

Detailed failure classification

Definition of done:
Download pipeline must survive transient errors and large public files.

11. Document Classification (Option C – Locked Strategy)

Goal:
Auto detect artifact type.

Supported types:

resume

drivers_license

faa_certificate

intake_form

other

Strategy:

Rule-based classifier first

LLM fallback if low confidence

Persist in extracted_json:

detected_artifact_type

confidence

method

evidence

needs_review

Definition of done:
Test Google and SharePoint artifacts produce classification metadata.

12. Structured Extraction

Per artifact type:

Resume

name

email

phone

location

roles

certifications

aircraft

FAA Cert

certificate number

rating

issue date

Driver License

license number

state

expiration

DOB

Rules extraction first.
LLM fallback for missing structured fields.

Stored under:
extracted_json.structured

13. Normalization Layer

For extracted raw values:

call core.fn_resolve_concept_code

unresolved → core.fn_queue_normalization_suggestion

Persist:
extracted_json.normalized

Definition of done:
Unknown values generate suggestions for Airtable review.

14. Candidate Upsert

Build canonical candidate payload.

Call:

delivery.fn_upsert_candidate

delivery.fn_link_intake_candidate

Guarantee:

Idempotent

No duplicate candidate rows

15. Embedding Layer

Build canonical_text from:

normalized roles

certifications

aircraft

location

Compute embedding in Python.
Call:

core.fn_upsert_embedding

Definition of done:
Similarity search operational.

16. Backfill Lane

Two lanes:

live

backfill

Requirements:

No starvation of live lane

Independent polling limits

Idempotent reprocessing

17. Observability

Required:

Structured logs with:

artifact_id

intake_id

stage

timing

source

Counters:

claimed

extracted

failed

retries

classification fallback

Failure classes:

download

parse

classify

normalization

db

Goal:
Root cause identifiable without guesswork.

18. n8n Orchestration Milestones

Email trigger implemented

Attachment upload to Inbox

Public link generation

Ingest call to Python

Polling for artifact status

Move to Processed or Failed

Idempotency safeguards

n8n never touches database.

19. Deployment Milestones

FastAPI deployed on Render

Worker deployed on Render

Env vars configured

Health endpoints implemented

Logging centralized

20. Current Achievement Snapshot

Achieved:

Intake ingest

Artifact registration

Worker polling

Extraction

Google Drive support

SharePoint support

Metadata persistence

In Progress:

Hardening

Classification

Structured extraction

Not Started:

Normalization

Candidate upsert

Embeddings

Full n8n orchestration loop

Render production deployment