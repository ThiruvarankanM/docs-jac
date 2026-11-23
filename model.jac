node User {
    has id: str,
        sub: str,
        email: str,
        full_name: str = "",
        short_name: str = "",
        language: str = "",
        first: bool = True,
        created: float = 0.0;
}

node Me {
    has user: str;
}

node Doc {
    has id: str,
        path: str,
        depth: int,
        creator: str,
        created: float,
        updated: float,
        numchild: int = 0,
        title: str = "",
        titled: bool = False,
        link_reach: str = "restricted",
        link_role: str = "reader",
        deleted: float = 0.0,
        anc_deleted: float = 0.0,
        nb_direct: int = 0,
        nb_anc: int = 0,
        nb_at: float = 0.0;
}

node Invite {
    has id: str,
        email: str,
        role: str,
        issuer: str,
        created: float;
}

edge Access: Doc --> User {
    has id: str,
        role: str,
        created: float,
        updated: float;
}

edge Trace: Doc --> User {}

edge Favorite: Doc --> User {}

glob ROLES: list[str] = ["reader", "commenter", "editor", "administrator", "owner"],
    LINK_ROLES: list[str] = ["reader", "commenter", "editor"],
    REACHES: list[str] = ["restricted", "authenticated", "public"],
    PRIVILEGED: list[str] = ["administrator", "owner"],
    COMMENTING: list[str] = ["commenter", "editor", "administrator", "owner"],
    STEP: int = 7,
    NB_TTL: float = 600.0,
    TRASH_DAYS: float = 30.0;

def prio(order: list[str], v: str) -> int;

def top(order: list[str], vals: list[str]) -> str;

def nz(s: str) -> str | None;

def caller -> User | None;

def user_by_id(id: str) -> User | None;

def users -> list[User];

def docs -> list[Doc];

def doc_by_id(id: str) -> Doc | None;

def under(d: Doc) -> list[Doc];

def lineage(d: Doc) -> list[Doc];

def parent(d: Doc) -> Doc | None;

def kids(d: Doc) -> list[Doc];

def holder(e: Access) -> User;

def accesses(d: Doc) -> list[Access];

def access_of(d: Doc, u: User) -> Access | None;

def traced(d: Doc, u: User) -> bool;

def faved(d: Doc, u: User) -> bool;

def roles_of(u: User | None, d: Doc) -> list[str];

def role_of(u: User | None, d: Doc) -> str;

def equivalent(links: list[tuple[str, str]]) -> tuple[str, str];

def ancestors_def(d: Doc) -> tuple[str, str];

def select_options(reach: str, role: str) -> dict[str, any];

def abilities(u: User | None, d: Doc) -> dict[str, any];

def nb_accesses(d: Doc) -> tuple[int, int];

def forget_nb(d: Doc);

def doc_json(u: User | None, d: Doc, fav: bool) -> dict[str, any];

def user_json(u: User) -> dict[str, any];

def light_user(u: User) -> dict[str, any];

def gate(u: User | None, d: Doc, action: str) -> Reply | None;

def no_doc -> Reply;

def in_trash(d: Doc) -> bool;
