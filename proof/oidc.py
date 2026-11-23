"""A minimal OpenID Connect provider, so both Docs servers log in through the same flow.

POST /as?email=<email>           -> the next /auth logs in as that email
GET  /auth?redirect_uri=..&state=..&nonce=..  -> 302 to redirect_uri?code=..&state=..
POST /token     (code)            -> {"access_token", "id_token", "token_type"}
GET  /userinfo  (Bearer token)    -> {"sub", "email", "given_name", "usual_name"}
GET  /jwks                        -> the RS256 public key
"""

import base64
import hashlib
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
KEY = os.path.join(HERE, "op-key.pem")
ISSUER = "http://127.0.0.1:8600"
CLIENT_ID = "docs"
codes = {}
next_user = {"email": "anon@example.com"}
tokens = {}


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def modulus() -> int:
    if not os.path.exists(KEY):
        subprocess.check_call(["openssl", "genrsa", "-out", KEY, "2048"], stderr=subprocess.DEVNULL)
    out = subprocess.check_output(["openssl", "rsa", "-in", KEY, "-noout", "-modulus"], text=True)
    return int(out.strip().split("=", 1)[1], 16)


N = modulus()


def sign(claims: dict) -> str:
    head = b64(json.dumps({"alg": "RS256", "typ": "JWT", "kid": "op"}).encode())
    body = b64(json.dumps(claims).encode())
    sig = subprocess.check_output(
        ["openssl", "dgst", "-sha256", "-sign", KEY], input=f"{head}.{body}".encode()
    )
    return f"{head}.{body}.{b64(sig)}"


def user_for(email: str) -> dict:
    local = email.split("@")[0]
    return {
        "sub": hashlib.sha256(email.encode()).hexdigest()[:24],
        "email": email,
        "given_name": local.capitalize(),
        "usual_name": "Tester",
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        return

    def reply(self, status, body=None, headers=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        if body is not None:
            self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        u = urllib.parse.urlsplit(self.path)
        q = {k: v[0] for k, v in urllib.parse.parse_qs(u.query).items()}
        if u.path == "/auth":
            code = secrets.token_urlsafe(16)
            codes[code] = {"email": next_user["email"], "nonce": q.get("nonce")}
            loc = q["redirect_uri"] + ("&" if "?" in q["redirect_uri"] else "?")
            loc += urllib.parse.urlencode({"code": code, "state": q.get("state", "")})
            return self.reply(302, headers={"Location": loc})
        if u.path == "/userinfo":
            tok = self.headers.get("Authorization", "")[7:]
            if tok not in tokens:
                return self.reply(401, {"error": "invalid_token"})
            return self.reply(200, user_for(tokens[tok]))
        if u.path == "/jwks":
            n = N.to_bytes((N.bit_length() + 7) // 8, "big")
            return self.reply(200, {"keys": [{"kty": "RSA", "alg": "RS256", "use": "sig", "kid": "op", "n": b64(n), "e": "AQAB"}]})
        return self.reply(404, {"error": "not_found"})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0") or 0)
        form = {k: v[0] for k, v in urllib.parse.parse_qs(self.rfile.read(n).decode()).items()}
        u = urllib.parse.urlsplit(self.path)
        if u.path == "/as":
            next_user["email"] = urllib.parse.parse_qs(u.query)["email"][0]
            return self.reply(204)
        if u.path != "/token":
            return self.reply(404, {"error": "not_found"})
        got = codes.pop(form.get("code", ""), None)
        if got is None:
            return self.reply(400, {"error": "invalid_grant"})
        now = int(time.time())
        claims = {"iss": ISSUER, "aud": CLIENT_ID, "sub": user_for(got["email"])["sub"], "iat": now, "exp": now + 3600}
        if got["nonce"]:
            claims["nonce"] = got["nonce"]
        access = secrets.token_urlsafe(24)
        tokens[access] = got["email"]
        return self.reply(200, {"access_token": access, "id_token": sign(claims), "token_type": "Bearer", "expires_in": 3600})


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8600
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
