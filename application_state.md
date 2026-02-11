# CBL Aero Intake Platform – Application State

## Repo Structure

Root:

- api/
- worker/
- core logic in Postgres
- .env
- requirements.txt

---

## API Layer (FastAPI)

Entry:
uvicorn api.main:app

Swagger:
http://localhost:8000/docs

---

### Key Endpoint

POST /v1/artifacts/register

Request Model:

{
  "intake_id": "uuid",
  "artifact_type": "string",
  "file_name": "string",
  "mime_type": "string",
  "storage_uri": "string",
  "sha256": "string"
}

Validation Rules:

- intake_id must be valid UUID
- sha256 must be string (cannot be null)

---

## Worker

Entry:

python -m worker.worker_main

Worker Responsibilities:

- Poll artifacts where status = registered
- Transition to extracting
- Download file from storage_uri
- Extract text
- Persist via fn_finalize_artifact_extraction
- On failure call fn_fail_artifact

---

## Extraction Engine

File:
worker/extractors/extract.py

Functions:

- download_bytes(url)
- extract_pdf_text()
- extract_docx_text()
- extract_text_from_url()

Download source tagging:
- http
- graph

Extraction metadata stored in extracted_json:

Example:

{
  "bytes": 586207,
  "parser": "pypdf",
  "source": "http",
  "content_type": "application/pdf"
}

---

## SharePoint Integration

File:
worker/utils/graph_download.py

Uses:
- msal
- Client credentials flow

Graph API:
https://graph.microsoft.com/v1.0/shares/{shareId}/driveItem/content

Requires env vars:

MS_TENANT_ID
MS_CLIENT_ID
MS_CLIENT_SECRET

---

## Google Drive Handling

Supported:

- Public direct download links:
  https://drive.google.com/uc?export=download&id=FILE_ID

Viewer links must be converted manually.

---

## Local Dev Commands

Activate venv:
source .venv/Scripts/activate

Start API:
uvicorn api.main:app --reload

Start Worker:
python -m worker.worker_main

Check interpreter:
python -c "import sys; print(sys.executable)"

---

## Test Intake ID (Pinned)

Standard test intake_id:

8aedb112-946e-4a4c-802c-1f9d830d84ee

Used for all artifact registration tests unless specified otherwise.

---

## Verified Working End-to-End

Tested flow:

- Register artifact via Swagger
- Worker transitions registered → extracting → extracted
- extracted_json populated
- extracted_text populated
- Google public PDF successfully parsed

System confirmed stable at current milestone.
