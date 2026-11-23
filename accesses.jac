def:pub list_accesses(pk: str) -> Reply;

def:pub create_access(pk: str, body: str) -> Reply;

def:pub my_access(pk: str) -> Reply;

def:pub get_access(pk: str, id: str) -> Reply;

def:pub patch_access(pk: str, id: str, body: str) -> Reply;

def:pub put_access(pk: str, id: str, body: str) -> Reply;

def:pub delete_access(pk: str, id: str) -> Reply;

def roles_tuple(u: User, d: Doc) -> tuple[str, str];

def access_abilities(u: User, e: Access, d: Doc, roles: tuple[str, str], anc_max: str) -> dict[str, any];

def access_json(u: User, e: Access, d: Doc, roles: tuple[str, str], anc_max: str, full: bool) -> dict[str, any];

def find_access(d: Doc, id: str) -> Access | None;

def change_access(pk: str, id: str, body: str, action: str) -> Reply;
