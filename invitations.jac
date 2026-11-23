glob VALID_FOR: float = 604800.0,
    EMAIL: str = r"^[^@\s]+@[^@\s]+\.[^@\s]+$";

def:pub list_invitations(pk: str, query: str, base: str) -> Reply;

def:pub create_invitation(pk: str, body: str) -> Reply;

def:pub get_invitation(pk: str, id: str) -> Reply;

def:pub patch_invitation(pk: str, id: str, body: str) -> Reply;

def:pub put_invitation(pk: str, id: str, body: str) -> Reply;

def:pub delete_invitation(pk: str, id: str) -> Reply;

def invite_abilities(role: str, i: Invite) -> dict[str, any];

def invite_json(role: str, d: Doc, i: Invite) -> dict[str, any];

def invites(d: Doc) -> list[Invite];

def check_role(role: any, mine: str) -> dict[str, list[str]];

def change_invitation(pk: str, id: str, body: str, action: str) -> Reply;
