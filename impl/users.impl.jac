import json;
import re;

impl signed_in(sub: str, email: str) -> dict[str, str] {
    for m in [root --> [?:Me]] {
        return {"user": m.user};
    }
    found: User | None = None;
    for u in users() {
        if u.sub == sub {
            found = u;
        }
    }
    if found is None {
        found = User(id=new_uuid(), sub=sub, email=email, created=now());
        root.shared ++> found;
    }
    root ++> Me(user=found.id);
    return {"user": found.id};
}

impl me -> Reply {
    u = caller();
    if u is None {
        return denied(True);
    }
    return reply(200, user_json(u));
}

impl onboarding_done -> Reply {
    u = caller();
    if u is None {
        return denied(True);
    }
    u.first = False;
    return detail(200, "Onboarding marked as done.");
}

impl trigrams(s: str) -> set[str] {
    out: set[str] = set();
    for w in re.findall(r"[^\W_]+", s.lower()) {
        p = "  " + w + " ";
        for i in range(len(p) - 2) {
            out.add(p[i:i + 3]);
        }
    }
    return out;
}

impl similarity(a: str, b: str) -> float {
    (x, y) = (trigrams(a), trigrams(b));
    if not x or not y {
        return 0.0;
    }
    return len(x & y) / len(x | y);
}

impl distance(a: str, b: str) -> int {
    row = list(range(len(b) + 1));
    for (i, ca) in enumerate(a) {
        nxt = [i + 1];
        for (j, cb) in enumerate(b) {
            nxt.append(min(row[j + 1] + 1, nxt[j] + 1, row[j] + (0 if ca == cb else 1)));
        }
        row = nxt;
    }
    return row[-1];
}

impl search(query: str) -> Reply {
    me = caller();
    if me is None {
        return denied(True);
    }
    q: dict[str, str] = json.loads(query);
    text = q.get("q", "");
    if text and len(text) < 3 {
        return reply(400, {"q": [f"Ensure this value has at least 3 characters (it has {len(text)})."]});
    }
    if len(text) > 254 {
        return reply(400, {"q": [f"Ensure this value has at most 254 characters (it has {len(text)})."]});
    }
    pool = users();
    if q.get("document_id", "") {
        d = doc_by_id(q["document_id"]);
        if d is not None {
            inside = {holder(e).id for e in accesses(d)};
            pool = [u for u in pool if u.id not in inside];
        }
    }
    text = fold(text);
    if not text {
        return reply(200, []);
    }
    if "@" in text {
        hits = [u for u in pool if similarity(fold(u.email), text) >= SIMILAR and distance(fold(u.email), text) <= 3];
        hits = sorted(hits, key=lambda (u: User) -> tuple[int, str] { (distance(fold(u.email), text), u.email) });
        return reply(200, [user_json(u) for u in hits[:SEARCH_LIMIT]]);
    }
    shared: dict[str, float] = {};
    for d in docs() {
        if access_of(d, me) is None {
            continue;
        }
        for e in accesses(d) {
            who = holder(e).id;
            if who != me.id {
                shared[who] = max(shared.get(who, 0.0), e.created);
            }
        }
    }
    domain = me.email.split("@")[-1];
    def score(u: User) -> float {
        return max(similarity(fold(u.email), text), similarity(fold(u.full_name), text));
    }
    near = [u for u in pool if score(u) >= SIMILAR];
    first = sorted(
        [u for u in near if u.id in shared],
        key=lambda (u: User) -> tuple[float, bool, float] { (shared[u.id], u.email.split("@")[-1] == domain, score(u)) },
        reverse=True,
    );
    rest = sorted(
        [u for u in near if u.id not in shared and u.email.endswith("@" + domain)],
        key=lambda (u: User) -> float { -score(u) },
    );
    return reply(200, [user_json(u) for u in (first + rest)[:SEARCH_LIMIT]]);
}

impl update(id: str, body: str) -> Reply {
    me = caller();
    if me is None {
        return denied(True);
    }
    u = user_by_id(id);
    if u is None {
        return detail(404, "No User matches the given query.");
    }
    if u.id != me.id {
        return denied(False);
    }
    data = loads(body);
    if "language" in data {
        lang = data["language"];
        if lang is not None and lang not in LANGUAGES {
            return reply(400, {"language": [f"\"{lang}\" is not a valid choice."]});
        }
        u.language = lang or "";
    }
    return reply(200, user_json(u));
}
