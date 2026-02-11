\# CBL Aero Intake Platform – Chat Handoff



This file is the single source of truth for starting any new ChatGPT session for this project.

Do not rely on memory. Do not assume schema or states.



\## Repository



https://github.com/cbl-aero/cbl-aero-intake-platform



Branch: main



\## Non Negotiables



\- Python is the only component allowed to talk to Postgres.

\- Python must call only stored Postgres functions. No direct table writes.

\- n8n must not execute SQL. n8n only orchestrates HTTP calls to Python.

\- Do not redesign DB schema unless explicitly requested.

\- Do not introduce new lifecycle terms or statuses.

\- Always use the repo files as truth. If anything is unclear, inspect the code or DDL files.



\## Locked Artifact Status Vocabulary



registered

extracting

extracted

failed



No other terms allowed.



\## Pinned Test Intake ID



8aedb112-946e-4a4c-802c-1f9d830d84ee



Use this intake\_id for all Swagger and worker tests unless explicitly overridden.



\## What Is Already Working



\- Intake ingest endpoint exists and works.

\- Artifact register endpoint exists and works.

\- Worker polling works.

\- Worker transitions artifact status: registered → extracting → extracted or failed.

\- Extraction works for public HTTPS URLs.

\- PDF extraction uses pypdf.

\- DOCX extraction uses python-docx.

\- Google Drive works when using the direct download format:

&nbsp; https://drive.google.com/uc?export=download\&id=FILE\_ID

\- SharePoint and OneDrive support exists via Microsoft Graph download in the worker.



\## SharePoint and OneDrive Requirements



Worker can use Microsoft Graph to download SharePoint and OneDrive sharing links.



Required env vars:

MS\_TENANT\_ID

MS\_CLIENT\_ID

MS\_CLIENT\_SECRET



Graph endpoint used:

GET https://graph.microsoft.com/v1.0/shares/{shareId}/driveItem/content



\## Files To Read In A New Chat



Read these first, in this order:



1\. ARCHITECTURE\_STATE.md

2\. APPLICATION\_STATE.md

3\. DB\_STATE.md

4\. db/ddl/00\_schema\_core\_delivery.sql

5\. db/ddl/01\_functions.sql

6\. api/ (entrypoints and v1 endpoints)

7\. worker/worker\_main.py

8\. worker/extractors/extract.py

9\. worker/utils/graph\_download.py



\## Local Run Commands



Activate venv:

source .venv/Scripts/activate



Run worker:

python -m worker.worker\_main



Run API:

uvicorn api.main:app --reload



Swagger:

http://localhost:8000/docs



\## Known API Validation Constraint



artifact register request requires sha256 to be a string.

sha256 cannot be null.



\## Current Milestone



SharePoint and Google download hardening.



\## Next 3 Work Items



1\. SharePoint hardening

&nbsp;  - Ensure SharePoint links use Graph when creds exist.

&nbsp;  - Add safe fallback to direct HTTP only when it returns real file bytes, not HTML.

&nbsp;  - Add clear logs for which download path was used.



2\. Google Drive viewer link normalization

&nbsp;  - Accept viewer links like:

&nbsp;    https://drive.google.com/file/d/<id>/view

&nbsp;  - Convert to direct download format automatically.

&nbsp;  - Detect HTML downloads and fail with clear error before extraction.



3\. Operator runbook

&nbsp;  - Add RUNBOOK\_LOCAL.md with the exact steps to run API and worker, test in Swagger, and verify DB results.

&nbsp;  - Include example payload using pinned test intake\_id.



After completing the next 3 work items:

\- Update ARCHITECTURE\_STATE.md and APPLICATION\_STATE.md.

\- If any DB function or schema changes occur, re export db/ddl snapshots and update DB\_STATE.md.

\- Commit and push changes before starting a new chat.



\## New Chat Starter Message



Use this as the first message in a new chat:



Continue CBL Aero Intake Platform build.

Repository: https://github.com/cbl-aero/cbl-aero-intake-platform

Follow CHAT\_HANDOFF.md as the single source of truth.



