import os
import base64
import msal
import requests


GRAPH_SCOPE = ["https://graph.microsoft.com/.default"]
GRAPH_BASE = "https://graph.microsoft.com/v1.0"


def _get_token():
    tenant_id = os.getenv("MS_TENANT_ID")
    client_id = os.getenv("MS_CLIENT_ID")
    client_secret = os.getenv("MS_CLIENT_SECRET")

    if not all([tenant_id, client_id, client_secret]):
        raise RuntimeError("Microsoft Graph credentials not configured")

    authority = f"https://login.microsoftonline.com/{tenant_id}"

    app = msal.ConfidentialClientApplication(
        client_id,
        authority=authority,
        client_credential=client_secret,
    )

    result = app.acquire_token_for_client(scopes=GRAPH_SCOPE)

    if "access_token" not in result:
        raise RuntimeError(f"Graph auth failed: {result}")

    return result["access_token"]


def download_sharepoint_file(share_url: str) -> bytes:
    """
    Accepts a full SharePoint/OneDrive sharing URL.
    Converts to Graph shareId and downloads file bytes.
    """

    token = _get_token()

    # Graph expects base64-encoded URL
    encoded_url = base64.urlsafe_b64encode(
        share_url.encode("utf-8")
    ).decode("utf-8").rstrip("=")

    share_id = f"u!{encoded_url}"

    endpoint = f"{GRAPH_BASE}/shares/{share_id}/driveItem/content"

    headers = {"Authorization": f"Bearer {token}"}

    response = requests.get(endpoint, headers=headers)

    if response.status_code != 200:
        raise RuntimeError(
            f"SharePoint download failed: {response.status_code} {response.text}"
        )

    return response.content
