impl prio(order: list[str], v: str) -> int {
    return order.index(v) + 1 if v in order else 0;
}

impl top(order: list[str], vals: list[str]) -> str {
    best = "";
    for v in vals {
        if best == "" or prio(order, v) > prio(order, best) {
            best = v;
        }
    }
    return best;
}

impl nz(s: str) -> str | None {
    return s or None;
}

impl caller -> User | None {
    try {
        r = root;
    } except RuntimeError {
        return None;
    }
    for m in [r --> [?:Me]] {
        return user_by_id(m.user);
    }
    return None;
}

impl users -> list[User] {
    return [root.shared --> [?:User]];
}

impl user_by_id(id: str) -> User | None {
    for u in users() {
        if u.id == id {
            return u;
        }
    }
    return None;
}

impl docs -> list[Doc] {
    return [root.shared --> [?:Doc]];
}

impl doc_by_id(id: str) -> Doc | None {
    for d in docs() {
        if d.id == id {
            return d;
        }
    }
    return None;
}

impl under(d: Doc) -> list[Doc] {
    return sorted([x for x in docs() if x.path.startswith(d.path)], key=lambda (x: Doc) -> str { x.path });
}

impl lineage(d: Doc) -> list[Doc] {
    return sorted([x for x in docs() if d.path.startswith(x.path)], key=lambda (x: Doc) -> str { x.path });
}

impl parent(d: Doc) -> Doc | None {
    if d.depth <= 1 {
        return None;
    }
    up = d.path[:-STEP];
    for x in docs() {
        if x.path == up {
            return x;
        }
    }
    return None;
}

impl kids(d: Doc) -> list[Doc] {
    return [x for x in under(d) if x.depth == d.depth + 1];
}

impl holder(e: Access) -> User {
    return [e -->][?:User][0];
}

impl accesses(d: Doc) -> list[Access] {
    return [edge d ->:Access:->];
}

impl access_of(d: Doc, u: User) -> Access | None {
    for e in [edge d ->:Access:-> u] {
        return e;
    }
    return None;
}

impl traced(d: Doc, u: User) -> bool {
    return len([edge d ->:Trace:-> u]) > 0;
}

impl faved(d: Doc, u: User) -> bool {
    return len([edge d ->:Favorite:-> u]) > 0;
}

impl roles_of(u: User | None, d: Doc) -> list[str] {
    if u is None {
        return [];
    }
    return [e.role for x in lineage(d) for e in [edge x ->:Access:-> u]];
}

impl role_of(u: User | None, d: Doc) -> str {
    return top(ROLES, roles_of(u, d));
}

impl equivalent(links: list[tuple[str, str]]) -> tuple[str, str] {
    if not links {
        return ("", "");
    }
    reach = top(REACHES, [l[0] for l in links]);
    if reach == "restricted" {
        return (reach, "");
    }
    return (reach, top(LINK_ROLES, [l[1] for l in links if l[0] == reach]));
}

impl ancestors_def(d: Doc) -> tuple[str, str] {
    p = parent(d);
    if p is None or p.anc_deleted > 0.0 {
        return equivalent([]);
    }
    return equivalent([(x.link_reach, x.link_role) for x in lineage(p)]);
}

impl select_options(reach: str, role: str) -> dict[str, any] {
    return {
        r: (None if r == "restricted" else [x for x in LINK_ROLES if prio(LINK_ROLES, x) >= prio(LINK_ROLES, role)])
        for r in REACHES
        if prio(REACHES, r) >= prio(REACHES, reach)
    };
}

impl abilities(u: User | None, d: Doc) -> dict[str, any] {
    role = role_of(u, d);
    signed = u is not None;
    is_owner = role == "owner";
    is_deleted = d.anc_deleted > 0.0;
    owner_admin = (is_owner or role == "administrator") and not is_deleted;
    has_role = role != "" and not is_deleted;
    update_by_access = (owner_admin or role == "editor") and not is_deleted;
    can_leave = signed and not is_deleted and (
        (has_role and not owner_admin) or (not has_role and u is not None and traced(d, u))
    );
    anc = ancestors_def(d);
    (reach, link_role) = equivalent([anc, (d.link_reach, d.link_role)]);
    if reach == "public" or (reach == "authenticated" and signed) {
        role = top(ROLES, [role, link_role]);
    }
    can_get = role != "" and not is_deleted;
    retrieve = can_get or is_owner;
    can_update = (owner_admin or role == "editor") and not is_deleted;
    can_comment = (can_update or role == "commenter") and not is_deleted;
    can_children = update_by_access and signed;
    mine = u is not None and d.creator == u.id;
    can_destroy = (is_owner if d.depth == 1 else (owner_admin or (can_children and mine and d.numchild == 0))) and not is_deleted;
    ai = signed and can_update;
    return {
        "accesses_manage": owner_admin,
        "accesses_view": has_role,
        "ai_proxy": ai,
        "ai_transform": ai,
        "ai_translate": ai,
        "attachment_upload": can_update,
        "media_check": can_get,
        "children_list": can_get,
        "children_create": can_children,
        "collaboration_auth": can_get,
        "comment": can_comment,
        "formatted_content": can_get,
        "cors_proxy": can_get,
        "descendants": can_get,
        "destroy": can_destroy,
        "duplicate": can_get and signed,
        "favorite": can_get and signed,
        "link_configuration": owner_admin,
        "invite_owner": is_owner and not is_deleted,
        "leave": can_leave,
        "mention": has_role and can_comment,
        "move": owner_admin and not is_deleted,
        "move_to_another_tree": is_owner and not is_deleted,
        "partial_update": can_update,
        "restore": is_owner and d.deleted > 0.0,
        "retrieve": retrieve,
        "media_auth": can_get,
        "link_select_options": select_options(anc[0], anc[1]),
        "tree": retrieve,
        "update": can_update,
        "versions_list": has_role,
        "search": can_get
    };
}

impl nb_accesses(d: Doc) -> tuple[int, int] {
    t = now();
    if d.nb_at > 0.0 and t - d.nb_at < NB_TTL {
        return (d.nb_direct, d.nb_anc);
    }
    d.nb_direct = len(accesses(d));
    d.nb_anc = sum(len(accesses(x)) for x in lineage(d) if x.anc_deleted == 0.0);
    d.nb_at = t;
    return (d.nb_direct, d.nb_anc);
}

impl forget_nb(d: Doc) {
    for x in under(d) {
        x.nb_at = 0.0;
    }
}

impl doc_json(u: User | None, d: Doc, fav: bool) -> dict[str, any] {
    anc = ancestors_def(d);
    comp = equivalent([anc, (d.link_reach, d.link_role)]);
    (direct, total) = nb_accesses(d);
    out: dict[str, any] = {
        "id": d.id,
        "abilities": abilities(u, d),
        "ancestors_link_reach": nz(anc[0]),
        "ancestors_link_role": nz(anc[1]),
        "computed_link_reach": nz(comp[0]),
        "computed_link_role": nz(comp[1]),
        "created_at": iso(d.created),
        "creator": d.creator,
        "deleted_at": iso(d.anc_deleted),
        "depth": d.depth,
        "excerpt": None
    };
    if fav {
        out["is_favorite"] = u is not None and faved(d, u);
    }
    out["link_role"] = d.link_role;
    out["link_reach"] = d.link_reach;
    out["nb_accesses_ancestors"] = total;
    out["nb_accesses_direct"] = direct;
    out["numchild"] = d.numchild;
    out["path"] = d.path;
    out["title"] = d.title if d.titled else None;
    out["updated_at"] = iso(d.updated);
    out["user_role"] = nz(role_of(u, d));
    return out;
}

impl user_json(u: User) -> dict[str, any] {
    local = slug(u.email.split("@")[0]);
    return {
        "id": u.id,
        "email": u.email,
        "full_name": u.full_name or local,
        "short_name": u.short_name or local,
        "language": nz(u.language),
        "is_first_connection": u.first
    };
}

impl light_user(u: User) -> dict[str, any] {
    local = slug(u.email.split("@")[0]);
    return {"id": u.id, "full_name": u.full_name or local, "short_name": u.short_name or local};
}

impl in_trash(d: Doc) -> bool {
    return d.anc_deleted > 0.0 and d.anc_deleted < now() - TRASH_DAYS * 86400.0;
}

impl no_doc -> Reply {
    return detail(404, "No Document matches the given query.");
}

impl gate(u: User | None, d: Doc, action: str) -> Reply | None {
    if in_trash(d) {
        return detail(404, "Not found.");
    }
    allowed = bool(abilities(u, d).get(action, False));
    if d.anc_deleted > 0.0 and "owner" not in roles_of(u, d) {
        return detail(404, "Not found.");
    }
    if not allowed {
        return denied(u is None);
    }
    return None;
}
