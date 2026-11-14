extends SceneTree
## Density diagnostic with scripted targeting and TEST-ONLY invulnerability.
## Runs against current code; historical v0.8 measurements require the v0.8 code.
## Measures this controller's population, not human difficulty or enjoyment.
const Run = preload("res://scripts/run_model.gd")
func _initialize():
 for seed in [7, 11, 71]:
  for path in ["sweep", "hunt"]:
   var m = Run.new(seed, "nana", "standard", "nana_growth")
   var steps = 0
   var density_sum = 0
   var near_sum = 0
   var max_alive = 0
   var empty_frames = 0
   while m.state not in ["won", "lost"] and steps < 9000:
    if m.state == "upgrade":
     var choice: String = path if path in m.offers else m.offers[0]
     m.choose_upgrade(choice)
     continue
    var nearest: Dictionary = m.nearest_target(m.player, [])
    var direction: Vector2 = (Vector2(nearest.pos) - m.player).normalized() if not nearest.is_empty() else Vector2.RIGHT
    var movement: Vector2 = direction if not nearest.is_empty() and Vector2(nearest.pos).distance_to(m.player) > 115.0 else Vector2.ZERO
    if m.nana.cooldown == 0.0 and m.enemies.size() >= 4: m.nana.activate_ultimate(m)
    m.invulnerability = 1.0
    m.tick(1.0 / 30.0, movement, direction, not nearest.is_empty())
    steps += 1
    density_sum += m.enemies.size()
    max_alive = maxi(max_alive,m.enemies.size())
    if m.enemies.is_empty(): empty_frames += 1
    for e in m.enemies:
     if Vector2(e.pos).distance_to(m.player) <= 300.0: near_sum += 1
   print("seed=", seed, " path=", path, " state=",m.state," t=", snappedf(m.elapsed,0.1)," hp=",m.hp," level=",m.level," kills=",m.kills," elite=",m.encounters.elite_defeated," avg_alive=",snappedf(float(density_sum)/steps,0.01)," avg_near300=",snappedf(float(near_sum)/steps,0.01)," max_alive=",max_alive," empty_pct=",snappedf(100.0*empty_frames/steps,0.1))
 quit()
