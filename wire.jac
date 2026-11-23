obj Reply {
    has status: int = 200,
        body: str = "",
        ctype: str = "application/json";
}

def reply(status: int, data: any) -> Reply;

def empty -> Reply;

def detail(status: int, msg: str) -> Reply;

def denied(anon: bool) -> Reply;

def now -> float;

def iso(t: float) -> str | None;

def new_uuid -> str;

def is_uuid(s: any) -> bool;

def loads(text: str) -> dict[str, any];

def slug(s: str) -> str;

def fold(s: str) -> str;

def page(items: list[any], q: dict[str, str], base: str, path: str) -> Reply | dict[str, any];
