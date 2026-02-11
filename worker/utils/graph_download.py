from __future__ import annotations

import base64
import os
from typing import Optional

import httpx
import msal


GRAPH_SCOPE = ["https://graph.microsoft.com/.default"]
GRAPH_BASE = "https://graph.microsoft.com/v1.0"


def _get_env(name: str) -> str:
    v = os.getenv(name)
    if not v:
        raise RuntimeError(f"Missing env var: {name}")
    return v


def get_graph_access_token() -> str:
    tenant_id = _get_env("MS_TENANT_ID")
    client_id = _get_env("MS_CLIENT_ID")
    client_secret = _get_env("MS_CLIENT_SECRET")

    authority = f"https://login.microsoftonline.com/{tenant_id}"

    app = msal.ConfidentialClientApplication(
        client_id=client_id,
        authority=authority,
        client_credential=client_secret,
    )

    result = app.acquire_token_for_client(scopes=GRAPH_SCOPE)
    token = result.get("access_token")
    if not token:
        raise RuntimeError(f"Graph token error: {result}")
    return token


def _to_share_id(share_url: str) -> str:
    # Graph "shares" API expects a url-safe base64 encoded URL, no padding, prefixed with u!
    encoded = base64.urlsafe_b64encode(share_url.encode("utf-8")).decode("utf-8")
    encoded = encoded.rstrip("=")
    return f"u!{encoded}"


def download_sharepoint_bytes(url: str, timeout_seconds: int = 90) -> tuple[bytes, dict[str, str]]:
    token = get_graph_access_token()
    share_id = _to_share_id(url)

    endpoint = f"{GRAPH_BASE}/shares/{share_id}/driveItem/content"

    headers = {"Authorization": f"Bearer {token}"}

    with httpx.Client(follow_redirects=True, timeout=timeout_seconds) as client:
        r = client.get(endpoint, headers=headers)
        r.raise_for_status()
        out_headers = {k.lower(): v for k, v in r.headers.items()}
        out_headers["x-download-source"] = "graph"
        return r.content, out_headers


def is_sharepoint_url(url: str) -> bool:
    u = url.lower()
    return ("sharepoint.com" in u) or ("1drv.ms" in u)
