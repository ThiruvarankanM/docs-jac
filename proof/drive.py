"""Run the same API scenario against a Docs server and print every reply, normalised.

usage: drive.py <base-url> <oidc-url>
"""

import http.cookiejar
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE, OP = sys.argv[1].rstrip("/"), sys.argv[2].rstrip("/")
API = BASE + "/api/v1.0/"
names: dict[str, str] = {}
order: list[str] = []


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


class Client:
    def __init__(self, email=None):
        self.jar = http.cookiejar.CookieJar()
        self.open = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.jar), NoRedirect).open
        if email:
            self.login(email)

    def raw(self, method, url, body=None, headers=None):
        req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
        try:
            r = self.open(req)
        except urllib.error.HTTPError as e:
            r = e
        return r.status, dict(r.headers), r.read()

    def login(self, email):
        urllib.request.urlopen(urllib.request.Request(OP + "/as?email=" + urllib.parse.quote(email), method="POST"))
        url = API + "authenticate/"
        for _ in range(6):
            status, headers, _ = self.raw("GET", url)
            loc = headers.get("Location")
            if status not in (301, 302, 303) or not loc:
                break
            url = urllib.parse.urljoin(url, loc)
            if url.startswith(OP):
                status, headers, _ = self._op(url)
                url = headers["Location"]
        self.csrf = next((c.value for c in self.jar if c.name == "csrftoken"), "")

    def _op(self, url):
        try:
            r = urllib.request.build_opener(NoRedirect).open(url)
        except urllib.error.HTTPError as e:
            r = e
        return r.status, dict(r.headers), r.read()

    def call(self, method, path, body=None):
        headers = {"Accept": "application/json"}
        data = None
        if body is not None:
            data = fill(json.dumps(body)).encode()
            headers["Content-Type"] = "application/json"
        if method not in ("GET", "HEAD"):
            headers["X-CSRFToken"] = getattr(self, "csrf", "")
            headers["Referer"] = BASE + "/"
        return self.raw(method, API + fill(path), data, headers)


def fill(text):
    return re.sub(r"\{(\w+)\}", lambda m: names[m.group(1)], text)


UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
DATE = re.compile(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d:\d\d)")


def norm(text):
    def uid(m):
        v = m.group(0)
        if v not in order:
            order.append(v)
        label = next((k for k, x in names.items() if x == v), None)
        return "<" + (label or "id%d" % order.index(v)) + ">"

    text = UUID.sub(uid, text)
    return DATE.sub("<date>", text)


def show(step, status, headers, body):
    ctype = headers.get("Content-Type", "")
    text = body.decode(errors="replace")
    if "json" in ctype and text:
        text = json.dumps(json.loads(text), indent=1, ensure_ascii=False)
    elif text:
        text = "<%s %d bytes>" % (ctype.split(";")[0], len(body))
    print("### %s -> %d" % (step, status))
    if text:
        print(norm(text))


def run(who, method, path, body=None, keep=None, label=None):
    status, headers, data = clients[who].call(method, path, body)
    if keep and status < 300:
        got = json.loads(data)
        for name, key in keep.items():
            names[name] = got[key]
    show(label or "%s %s %s%s" % (who, method, path, "" if body is None else " " + json.dumps(body)), status, headers, data)
    return status


if __name__ == "__main__":
    clients = {"anon": Client()}
    for who in ["amy", "bob", "cat"]:
        clients[who] = Client(who + "@example.com")

    run("anon", "GET", "config/")
    run("anon", "GET", "users/me/")
    run("amy", "GET", "users/me/", keep={"amy": "id"})
    run("bob", "GET", "users/me/", keep={"bob": "id"})
    run("cat", "GET", "users/me/", keep={"cat": "id"})
    run("amy", "POST", "users/onboarding-done/")
    run("amy", "GET", "users/me/")

    run("amy", "POST", "documents/", {"title": "Plan"}, keep={"plan": "id"})
    run("amy", "POST", "documents/", {"title": "Notes"}, keep={"notes": "id"})
    run("amy", "POST", "documents/", {}, keep={"blank": "id"})
    run("amy", "POST", "documents/", {"title": 5})
    run("amy", "POST", "documents/", {"title": "x" * 256})
    run("amy", "POST", "documents/", {"id": "not-a-uuid"})
    run("anon", "POST", "documents/", {"title": "nope"})
    run("amy", "GET", "documents/")
    run("amy", "GET", "documents/{plan}/")
    run("bob", "GET", "documents/{plan}/")
    run("anon", "GET", "documents/{plan}/")
    run("amy", "GET", "documents/00000000-0000-4000-8000-000000000000/")
    run("amy", "GET", "documents/{plan}/abilities/")
    run("amy", "PATCH", "documents/{plan}/", {"title": "Plan v2"})
    run("amy", "PUT", "documents/{notes}/", {"title": "Notes v2"})
    run("bob", "PATCH", "documents/{plan}/", {"title": "hack"})

    run("amy", "POST", "documents/{plan}/children/", {"title": "Step 1"}, keep={"step1": "id"})
    run("amy", "POST", "documents/{plan}/children/", {"title": "Step 2"}, keep={"step2": "id"})
    run("amy", "POST", "documents/{step1}/children/", {"title": "Detail"}, keep={"detail": "id"})
    run("amy", "GET", "documents/{plan}/children/")
    run("amy", "GET", "documents/{plan}/children/?title=step%202")
    run("amy", "GET", "documents/{detail}/tree/")
    run("bob", "GET", "documents/{detail}/tree/")
    run("amy", "GET", "documents/{step1}/")

    run("amy", "PUT", "documents/{plan}/link-configuration/", {"link_reach": "public", "link_role": "commenter"})
    run("amy", "PUT", "documents/{step1}/link-configuration/", {"link_reach": "authenticated", "link_role": "reader"})
    run("amy", "PUT", "documents/{step1}/link-configuration/", {"link_reach": "public", "link_role": "editor"})
    run("amy", "PUT", "documents/{notes}/link-configuration/", {"link_reach": "restricted", "link_role": "reader"})
    run("amy", "PUT", "documents/{notes}/link-configuration/", {"link_reach": "restricted", "link_role": None})
    run("amy", "PUT", "documents/{notes}/link-configuration/", {"link_role": "editor"})
    run("amy", "PUT", "documents/{notes}/link-configuration/", {"link_reach": "galaxy"})
    run("anon", "GET", "documents/{step1}/")
    run("bob", "GET", "documents/{step1}/")
    run("bob", "GET", "documents/")
    run("bob", "GET", "documents/{detail}/tree/")

    run("amy", "POST", "documents/{notes}/accesses/", {"user_id": "{bob}", "role": "editor"}, keep={"bob_notes": "id"})
    run("amy", "POST", "documents/{notes}/accesses/", {"user_id": "{bob}", "role": "reader"})
    run("amy", "POST", "documents/{plan}/accesses/", {"user_id": "{cat}", "role": "reader"}, keep={"cat_plan": "id"})
    run("bob", "POST", "documents/{notes}/accesses/", {"user_id": "{cat}", "role": "reader"})
    run("amy", "GET", "documents/{notes}/accesses/")
    run("bob", "GET", "documents/{notes}/accesses/")
    run("cat", "GET", "documents/{step1}/accesses/")
    run("bob", "GET", "documents/{notes}/accesses/me/")
    run("cat", "GET", "documents/{notes}/accesses/me/")
    run("amy", "PATCH", "documents/{notes}/accesses/{bob_notes}/", {"role": "administrator"})
    run("bob", "GET", "documents/{notes}/accesses/")
    run("bob", "PATCH", "documents/{notes}/accesses/{bob_notes}/", {"role": "owner"})
    run("amy", "GET", "documents/{notes}/accesses/{bob_notes}/")
    run("bob", "GET", "documents/{notes}/")
    run("bob", "GET", "documents/")

    run("amy", "POST", "documents/{notes}/invitations/", {"email": "dan@example.com", "role": "editor"}, keep={"inv": "id"})
    run("amy", "POST", "documents/{notes}/invitations/", {"email": "dan@example.com", "role": "reader"})
    run("amy", "POST", "documents/{notes}/invitations/", {"email": "bob@example.com", "role": "reader"})
    run("amy", "POST", "documents/{notes}/invitations/", {"email": "nope", "role": "reader"})
    run("cat", "POST", "documents/{plan}/invitations/", {"email": "eve@example.com", "role": "reader"})
    run("amy", "GET", "documents/{notes}/invitations/")
    run("cat", "GET", "documents/{notes}/invitations/")
    run("amy", "PATCH", "documents/{notes}/invitations/{inv}/", {"role": "administrator"})
    run("amy", "GET", "documents/{notes}/invitations/{inv}/")
    run("amy", "DELETE", "documents/{notes}/invitations/{inv}/")
    run("amy", "GET", "documents/{notes}/invitations/")

    run("amy", "POST", "documents/{plan}/favorite/")
    run("amy", "POST", "documents/{plan}/favorite/")
    run("amy", "POST", "documents/{step2}/favorite/")
    run("amy", "GET", "documents/favorites/")
    run("amy", "GET", "documents/?is_favorite=true")
    run("amy", "GET", "documents/?is_favorite=false&ordering=title")
    run("amy", "DELETE", "documents/{step2}/favorite/")
    run("amy", "DELETE", "documents/{step2}/favorite/")
    run("bob", "GET", "documents/?is_creator_me=false")
    run("bob", "GET", "documents/?is_creator_me=true")
    run("amy", "GET", "documents/?title=plan")
    run("amy", "GET", "documents/?ordering=-title&page_size=2")
    run("amy", "GET", "documents/?page=2&page_size=2")
    run("amy", "GET", "documents/?page=9")
    run("amy", "GET", "documents/all/")

    run("amy", "POST", "documents/{step2}/move/", {"target_document_id": "{step1}", "position": "first-child"})
    run("amy", "GET", "documents/{plan}/tree/")
    run("amy", "POST", "documents/{step2}/move/", {"target_document_id": "{detail}", "position": "left"})
    run("amy", "POST", "documents/{plan}/move/", {"target_document_id": "{detail}", "position": "last-child"})
    run("amy", "POST", "documents/{step2}/move/", {"target_document_id": "{plan}", "position": "nowhere"})
    run("amy", "POST", "documents/{step2}/move/", {"target_document_id": "00000000-0000-4000-8000-000000000000"})
    run("bob", "POST", "documents/{notes}/move/", {"target_document_id": "{plan}", "position": "first-child"})
    run("amy", "GET", "documents/{detail}/tree/")


    run("amy", "DELETE", "documents/{step1}/")
    run("amy", "GET", "documents/{step1}/")
    run("amy", "GET", "documents/{detail}/")
    run("cat", "GET", "documents/{step1}/")
    run("amy", "GET", "documents/{plan}/children/")
    run("amy", "GET", "documents/{plan}/")
    run("amy", "GET", "documents/trashbin/")
    run("bob", "DELETE", "documents/{plan}/")
    run("amy", "POST", "documents/{step1}/restore/")
    run("amy", "POST", "documents/{step1}/restore/")
    run("amy", "GET", "documents/{plan}/tree/")
    run("amy", "DELETE", "documents/{blank}/")
    run("amy", "GET", "documents/trashbin/")

    run("cat", "POST", "documents/{plan}/leave/")
    run("cat", "GET", "documents/")
    run("bob", "GET", "documents/{step1}/")
    run("bob", "POST", "documents/{step1}/leave/")
    run("amy", "POST", "documents/{plan}/leave/")

    run("amy", "GET", "users/?q=bob@example.com")
    run("amy", "GET", "users/?q=bo")
    run("amy", "GET", "users/?q=b")
    run("amy", "GET", "users/?q=cat&document_id={plan}")
    run("amy", "PATCH", "users/{amy}/", {"language": "fr-fr"})
    run("amy", "PATCH", "users/{bob}/", {"language": "fr-fr"})
    run("amy", "PATCH", "users/{amy}/", {"language": "klingon"})
    run("amy", "GET", "users/me/")
