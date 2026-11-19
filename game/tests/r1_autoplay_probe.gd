extends SceneTree
## Deterministic developer probe: no invulnerability, but instantaneous aim and
## menu choices, always the safer route, and skipped chest/event rewards.
## Results are not human completion rates, player enjoyment, or mobile timings.
const Run = preload("res://scripts/run_model.gd")
const Expedition = preload("res://scripts/r1_expedition.gd")

func _initialize():
 for opening in ["a", "b", "c"]:
  var run = Run.new()
  var ex = Expedition.new()
  ex.begin(run, opening, 91273, "", "", false)
  var step = 0
  var frames_in_node = 0
  var recorded = []
  var total_battle_seconds = 0.0
  while ex.phase != "result" and step < 108000:
   if run.state == "upgrade":
    var id = str(run.offers[0])
    if id in ["a", "b", "c"] and int(run.growth.levels.get(id, 0)) == 2:
     id = {"a":"a_wide", "b":"b_double", "c":"c_hold"}[id]
    run.choose_upgrade(id)
   elif ex.phase == "battle" and run.state in ["lost", "won"]:
    recorded.append("%d:%.0fs hp%.0f" % [ex.node, run.elapsed, run.hp])
    total_battle_seconds += run.elapsed
    ex.finish_node(run)
   elif ex.phase == "battle":
    var nearest = {}
    var near_d = INF
    var nearby = 0
    for e in run.enemies:
     if float(e.hp) <= 0: continue
     var d = run.player.distance_to(e.pos)
     if d < 230.0: nearby += 1
     if d < near_d: nearest = e; near_d = d
    var aim = Vector2.RIGHT
    var movement = Vector2.ZERO
    var fire = not nearest.is_empty()
    if not nearest.is_empty():
     aim = (Vector2(nearest.pos) - run.player).normalized()
     movement = aim if near_d > 140 else (-aim if near_d < 90 else aim.orthogonal())
    if opening == "b" and run.nana.movement_charge < run.growth.charge_cost() and frames_in_node % 160 < 75:
     fire = false
     if movement == Vector2.ZERO: movement = Vector2.UP
    if nearby >= 3 and run.nana.cooldown <= 0: run.nana.activate_ultimate(run)
    run.tick(1.0/30.0, movement, aim, fire)
    frames_in_node += 1
   elif ex.phase in ["chest", "chest_event", "event_common", "event_supply"]:
    ex.advance_pending()
   elif ex.phase == "camp":
    var routes = ex.choose_routes(run)
    ex.select_route(routes[0])
   elif ex.phase == "between":
    ex.next_node(run)
    frames_in_node = 0
   else:
    print("ERROR unexpected phase ", ex.phase)
    break
   step += 1
  print("AI_PROBE ", opening, " ", recorded, " combat_seconds=", snappedf(total_battle_seconds, 0.1), " outcome=", ("won" if ex.won else "not won"), " steps=", step)
 quit()
