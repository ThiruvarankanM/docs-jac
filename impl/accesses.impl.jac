impl roles_tuple(u: User, d: Doc) -> tuple[str, str] {
    above: list[str] = [];
    at_doc: list[str] = [];
    for x in lineage(d) {
        if x.anc_deleted > 0.0 {
            continue;
        }
        for e in [edge x ->:Access:-> u] {
            if x is d {
                at_doc.append(e.role);
            } else {
                above.append(e.role);
            }
        }
    }
    return (top(ROLES, above), top(ROLES, at_doc));
}

impl access_abilities(u: User, e: Access, d: Doc, roles: tuple[str, str], anc_max: str) -> dict[str, any] {
    role = top(ROLES, [roles[0], roles[1]]);
    is_priv = role in PRIVILEGED;
    set_to: list[str] = [];
    if e.role == "owner" {
        can_delete = role == "owner" and (d.depth > 1 or len([a for a in accesses(d) if a.role == "owner"]) > 1);
        if can_delete {
            set_to = list(ROLES);
        }
    } else {
        can_delete = is_priv;
        if is_priv {
            set_to = ["reader", "commenter", "editor", "administrator"];
        }
        if role == "owner" {
            set_to.append("owner");
        }
    }
    set_to = [r for r in set_to if prio(ROLES, r) >= prio(ROLES, anc_max)];
    if len(set_to) == 1 {
        set_to = [];
    }
    return {
        "destroy": can_delete,
        "update": bool(set_to) and is_priv,
        "partial_update": bool(set_to) and is_priv,
        "retrieve": holder(e).id == u.id or is_priv,
        "set_role_to": set_to
    };
}

impl access_json(u: User, e: Access, d: Doc, roles: tuple[str, str], anc_max: str, full: bool) -> dict[str, any] {
    who = holder(e);
    return {
        "id": e.id,
        "document": {"id": d.id, "path": d.path, "depth": d.depth},
        "user": user_json(who) if full else light_user(who),
        "team": "",
        "role": e.role,
        "abilities": access_abilities(u, e, d, roles, anc_max),
        "max_ancestors_role": nz(anc_max),
        "max_role": top(ROLES, [anc_max, e.role]),
        "updated_at": iso(e.updated),
        "created_at": iso(e.created)
    };
}

impl find_access(d: Doc, id: str) -> Access | None {
    for e in accesses(d) {
        if e.id == id {
            return e;
        }
    }
    return None;
}

impl list_accesses(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return detail(404, "Not found.");
    }
    u = caller();
    if u is None {
        return denied(True);
    }
    role = role_of(u, d);
    if not role {
        return reply(200, []);
    }
    full = role in PRIVILEGED;
    rows: list[tuple[Doc, Access]] = [];
    for x in lineage(d) {
        if x.anc_deleted > 0.0 {
            continue;
        }
        for e in sorted(accesses(x), key=lambda (a: Access) -> float { a.created }) {
            if role not in COMMENTING and e.role not in PRIVILEGED {
                continue;
            }
            if role in COMMENTING and not full and e.role not in COMMENTING {
                continue;
            }
            rows.append((x, e));
        }
    }
    key_max: dict[str, dict[str, str]] = {};
    anc_roles: dict[str, list[str]] = {};
    my_role: dict[str, str] = {};
    for (x, e) in rows {
        k = holder(e).id;
        up = x.path[:-STEP];
        at_doc = key_max.setdefault(x.path, {});
        at_doc[k] = top(ROLES, [at_doc.get(k, ""), e.role]);
        if up {
            at_doc[k] = top(ROLES, [key_max.setdefault(up, {}).get(k, ""), at_doc[k]]);
            anc_roles.setdefault(x.path, []).extend(anc_roles.get(up, []));
            anc_roles[x.path].append(my_role.get(up, ""));
        } else {
            anc_roles[x.path] = [];
        }
        if k == u.id {
            my_role[x.path] = top(ROLES, [my_role.get(x.path, ""), e.role]);
        }
    }
    out: list[dict[str, any]] = [];
    for (x, e) in rows {
        up = x.path[:-STEP];
        anc_max = key_max.get(up, {}).get(holder(e).id, "") if up else "";
        roles = (top(ROLES, anc_roles.get(x.path, [])), my_role.get(x.path, ""));
        out.append(access_json(u, e, x, roles, anc_max, full));
    }
    return reply(200, out);
}

impl create_access(pk: str, body: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return detail(404, "Not found.");
    }
    u = caller();
    if u is None {
        return denied(True);
    }
    mine = role_of(u, d);
    if mine not in PRIVILEGED {
        return detail(403, "You are not allowed to manage accesses for this resource.");
    }
    data = loads(body);
    errors: dict[str, list[str]] = {};
    role = data.get("role");
    if role is None {
        errors["role"] = ["This field is required."];
    } elif role not in ROLES {
        errors["role"] = [f"\"{role}\" is not a valid choice."];
    }
    who: User | None = None;
    if data.get("user_id") is not None {
        who = user_by_id(str(data["user_id"]));
        if who is None {
            errors["user_id"] = [f"Invalid pk \"{data['user_id']}\" - object does not exist."];
        }
    }
    if errors {
        return reply(400, errors);
    }
    if who is None {
        return reply(400, {"__all__": ["Either user or team must be set, not both."]});
    }
    if access_of(d, who) is not None {
        return reply(400, {"__all__": ["This user is already in this document."]});
    }
    if role == "owner" and mine != "owner" {
        return detail(403, "Only owners of a document allowed assign other users as owners.");
    }
    t = now();
    e = Access(id=new_uuid(), role=role, created=t, updated=t);
    d +>:e:+> who;
    forget_nb(d);
    return reply(201, access_json(u, e, d, roles_tuple(u, d), "", True));
}

impl my_access(pk: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return detail(404, "Not found.");
    }
    u = caller();
    if u is None {
        return denied(True);
    }
    found: list[tuple[Doc, Access]] = [];
    for x in lineage(d) {
        if x.anc_deleted == 0.0 {
            for e in [edge x ->:Access:-> u] {
                found.append((x, e));
            }
        }
    }
    if not found {
        return denied(False);
    }
    (x, e) = sorted(found, key=lambda (p: tuple[Doc, Access]) -> float { p[1].created })[0];
    return reply(200, access_json(u, e, x, roles_tuple(u, x), "", False));
}

impl get_access(pk: str, id: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return detail(404, "Not found.");
    }
    u = caller();
    if u is None {
        return denied(True);
    }
    e = find_access(d, id);
    if e is None {
        return detail(404, "No DocumentAccess matches the given query.");
    }
    roles = roles_tuple(u, d);
    if not access_abilities(u, e, d, roles, "")["retrieve"] {
        return denied(False);
    }
    return reply(200, access_json(u, e, d, roles, "", role_of(u, d) in PRIVILEGED));
}

impl change_access(pk: str, id: str, body: str, action: str) -> Reply {
    d = doc_by_id(pk);
    if d is None {
        return detail(404, "Not found.");
    }
    u = caller();
    if u is None {
        return denied(True);
    }
    e = find_access(d, id);
    if e is None {
        return detail(404, "No DocumentAccess matches the given query.");
    }
    roles = roles_tuple(u, d);
    allowed = access_abilities(u, e, d, roles, "");
    data = loads(body);
    want = data.get("role");
    if (want and want not in allowed["set_role_to"]) or not allowed[action] {
        return denied(False);
    }
    if action == "destroy" {
        del e;
        forget_nb(d);
        return empty();
    }
    if "role" in data {
        if want not in ROLES {
            return reply(400, {"role": [f"\"{want}\" is not a valid choice."]});
        }
        e.role = want;
    }
    e.updated = now();
    forget_nb(d);
    return reply(200, access_json(u, e, d, roles_tuple(u, d), "", role_of(u, d) in PRIVILEGED));
}

impl patch_access(pk: str, id: str, body: str) -> Reply {
    return change_access(pk, id, body, "partial_update");
}

impl put_access(pk: str, id: str, body: str) -> Reply {
    return change_access(pk, id, body, "update");
}

impl delete_access(pk: str, id: str) -> Reply {
    return change_access(pk, id, "", "destroy");
}
