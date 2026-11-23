import json;
import secrets;
import threading;
import time;
import http.server;
import http.client;
import http.cookies;
import urllib.parse;
import from transport.contract { Transport, Request, Response, Claim, Tick, CannotListen }
import from common.contract { Host }

obj Route {
    has method: str,
        parts: list[str],
        target: str,
        args: list[str];
}

obj HttpClaim(Claim) {
    has srv: any = None;
}

glob served: dict[str, any] = {};

class Handler(http.server.BaseHTTPRequestHandler) {
    def do_GET;

    def do_POST;

    def do_PUT;

    def do_PATCH;

    def do_DELETE;

    def log_message(format: str, *args: any);
}

obj DocsTransport(Transport) {
    has routes: list[str] = [],
        login_path: str = "/api/v1.0/authenticate/",
        callback_path: str = "/api/v1.0/callback/",
        login_redirect: str = "/",
        login_failure: str = "/",
        signed_in: str = "api.users.signed_in",
        session_cookie: str = "sessionid",
        session_age: int = 43200,
        csrf_cookie: str = "csrftoken",
        csrf_age: int = 31449600;

    def open(host: dyn Host);

    def send(address: str, r: Request, seconds: float) -> Response;

    def claim(address: str) -> Claim;

    def listen(
        claim: Claim,
        handle: Callable[[Request], Response],
        ticks: list[Tick],
        listening: Callable[[int], None] | None,
    );

    def on_loop(work: Callable[[], None]);

    def serving -> bool;

    def serves_paths -> bool;
}

def parse_route(spec: str) -> Route;

def route_args(r: Route, method: str, parts: list[str]) -> dict[str, str] | None;

def cookies_of(headers: dict[str, str]) -> dict[str, str];

def cookie(name: str, value: str, age: int, http_only: bool) -> str;

def call(req: Request) -> Response;

def known(headers: dict[str, str]) -> bool;

def sign_in_start(h: any, t: DocsTransport, headers: dict[str, str]);

def sign_in_back(h: any, t: DocsTransport, query: str, headers: dict[str, str]);

def answer(h: any);

def unwrap(resp: Response) -> Response;

def json_reply(status: int, data: any) -> Response;

def write(h: any, resp: Response, extra: list[tuple[str, str]]);
