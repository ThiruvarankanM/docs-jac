import json;
import os;
import secrets;
import hashlib;
import base64;
import threading;
import importlib;
import http.client;
import urllib.parse;
import from auth.contract { Auth, AuthHost, SignIn, SignInAction, Session, Rejected, bearer_token }
import from common.contract { Secret }

obj OidcAuth(Auth) {
    has authorization_endpoint: str = "",
        token_endpoint: str = "",
        jwks_endpoint: str = "",
        user_endpoint: str = "",
        client_id: str = "",
        client_secret: Secret = Secret(variable="OIDC_RP_CLIENT_SECRET"),
        redirect_uri: str = "",
        scopes: str = "openid email",
        secret: str postinit,
        file: str postinit,
        pending: dict[str, str] postinit,
        sessions: dict[str, str] postinit,
        lock: any postinit;

    def postinit;

    def open(host: dyn AuthHost);

    def caller(headers: dict[str, str]) -> str | None;

    def asks(headers: dict[str, str]) -> SignIn;

    def answer(action: str, given: dict[str, str], client: str) -> Session;

    def leave(headers: dict[str, str]);

    def save;
}

def fetch(method: str, url: str, body: str, headers: dict[str, str]) -> tuple[int, str];

def unb64(s: str) -> bytes;

def token_string(n: int) -> str;

def rs256_ok(token: str, keys: list[dict[str, str]]) -> bool;
