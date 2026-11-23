graph layers {
    layer all { *; }
}

graph import {
    wire ++> model { Reply, detail, denied, iso, now, slug }
    wire ++> users { Reply, reply, detail, denied, new_uuid, now, loads, fold }
    model ++> users { User, Me, users, user_by_id, caller, docs, accesses, access_of, holder, user_json, doc_by_id }
    wire ++> documents { Reply, reply, empty, detail, denied, now, new_uuid, is_uuid, loads, fold, page }
    model ++> documents { User, Doc, Invite, Access, Trace, Favorite, STEP, TRASH_DAYS, LINK_ROLES, REACHES, PRIVILEGED, docs, doc_by_id, caller, lineage, under, parent, kids, holder, accesses, access_of, traced, faved, role_of, ancestors_def, select_options, abilities, forget_nb, doc_json, gate, no_doc }
    wire ++> accesses { Reply, reply, empty, detail, denied, now, new_uuid, iso, loads }
    model ++> accesses { User, Doc, Access, ROLES, PRIVILEGED, COMMENTING, STEP, lineage, accesses, access_of, holder, top, prio, nz, role_of, doc_by_id, user_by_id, caller, user_json, light_user, forget_nb }
    wire ++> invitations { Reply, reply, empty, detail, denied, now, new_uuid, iso, loads, page }
    model ++> invitations { Doc, Invite, ROLES, PRIVILEGED, prio, role_of, doc_by_id, caller, users }
    wire ++> config { Reply, reply }
}

graph spaces {
    space api: native { wire; model; users; documents; accesses; invitations; config; }

    app docs { run api; }
}
