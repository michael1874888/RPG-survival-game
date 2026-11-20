extends RefCounted
## Fodder and hounds: run straight at the player, spread apart, hurt on contact.


static func update(b, e: Dictionary, dt: float) -> void:
	var dir: Vector2 = b.dir_to_player(e)
	var separation := Vector2.ZERO
	var radius: float = float(e.radius)
	for index in b.grid.query(e.pos, radius * 2.5):
		var other: Dictionary = b.enemies[index]
		if int(other.id) == int(e.id) or float(other.hp) <= 0.0: continue
		var away: Vector2 = e.pos - other.pos
		var distance := away.length()
		var limit: float = radius + float(other.radius)
		if distance > 0.01 and distance < limit:
			separation += away / distance * (1.0 - distance / limit)
	var velocity: Vector2 = (dir + separation.limit_length(1.0) * 0.9).normalized() * float(e.speed)
	b.move_enemy(e, velocity, dt)
	if float(e.contact) > 0.0 and e.pos.distance_to(b.player.pos) <= radius + b.player_radius():
		b.hurt_player(float(e.contact), str(e.kind))
