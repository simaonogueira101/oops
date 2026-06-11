#!/usr/bin/env python3
"""Prepend a new version entry to the SideStore source manifest (source.json).

Usage: update_source.py <version> <ipa_size_bytes> <download_url>
Newest version goes first; re-runs for the same version replace in place.
"""
import json
import sys
from datetime import datetime, timezone

version, size, url = sys.argv[1], int(sys.argv[2]), sys.argv[3]

with open("source.json") as f:
    data = json.load(f)

app = data["apps"][0]
entry = {
    "version": version,
    "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "localizedDescription": "Automated build.",
    "downloadURL": url,
    "size": size,
    "minOSVersion": "26.0",
}

app["versions"] = [v for v in app["versions"] if v.get("version") != version]
app["versions"].insert(0, entry)

with open("source.json", "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print(f"source.json updated to {version} ({size} bytes)")
