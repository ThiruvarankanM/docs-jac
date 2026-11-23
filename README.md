# La Suite Docs in Jac

A Jac (neojac 0.4.0) port of the API behind [La Suite Docs](https://github.com/suitenumerique/docs), a collaborative document editor: OIDC sign-in, users, the document tree, favorites, link reach, accesses and invitations. On a 117-request scenario with 3 users, its replies are identical to the original's. What neojac could not do is in [FINDINGS.md](FINDINGS.md).

## Run

```sh
python3 proof/oidc.py 8600
neojac check
JAC_DOCS_LISTEN=127.0.0.1:8072 OIDC_RP_CLIENT_SECRET=secret neojac run docs --fresh
```

`proof/oidc.py` is a small fake OpenID provider. The port signs in through it, and so does the original. `--fresh` starts with empty data. Leave it off to keep the data from the last run.

## Layout

| Module | Holds |
|---|---|
| `wire` | `Reply` (status and body), DRF's error shapes (`detail`, `denied`), dates, uuids, JSON parsing, `page` (DRF's page-number pagination) |
| `model` | Nodes `User`, `Doc`, `Invite`; edges `Access`, `Trace`, `Favorite`; roles, link reach, abilities, and the document JSON |
| `users` | `users/me/`, `onboarding-done`, user search, profile update |
| `documents` | List, favorites, trashbin, all, create, retrieve, update, delete, children, tree, move, restore, favorite, leave, link configuration, abilities |
| `accesses` | `documents/<id>/accesses/`: list (with inherited roles), create, `me`, get, update, delete |
| `invitations` | `documents/<id>/invitations/`: list, create, get, update, delete |
| `config` | `config/`, the original's settings reply |
| `plugins/docs_transport` | Maps Docs' 38 routes (methods, path parameters, JSON bodies, query strings) onto the endpoints, and a `Reply` onto the HTTP response. Also handles the sign-in redirects, the session and CSRF cookies, and the CSRF check. |
| `plugins/oidc_auth` | The OpenID Connect code flow: authorize, token, userinfo, and the RS256 check of the `id_token` |

`archwire.jac` wires the modules. The routes are in `jac.toml` under `[transport.docs_transport]`.

### Where the data lives

- Users, documents and invitations are nodes on `root.shared`, because every user sees documents that other users made.
- A user's role on a document is an `Access` edge from the document to the user. Favorites and "visited a public link" traces are edges too.
- The document tree uses the same `path` strings as the original's django-treebeard (base-36 steps of 7 characters). So the `path`, `depth` and `numchild` fields and the order of the tree are the same, including after moves.
- Optional fields are kept as `""` and sent as JSON `null`, because a kept `None` breaks the graph after a restart ([FINDINGS #14](FINDINGS.md#14-a-str--none-field-holding-none-still-makes-the-kept-graph-unreadable-marked-17)).

## Proof

`proof/drive.py` signs in amy, bob and cat through `proof/oidc.py`. It then sends the same 117 requests and prints every reply, with ids, dates and tokens masked. `proof/expected.out` is the original's output.

```sh
proof/fresh.sh http://127.0.0.1:8072 port.out
diff proof/expected.out port.out
```

To check a restart, run `python3 proof/restart.py http://127.0.0.1:8072 http://127.0.0.1:8600` once, restart the server without `--fresh`, and run it again. The two outputs must be the same.

| Check | Result |
|---|---|
| 117-request scenario: 64×200, 12×201, 6×204, 18×400, 3×401, 11×403, 3×404 | identical to `proof/expected.out` |
| Read everything back, restart, read again (43 requests) | identical |
| Scenario time: port vs original | 0.15–0.18 s vs 1.05–1.14 s |
| Server memory after the scenario: port vs original | about 35 MB vs about 238 MB |

To make `expected.out` again from the original, you need Docs' `src/backend` with its virtualenv, plus Postgres, Redis and MinIO as `proof/original.env` describes. Then run `proof/original.sh <docs>/src/backend` and run `proof/fresh.sh` against it.

## Not ported

- **Document content:** the Y.js content stored in S3/MinIO is not ported, so neither are `content`, `formatted-content`, `content-updated`, `duplicate` and versions. The scenario works on titles and the tree only.
- **Other features:**
  - attachments and media (`attachment-upload`, `media-auth`, `media-check`)
  - search, `mention`, `cors-proxy` and the AI endpoints
  - ask-for-access, threads, comments and reactions
  - `create-for-owner` (server-to-server)
  - teams, logout, and the emails sent with invitations
  - the collaboration websocket server and the frontend
