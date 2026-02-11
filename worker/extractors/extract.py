from __future__ import annotations

import io
import logging
import os
import re
from typing import Any, Tuple
from urllib.parse import parse_qs, parse_qsl, urlencode, urlparse, urlunparse

import httpx
from docx import Document
from pypdf import PdfReader

from worker.utils.graph_download import download_sharepoint_bytes, is_sharepoint_url

from dotenv import load_dotenv
load_dotenv()


logger = logging.getLogger(__name__)



def normalize_google_drive_url(url: str) -> str:
    """
    Convert common Google Drive viewer URLs into direct download URLs.
    """

    parsed = urlparse(url)

    if "drive.google.com" not in parsed.netloc:
        return url

    # Case 1: /file/d/<id>/view
    match = re.search(r"/file/d/([^/]+)/", parsed.path)
    if match:
        file_id = match.group(1)
        return f"https://drive.google.com/uc?export=download&id={file_id}"

    # Case 2: open?id=<id>
    query = parse_qs(parsed.query)
    if "id" in query:
        file_id = query["id"][0]
        return f"https://drive.google.com/uc?export=download&id={file_id}"

    return url

def _has_graph_creds() -> bool:
    return all([
        os.getenv("MS_TENANT_ID"),
        os.getenv("MS_CLIENT_ID"),
        os.getenv("MS_CLIENT_SECRET"),
    ])

def _with_download_flag(url: str) -> str:
    u = urlparse(url)
    q = dict(parse_qsl(u.query, keep_blank_values=True))
    q.setdefault("download", "1")
    return urlunparse((u.scheme, u.netloc, u.path, u.params, urlencode(q), u.fragment))

def _looks_like_html(data: bytes) -> bool:
    head = data[:300].lstrip().lower()
    return head.startswith(b"<!doctype html") or head.startswith(b"<html") or b"<head" in head

def sniff_format(data: bytes) -> str:
    """
    Best-effort file type sniffing using magic bytes.
    Returns: 'pdf', 'zip', 'ole', 'rtf', 'txt', or 'unknown'
    """
    if not data:
        return "unknown"

    head = data[:16]

    # PDF: %PDF
    if data.startswith(b"%PDF"):
        return "pdf"

    # ZIP container: PK (docx is a zip)
    if head[:2] == b"PK":
        return "zip"

    # OLE Compound File: old .doc, .xls, etc
    if head.startswith(b"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1"):
        return "ole"

    # RTF
    if data.startswith(b"{\\rtf"):
        return "rtf"

    # Text heuristic: mostly printable bytes in first chunk
    sample = data[:2048]
    try:
        sample.decode("utf-8")
        return "txt"
    except Exception:
        return "unknown"

def download_bytes(url: str, timeout_seconds: int = 60) -> tuple[bytes, dict[str, str]]:
    original_url = url
    url = normalize_google_drive_url(url)

    if url != original_url:
        logger.info(f"artifact_url_normalized original={original_url} resolved={url}")

    if is_sharepoint_url(url):
        # 1) If Graph creds exist, prefer Graph first
        if not _has_graph_creds():
            host = urlparse(url).netloc
            logger.info(f"sharepoint_graph_skipped_missing_creds host={host}")

        if _has_graph_creds():
            try:
                data, headers = download_sharepoint_bytes(url, timeout_seconds=max(timeout_seconds, 90))
                headers["x-download-source"] = "graph"
                host = urlparse(url).netloc
                ct = headers.get("content-type", "unknown")
                logger.info(f"artifact_downloaded host={host} source=graph content_type={ct} bytes={len(data)}")
                return data, headers

            except Exception as e:
                host = urlparse(url).netloc
                logger.warning(f"sharepoint_graph_download_failed host={host} error={e}")
                logger.info("sharepoint_http_fallback_due_to_graph_failure")
        
        logger.info("sharepoint_http_fallback_attempt")
        # 2) HTTP fallback attempt using download=1
        url2 = _with_download_flag(url)
        with httpx.Client(follow_redirects=True, timeout=timeout_seconds) as client:
            r = client.get(url2)
            r.raise_for_status()
            headers = {k.lower(): v for k, v in r.headers.items()}
            data = r.content

            ct = (headers.get("content-type") or "").lower()
            if "text/html" not in ct and not _looks_like_html(data):
                headers["x-download-source"] = "http"
                logger.info(f"artifact_downloaded host={urlparse(url).netloc} source=http content_type={ct} bytes={len(data)}")
                return data, headers

        # 3) If we got here, HTTP returned HTML and Graph was not available or failed
        raise ValueError(
            "SharePoint download failed: direct HTTP returned HTML and Graph credentials are missing or Graph failed"
        )

    # Non-SharePoint path
    with httpx.Client(follow_redirects=True, timeout=timeout_seconds) as client:
        r = client.get(url)
        r.raise_for_status()
        headers = {k.lower(): v for k, v in r.headers.items()}
        data = r.content

        ct = (headers.get("content-type") or "").lower()
        if "text/html" in ct or _looks_like_html(data):
            raise ValueError(
                "Download failed: server returned HTML instead of file bytes (often permissions or viewer page)"
            )

        headers["x-download-source"] = "http"
        host = urlparse(url).netloc
        size = len(data)
        logger.info(f"artifact_downloaded host={host} source=http content_type={ct or 'unknown'} bytes={size}")

        return data, headers


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
    ext = (urlparse(url).path or "").lower()
    sig = sniff_format(data)

    meta: dict[str, Any] = {
        "source": headers.get("x-download-source", "http"),
        "content_type": ct,
        "bytes": len(data),
        "sniffed_format": sig,
    }

    # PDF: by signature, content-type, or extension
    if sig == "pdf" or "pdf" in ct or ext.endswith(".pdf"):
        text = extract_pdf_text(data)
        meta["parser"] = "pypdf"
        return text, meta

    # DOCX: zip signature plus word hints, or extension/content-type
    # Warning: zip could be other things, but in staffing intake, it is commonly docx.
    is_docx_hint = ("word" in ct) or ext.endswith(".docx")
    if sig == "zip" and is_docx_hint:
        text = extract_docx_text(data)
        meta["parser"] = "python-docx"
        return text, meta

    # If it is zip but not clearly docx, fail clearly
    if sig == "zip" and not is_docx_hint:
        raise ValueError("Downloaded a ZIP container but it does not look like a DOCX. Unsupported for extraction.")

    # Plain text: decode best effort
    if sig == "txt" or "text/plain" in ct or ext.endswith(".txt"):
        try:
            text = data.decode("utf-8", errors="replace")
        except Exception:
            text = data.decode("latin-1", errors="replace")
        meta["parser"] = "text"
        return text.strip(), meta

    # RTF: we can store but not reliably parse without adding a dependency
    if sig == "rtf" or "rtf" in ct or ext.endswith(".rtf"):
        raise ValueError("RTF detected. Extraction not supported yet. Convert to PDF or DOCX.")

    # Old Word .doc
    if sig == "ole" or ext.endswith(".doc"):
        raise ValueError("Legacy .doc detected (OLE). Extraction not supported yet. Convert to PDF or DOCX.")

    raise ValueError(f"unsupported content type for extraction: {ct or 'unknown'} (sniffed={sig})")
