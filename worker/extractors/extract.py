from __future__ import annotations

import io
from typing import Any, Tuple

import httpx
from pypdf import PdfReader
from docx import Document
from worker.utils.graph_download import download_sharepoint_bytes, is_sharepoint_url


def download_bytes(url: str, timeout_seconds: int = 60) -> tuple[bytes, dict[str, str]]:
    # SharePoint and OneDrive viewer links often block direct HTTP downloads
    if is_sharepoint_url(url):
        data, headers = download_sharepoint_bytes(url, timeout_seconds=max(timeout_seconds, 90))
        return data, headers

    headers: dict[str, str] = {}
    with httpx.Client(follow_redirects=True, timeout=timeout_seconds) as client:
        r = client.get(url)
        r.raise_for_status()
        headers = {k.lower(): v for k, v in r.headers.items()}
        headers["x-download-source"] = "http"
        return r.content, headers


def extract_pdf_text(data: bytes) -> str:
    reader = PdfReader(io.BytesIO(data))
    parts: list[str] = []
    for page in reader.pages:
        t = page.extract_text() or ""
        t = t.strip()
        if t:
            parts.append(t)
    return "\n\n".join(parts).strip()


def extract_docx_text(data: bytes) -> str:
    doc = Document(io.BytesIO(data))
    parts: list[str] = []
    for p in doc.paragraphs:
        t = (p.text or "").strip()
        if t:
            parts.append(t)
    return "\n".join(parts).strip()


def extract_text_from_url(url: str, mime_type: str | None = None) -> Tuple[str, dict[str, Any]]:
    data, headers = download_bytes(url)

    ct = (mime_type or headers.get("content-type") or "").lower()

    meta: dict[str, Any] = {
        "source": "http",
        "content_type": ct,
        "bytes": len(data),
    }

    if "pdf" in ct or url.lower().endswith(".pdf"):
        text = extract_pdf_text(data)
        meta["parser"] = "pypdf"
        return text, meta

    if "word" in ct or url.lower().endswith(".docx"):
        text = extract_docx_text(data)
        meta["parser"] = "python-docx"
        return text, meta

    raise ValueError(f"unsupported content type for extraction: {ct or 'unknown'}")
