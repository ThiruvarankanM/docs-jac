impl OidcAuth.postinit {
    self.secret = "";
    self.file = "";
    self.pending = {};
    self.sessions = {};
    self.lock = threading.Lock();
}

impl OidcAuth.open(host: dyn AuthHost) {
    self.secret = host.secret(self.client_secret);
    self.file = os.path.join(host.data_dir(), "oidc_sessions.json");
    if os.path.exists(self.file) {
        with open(self.file) as f {
            self.sessions = json.load(f);
        }
    }
}

impl OidcAuth.save {
    with open(self.file, "w") as f {
        json.dump(self.sessions, f);
    }
}

impl OidcAuth.caller(headers: dict[str, str]) -> str | None {
    token = bearer_token(headers);
    if not token {
        return None;
    }
    with self.lock {
        return self.sessions.get(token);
    }
}

impl OidcAuth.asks(headers: dict[str, str]) -> SignIn {
    state = token_string(32);
    nonce = token_string(32);
    with self.lock {
        self.pending[state] = nonce;
    }
    query = urllib.parse.urlencode({
        "response_type": "code",
        "scope": self.scopes,
        "client_id": self.client_id,
        "redirect_uri": self.redirect_uri,
        "state": state,
        "nonce": nonce
    });
    act = SignInAction(
        name="oidc",
        label="Sign in",
        needs=["code", "state"],
        redirect=self.authorization_endpoint + "?" + query,
        keeps={"sent_state": state}
    );
    return SignIn(fields=[], actions=[act], redirect="", session=None);
}

impl OidcAuth.answer(action: str, given: dict[str, str], client: str) -> Session {
    with self.lock {
        nonce = self.pending.pop(given.get("state", ""), None);
    }
    if action != "oidc" or nonce is None or given.get("sent_state") != given.get("state") {
        raise Rejected(detail="unknown sign-in state", retry_after=0);
    }
    form = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": given.get("code", ""),
        "redirect_uri": self.redirect_uri,
        "client_id": self.client_id,
        "client_secret": self.secret
    });
    (status, text) = fetch("POST", self.token_endpoint, form, {"Content-Type": "application/x-www-form-urlencoded"});
    if status != 200 {
        raise Rejected(detail="token exchange failed", retry_after=0);
    }
    got = json.loads(text);
    id_token: str = got.get("id_token", "");
    access: str = got.get("access_token", "");
    (status, text) = fetch("GET", self.jwks_endpoint, "", {});
    keys = json.loads(text).get("keys", []) if status == 200 else [];
    if not rs256_ok(id_token, keys) {
        raise Rejected(detail="id_token signature", retry_after=0);
    }
    claims = json.loads(unb64(id_token.split(".")[1]));
    if claims.get("nonce") != nonce or claims.get("aud") != self.client_id {
        raise Rejected(detail="id_token claims", retry_after=0);
    }
    (status, text) = fetch("GET", self.user_endpoint, "", {"Authorization": "Bearer " + access});
    if status != 200 {
        raise Rejected(detail="userinfo failed", retry_after=0);
    }
    info = json.loads(text);
    sub: str = str(info.get("sub", ""));
    email: str = str(info.get("email", ""));
    if not sub or sub != claims.get("sub") {
        raise Rejected(detail="userinfo subject", retry_after=0);
    }
    token = token_string(48);
    with self.lock {
        self.sessions[token] = sub;
        self.save();
    }
    return Session(user=sub, token=token, name=email);
}

impl OidcAuth.leave(headers: dict[str, str]) {
    token = bearer_token(headers);
    with self.lock {
        if token and token in self.sessions {
            del self.sessions[token];
            self.save();
        }
    }
}

impl fetch(method: str, url: str, body: str, headers: dict[str, str]) -> tuple[int, str] {
    u = urllib.parse.urlsplit(url);
    conn = http.client.HTTPSConnection(u.netloc, timeout=10) if u.scheme == "https" else http.client.HTTPConnection(u.netloc, timeout=10);
    path = u.path + ("?" + u.query if u.query else "");
    try {
        conn.request(method, path, body=body.encode() if body else None, headers=headers);
        r = conn.getresponse();
        return (r.status, r.read().decode());
    } except Exception {
        return (0, "");
    } finally {
        conn.close();
    }
}

impl unb64(s: str) -> bytes {
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4));
}

impl token_string(n: int) -> str {
    abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    return "".join([secrets.choice(abc) for _ in range(n)]);
}

impl rs256_ok(token: str, keys: list[dict[str, str]]) -> bool {
    parts = token.split(".");
    if len(parts) != 3 {
        return False;
    }
    py = importlib.import_module("builtins");
    head = json.loads(unb64(parts[0]));
    sig = unb64(parts[2]);
    digest = hashlib.sha256((parts[0] + "." + parts[1]).encode()).digest();
    info = bytes.fromhex("3031300d060960864801650304020105000420") + digest;
    for key in keys {
        if key.get("kty") != "RSA" or ("kid" in head and key.get("kid") != head["kid"]) {
            continue;
        }
        n = py.int.from_bytes(unb64(key["n"]), "big");
        e = py.int.from_bytes(unb64(key["e"]), "big");
        size = (n.bit_length() + 7) // 8;
        if len(sig) != size or size < len(info) + 11 {
            continue;
        }
        m: bytes = py.pow(py.int.from_bytes(sig, "big"), e, n).to_bytes(size, "big");
        want = b"\x00\x01" + b"\xff" * (size - len(info) - 3) + b"\x00" + info;
        if m == want {
            return True;
        }
    }
    return False;
}
