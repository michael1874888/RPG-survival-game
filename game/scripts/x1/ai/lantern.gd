extends RefCounted
## E08: no attack; links to one nearby ally and gives it damage reduction while in range.

const Common := preload("res://scripts/x1/ai/common.gd")


static func init(_b, e: Dictionary) -> void:
	e.link_id = -1
	e.relink = 0.0


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	Common.keep_distance(b, e, float(s.keep), dt)
	var range_limit: float = float(s.link_range)
	var link: Dictionary = b.by_id.get(int(e.link_id), {})
	if not link.is_empty() and float(link.hp) > 0.0 and link.pos.distance_to(e.pos) <= range_limit:
		return
	if not link.is_empty() and int(link.get("shield_by", -1)) == int(e.id): link.shield_by = -1
	e.link_id = -1
	e.relink = float(e.relink) - dt
	if float(e.relink) > 0.0: return
	var best: Dictionary = {}
	var best_distance := INF
	for other: Dictionary in b.enemies:
		if float(other.hp) <= 0.0 or int(other.id) == int(e.id) or other.role == "boss" or other.ai == "lantern": continue
		if int(other.get("shield_by", -1)) >= 0 and b.by_id.has(int(other.shield_by)): continue
		var distance: float = other.pos.distance_to(e.pos)
		if distance <= range_limit and distance < best_distance:
			best_distance = distance
			best = other
	if best.is_empty(): return
	e.link_id = int(best.id)
	best.shield_by = int(e.id)
	e.relink = float(s.relink)
	b.event("link", {"pos": e.pos, "to": best.pos})
