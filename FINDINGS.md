# neojac findings: porting La Suite Docs to Jac

**Original:** [suitenumerique/docs](https://github.com/suitenumerique/docs), the backend of a collaborative document editor in Python (Django + DRF + django-treebeard, Postgres, Redis, OIDC sign-in; `core` app: 58 files, 14.6k lines without tests and migrations).
**Port:** this repo, on neojac 0.4.0: 2,173 lines of app code and 629 lines in 2 plugins.
**Scope:** OIDC sign-in, users, the document tree (create, children, move, trash, restore), favorites, link reach, accesses and invitations, `config`. See the [README](README.md) for what isn't ported.
**Status:** done.

## The short version

- **Same replies:** all **117/117** requests from 3 signed-in users get identical replies from the original and the port: statuses, JSON bodies, key order and error messages.
- **Survives a restart:** 43 read-backs of everything the scenario left are identical before and after a restart.
- **Faster and smaller:** the scenario runs in about 0.15 s on the port and about 1.1 s on the original, with about 35 MB of server memory against about 238 MB.
- **20 findings:** 2 critical, 2 blocker, 8 major and 8 minor.
- **Two data-store bugs from marked-jac are still in 0.4.0** ([#14](#14-a-str--none-field-holding-none-still-makes-the-kept-graph-unreadable-marked-17), [#15](#15-one-subclass-value-in-a-kept-field-still-breaks-every-users-calls-marked-16)): a `None` in a kept field breaks the graph after a restart. The port stores `""` instead of `None` to avoid it.
- **The built-in server still can't describe a real HTTP API:** it has no PATCH/PUT/DELETE, no path parameters, no status codes and no cookies. So the port has its own transport plugin.
- **Hand-written:** `neojac port` refused 41 of the 58 app files, and what it did translate is typed `any`, which an endpoint can't use.

## Ground rules

We met neojac cold, the way a new user would:

- Only the latest neojac release (0.4.0) was used.
- Everything about Jac was learned from what neojac ships: `neojac docs`, `neojac skills`, `neojac help` and its error messages.
- neojac's own source was never read, including the plugin examples it ships ([#10](#10-plugin-examples-ship-but-as-neojac-source)). Each bug is reported by its symptom and a small repro, and any guess at a cause is labelled as a guess.
- The original app's source could be read freely.
- Every gap was logged when it was hit. Nothing was quietly worked around.

## What we did

| Step | Result |
|---|---|
| 1. Import the Python dependencies (`neojac absorb`) | Refused: `pyproject.toml` isn't a manifest it takes. |
| 2. Machine-translate (`neojac port`) | 41 of 58 files refused with 2,514 diagnostics. The rest came out as `any` everywhere. |
| 3. Write it by hand, in idiomatic Jac | Done. Users, documents and invitations are nodes on `root.shared`. Accesses, favorites and link traces are edges from a document to a user. The modules are wired in `archwire.jac`. |
| 4. Plugins for what the server can't do | `docs_transport` maps Docs' 38 routes, methods, bodies, query strings, statuses, cookies and CSRF. `oidc_auth` runs the OpenID Connect sign-in and checks the RS256 `id_token`. |
| 5. Prove it behaves the same | The 117-request scenario is identical, the restart read-back is identical, and the timings are below. |

## How "the same" is checked

`proof/drive.py` signs in 3 users (amy, bob, cat) through the same fake OpenID provider (`proof/oidc.py`) and sends the same 117 requests to a fresh server. It covers the document tree, moves in every position, trash and restore, every role and link reach, accesses, invitations, pagination, filters, ordering and the error cases. Ids, dates and tokens are masked. Any other difference counts as a failure, including a status code, a field, the order of keys or an error message.

| Check | Baseline from the original | Result |
|---|---|---|
| The full scenario: 64×200, 12×201, 6×204, 18×400, 3×401, 11×403, 3×404 | `proof/expected.out` | 117 / 117 identical |
| Restart: read everything back (`proof/restart.py`), restart the server, read again | the first read | 43 / 43 identical |

### Speed and memory

Same machine, same scenario, each run 3 times on a fresh database.

| | Original (Django `runserver`) | Port (`neojac run`, built binary) |
|---|---|---|
| 117-request scenario | 1.05–1.14 s | 0.15–0.18 s |
| 43-request read-back | 0.39–0.42 s | 0.10–0.11 s |
| Server memory (RSS) after the scenario | about 238 MB | about 35 MB |
| Start of the server, with data | | 0.14 s |

The original's memory is the Django process alone: Postgres and Redis come on top. Django's development server isn't its production setup, so read the timings as a rough guide.

## Findings at a glance

| Severity | Count | Meaning |
|---|---|---|
| Critical | 2 | Loses or locks up data that was accepted |
| Blocker | 2 | Stops the port as neojac stands |
| Major | 8 | Needs a real workaround, such as a custom plugin |
| Minor | 8 | Friction, wrong docs, or an unclear error |

Click a number to jump to its full repro.

### The data store

| # | Severity | What happens |
|---|---|---|
| [#14](#14-a-str--none-field-holding-none-still-makes-the-kept-graph-unreadable-marked-17) | Critical | A `str \| None` field holding `None` is accepted, and after a restart every call that reads the graph fails. Still there from marked-jac. |
| [#15](#15-one-subclass-value-in-a-kept-field-still-breaks-every-users-calls-marked-16) | Critical | One subclass value in a kept field makes every user's calls fail until a restart, and then the node is gone. Still there from marked-jac. |

### The built-in server

| # | Severity | What happens |
|---|---|---|
| [#6](#6-restspec-still-has-getpost-only-vaultwarden-4) | Blocker | `@restspec` still has GET and POST only, with no path parameters, body or status. Docs' API is PATCH, PUT and DELETE on `/documents/<id>/...`. |
| [#7](#7-an-endpoint-cant-see-who-signed-in-vaultwarden-7) | Major | An endpoint can't tell who signed in. The OIDC claims reach the auth plugin but not the endpoint. |
| [#8](#8-any-is-still-not-sendable-vaultwarden-8) | Major | `any` can't be an endpoint's parameter or return, so a partial JSON body has to cross as text. |
| [#9](#9-no-reply-status-headers-or-cookies-vaultwarden-10) | Major | Replies have no status, headers or cookies. A 201, a 400 with field errors, a 302 with `Set-Cookie` and a CSRF check all need a plugin. |

### Porting tools

| # | Severity | What happens |
|---|---|---|
| [#2](#2-neojac-port-refuses-most-of-a-django-app) | Blocker | `port` refuses 41 of Docs' 58 app files: every Django model, serializer and viewset. |
| [#1](#1-neojac-absorb-refuses-a-python-project) | Major | `absorb` refuses a Python project: `pyproject.toml` isn't a manifest it takes. |
| [#3](#3-ported-python-is-all-any-and-an-endpoint-refuses-any) | Major | What `port` translates is `any` everywhere, which an endpoint refuses. |

### Language and runtime

| # | Severity | What happens |
|---|---|---|
| [#11](#11-no-arithmetic-past-64-bits-and-no-rsa-for-an-rs256-sign-in) | Major | `int` is 64 bits and there is no RSA, so an RS256 sign-in can't be checked in Jac alone. |
| [#18](#18-keyword-arguments-to-a-method-on-an-any-value-pass-check-then-fail-at-runtime) | Major | Keyword arguments to a method on an `any` value pass `check` and then fail at runtime. It crashed every request. |
| [#17](#17-an-edge-whose-type-is-a-union-cant-be-followed-to-its-ends) | Minor | An edge whose type is a union (`A \| B`) can't be followed to its ends, and the error says edges aren't nodes. |
| [#19](#19-tracebackformat_exc-is-empty-inside-except) | Minor | `traceback.format_exc()` is empty inside `except`, so Python libraries log errors with no traceback. |

### Toolchain and error messages

| # | Severity | What happens |
|---|---|---|
| [#4](#4-040-breaks-033-projects-with-no-migration-page) | Major | 0.4.0 breaks every 0.3.3 project that uses plugins or `stdjac.<module>` imports, with no changelog or migration page. |
| [#5](#5-no-self-update) | Minor | There is no self-update: a new release means re-running the installer by hand. |
| [#20](#20-a-helper-script-in-the-project-tree-is-built-into-the-app) | Minor | A helper script in the project tree is built into the app. One that imports a sibling stops the build, and the error never mentions `[project] exclude`. |

### Documentation

| # | Severity | What happens |
|---|---|---|
| [#10](#10-plugin-examples-ship-but-as-neojac-source) | Minor | The plugin examples ship only as neojac's own source. The docs pages give no complete transport or auth plugin. |
| [#12](#12-neojac-check-refuses-a-plugins-own-directory) | Minor | `apps/plugins` says `neojac check` works in a plugin's directory. It doesn't. |
| [#13](#13-the-docs-own-example-plugin-fails-the-lints) | Minor | The docs' own example plugin fails `neojac check`'s lints. |
| [#16](#16-neojac-fmt---fix-with-no-path-as-the-messages-say-refuses) | Minor | The messages say to run `neojac fmt --fix`, which refuses to run without a path. |

Other ports from the same run: [marked-jac](https://github.com/ThiruvarankanM/marked-jac) and [vaultwarden-jac](https://github.com/ThiruvarankanM/vaultwarden-jac).

---

## Setup details

Compiler: neojac 0.4.0 (macos-aarch64, bdb6b2746f64)
Target: La Suite Docs' backend, a collaborative document editor's API (Python, Django + DRF + django-treebeard, Postgres, OIDC sign-in)
Proof: `proof/drive.py` sends the same 117 HTTP requests (signing in through the same fake OpenID provider, `proof/oidc.py`) to the original and the Jac version; `proof/expected.out` is the original's normalised replies.

| # | Area | Severity | Gap |
|---|---|---|---|
| 1 | absorb | major | `neojac absorb` refuses a Python project: `pyproject.toml` is not a manifest it takes |
| 2 | port | blocker | `neojac port` on Docs' `core` app: 2514 diagnostics, 41 of the 58 app files (tests and migrations aside) refused; every Django model, serializer and viewset needs decorators, class attributes and `with` |
| 3 | port | major | What `port` does translate is typed `any` everywhere, which an endpoint refuses (E1308): ported Python can never be served as it comes out |
| 4 | toolchain | major | 0.4.0 breaks every 0.3.3 project that uses plugins or `stdjac.<module>` imports, and `neojac docs` has no changelog or migration page |
| 5 | toolchain | minor | No self-update: moving to a new release is re-running the installer by hand |
| 6 | server | blocker | Still from vaultwarden (4): `@restspec` is GET/POST only (`PATCH` is E0033), with no parameters, path parameters, headers, body or status |
| 7 | server | major | Still from vaultwarden (7): an endpoint knows its caller only as `root`; what sign-in learnt (email, OIDC claims) cannot reach it |
| 8 | crossings | major | Still from vaultwarden (8): `any` is E1308 as an endpoint parameter or return, so a JSON body of open shape cannot cross |
| 9 | server | major | Still from vaultwarden (10): an endpoint's reply has no status, headers or cookies: a 302, a `Set-Cookie` and a DRF `400 {"field": [...]}` all need a transport plugin |
| 10 | docs | minor | The plugin examples now ship (`~/.neojac/0.4.0/abstractions/`), but they are neojac's own source; the docs pages themselves still give no complete transport or auth plugin |
| 11 | library | major | `int` is 64 bits and there is no RSA in the native library: an OIDC sign-in can't check its RS256 `id_token` without reaching into CPython's own ints |
| 12 | docs | minor | `apps/plugins` says `neojac check` in a plugin's own directory checks it; it is E5152 "no main.jac" there, and only `neojac check <module>.jac` works |
| 13 | docs | minor | The `apps/plugins` example plugin fails `neojac check`'s own lints: W3002 on its two `has ... postinit;` lines and W3055 on its inline `def postinit { ... }` |
| 14 | store | critical | Still from marked (17), on 0.4.0: a `str \| None` field holding `None` is kept, and after a restart every call that reads that graph fails with `DataError ... expected a str, got None` |
| 15 | store | critical | Still from marked (16), on 0.4.0: one node whose `obj` field holds a subclass makes every later graph call, by every user, answer 400 `rejected` until a restart; the node is then gone |
| 16 | docs | minor | W3055's message and the `building-an-app` skill say to run `neojac fmt --fix`; with no path it refuses ("it needs the files or directories to format") |
| 17 | language | minor | An edge typed as a union (`A \| B`) is E1178 "edges lead from nodes" on `[e -->]`; one edge type works |
| 18 | language | major | Keyword arguments to a method on an `any` value (`raw.decode(errors="replace")`) pass `check`, then fail at runtime: every request crashed |
| 19 | runtime | minor | `traceback.format_exc()` inside `except` gives `NoneType: None`; Python libraries that log errors that way print no traceback |
| 20 | diagnostics | minor | A Python helper script in the project tree is built into the app; one that imports a sibling is E1575, whose fix never names `[project] exclude` |

---

## 1. `neojac absorb` refuses a Python project

Repro, in Docs' `src/backend` (it has `pyproject.toml` and `uv.lock`):

```sh
neojac absorb .
```

Result:

```text
neojac: absorb: . holds no manifest to take into jac.toml: a package.json, or under it a Cargo.toml or a cmodule.toml
```

Expected: the Python dependencies (`pyproject.toml` `[project] dependencies`, pinned by `uv.lock`) taken into `jac.toml` `[dependencies.pypi]`, as a `package.json` is taken into an npm tree. `neojac help absorb` names npm, Cargo and C modules only.

Other languages: `uv`/`poetry`/`pdm` all import each other's `pyproject.toml`; `cargo` reads `Cargo.toml`, `npm` reads `package.json`.

Suggested support: read PEP 621 `[project] dependencies` (and `uv.lock`/`poetry.lock` pins) into `[dependencies.pypi]`.

## 2. `neojac port` refuses most of a Django app

Repro, in Docs' `src/backend`:

```sh
neojac port --check core --diagnostics json
```

Result: exit 1, 2514 diagnostics over 188 files. App code (tests and migrations aside): 41 of 58 files refused. Most diagnostics per file: `core/api/viewsets.py` 216, `core/models.py` 216, `core/api/serializers.py` 83. By construct:

| Count | E4001 "port does not translate ... yet" |
|---|---|
| 796 | a Python decorator |
| 521 | Python's `with` |
| 438 | a class's own attribute (Python's Assign) |
| 103 | a Python bytes literal |
| 93 | Python's `try` |
| 78 | Python's `*args`, `**kwargs`, keyword-only and positional-only parameters |
| 46 | Python's `super()` |
| 46 | a Python function inside a function |
| 45 | a class's own statement (Python's ClassDef) |

Minimal repro:

```python
# m/a.py
class Doc:
    reach = "restricted"

    @property
    def is_root(self):
        return True
```

```text
m/a.py:2:5: error[E4001]: port does not translate a class's own attribute (Python's Assign) yet
m/a.py:4:6: error[E4001]: port does not translate a Python decorator yet
```

Expected: class attributes, `@property`, `@staticmethod`/`@classmethod`, `try`, `with` and `super()` have direct Jac forms (`has`, `static def`, `try`, `with`, `super`); a Django model is a class of class attributes with a `class Meta`, so without them no model, serializer or view ports.

Other languages: `2to3`/`pyupgrade`-style translators handle every statement form; transpilers such as `py2many` or `Transcrypt` take class attributes and decorators.

Suggested support: translate class attributes to `has` (or `static has`), `@property`/`@staticmethod`/`@classmethod`, `try`, `with`, `super()`, nested functions and classes; keep unknown decorators as Jac decorators.

## 3. Ported Python is all `any`, and an endpoint refuses `any`

Repro:

```python
# m/b.py
def priority(role):
    return ["reader", "editor"].index(role)
```

`neojac port m -o out` writes:

```jac
def priority(role: any) -> any {
    return ["reader", "editor"].index(role);
}
```

Marked `:pub`, it is E1308 "not sendable" on both the parameter and the return (6, 8). So nothing ported serves without retyping every signature by hand.

Expected: types inferred where they can be (here `str -> int`), or kept from Python annotations, so a ported function can be an endpoint.

Suggested support: type inference over the ported module, or at least carrying annotations over.

## 4. 0.4.0 breaks 0.3.3 projects, with no migration page

Repro: the vaultwarden port (`../vaultwarden-jac`), which built and passed its proof on 0.3.3:

```sh
cd ../vaultwarden-jac && neojac check
```

Result on 0.4.0:

```text
jac.toml:4:1: error[E2226]: jac.toml's [plugins] is no table of a package's: a package declares the packages it uses, libraries and plugins alike, in [packages]
jac.toml:14:1: error[E2214]: no plugin 'rest_transport': jac.toml's [packages] declares none of that name, and neojac ships none
impl/model.impl.jac:1:28: error[E2234]: 'allroots' is not imported from 'stdjac.graph': a program imports it from `stdjac` itself (`import from stdjac { allroots }`)
impl/wire.impl.jac:9:27: error[E2234]: 'data_dir' is not imported from 'stdjac.plan': a program imports it from `stdjac` itself (`import from stdjac { data_dir }`)
```

The E2234s say exactly what to write: good. E2226 says where packages go but not the shape of an entry (`name = { path = "..." }`), which only the skill shows.

And, from the `writing-a-plugin` skill, a plugin now also needs `interface_ver = 1` in its `[plugin]` table (E2216), its own `archwire.jac` (E2231), and imports its contract from `transport.contract` / `auth.contract` / `common.contract` instead of `stdjac.remote`/`stdjac.server`.

Expected: a changelog or "moving from 0.3" page in `neojac docs`, or the diagnostics saying what to write instead; `neojac docs search "migrat"` and `neojac docs search "changelog"` find nothing.

Other languages: Rust editions ship `cargo fix --edition`; Python and Node ship release notes with "porting to" sections.

Suggested support: a `neojac docs changes` page per release, and `neojac fix` for the mechanical renames.

## 5. No self-update

`neojac help` lists no `update`/`upgrade`/`self-update`. Moving from 0.3.3 to 0.4.0 is running `install.sh` again (which keeps the old release beside it).

Other languages: `rustup update`, `uv self update`, `deno upgrade`, `bun upgrade`.

Suggested support: `neojac upgrade`, doing what `install.sh` does.

## 6. `@restspec` still has GET/POST only (vaultwarden 4)

Repro (0.4.0):

```jac
import from stdjac { restspec, HTTPMethod }

@restspec(method=HTTPMethod.PATCH, path="/x")
def:pub x -> int { return 1; }
```

Result: `error[E0033]: 'PATCH' must be known at compile time`; `restspec` still takes "one of no parameters". Docs' API is `PATCH`/`PUT`/`DELETE` on `/api/v1.0/documents/<id>/...` with query strings: none of it is a restspec. Served here by a transport plugin.

## 7. An endpoint can't see who signed in (vaultwarden 7)

Docs makes its user from the OIDC claims (`sub`, `email`, names) at sign-in, and every view reads `request.user.email`. In Jac, the auth plugin's `answer` sees the claims and gives a `Session(user, token, name)`, but an endpoint only has `root`: no account id, no name, no email. Worked around by the transport calling a `users.signed_in(email, sub)` endpoint, with the new session's token, right after sign-in, so the endpoint can put a profile on that root.

Expected: the session's account and name readable from server code (`stdjac.caller()` or similar), and something for claims.

## 8. `any` is still not sendable (vaultwarden 8)

`def:pub echo(v: any) -> any` on 0.4.0: E1308 on parameter and return. Docs' endpoints take partial bodies (`PATCH {"title": 5}` must answer as DRF does: the 5 becomes `"5"`; `{"id": "not-a-uuid"}` must answer "Must be a valid UUID."), so bodies cross as the JSON text and are parsed inside.

## 9. No reply status, headers or cookies (vaultwarden 10)

Docs answers `201`, `204`, `400 {"title": ["Ensure this field has no more than 255 characters."]}`, `401`, `403`, `404`, a `302` with `Location` and `Set-Cookie` at sign-in, and checks `X-CSRFToken` against the `csrftoken` cookie. None of that is expressible from an endpoint; the transport plugin unwraps a `{status, body}` reply.

## 10. Plugin examples ship, but as neojac source

The `writing-a-plugin` skill now points at `~/.neojac/0.4.0/abstractions/` as worked examples. Those are neojac's own shipped plugins; under this run's rules (no reading neojac's source) they are off limits, and the docs pages alone still give no complete transport or auth plugin, only the contracts.

## 11. No arithmetic past 64 bits, and no RSA, for an RS256 sign-in

Docs signs in through OpenID Connect, and `mozilla-django-oidc` checks the `id_token`'s RS256 signature against the provider's JWKS: `pow(signature, e, n)` over a 2048-bit `n`.

Repro:

```jac
with entry {
    big = 2 ** 2048 - 159;
    print(big.bit_length());
}
```

```text
OverflowError: integer overflow
```

This is documented (`neojac docs language/types`: "`int` is 64 bits and overflow raises; it is not arbitrary precision"), and `hashlib`, `hmac`, `secrets`, `ssl` are native, but nothing native verifies an RSA signature (`ssl` holds TLS, not signatures). The `using-python-packages` skill says not to import a PyPI package (`cryptography`, `PyJWT`) in an app's native space "for now" (a known W1100 defect), so the auth plugin does the modular power with CPython's own ints:

```jac
py = importlib.import_module("builtins");
m = py.pow(py.int.from_bytes(sig, "big"), py.int(e), py.int(n_hex, 16));
```

which works (checked against Python), but every value is a `PyObject`.

Expected: an arbitrary-precision integer type (or `pow(a, b, m)` on bytes), or an RSA/JWT verify in the native library, since sign-in through OIDC (Google, Microsoft, Keycloak, ProConnect) is RS256 almost everywhere.

Other languages: Python's `int` is unbounded; Go has `math/big` and `crypto/rsa`; Rust has `num-bigint` and `rsa`; Node has `BigInt` and `crypto.verify`.

Suggested support: a native `bigint` (the `decimal` module already holds arbitrary-precision coefficients), or `rsa_verify` / JWT verification in the library.

## 12. `neojac check` refuses a plugin's own directory

`neojac docs apps/plugins` ("What a plugin imports"): "`neojac check` in the plugin's own directory holds it to all of this, with no app around it."

Repro: a plugin package (`jac.toml` with `kind = "plugin"`, its `archwire.jac` and `oidc.jac`), in its directory:

```sh
neojac check
```

```text
error[E5152]: the Jac project '.' has no main.jac, the program it is
```

`neojac check oidc.jac` checks it. Expected: a `kind = "plugin"` project checked as a plugin (no main module), as the page says, or the page naming the module to give.

## 13. The docs' own example plugin fails the lints

The `JsonStore` example in `neojac docs apps/plugins` ("Writing a plugin") has

```jac
    has rows: dict[str, list[any]] postinit;
    has data_dir: str postinit;

    def postinit {
        self.rows = {};
        self.data_dir = "";
    }
```

Copied into a module, `neojac check` gives W3002 ("a `has` after one with the same modifiers belongs in it") on both `has` lines, and W3055 ("the body of 'postinit' belongs in an impl"). The block is marked "example: not checked". Expected: the page's examples written as the lints want them, since a reader copies them.

## 14. A `str | None` field holding `None` still makes the kept graph unreadable (marked 17)

Retested on 0.4.0 with a one-module app (`space api: native { notes; }`):

```jac
node Note {
    has text: str, tag: str | None = None;
}

def:pub add(text: str) -> int;    # root.shared ++> Note(text=text); return the count
def:pub count -> int;              # return len([root.shared --> [?:Note]])
```

`add("a")` answers `{"ok": true, "data": 1}`. Stop the server, start it again, call `count`:

```text
{"ok": false, "kind": "failed", "detail": "count failed"}
endpoint /__jac/call/api/notes/count failed: DataError: .../.jac/data/api/graph.db holds a notes.Note node, b503494bc2e55bf90000000000000003, which no longer fits its type (.tag: expected a str, got None)
```

The program did not change between the two starts. The value was accepted when written, and is refused when read. `apps/data`'s "Data that no longer fits" table lists only program changes as causes. Other dogfooders report the same on 0.4.0 and 0.3.3.

Docs has many optional fields (a document's `excerpt`, `deleted_at`, an access's `user` or `team`). This port does not keep them as `str | None`. It keeps `""` for "none" and turns it into JSON `null` at the reply. That is a workaround forced by this bug, written down here, not silent.

Expected: what a write accepts, a read accepts.

## 15. One subclass value in a kept field still breaks every user's calls (marked 16)

Retested on 0.4.0, as marked-jac 16 gives it (`obj Circle(Shape)`, `node Box { has s: Shape; }`, a `Put` walker that makes a `Box(s=Circle(...))`, a `Count` walker). Users amy and bob:

| Call | Answer |
|---|---|
| bob `Count` | 200 `reports: [0]` |
| amy `Put` | 400 `rejected`: `Put: expected exactly the class its type names, got a Circle` |
| bob `Count` | 400 `rejected`: `Count: expected exactly the class its type names, got a Circle` |
| amy `Count` | the same 400 |
| after a restart, amy `Count` | 200 `reports: [0]` (the Box is gone) |

Nothing is printed on the server's output. Unchanged from 0.3.3.

## 16. `neojac fmt --fix` with no path, as the messages say, refuses

W3055 says "`neojac fmt --fix` moves the body to the module's impl annex", and the `building-an-app` skill says "run `neojac fmt --fix` before `check`". Run as written:

```text
neojac fmt: it needs the files or directories to format
```

`neojac fmt --fix .` works. Expected: the messages say `neojac fmt --fix .`, or `fmt` with no path formats the project, as `check` with no path checks it.

## 17. An edge whose type is a union can't be followed to its ends

`language/edge-references` says `[e -->]` on an edge gives its destination. It works when `e` has one edge type, and is refused when `e`'s type is a union of edge types:

```jac
node P {}

edge A: P --> P {}

edge B: P --> P {}

def dest(e: A | B) -> list[P] {
    return [e -->][?:P];
}
```

```text
main.jac:8:13: error[E1178]: edges lead from nodes, found A | B
```

With `e: A` it runs. The message is also wrong for edges: they are valid sources, as the docs page shows. Expected: a union of edge types works where each of its members works. The port's `holder` takes `Access` only, which is all it needed.

## 18. Keyword arguments to a method on an `any` value pass `check`, then fail at runtime

```jac
import io;

def go(h: any) {
    print(h.getvalue().split(sep=b","));
}

with entry {
    go(io.BytesIO(b"a,b"));
}
```

`neojac check` passes. `neojac run`:

```text
TypeError: 'bytes.split' takes no keyword arguments
```

CPython's `bytes.split`, `bytes.decode` and the rest take these keywords. The same call on a value whose type the compiler knows (`b"a,b".split(sep=b",")`) works. In this port it was `raw.decode(errors="replace")` on a request body read from Python's `http.server`. Every request to the Jac app crashed, and the server printed only `Exception occurred during processing of request` with no traceback (see 19). Fix used: positional arguments, `raw.decode("utf-8", "replace")`.

Expected: the call works as in Python, or `check` refuses it.

## 19. `traceback.format_exc()` is empty inside `except`

```jac
import sys;
import traceback;

with entry {
    try {
        int("x");
    } except ValueError as e {
        print("exc_info:", sys.exc_info()[0]);
        print("format_exc:", traceback.format_exc().strip());
    }
}
```

```text
exc_info: <class 'ValueError'>
format_exc: NoneType: None
```

`sys.exc_info()` knows the exception, but `traceback.format_exc()` doesn't. A guess, marked as one: the traceback isn't attached the way CPython's `traceback` module reads it. Python libraries that print errors this way go silent: `socketserver`'s `handle_error` printed a header and no traceback for finding 18, which made a one-line bug take several rounds to find.

## 20. A helper script in the project tree is built into the app

The proof scripts sit in `proof/` beside the app. `proof/drive.py`, which imports nothing local, was taken in silently. `proof/restart.py`, which does `import drive`, stopped the app from building:

```text
proof/restart.py:10:1: error[E1575]: 'proof.restart' imports 'proof.drive' whole, and no '-->' wire declares it: add `proof.drive --> proof.restart;` to its `graph import` block
```

Minimal repro: an app with `graph layers { layer all { *; } }`, plus `tools/a.py` (`print("tool")`) and `tools/b.py` (`import a`). `neojac check` gives the same E1575 for `tools/b.py`. With the import removed, both files pass as modules of the app.

`toolchain/projects` does document this ("Every file under an `archwire.jac` ... is a module of the project") and the way out, `[project] exclude`, which this port now uses (`exclude = ["proof/*"]`). But the message and `neojac docs E1575` only say "add the wire the message gives, or remove the import". Following that advice wires a test script into the server.

Expected: E1575's fix also names `[project] exclude`, for files that aren't the app's source.
