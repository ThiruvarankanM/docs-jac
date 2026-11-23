glob PATH: str = "/api/v1.0/documents/",
    ALPHABET: str = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    POSITIONS: list[str] = ["first-child", "last-child", "first-sibling", "last-sibling", "left", "right"],
    ORDERINGS: list[str] = ["created_at", "updated_at", "title"];

def:pub listing(query: str, base: str) -> Reply;

def:pub favorites(query: str, base: str) -> Reply;

def:pub trashbin(query: str, base: str) -> Reply;

def:pub all_docs(query: str, base: str) -> Reply;

def:pub create(body: str) -> Reply;

def:pub retrieve(pk: str) -> Reply;

def:pub patch(pk: str, body: str) -> Reply;

def:pub put(pk: str, body: str) -> Reply;

def:pub destroy(pk: str) -> Reply;

def:pub abilities_of(pk: str) -> Reply;

def:pub children(pk: str, query: str, base: str) -> Reply;

def:pub add_child(pk: str, body: str) -> Reply;

def:pub tree(pk: str) -> Reply;

def:pub link_configuration(pk: str, body: str) -> Reply;

def:pub favorite(pk: str) -> Reply;

def:pub unfavorite(pk: str) -> Reply;

def:pub leave(pk: str) -> Reply;

def:pub move(pk: str, body: str) -> Reply;

def:pub restore(pk: str) -> Reply;

def key(n: int) -> str;

def num(seg: str) -> int;

def last_key(prefix: str, depth: int) -> int;

def roots_of(paths: list[str]) -> list[str];

def readable(u: User) -> list[Doc];

def filtered(u: User, items: list[Doc], q: dict[str, str]) -> list[Doc];

def by_fav(u: User, items: list[Doc], q: dict[str, str]) -> list[Doc];

def ordered(items: list[Doc], q: dict[str, str]) -> list[Doc];

def paged(u: User | None, items: list[Doc], q: dict[str, str], base: str, path: str, fav: bool) -> Reply;

def title_error(data: dict[str, any]) -> Reply | None;

def set_title(d: Doc, data: dict[str, any]);

def edit(pk: str, body: str, action: str) -> Reply;

def soft_delete(d: Doc);

def shift(prefix: str, depth: int, start: int);

def repath(d: Doc, path: str);
