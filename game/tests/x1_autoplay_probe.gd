extends SceneTree
## Developer probe: whole runs with the scripted bot. Instant reactions, perfect warning reads,
## no menu time. Numbers describe the rules and pacing, NOT human win rates or fun.
## Usage: Godot --headless --path game --script res://tests/x1_autoplay_probe.gd [-- seeds=3 night=0 region=all]

const Run := preload("res://scripts/x1/core/run.gd")
const Bot := preload("res://tests/x1_bot.gd")
const Data := preload("res://scripts/x1/core/data.gd")


func _initialize() -> void:
	var seeds := 3
	var nights := [0, 4]
	var regions: Array = ["courtyard", "greenhouse", "belltower"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="): seeds = int(arg.split("=")[1])
		if arg.begins_with("night="): nights = [int(arg.split("=")[1])]
		if arg.begins_with("region=") and arg.split("=")[1] != "all": regions = [arg.split("=")[1]]
	var data = Data.shared()
	var unlocked_all: Array = []
	for card: Dictionary in data.card_list:
		if not card.starter: unlocked_all.append(card.id)
	for region in regions:
		for night in nights:
			for habit in ["shadow", "roam", "hunt"]:
				for s in seeds:
					_run_one(region, night, habit, 1000 + s * 17 + night, unlocked_all if s % 2 == 1 else [])
	quit()


func _run_one(region: String, night: int, habit: String, seed_value: int, unlocked: Array) -> void:
	var run = Run.new()
	run.begin({"seed": seed_value, "region": region, "habit": habit, "night": night, "unlocked": unlocked, "owned": ["U01", "U02"]})
	var bot = Bot.new()
	var durations := {"hunt": [], "den": [], "boss": []}
	var ult_per_battle: Array = []
	var guard := 0
	var real_start := Time.get_ticks_msec()
	while run.phase != "result" and guard < 200000:
		guard += 1
		if run.phase == "battle":
			if run.needs_level_choice():
				run.choose_card(bot.pick_card(run))
				continue
			var b = run.battle
			var kind: String = run.node_kind
			var ended: bool = run.tick(1.0 / 60.0, bot.battle_input(b, 1.0 / 60.0))
			b.take_events()
			if ended:
				durations[kind].append(snappedf(b.elapsed, 0.1))
				ult_per_battle.append(int(b.metrics.ult_uses))
		elif not bot.handle_phase(run):
			print("stuck in phase ", run.phase)
			break
	var s: Dictionary = run.summary()
	var avg := func(list: Array) -> float:
		var total := 0.0
		for v in list: total += float(v)
		return total / maxf(1.0, list.size())
	var battle_time := 0.0
	for kind in durations:
		for v in durations[kind]: battle_time += float(v)
	print("%-10s n%d %-6s seed%-5d %s layer%d lvl%2d battle=%3.0fs hunt=%s den=%s boss=%s ult/battle=%.1f esc=%d evo=%d hp=%.0f last=%s cards=%s (%.1fs real)" % [
		region, night, habit, seed_value, "WIN " if s.won else "LOSS", s.layer, s.level, battle_time,
		str(durations.hunt), str(durations.den), str(durations.boss), avg.call(ult_per_battle), int(s.metrics.escape_pounces),
		int(s.metrics.evolutions), run.hp, s.last_hurt, ",".join(s.cards.map(func(c): return "%s%d" % [c.id, c.level])),
		(Time.get_ticks_msec() - real_start) / 1000.0])
