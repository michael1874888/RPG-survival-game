extends SceneTree
## v0.8 spawn-only diagnostic. Immediately removes born enemies to isolate
## cadence and safety cancellation from caps, combat, health and growth.
const Run = preload("res://scripts/run_model.gd")
const ROUTE = [Vector2(500, 450), Vector2(2100, 450), Vector2(2100, 1450), Vector2(500, 1450)]
func _initialize():
 for moving in [false, true]:
  for seed in [7, 11, 71]:
   var m = Run.new(seed, "nana", "standard", "nana_growth")
   var warnings = 0
   var cancelled = 0
   var births = 0
   var waypoint = 0
   for frame in 14400:
    var dt = 1.0 / 60.0
    m.elapsed += dt
    if moving:
     if m.player.distance_to(ROUTE[waypoint]) < 10.0: waypoint = (waypoint + 1) % ROUTE.size()
     m.player = m.player.move_toward(ROUTE[waypoint], m.move_speed() * dt)
    var before: int = m.encounters.pending_spawns.size()
    var cancel_step = 0
    for item in m.encounters.pending_spawns:
     if float(item.timer) <= dt and Vector2(item.pos).distance_to(m.player) < 320.0: cancel_step += 1
    var before_id: int = m.next_enemy_id
    m.encounters.update_growth(m, dt)
    var new_births: int = m.next_enemy_id - before_id
    warnings += m.encounters.pending_spawns.size() - before + new_births + cancel_step
    cancelled += cancel_step
    births += new_births
    m.enemies.clear()
   print("SPAWN_ISOLATION moving=", moving, " seed=", seed, " warnings=", warnings, " births=", births, " cancelled=",cancelled)
 quit()
