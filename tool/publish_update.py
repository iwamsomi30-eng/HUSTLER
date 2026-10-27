"""Inaandika app_updates/android na app_updates/windows kwenye Firestore
baada ya release ya GitHub kukamilika. Inaendeshwa na GitHub Actions."""
import json, os, re, sys
import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

REPO = os.environ["REPO"]
TAG = os.environ["TAG"]
PROJECT = "tag-750a0"

# Toleo kutoka pubspec.yaml (chanzo kimoja cha ukweli)
m = re.search(r"^version:\s*([\d.]+)\+(\d+)", open("pubspec.yaml", encoding="utf-8").read(), re.M)
if not m:
    sys.exit("pubspec.yaml: version: X.Y.Z+N haipatikani")
version, build = m.group(1), int(m.group(2))
if not TAG.lstrip("vV").startswith(version):
    sys.exit(f"Tag {TAG} hailingani na pubspec version {version}")

notes = ""
nf = os.environ.get("NOTES_FILE", "")
if nf and os.path.exists(nf):
    notes = open(nf, encoding="utf-8").read().strip()[:4000]

base = f"https://github.com/{REPO}/releases/download/{TAG}"
docs = {
    "android": f"{base}/mfuko-wa-kanisa.apk",
    "windows": f"{base}/MFUKO-WA-KANISA-Setup-v{version}.exe",
}

info = json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT"])
creds = service_account.Credentials.from_service_account_info(
    info, scopes=["https://www.googleapis.com/auth/datastore"])
creds.refresh(Request())
H = {"Authorization": f"Bearer {creds.token}"}

for name, url in docs.items():
    # Hakikisha faili lipo kabla ya kutangaza (repo lazima iwe public)
    r = requests.head(url, allow_redirects=True, timeout=30)
    if r.status_code != 200:
        sys.exit(f"{name}: {url} -> HTTP {r.status_code} (repo ni public? release ina faili?)")
    size = int(r.headers.get("Content-Length", 0))

    fields = {
        "version": {"stringValue": version},
        "build": {"integerValue": str(build)},
        "url": {"stringValue": url},
        "notes": {"stringValue": notes},
        "size": {"integerValue": str(size)},
        "pageUrl": {"stringValue": f"https://github.com/{REPO}/releases/tag/{TAG}"},
    }
    # updateMask: hairudishi 'minBuild' / 'force' ulizoweka mkono
    mask = "&".join(f"updateMask.fieldPaths={k}" for k in fields)
    api = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
           f"/databases/(default)/documents/app_updates/{name}?{mask}")
    resp = requests.patch(api, headers=H, json={"fields": fields}, timeout=30)
    if resp.status_code != 200:
        sys.exit(f"{name}: Firestore {resp.status_code} {resp.text}")
    print(f"OK app_updates/{name} -> {version}+{build} ({size} bytes)")
