import json;
import re;
import time;
import uuid;
import unicodedata;
import urllib.parse;
import from datetime { datetime, timezone }

impl reply(status: int, data: any) -> Reply {
    return Reply(status=status, body=json.dumps(data));
}

impl empty -> Reply {
    return Reply(status=204, body="");
}

impl detail(status: int, msg: str) -> Reply {
    return reply(status, {"detail": msg});
}

impl denied(anon: bool) -> Reply {
    if anon {
        return detail(401, "Authentication credentials were not provided.");
    }
    return detail(403, "You do not have permission to perform this action.");
}

impl now -> float {
    return time.time();
}

impl iso(t: float) -> str | None {
    if t <= 0.0 {
        return None;
    }
    return datetime.fromtimestamp(t, timezone.utc).isoformat().replace("+00:00", "Z");
}

impl new_uuid -> str {
    return str(uuid.uuid4());
}

impl is_uuid(s: any) -> bool {
    if not isinstance(s, str) {
        return False;
    }
    try {
        uuid.UUID(s);
        return True;
    } except ValueError {
        return False;
    }
}

impl loads(text: str) -> dict[str, any] {
    try {
        v = json.loads(text) if text else {};
    } except ValueError {
        return {};
    }
    return v if isinstance(v, dict) else {};
}

impl slug(s: str) -> str {
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii");
    s = re.sub(r"[^\w\s-]", "", s.lower());
    return re.sub(r"[-\s]+", "-", s).strip("-_");
}

impl fold(s: str) -> str {
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c)).lower();
}

impl page(items: list[any], q: dict[str, str], base: str, path: str) -> Reply | dict[str, any] {
    size = 20;
    if q.get("page_size", "").isdigit() and int(q["page_size"]) > 0 {
        size = min(int(q["page_size"]), 200);
    }
    n = 1;
    raw = q.get("page", "1");
    if raw == "last" {
        n = max(1, (len(items) + size - 1) // size);
    } elif raw.isdigit() {
        n = int(raw);
    } else {
        return detail(404, "Invalid page.");
    }
    pages = max(1, (len(items) + size - 1) // size);
    if n < 1 or n > pages {
        return detail(404, "Invalid page.");
    }
    def link(k: int) -> str {
        p = {a: b for (a, b) in q.items() if a != "page"};
        if k > 1 {
            p["page"] = str(k);
        }
        qs = urllib.parse.urlencode(sorted(p.items()));
        return base + path + ("?" + qs if qs else "");
    }
    return {
        "count": len(items),
        "next": link(n + 1) if n < pages else None,
        "previous": link(n - 1) if n > 1 else None,
        "results": items[(n - 1) * size:n * size]
    };
}
