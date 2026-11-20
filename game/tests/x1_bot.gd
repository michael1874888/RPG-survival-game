extends RefCounted
## Scripted player for probes and flow tests. Reacts instantly and never misreads warnings,
## so its results describe the rules, not human difficulty or fun.

const Data := preload("res://scripts/x1/core/data.gd")

var pounce_cooldown := 0.0


func battle_input(b, dt: float) -> Dictionary:
	pounce_cooldown = maxf(0.0, pounce_cooldown - dt)
	var me: Vector2 = b.player.pos
	var push := Vector2.ZERO
	var crowd := 0
	var target: Dictionary = {}
	var target_distance := INF
	for e: Dictionary in b.enemies:
		if float(e.hp) <= 0.0: continue
		var offset: Vector2 = me - e.pos
		var distance := offset.length()
		if distance < 110.0: crowd += 1
		if distance < 260.0 and distance > 0.01:
			push += offset / distance * (260.0 - distance) / 260.0 * (2.5 if e.get("busy", false) else 1.0)
		if b.is_prey(e) and distance < target_distance:
			target_distance = distance
			target = e
	for shot: Dictionary in b.shots:
		var offset: Vector2 = me - Vector2(shot.pos)
		if offset.length() < 160.0: push += Vector2(shot.dir).orthogonal() * signf(Vector2(shot.dir).orthogonal().dot(offset) + 0.001) * 2.0
	for hazard: Dictionary in b.hazards:
		var offset: Vector2 = me - Vector2(hazard.pos)
		if offset.length() < float(hazard.radius) + 40.0: push += offset.normalized() * 2.0
	var move := push
	if not target.is_empty() and target_distance > 200.0 and not target.get("busy", false):
		move += (target.pos - me).normalized() * 0.8
	var center: Vector2 = b.world * 0.5
	if me.distance_to(center) > 600.0: move += (center - me).normalized() * 0.6
	if move.length_squared() < 0.01: move = Vector2.RIGHT.rotated(b.elapsed * 0.7) * 0.3
	var pounce := Vector2.ZERO
	if pounce_cooldown <= 0.0 and int(b.pounce.charges) >= 1:
		if crowd >= 4:
			pounce = push.normalized() if push.length_squared() > 0.01 else Vector2.UP
		elif not target.is_empty() and target_distance > 140.0 and target_distance < 300.0 and int(b.pounce.charges) >= 2 \
				and not target.get("busy", false):
			pounce = (target.pos - me).normalized()
		if pounce != Vector2.ZERO: pounce_cooldown = 0.35
	var crowd_wide := 0
	for e: Dictionary in b.enemies:
		if float(e.hp) > 0.0 and me.distance_to(e.pos) < 220.0: crowd_wide += 1
	var ult: bool = b.ult_ready() and (crowd_wide >= 4 or (not target.is_empty() and target.role == "boss" and target_distance < 260.0))
	return {"move": move.normalized(), "pounce": pounce, "ult": ult}


func pick_card(run) -> String:
	var offers: Array = run.build.offers
	for id in offers:
		if str(id).begins_with("EV"): return id
	var bias: Array = run.data.habits[run.habit].bias
	for id in offers:
		if run.build.cards.has(id): return id
	for id in offers:
		if run.data.cards[id].category in bias: return id
	return offers[0]


func pick_node(run) -> String:
	var options: Array = run.available_nodes()
	var ratio: float = run.hp / run.max_hp()
	var order: Array = ["bed", "shop", "moon", "hunt", "den"] if ratio < 0.45 else ["den", "hunt", "moon", "shop", "bed"]
	for kind in order:
		for id in options:
			if run.map.nodes[id].kind == kind: return id
	return options[0]


## Drives non-battle phases. Returns false when nothing could be done.
func handle_phase(run) -> bool:
	match run.phase:
		"map": return run.enter(pick_node(run))
		"card":
			if run.build.offers.is_empty(): run.skip_card()
			else: run.choose_card(pick_card(run))
		"bed":
			if run.hp / run.max_hp() < 0.7 or run.build.upgradable().is_empty(): run.bed_rest()
			else: run.bed_train()
		"upgrade_pick": run.pick_upgrade(run.build.upgradable()[0])
		"shop":
			for i in run.shop_stock.size():
				var entry: Dictionary = run.shop_stock[i]
				if entry.type == "heal" and run.hp / run.max_hp() < 0.6 and run.shop_can_buy(i): run.shop_buy(i)
				elif entry.type == "card" and run.shop_can_buy(i): run.shop_buy(i)
			run.leave_node()
		"moon":
			var options: Array = run.data.event(run.event_id).options
			for i in options.size():
				if run.option_ok(options[i]):
					return run.choose_event(i)
			return false
		"item": run.confirm_item(run.item_choices[0])
		"supply": run.choose_supply(run.supply_choices[0])
		_: return false
	return true
