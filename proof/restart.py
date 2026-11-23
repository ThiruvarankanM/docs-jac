"""Read back what the scenario left, so two runs (before and after a restart) can be diffed.

usage: restart.py <base-url> <oidc-url>
"""

import json
import sys

sys.argv = [sys.argv[0], sys.argv[1], sys.argv[2]]
import drive  # noqa: E402  (runs nothing: drive.py's scenario is guarded below)

C = {w: drive.Client(w + "@example.com") for w in ["amy", "bob", "cat"]}


def get(who, path):
    status, _, body = C[who].call("GET", path)
    print("###", who, path, status)
    print(json.dumps(json.loads(body), indent=1, sort_keys=True) if body else "")
    return json.loads(body) if body else None


for who in C:
    get(who, "users/me/")
    for d in get(who, "documents/all/")["results"]:
        get(who, "documents/%s/abilities/" % d["id"])
        get(who, "documents/%s/tree/" % d["id"])
        get(who, "documents/%s/accesses/" % d["id"])
        get(who, "documents/%s/invitations/" % d["id"])
    get(who, "documents/")
    get(who, "documents/favorites/")
    get(who, "documents/trashbin/")
