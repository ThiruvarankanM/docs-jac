import json;
import re;
import from stdjac { remove }

impl invites(d: Doc) -> list[Invite] {
    return sorted([d --> [?:Invite]], key=lambda (i: Invite) -> float { i.created }, reverse=True);
}

impl invite_abilities(role: str, i: Invite) -> dict[str, any] {
    is_priv = role in PRIVILEGED;
    allowed = role == "owner" if i.role == "owner" else is_priv;
    return {
        "destroy": allowed,
        "update": allowed,
        "partial_update": allowed,
        "retrieve": is_priv,
        "set_role_to": [r for r in ROLES if prio(ROLES, r) <= prio(ROLES, role)] if allowed else []
    };
}

impl invite_json(role: str, d: Doc, i: Invite) -> dict[str, any] {
    return {
        "id": i.id,
        "abilities": invite_abilities(role, i),
        "created_at": iso(i.created),
        "email": i.email,
        "document": d.id,
        "role": i.role,
        "issuer": i.issuer,
        "is_expired": now() > i.created + VALID_FOR
    };
}

impl check_role(role: any, mine: str) -> dict[str, list[str]] {
    if role not in ROLES {
        return {"role": [f"\"{role}\" is not a valid choice."]};
    }
    if role == "owner" and mine != "owner" {
        return {"role": ["Only owners of a document allowed invite other users as owners."]};
    }
    return {};
}

impl list_invitations(pk: str, query: str, base: str) -> Reply {
    u = caller();
    if u is None {
        return denied(True);
    }
    q: dict[str, str] = json.loads(query);
    d = doc_by_id(pk);
    role = role_of(u, d) if d is not None else "";
    items = invites(d) if d is not None and role in PRIVILEGED else [];
    got = page(items, q, base, "/api/v1.0/documents/" + pk + "/invitations/");
    if isinstance(got, Reply) {
        return got;
    }
    got["results"] = [invite_json(role, d, i) for i in got["results"]];
    return reply(200, got);
}

impl create_invitation(pk: str, body: str) -> Reply {
    u = caller();
    if u is None {
        return denied(True);
    }
    d = doc_by_id(pk);
    mine = role_of(u, d) if d is not None else "";
    if mine not in PRIVILEGED {
        return denied(False);
    }
    data = loads(body);
    errors: dict[str, list[str]] = {};
    email = data.get("email");
    if email is None {
        errors["email"] = ["This field is required."];
    } elif not re.match(EMAIL, str(email).strip()) {
        errors["email"] = ["Enter a valid email address."];
    }
    errors.update(check_role(data.get("role", "reader"), mine));
    if errors {
        return reply(400, errors);
    }
    email = str(email).strip().lower();
    if any(i.email == email for i in invites(d)) {
        return reply(400, {"__all__": ["Document invitation with this Email address and Document already exists."]});
    }
    if any(x.email == email for x in users()) {
        return reply(400, {"email": ["This email is already associated to a registered user."]});
    }
    i = Invite(id=new_uuid(), email=email, role=data.get("role", "reader"), issuer=u.id, created=now());
    d ++> i;
    return reply(201, invite_json(mine, d, i));
}

impl get_invitation(pk: str, id: str) -> Reply {
    return change_invitation(pk, id, "", "retrieve");
}

impl change_invitation(pk: str, id: str, body: str, action: str) -> Reply {
    u = caller();
    if u is None {
        return denied(True);
    }
    d = doc_by_id(pk);
    found: Invite | None = None;
    if d is not None {
        for i in invites(d) {
            if i.id == id {
                found = i;
            }
        }
    }
    if found is None {
        return detail(404, "No Invitation matches the given query.");
    }
    mine = role_of(u, d);
    if not invite_abilities(mine, found)[action] {
        return denied(False);
    }
    if action == "retrieve" {
        return reply(200, invite_json(mine, d, found));
    }
    if action == "destroy" {
        remove(found);
        return empty();
    }
    data = loads(body);
    if "email" in data and str(data["email"]).strip().lower() != found.email {
        return reply(400, {"email": ["The email of an invitation cannot be changed."]});
    }
    if "role" in data {
        bad = check_role(data["role"], mine);
        if bad {
            return reply(400, bad);
        }
        found.role = data["role"];
    }
    return reply(200, invite_json(mine, d, found));
}

impl patch_invitation(pk: str, id: str, body: str) -> Reply {
    return change_invitation(pk, id, body, "partial_update");
}

impl put_invitation(pk: str, id: str, body: str) -> Reply {
    return change_invitation(pk, id, body, "update");
}

impl delete_invitation(pk: str, id: str) -> Reply {
    return change_invitation(pk, id, "", "destroy");
}
