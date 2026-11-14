extends SceneTree
## Historical v0.7 comparison: run against v0.7 scripts to reproduce the recorded result.
## Running against a later project measures that version instead.
## Resets positions to exclude knockback; excludes later vulnerability benefits.
const Run = preload("res://scripts/run_model.gd")
func _initialize():
 for count in [1, 3, 6]:
  for path in ["sweep", "hunt"]:
   var run = Run.new(10, "nana")
   run.player = Vector2(500, 500)
   run.aim = Vector2.RIGHT
   run.upgrades[path] = 1
   for i in count:
    run.encounters.add_enemy(run, "chaser", run.player + Vector2.RIGHT.rotated((i-float(count-1)/2)*0.1)*100.0)
    run.enemies.back().hp = 10000.0
   for attack in 4:
    for i in count:
     run.enemies[i].pos = run.player + Vector2.RIGHT.rotated((i-float(count-1)/2)*0.1)*100.0
    run.nana.attack(run)
    run.nana.advance(run, 0.11)
   var damage = 0.0
   for e in run.enemies: damage += 10000.0 - float(e.hp)
   print("ONE_CYCLE targets=",count," spec=",path," total_damage=",damage)
 quit()
