from __future__ import annotations
import os
from urllib.parse import urlparse, parse_qsl, urlencode, urlunparse

import logging
from urllib.parse import urlparse

import io
from typing import Any, Tuple

import httpx
from pypdf import PdfReader
from docx import Document
from worker.utils.graph_download import download_sharepoint_bytes, is_sharepoint_url

logger = logging.getLogger(__name__)


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


def download_bytes(url: str, timeout_seconds: int = 60) -> tuple[bytes, dict[str, str]]:
    if is_sharepoint_url(url):
        # 1) If Graph creds exist, prefer Graph first
        if _has_graph_creds():
            try:
                data, headers = download_sharepoint_bytes(url, timeout_seconds=max(timeout_seconds, 90))
                headers["x-download-source"] = "graph"
                host = urlparse(url).netloc
                ct = headers.get("content-type", "unknown")
                logger.info(f"artifact_downloaded host={host} source=graph content_type={ct} bytes={len(data)}")
                return data, headers

            except Exception as e:
                # If Graph fails, we only fall back to HTTP if it yields a real file (not HTML)
                pass

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
                return data, headers

        # 3) If we got here, HTTP returned HTML and Graph was not available or failed
        raise ValueError("SharePoint download failed: direct HTTP returned HTML and Graph credentials are missing or Graph failed")

    # Non SharePoint path remains unchanged
    headers: dict[str, str] = {}
    with httpx.Client(follow_redirects=True, timeout=timeout_seconds) as client:
        r = client.get(url)
        r.raise_for_status()
        headers = {k.lower(): v for k, v in r.headers.items()}
        headers["x-download-source"] = "http"
        host = urlparse(url).netloc
        source = headers.get("x-download-source", "http")  # graph branch should set this explicitly
        ct = headers.get("content-type", "unknown")
        size = len(r.content)
        logger.info(f"artifact_downloaded host={host} source={source} content_type={ct} bytes={size}")

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
