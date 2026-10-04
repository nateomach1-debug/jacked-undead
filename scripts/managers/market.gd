extends RefCounted
## Market rules: what's free and what's owned. Purchases are saved in profile.owned as
## "att:<id>" (attachments), later "char:<id>" and "badge:<id>".
## Loaded with load() + a null check.

const STARTER_ATTACHMENTS: Array = ["red_dot", "long_barrel", "ext_mag", "foregrip"]


func attachment_key(id: String) -> String:
	return "att:" + id


func owns_attachment(profile, id: String) -> bool:
	if STARTER_ATTACHMENTS.has(id):
		return true
	return profile != null and profile.has_item(attachment_key(id))
