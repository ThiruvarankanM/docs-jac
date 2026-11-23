impl Handler.do_GET {
    answer(self);
}

impl Handler.do_POST {
    answer(self);
}

impl Handler.do_PUT {
    answer(self);
}

impl Handler.do_PATCH {
    answer(self);
}

impl Handler.do_DELETE {
    answer(self);
}

impl Handler.log_message(format: str, *args: any) {
    return;
}

impl DocsTransport.open(host: dyn Host) {
    served["transport"] = self;
    served["pending"] = {};
    served["work"] = [];
}

impl DocsTransport.send(address: str, r: Request, seconds: float) -> Response {
    u = urllib.parse.urlsplit(address);
    conn = http.client.HTTPConnection(u.hostname, u.port, timeout=seconds);
    conn.request(r.method, r.path + ("?" + r.query if r.query else ""), body=r.body, headers=r.headers);
    resp = conn.getresponse();
    return Response(
        status=resp.status,
        ctype=resp.getheader("Content-Type", ""),
        body=resp.read(),
        headers={},
        events=None,
    );
}

impl DocsTransport.claim(address: str) -> Claim {
    hp = address.split("://")[-1].rsplit(":", 1);
    try {
        srv = http.server.ThreadingHTTPServer((hp[0], int(hp[1])), Handler);
    } except OSError as e {
        raise CannotListen(reason=str(e.strerror));
    } except (ValueError, IndexError) {
        raise CannotListen(reason="not host:port");
    }
    return HttpClaim(srv=srv);
}

impl DocsTransport.listen(
    claim: Claim,
    handle: Callable[[Request], Response],
    ticks: list[Tick],
    listening: Callable[[int], None] | None,
) {
    if not isinstance(claim, HttpClaim) {
        return;
    }
    srv = claim.srv;
    served["handle"] = handle;
    served["routes"] = [parse_route(r) for r in self.routes];
    threading.Thread(target=srv.serve_forever, args=(0.05,), daemon=True).start();
    if listening is not None {
        listening(srv.server_port);
    }
    due = {t.name: time.time() for t in ticks};
    while True {
        for t in ticks {
            if time.time() >= due[t.name] {
                t.run();
                due[t.name] = time.time() + t.every;
            }
        }
        while served["work"] {
            served["work"].pop(0)();
        }
        time.sleep(0.05);
    }
}

impl DocsTransport.on_loop(work: Callable[[], None]) {
    served["work"].append(work);
}

impl DocsTransport.serving -> bool {
    return "handle" in served;
}

impl DocsTransport.serves_paths -> bool {
    return True;
}

impl parse_route(spec: str) -> Route {
    (left, right) = spec.split("=", 1);
    (method, path) = left.strip().split(" ", 1);
    right = right.strip();
    target = right.split("(")[0].strip();
    args = [a.strip() for a in right.split("(")[1].rstrip(")").split(",") if a.strip()]
        if "(" in right
        else [];
    return Route(method=method, parts=path.strip().strip("/").split("/"), target=target, args=args);
}

impl route_args(r: Route, method: str, parts: list[str]) -> dict[str, str] | None {
    if r.method != method or len(r.parts) != len(parts) {
        return None;
    }
    got: dict[str, str] = {};
    for (want, have) in zip(r.parts, parts) {
        if want.startswith("{") {
            got[want[1:-1]] = urllib.parse.unquote(have);
        } elif want != have {
            return None;
        }
    }
    return got;
}

impl cookies_of(headers: dict[str, str]) -> dict[str, str] {
    jar = http.cookies.SimpleCookie();
    try {
        jar.load(headers.get("cookie", ""));
    } except http.cookies.CookieError {
        return {};
    }
    return {k: m.value for (k, m) in jar.items()};
}

impl cookie(name: str, value: str, age: int, http_only: bool) -> str {
    return name + "=" + value + ("; HttpOnly" if http_only else "") + "; Max-Age=" + str(age) + "; Path=/; SameSite=Lax";
}

impl call(req: Request) -> Response {
    return served["handle"](req);
}

impl known(headers: dict[str, str]) -> bool {
    resp = call(Request(method="GET", path="/__jac/auth/me", query="", headers=headers, body=b"", client=""));
    return resp.status == 200;
}

impl sign_in_start(h: any, t: DocsTransport, headers: dict[str, str]) {
    resp = call(Request(method="GET", path="/__jac/auth/", query="", headers=headers, body=b"", client=h.client_address[0]));
    env = json.loads(resp.body.decode());
    acts = env.get("data", {}).get("actions", []) if env.get("ok") else [];
    if not acts {
        write(h, json_reply(500, {"detail": "no sign-in action"}), []);
        return;
    }
    act = acts[0];
    key = secrets.token_hex(16);
    served["pending"][key] = (act["name"], act.get("keeps", {}));
    write(
        h,
        Response(status=302, ctype="", body=b"", headers={}, events=None),
        [("Location", act["redirect"]), ("Set-Cookie", cookie(t.session_cookie, key, t.session_age, True))],
    );
}

impl sign_in_back(h: any, t: DocsTransport, query: str, headers: dict[str, str]) {
    fail = [("Location", t.login_failure)];
    got = served["pending"].pop(cookies_of(headers).get(t.session_cookie, ""), None);
    if got is None {
        write(h, Response(status=302, ctype="", body=b"", headers={}, events=None), fail);
        return;
    }
    (action, keeps) = got;
    given: dict[str, str] = dict(keeps);
    for (k, v) in urllib.parse.parse_qsl(query, keep_blank_values=True) {
        given[k] = v;
    }
    resp = call(Request(
        method="POST",
        path="/__jac/auth/" + action,
        query="",
        headers={"content-type": "application/json"},
        body=json.dumps(given).encode(),
        client=h.client_address[0],
    ));
    env = json.loads(resp.body.decode()) if resp.body else {};
    if not env.get("ok") {
        write(h, Response(status=302, ctype="", body=b"", headers={}, events=None), fail);
        return;
    }
    s = env["data"];
    target = t.signed_in.split(".");
    made = call(Request(
        method="POST",
        path="/__jac/call/" + "/".join(target),
        query="",
        headers={"content-type": "application/json", "authorization": "Bearer " + s["token"]},
        body=json.dumps({"args": {"sub": s["user"], "email": s["name"]}}).encode(),
        client=h.client_address[0],
    ));
    if made.status != 200 {
        write(h, Response(status=302, ctype="", body=b"", headers={}, events=None), fail);
        return;
    }
    write(
        h,
        Response(status=302, ctype="", body=b"", headers={}, events=None),
        [
            ("Location", t.login_redirect),
            ("Set-Cookie", cookie(t.csrf_cookie, secrets.token_urlsafe(24), t.csrf_age, False)),
            ("Set-Cookie", cookie(t.session_cookie, s["token"], t.session_age, True)),
        ],
    );
}

impl answer(h: any) {
    t: DocsTransport = served["transport"];
    u = urllib.parse.urlsplit(h.path);
    n = int(h.headers.get("Content-Length", "0") or "0");
    raw = h.rfile.read(n) if n else b"";
    headers: dict[str, str] = {str(k).lower(): str(v) for (k, v) in h.headers.items()};
    jar = cookies_of(headers);
    session = jar.get(t.session_cookie, "");
    if session and "authorization" not in headers {
        headers["authorization"] = "Bearer " + session;
    }
    if h.command == "GET" and u.path == t.login_path {
        sign_in_start(h, t, headers);
        return;
    }
    if h.command == "GET" and u.path == t.callback_path {
        sign_in_back(h, t, u.query, headers);
        return;
    }
    if u.path.startswith("/__jac") {
        write(h, call(Request(method=h.command, path=u.path, query=u.query, headers=headers, body=raw, client=h.client_address[0])), []);
        return;
    }
    parts = u.path.strip("/").split("/");
    for r in served["routes"] {
        got = route_args(r, h.command, parts);
        if got is None {
            continue;
        }
        if h.command not in ("GET", "HEAD", "OPTIONS") and session and known(headers) {
            sent = headers.get("x-csrftoken", "");
            if not jar.get(t.csrf_cookie) {
                write(h, json_reply(403, {"detail": "CSRF Failed: CSRF cookie not set."}), []);
                return;
            }
            if sent != jar.get(t.csrf_cookie) {
                write(h, json_reply(403, {"detail": "CSRF Failed: CSRF token incorrect."}), []);
                return;
            }
        }
        vals: dict[str, str] = dict(got);
        vals["body"] = raw.decode("utf-8", "replace");
        vals["query"] = json.dumps({k: v for (k, v) in urllib.parse.parse_qsl(u.query, keep_blank_values=True)});
        vals["base"] = "http://" + headers.get("host", "");
        args = {a: vals.get(a, "") for a in r.args};
        fwd: dict[str, str] = dict(headers);
        fwd["content-type"] = "application/json";
        target = r.target.split(".");
        req = Request(
            method="POST",
            path="/__jac/call/" + "/".join(target),
            query="",
            headers=fwd,
            body=json.dumps({"args": args}).encode(),
            client=h.client_address[0],
        );
        write(h, unwrap(call(req)), []);
        return;
    }
    write(h, Response(status=404, ctype="text/html; charset=utf-8", body=b"<h1>Not Found</h1>", headers={}, events=None), []);
}

impl unwrap(resp: Response) -> Response {
    try {
        env = json.loads(resp.body.decode()) if resp.body else {};
    } except ValueError {
        return resp;
    }
    if env.get("ok") {
        data = env.get("data");
        if isinstance(data, dict) and set(data.keys()) == {"status", "body", "ctype"} {
            return Response(status=data["status"], ctype=data["ctype"], body=data["body"].encode(), headers={}, events=None);
        }
        return json_reply(200, data);
    }
    return Response(status=resp.status if resp.status >= 400 else 500, ctype="application/json", body=resp.body, headers={}, events=None);
}

impl json_reply(status: int, data: any) -> Response {
    return Response(status=status, ctype="application/json", body=json.dumps(data).encode(), headers={}, events=None);
}

impl write(h: any, resp: Response, extra: list[tuple[str, str]]) {
    h.send_response(resp.status);
    if resp.body {
        h.send_header("Content-Type", resp.ctype or "application/json");
    }
    for (k, v) in (resp.headers or {}).items() {
        h.send_header(k, v);
    }
    for (k, v) in extra {
        h.send_header(k, v);
    }
    h.send_header("Content-Length", str(len(resp.body)));
    h.end_headers();
    h.wfile.write(resp.body);
}
