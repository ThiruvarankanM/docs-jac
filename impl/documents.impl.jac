import json;
import from stdjac { remove }

impl key(n: int) -> str {
    out = "";
    while n > 0 {
        out = ALPHABET[n % 36] + out;
        n = n // 36;
    }
    return out.rjust(STEP, "0");
}

impl num(seg: str) -> int {
    return int(seg, 36);
}

impl last_key(prefix: str, depth: int) -> int {
    found = [num(x.path[-STEP:]) for x in docs() if x.depth == depth and x.path.startswith(prefix)];
    return max(found) if found else 0;
}

impl roots_of(paths: list[str]) -> list[str] {
    out: list[str] = [];
    for p in sorted(paths) {
        if not out or not p.startswith(out[-1]) {
            out.append(p);
        }
    }
    return out;
}

impl readable(u: User) -> list[Doc] {
    return [
        d for d in docs()
        if d.anc_deleted == 0.0 and (access_of(d, u) is not None or (d.link_reach != "restricted" and traced(d, u)))
    ];
}

impl filtered(u: User, items: list[Doc], q: dict[str, str]) -> list[Doc] {
    mine = q.get("is_creator_me", "");
    if mine in ["true", "True", "1"] {
        items = [d for d in items if d.creator == u.id];
    } elif mine in ["false", "False", "0"] {
        items = [d for d in items if d.creator != u.id];
    }
    for k in ["title", "q"] {
        if q.get(k, "") {
            want = fold(q[k]);
            items = [d for d in items if d.titled and want in fold(d.title)];
        }
    }
    return items;
}

impl by_fav(u: User, items: list[Doc], q: dict[str, str]) -> list[Doc] {
    want = q.get("is_favorite", "");
    if want in ["true", "True", "1"] {
        return [d for d in items if faved(d, u)];
    }
    if want in ["false", "False", "0"] {
        return [d for d in items if not faved(d, u)];
    }
    return items;
}

impl ordered(items: list[Doc], q: dict[str, str]) -> list[Doc] {
    field = q.get("ordering", "-updated_at");
    desc = field.startswith("-");
    name = field.lstrip("-");
    if name not in ORDERINGS {
        (name, desc) = ("updated_at", True);
    }
    if name == "title" {
        titled = sorted([d for d in items if d.titled], key=lambda (d: Doc) -> str { d.title }, reverse=desc);
        blank = [d for d in items if not d.titled];
        return blank + titled if desc else titled + blank;
    }
    if name == "created_at" {
        return sorted(items, key=lambda (d: Doc) -> float { d.created }, reverse=desc);
    }
    return sorted(items, key=lambda (d: Doc) -> float { d.updated }, reverse=desc);
}

impl paged(u: User | None, items: list[Doc], q: dict[str, str], base: str, path: str, fav: bool) -> Reply {
    got = page(items, q, base, path);
    if isinstance(got, Reply) {
        return got;
    }
    got["results"] = [doc_json(u, d, fav) for d in got["results"]];
    return reply(200, got);
}

impl listing(query: str, base: str) -> Reply {
    q: dict[str, str] = json.loads(query);
    u = caller();
    if u is None {
        return paged(None, [], q, base, PATH, True);
    }
    items = filtered(u, readable(u), q);
    keep = roots_of([d.path for d in items]);
    items = by_fav(u, [d for d in items if d.path in keep], q);
    return paged(u, ordered(items, q), q, base, PATH, True);
}

impl favorites(query: str, base: str) -> Reply {
    q: dict[str, str] = json.loads(query);
    u = caller();
    if u is None {
        return denied(True);
    }
    keep = roots_of([d.path for d in readable(u)]);
    items = [
        d for d in docs()
        if d.anc_deleted == 0.0 and faved(d, u) and any(d.path.startswith(p) for p in keep)
    ];
    items = sorted(items, key=lambda (d: Doc) -> float { d.updated }, reverse=True);
    return paged(u, items, q, base, PATH + "favorites/", True);
}

impl trashbin(query: str, base: str) -> Reply {
    q: dict[str, str] = json.loads(query);
    u = caller();
    if u is None {
        return paged(None, [], q, base, PATH + "trashbin/", False);
    }
    owned = [d.path for d in docs() if access_of(d, u) is not None and access_of(d, u).role == "owner"];
    cutoff = now() - TRASH_DAYS * 86400.0;
    items = [
        d for d in docs()
        if d.deleted > 0.0 and d.deleted >= cutoff and any(d.path.startswith(p) for p in owned)
    ];
    items = sorted(items, key=lambda (d: Doc) -> float { d.deleted }, reverse=True);
    return paged(u, items, q, base, PATH + "trashbin/", False);
}

impl all_docs(query: str, base: str) -> Reply {
    q: dict[str, str] = json.loads(query);
    u = caller();
    if u is None {
        return paged(None, [], q, base, PATH + "all/", True);
    }
    paths = [d.path for d in readable(u)];
    items = [d for d in docs() if d.anc_deleted == 0.0 and any(d.path.startswith(p) for p in paths)];
    items = by_fav(u, filtered(u, items, q), q);
    return paged(u, ordered(items, q), q, base, PATH + "all/", True);
}

impl title_error(data: dict[str, any]) -> Reply | None {
    t = data.get("title");
    if t is not None and len(str(t)) > 255 {
        return reply(400, {"title": ["Ensure this field has no more than 255 characters."]});
    }
    return None;
}

impl set_title(d: Doc, data: dict[str, any]) {
    if "title" in data {
        t = data["title"];
        d.titled = t is not None;
        d.title = "" if t is None else str(t);
    }
}

impl create(body: str) -> Reply {
    u = caller();
    if u is None {
        return denied(True);
    }
    data = loads(body);
    bad = title_error(data);
    if bad is not None {
        return bad;
    }
    if "id" in data and not is_uuid(data["id"]) {
        return reply(400, {"id": ["Must be a valid UUID."]});
    }
    t = now();
    d = Doc(
        id=data.get("id") or new_uuid(),
        path=key(last_key("", 1) + 1),
        depth=1,
        creator=u.id,
        created=t,
        updated=t,
    );
    set_title(d, data);
    root.shared ++> d;
    t2 = now();
    d +>:Access(id=new_uuid(), role="owner", created=t2, updated=t2):+> u;
    return reply(201, doc_json(u, d, False));
}

impl retrieve(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "retrieve");
    if bad is not None {
        return bad;
    }
    if u is not None and not traced(d, u) {
        d +>:Trace:+> u;
    }
    return reply(200, doc_json(u, d, True));
}

impl abilities_of(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "retrieve");
    if bad is not None {
        return bad;
    }
    return reply(200, {"abilities": abilities(u, d)});
}

impl edit(pk: str, body: str, action: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, action);
    if bad is not None {
        return bad;
    }
    data = loads(body);
    bad = title_error(data);
    if bad is not None {
        return bad;
    }
    set_title(d, data);
    d.updated = now();
    return reply(200, doc_json(u, d, True));
}

impl patch(pk: str, body: str) -> Reply {
    return edit(pk, body, "partial_update");
}

impl put(pk: str, body: str) -> Reply {
    return edit(pk, body, "update");
}

impl soft_delete(d: Doc) {
    t = now();
    d.deleted = t;
    d.anc_deleted = t;
    d.updated = t;
    forget_nb(d);
    p = parent(d);
    if p is not None {
        p.numchild -= 1;
    }
    for x in under(d) {
        if x is not d and x.anc_deleted == 0.0 {
            x.anc_deleted = t;
            x.updated = t;
        }
    }
}

impl destroy(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "destroy");
    if bad is not None {
        return bad;
    }
    if role_of(u, d) not in PRIVILEGED and any(x.deleted == 0.0 for x in kids(d)) {
        return denied(False);
    }
    soft_delete(d);
    return empty();
}

impl children(pk: str, query: str, base: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "children_list");
    if bad is not None {
        return bad;
    }
    q: dict[str, str] = json.loads(query);
    items = [x for x in kids(d) if x.anc_deleted == 0.0];
    for k in ["title", "q"] {
        if q.get(k, "") {
            want = fold(q[k]);
            items = [x for x in items if x.titled and want in fold(x.title)];
        }
    }
    return paged(u, items, q, base, PATH + pk + "/children/", True);
}

impl add_child(pk: str, body: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "children_create");
    if bad is not None {
        return bad;
    }
    data = loads(body);
    bad = title_error(data);
    if bad is not None {
        return bad;
    }
    if "id" in data and not is_uuid(data["id"]) {
        return reply(400, {"id": ["Must be a valid UUID."]});
    }
    t = now();
    c = Doc(
        id=data.get("id") or new_uuid(),
        path=d.path + key(last_key(d.path, d.depth + 1) + 1),
        depth=d.depth + 1,
        creator=u.id,
        created=t,
        updated=t,
    );
    set_title(c, data);
    root.shared ++> c;
    d.numchild += 1;
    return reply(201, doc_json(u, c, False));
}

impl tree(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return detail(404, "Not found.");
    }
    u = caller();
    if d.anc_deleted > 0.0 {
        if role_of(u, d) != "owner" {
            return denied(u is None);
        }
        (high, line) = (d, [d]);
    } else {
        line = [x for x in lineage(d) if x.anc_deleted == 0.0];
        high: Doc | None = None;
        for x in line {
            open = x.link_reach == "public" or (x.link_reach == "authenticated" and u is not None);
            if (u is not None and access_of(x, u) is not None) or open {
                high = x;
                break;
            }
        }
        if high is None {
            return denied(u is None);
        }
    }
    picked = {x.path: x for x in line if x.depth >= high.depth};
    for a in line {
        if a.depth >= high.depth {
            for k in kids(a) {
                if k.deleted == 0.0 {
                    picked[k.path] = k;
                }
            }
        }
    }
    nodes: dict[str, dict[str, any]] = {};
    top_node: dict[str, any] | None = None;
    for p in sorted(picked) {
        n = doc_json(u, picked[p], True);
        n["children"] = [];
        nodes[p] = n;
        if p[:-STEP] in nodes {
            nodes[p[:-STEP]]["children"].append(n);
        } elif top_node is None {
            top_node = n;
        }
    }
    return reply(200, top_node);
}

impl link_configuration(pk: str, body: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "link_configuration");
    if bad is not None {
        return bad;
    }
    data = loads(body);
    errors: dict[str, list[str]] = {};
    for (field, choices) in [("link_role", LINK_ROLES), ("link_reach", REACHES)] {
        if field in data {
            v = data[field];
            if v is None {
                errors[field] = ["This field may not be null."];
            } elif v not in choices {
                errors[field] = [f"\"{v}\" is not a valid choice."];
            }
        }
    }
    if errors {
        return reply(400, errors);
    }
    reach = data.get("link_reach");
    role = data.get("link_role");
    if not reach {
        return reply(400, {"link_reach": ["This field is required."]});
    }
    anc = ancestors_def(d);
    options = select_options(anc[0], anc[1]);
    if reach not in options {
        return reply(400, {"link_reach": [f"Link reach '{reach}' is not allowed based on parent document configuration."]});
    }
    if reach == "restricted" {
        if role is not None {
            return reply(400, {"link_role": ["Cannot set link_role when link_reach is 'restricted'. Link role must be null for restricted reach."]});
        }
    } elif role not in options[reach] {
        allowed = ", ".join(options[reach]) if options[reach] else "none";
        return reply(400, {"link_role": [f"Link role '{role}' is not allowed for link reach '{reach}'. Allowed roles: {allowed}"]});
    }
    d.link_reach = reach;
    if role is not None {
        d.link_role = role;
    }
    d.updated = now();
    return reply(200, {"link_role": d.link_role, "link_reach": d.link_reach});
}

impl favorite(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "favorite");
    if bad is not None {
        return bad;
    }
    if faved(d, u) {
        return detail(200, "Document already marked as favorite");
    }
    d +>:Favorite:+> u;
    return detail(201, "Document marked as favorite");
}

impl unfavorite(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "favorite");
    if bad is not None {
        return bad;
    }
    if not faved(d, u) {
        return detail(200, "Document was already not marked as favorite");
    }
    d del ->:Favorite:-> u;
    return empty();
}

impl leave(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "leave");
    if bad is not None {
        return bad;
    }
    for x in under(d) {
        x del ->:Access:-> u;
        x del ->:Trace:-> u;
    }
    return empty();
}

impl shift(prefix: str, depth: int, start: int) {
    sibs = [x for x in docs() if x.depth == depth and x.path.startswith(prefix) and num(x.path[len(prefix):len(prefix) + STEP]) >= start];
    for s in sorted(sibs, key=lambda (x: Doc) -> str { x.path }, reverse=True) {
        repath(s, prefix + key(num(s.path[-STEP:]) + 1));
    }
}

impl repath(d: Doc, path: str) {
    old = d.path;
    for x in under(d) {
        x.path = path + x.path[len(old):];
        x.depth = len(x.path) // STEP;
    }
}

impl move(pk: str, body: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "move");
    if bad is not None {
        return bad;
    }
    data = loads(body);
    errors: dict[str, list[str]] = {};
    target_id = data.get("target_document_id");
    if target_id is None {
        errors["target_document_id"] = ["This field is required."];
    } elif not is_uuid(target_id) {
        errors["target_document_id"] = ["Must be a valid UUID."];
    }
    pos = data.get("position", "last-child");
    if pos not in POSITIONS {
        errors["position"] = [f"\"{pos}\" is not a valid choice."];
    }
    if errors {
        return reply(400, errors);
    }
    target = doc_by_id(target_id);
    if target is None or target.anc_deleted > 0.0 {
        return reply(400, {"target_document_id": "Target parent document does not exist."});
    }
    as_child = pos in ["first-child", "last-child"];
    owners: list[User] = [];
    msg = "";
    if as_child {
        if not abilities(u, target)["move"] {
            msg = "You do not have permission to move documents as a child to this target document.";
        }
    } elif target.depth == 1 {
        top_doc = lineage(d)[0];
        owners = [holder(e) for e in accesses(top_doc) if e.role == "owner"];
    } elif not abilities(u, parent(target))["move"] {
        msg = "You do not have permission to move documents as a sibling of this target document.";
    }
    if msg {
        return reply(400, {"target_document_id": msg});
    }
    sibling_root = not as_child and target.depth == 1;
    leaves = not sibling_root and d.path[:STEP] != target.path[:STEP];
    scope = d.depth == 1 or sibling_root or leaves;
    if scope and role_of(u, d) != "owner" {
        return detail(403, "Only an owner can move a document out of its tree.");
    }
    if target.path.startswith(d.path) {
        return reply(400, {"target_document_id": "Cannot move a document to its own descendant."});
    }
    old_parent = parent(d);
    if pos == "first-child" {
        first = kids(target);
        if first {
            (target, pos) = (first[0], "left");
        } else {
            pos = "last-child";
        }
    }
    if pos == "right" {
        later = [x for x in kids(parent(target)) if x.path > target.path] if target.depth > 1 else [x for x in docs() if x.depth == 1 and x.path > target.path];
        if later {
            (target, pos) = (later[0], "left");
        } else {
            pos = "last-sibling";
        }
    }
    if pos == "first-sibling" {
        prefix = target.path[:-STEP];
        sibs = sorted([x for x in docs() if x.depth == target.depth and x.path.startswith(prefix)], key=lambda (x: Doc) -> str { x.path });
        (target, pos) = (sibs[0], "left");
    }
    if pos == "last-child" {
        repath(d, target.path + key(last_key(target.path, target.depth + 1) + 1));
    } elif pos == "last-sibling" {
        prefix = target.path[:-STEP];
        repath(d, prefix + key(last_key(prefix, target.depth) + 1));
    } else {
        slot = target.path;
        shift(slot[:-STEP], target.depth, num(slot[-STEP:]));
        repath(d, slot);
    }
    if old_parent is not None {
        old_parent.numchild -= 1;
    }
    new_parent = parent(d);
    if new_parent is not None {
        new_parent.numchild += 1;
    }
    if scope {
        for e in accesses(d) {
            del e;
        }
        for i in [d --> [?:Invite]] {
            remove(i);
        }
    }
    if owners and not any(e.role == "owner" for e in accesses(d)) {
        for who in owners {
            t = now();
            d +>:Access(id=new_uuid(), role="owner", created=t, updated=t):+> who;
        }
    }
    forget_nb(d);
    return reply(200, {"message": "Document moved successfully."});
}

impl restore(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return no_doc();
    }
    u = caller();
    bad = gate(u, d, "restore");
    if bad is not None {
        return bad;
    }
    old = d.deleted;
    d.deleted = 0.0;
    gone = [x.deleted for x in lineage(d) if x is not d and x.deleted > 0.0];
    d.anc_deleted = min(gone) if gone else 0.0;
    forget_nb(d);
    for x in under(d) {
        if x is d or x.deleted > 0.0 or (x.anc_deleted > 0.0 and x.anc_deleted < old) {
            continue;
        }
        x.anc_deleted = d.anc_deleted;
    }
    p = parent(d);
    if p is not None {
        p.numchild += 1;
    }
    return detail(200, "Document has been successfully restored.");
}
