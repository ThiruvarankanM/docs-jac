glob LANGUAGES: list[str] = ["en-us", "fr-fr", "de-de", "nl-nl", "es-es"],
    SEARCH_LIMIT: int = 5,
    SIMILAR: float = 0.2;

def:protect signed_in(sub: str, email: str) -> dict[str, str];

def:pub me -> Reply;

def:pub onboarding_done -> Reply;

def:pub search(query: str) -> Reply;

def:pub update(id: str, body: str) -> Reply;

def trigrams(s: str) -> set[str];

def similarity(a: str, b: str) -> float;

def distance(a: str, b: str) -> int;
