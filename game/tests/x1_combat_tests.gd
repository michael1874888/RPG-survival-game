extends SceneTree
## X1 player rules: auto claw, pounce, landing bite, night shadow, hurt, hitstop, roam, marks, input.

const H := preload("res://tests/x1_helpers.gd")
const Touch := preload("res://scripts/x1/ui/touch_input.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	claw_tests()
	pounce_tests()
	ult_and_hurt_tests()
	roam_and_mark_tests()
	input_tests()
	print("X1 COMBAT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func claw_tests() -> void:
	var b = H.battle()
	var me: Vector2 = b.player.pos
	var fodder: Dictionary = H.enemy(b, "E01", me + Vector2(-100, 0), 500.0)
	var prey: Dictionary = H.enemy(b, "E03", me + Vector2(140, 0), 500.0, {"prey": true})
	H.run_for(b, 0.05)
	check(float(prey.hp) < 500.0 and float(fodder.hp) == 500.0, "claw prefers prey in range over a nearer fodder behind")
	check(b.player.facing.x > 0.9, "claw turns Nana toward the chosen target")
	var swings := 0
	b.claw_timer = 0.0
	for i in 60:
		b.step(1.0 / 60.0, {})
		for ev: Dictionary in b.take_events():
			if ev.kind == "swipe" and int(ev.depth) == 0: swings += 1
	check(swings >= 2 and swings <= 3, "claw swings every 0.42 s (2-3 swings per second, got %d)" % swings)
	var far = H.battle()
	H.enemy(far, "E01", far.player.pos + Vector2(400, 0), 500.0)
	H.run_for(far, 0.5)
	check(far.metrics.damage_dealt == 0.0, "claw does not swing at enemies beyond seek range")
	var spread = H.battle()
	var a: Dictionary = H.enemy(spread, "E01", spread.player.pos + Vector2(100, 10), 500.0)
	var c: Dictionary = H.enemy(spread, "E01", spread.player.pos + Vector2(100, -10), 500.0)
	H.run_for(spread, 0.05)
	check(float(a.hp) == 490.0 and float(c.hp) == 490.0, "one claw hits every enemy inside the arc for 10")


func pounce_tests() -> void:
	var b = H.battle()
	var start: Vector2 = b.player.pos
	check(int(b.pounce.charges) == 2, "pounce starts with 2 charges")
	var path: Dictionary = H.enemy(b, "E05", start + Vector2(110, 0), 900.0)
	var landing: Dictionary = H.enemy(b, "E05", start + Vector2(270, 0), 900.0)
	b.claw_timer = 99.0
	b.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	check(int(b.pounce.charges) == 1 and b.dashing(), "pounce spends one charge and dashes")
	b.hurt_player(50.0, "test")
	H.run_for(b, 0.25, {})
	check(float(b.player.hp) == 100.0, "no damage while dashing")
	check(absf(b.player.pos.x - start.x - 230.0) < 2.0, "pounce travels 230 (got %.1f)" % (b.player.pos.x - start.x))
	check(float(path.hp) == 900.0 - 12.0 - 30.0 or float(path.hp) == 900.0 - 12.0, "path enemy takes 12 once")
	check(float(landing.hp) <= 900.0 - 30.0, "landing bite hits the nearest enemy for 30")
	var path_hits := 0
	var refund = H.battle()
	var prey: Dictionary = H.enemy(refund, "E04", refund.player.pos + Vector2(250, 0), 900.0, {"prey": true})
	refund.claw_timer = 99.0
	refund.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	H.run_for(refund, 0.3)
	check(int(refund.pounce.charges) == 2, "biting marked prey refunds the pounce")
	refund.claw_timer = 99.0
	refund.step(1.0 / 60.0, {"pounce": Vector2.LEFT})
	H.run_for(refund, 0.3)
	refund.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	H.run_for(refund, 0.3)
	check(int(refund.pounce.charges) == 0, "prey refund has a cooldown (no endless chaining)")
	var elite = H.battle()
	H.enemy(elite, "EL01", elite.player.pos + Vector2(250, 0), 5000.0)
	elite.claw_timer = 99.0
	elite.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	H.run_for(elite, 0.3)
	check(int(elite.pounce.charges) == 1, "biting an elite does not refund")
	var recharge = H.battle()
	recharge.step(1.0 / 60.0, {"pounce": Vector2.UP})
	H.run_for(recharge, 2.4)
	check(int(recharge.pounce.charges) == 1, "no recharge before 2.5 s")
	H.run_for(recharge, 0.4)
	check(int(recharge.pounce.charges) == 2, "one charge back after 2.5 s")
	var wall = H.battle("roam", {}, "belltower", Vector2(1200, 470))
	wall.step(1.0 / 60.0, {"pounce": Vector2.DOWN})
	H.run_for(wall, 0.3)
	check(wall.player.pos.distance_to(Vector2(1200, 800)) >= 210.0 + 19.0 and not wall.dashing(), "pounce stops at the tower base instead of passing through")
	var empty = H.battle()
	empty.pounce.charges = 0
	empty.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	check(not empty.dashing(), "no pounce without charges")


func ult_and_hurt_tests() -> void:
	var b = H.battle()
	var near: Dictionary = H.enemy(b, "E05", b.player.pos + Vector2(150, 0), 900.0)
	b.claw_timer = 99.0
	check(not b.activate_ult(), "night shadow needs a full meter")
	b.pounce.charges = 0
	b.add_meter(100.0)
	check(b.ult_ready(), "full meter is ready")
	b.step(1.0 / 60.0, {"ult": true})
	check(b.ult_active() and float(b.ult.meter) == 0.0 and int(b.pounce.charges) == 2, "night shadow spends the meter and refills pounces")
	check(float(near.hp) <= 900.0 - 15.0, "night shadow shockwave hits nearby enemies")
	b.add_meter(50.0)
	check(float(b.ult.meter) == 0.0, "meter does not fill while the night shadow is active")
	var kill = H.battle()
	var fodder: Dictionary = H.enemy(kill, "E01", kill.player.pos + Vector2(100, 0))
	H.run_for(kill, 0.6)
	check(float(fodder.hp) <= 0.0 and float(kill.ult.meter) > 0.0, "kills charge the night shadow")
	var hurt = H.battle()
	hurt.claw_timer = 99.0
	hurt.hurt_player(8.0, "a")
	hurt.hurt_player(20.0, "b")
	hurt.step(1.0 / 60.0, {})
	check(float(hurt.player.hp) == 80.0, "simultaneous hits only apply the largest")
	hurt.hurt_player(20.0, "c")
	hurt.step(1.0 / 60.0, {})
	check(float(hurt.player.hp) == 80.0, "0.8 s protection after a hit")
	H.run_for(hurt, 0.85)
	hurt.hurt_player(10.0, "d")
	hurt.step(1.0 / 60.0, {})
	check(float(hurt.player.hp) == 70.0, "hits land again after protection")
	var assist = H.battle()
	assist.assist = true
	assist.hurt_player(20.0, "a")
	assist.step(1.0 / 60.0, {})
	check(float(assist.player.hp) == 85.0, "assist mode reduces enemy damage to 75%")
	var stop = H.battle()
	stop.hitstop_enabled = true
	stop.add_hitstop(0.05)
	var before: float = stop.elapsed
	stop.step(1.0 / 60.0, {})
	stop.step(1.0 / 60.0, {})
	check(stop.elapsed - before < 1.0 / 60.0, "hitstop freezes the simulation clock")
	var lose = H.battle()
	lose.player.hp = 5.0
	lose.hurt_player(10.0, "x")
	lose.step(1.0 / 60.0, {})
	check(lose.state == "lost", "hp 0 ends the battle as lost")


func roam_and_mark_tests() -> void:
	var b = H.battle("shadow")
	b.pounce.charges = 0
	b.claw_timer = 99.0
	H.run_for(b, 1.4, {"move": Vector2.RIGHT})
	check(int(b.pounce.charges) == 0, "moving under 400 does not grant a charge")
	H.run_for(b, 0.25, {"move": Vector2.RIGHT})
	check(int(b.pounce.charges) == 1, "moving 400 grants a pounce charge")
	var roam = H.battle("roam")
	roam.claw_timer = 99.0
	H.run_for(roam, 1.1, {"move": Vector2.RIGHT})
	check(int(roam.pounce.charges) == 3, "roam habit: 260 per charge and one extra over the cap")
	var hunt = H.battle("hunt")
	var target: Dictionary = H.enemy(hunt, "E05", hunt.player.pos + Vector2(250, 0), 900.0)
	hunt.claw_timer = 99.0
	hunt.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	H.run_for(hunt, 0.3)
	check(target.marked and hunt.marked_id == int(target.id), "hunt habit: landing bite leaves a mark")
	var hp_before: float = target.hp
	hunt.player.pos = target.pos - Vector2(240, 0)
	hunt.claw_timer = 99.0
	hunt.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
	H.run_for(hunt, 0.3)
	check(not target.marked and hp_before - float(target.hp) >= 30.0 * 1.5 + 20.0 * 1.5 - 0.1, "second bite cashes the mark (bite and cash both +50% on the mark)")


func input_tests() -> void:
	var touch = Touch.new()
	var size := Vector2(1280, 720)
	touch.handle(_touch(0, Vector2(1000, 400), true), size)
	touch.handle(_drag(0, Vector2(1010, 405)), size)
	touch.handle(_touch(0, Vector2(1010, 405), false), size)
	check(touch.take_pounce() == Vector2.ZERO and touch.cancelled, "release inside the 24 px deadzone cancels")
	touch.handle(_touch(1, Vector2(1000, 400), true), size)
	touch.handle(_drag(1, Vector2(1100, 400)), size)
	check(touch.aiming() and touch.aim_direction() == Vector2.RIGHT, "dragging shows the pounce line")
	touch.handle(_touch(1, Vector2(1100, 400), false), size)
	check(touch.take_pounce() == Vector2.RIGHT, "release after a drag pounces that way")
	touch.handle(_touch(2, Vector2(200, 400), true), size)
	touch.handle(_drag(2, Vector2(272, 400)), size)
	check(touch.movement() == Vector2.RIGHT, "left thumb moves")
	touch.handle(_touch(3, Vector2(900, 300), true), size)
	touch.handle(_drag(2, Vector2(200, 472)), size)
	check(touch.movement() == Vector2.DOWN and touch.aim_id == 3, "each finger keeps its own role")


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	return ev


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	return ev
