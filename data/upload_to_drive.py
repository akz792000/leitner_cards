#!/usr/bin/env python3
"""
Upload local JSON files from data/ to Google Drive FlashMind/ folders.

Local structure mirrors Drive:
  data/FA_EN/cards.json        → FlashMind/FA_EN/cards.json
  data/EN_DE/cards.json        → FlashMind/EN_DE/cards.json
  data/EN_DE_VERBS/cards.json  → FlashMind/EN_DE_VERBS/cards.json

Usage:
  python3 data/upload_to_drive.py              # upload all folders
  python3 data/upload_to_drive.py FA_EN        # upload only FA_EN

First run opens a browser for Google OAuth. Token is cached in data/.token.json.
"""

import json
import os
import sys

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaInMemoryUpload

SCOPES = ["https://www.googleapis.com/auth/drive"]
DATA_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.join(DATA_DIR, os.pardir)
TOKEN_PATH = os.path.join(DATA_DIR, ".token.json")
ENV_PATH = os.path.join(PROJECT_DIR, ".env")

FLASHMIND_ROOT = "FlashMind"


def load_env():
    """Load .env file into environment."""
    if os.path.exists(ENV_PATH):
        with open(ENV_PATH) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, val = line.split("=", 1)
                    os.environ.setdefault(key.strip(), val.strip())


def get_credentials():
    """Get or refresh OAuth credentials."""
    creds = None
    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            client_id = os.environ.get("GOOGLE_CLIENT_ID", "")
            client_secret = os.environ.get("GOOGLE_CLIENT_SECRET", "")
            if not client_id or not client_secret:
                print("❌ GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET required in .env")
                sys.exit(1)

            client_config = {
                "installed": {
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": ["http://localhost"],
                }
            }
            flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
            creds = flow.run_local_server(port=0)

        with open(TOKEN_PATH, "w") as f:
            f.write(creds.to_json())

    return creds


def find_or_create_folder(service, name, parent_id=None):
    """Find a folder by name (under parent) or create it."""
    q = f"name='{name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
    if parent_id:
        q += f" and '{parent_id}' in parents"

    results = service.files().list(q=q, fields="files(id,name)", spaces="drive").execute()
    files = results.get("files", [])

    if files:
        return files[0]["id"]

    metadata = {
        "name": name,
        "mimeType": "application/vnd.google-apps.folder",
    }
    if parent_id:
        metadata["parents"] = [parent_id]

    folder = service.files().create(body=metadata, fields="id").execute()
    print(f"  📁 Created folder: {name}")
    return folder["id"]


def upload_json(service, folder_id, filename, data):
    """Upload or update a JSON file in a Drive folder."""
    # Check if file exists
    q = f"name='{filename}' and '{folder_id}' in parents and trashed=false"
    results = service.files().list(q=q, fields="files(id)").execute()
    existing = results.get("files", [])

    content = json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8")
    media = MediaInMemoryUpload(content, mimetype="application/json")

    if existing:
        service.files().update(
            fileId=existing[0]["id"], media_body=media
        ).execute()
    else:
        metadata = {"name": filename, "parents": [folder_id]}
        service.files().create(body=metadata, media_body=media).execute()


def main():
    creds = get_credentials()
    service = build("drive", "v3", credentials=creds)

    # Discover deck folders in data/
    filter_name = sys.argv[1].upper() if len(sys.argv) > 1 else None
    deck_folders = sorted([
        d for d in os.listdir(DATA_DIR)
        if os.path.isdir(os.path.join(DATA_DIR, d)) and not d.startswith(".")
    ])

    if filter_name:
        deck_folders = [d for d in deck_folders if d == filter_name]
        if not deck_folders:
            print(f"❌ Folder not found: {filter_name}")
            print(f"   Available: {', '.join(sorted(os.listdir(DATA_DIR)))}")
            sys.exit(1)

    # Find or create FlashMind root folder
    root_id = find_or_create_folder(service, FLASHMIND_ROOT)

    for deck_name in deck_folders:
        deck_dir = os.path.join(DATA_DIR, deck_name)
        folder_id = find_or_create_folder(service, deck_name, root_id)

        # Upload all JSON files in the deck folder
        json_files = [f for f in os.listdir(deck_dir) if f.endswith(".json")]
        if not json_files:
            print(f"⚠️  Skipping {deck_name}/ — no JSON files")
            continue

        for json_file in json_files:
            file_path = os.path.join(deck_dir, json_file)
            with open(file_path) as f:
                data = json.load(f)

            upload_json(service, folder_id, json_file, data)
            count = len(data) if isinstance(data, list) else "—"
            print(f"✅ {deck_name}/{json_file} → FlashMind/{deck_name}/{json_file} ({count} items)")


if __name__ == "__main__":
    load_env()
    main()
