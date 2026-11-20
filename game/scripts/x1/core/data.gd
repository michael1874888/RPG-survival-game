extends RefCounted
## Loads every X1 table from res://data/x1/*.json and checks the references between them.
## Tuning numbers and content live in the JSON files; scripts only read them.

const SELF_PATH := "res://scripts/x1/core/data.gd"
const DIR := "res://data/x1/"
const FILES := ["tuning", "enemies", "spawns", "regions", "cards", "habits", "items", "events", "shop", "night_levels", "unlocks"]

## How each stat combines when several sources grant it.
const STATS := {
	"claw_damage_pct": "add", "claw_damage_flat": "add", "claw_angle": "add", "claw_reach_pct": "add", "claw_rate_pct": "add",
	"pounce_charges": "add", "pounce_recharge_pct": "add", "pounce_distance_pct": "add", "pounce_width": "add",
	"pounce_path_damage": "add", "pounce_knock": "add", "pounce_after_invuln": "add",
	"bite_damage_pct": "add", "bite_radius": "add", "bite_extra_targets": "add",
	"shadow_damage_pct": "add", "shadow_width_pct": "add", "shadow_echo": "add",
	"all_damage_pct": "add", "prey_damage_pct": "add", "marked_damage_pct": "add",
	"max_hp": "add", "move_speed_pct": "add", "pickup_radius": "add", "hurt_invuln_bonus": "add", "first_hit_block": "add",
	"roam_step_pct": "add", "roam_overcap": "add", "roam_step_set": "min_set",
	"ult_gain_pct": "add", "ult_duration": "add", "start_meter": "add", "rerolls": "add",
	"mark_keep": "add", "mark_transfer": "max",
}
const HOOKS := ["battle_start", "tick", "move", "claw_swing", "claw_hit", "hit", "pounce_start", "pounce_hit", "pounce_land",
	"bite_hit", "kill", "prey_kill", "hurt", "ult_start", "roam_charge"]
const ACTIONS := ["bounce_ball", "shadow_line", "shockwave", "claw_burst", "extra_claw", "heal", "refund_pounce", "meter",
	"bleed", "slow", "buff", "mark", "execute"]
const SOURCES := ["claw", "pounce", "bite", "shadow", "wind", "ball", "wave", "bleed", "ult", "cash", "burst", "execute"]
const AIS := ["chaser", "charger", "thrower", "guard", "trapper", "caller", "lantern", "warden", "stalker", "boss_tree", "boss_vine", "boss_crow"]
const ROLES := ["fodder", "hound", "special", "elite", "boss"]
const EVENT_EFFECTS := ["upgrade_random", "damage", "heal", "heal_pct", "next_battle", "fish", "card_choice", "max_hp",
	"upgrade_choice", "rerolls", "random_card", "item_choice"]
const EVENT_REQUIRES := ["upgradable", "fish", "card_room", "max_hp", "hp"]
const NEXT_BATTLE_MODS := ["extra_target", "item_reward", "full_meter", "speed_pct"]
const NIGHT_MODS := ["fodder_speed_pct", "extra_hounds", "target_escort", "bed_heal_pct", "elite_hp_pct", "pounce_recharge_add",
	"boss_phase2", "fodder_hp_pct"]
const COUNTERS := ["kills", "claw_kills", "runs", "pounce_kills", "escape_pounces", "bites", "elites", "prey_kills", "ult_uses",
	"shadow_kills", "roam_charges", "no_hit_battles", "xp", "marks", "bosses", "evolutions", "shop_buys", "moon_events"]
const NODE_KINDS := ["hunt", "den", "bed", "shop", "moon"]

static var _shared = null

var tuning: Dictionary = {}
var enemies: Dictionary = {}
var spawns: Dictionary = {}
var regions: Dictionary = {}
var categories: Dictionary = {}
var cards: Dictionary = {}          # every card and evolution by id
var card_list: Array = []           # normal cards in file order
var evolutions: Array = []
var habits: Dictionary = {}
var items: Dictionary = {}
var events: Array = []
var shop: Dictionary = {}
var night: Dictionary = {}
var unlocks: Array = []
var errors: Array[String] = []


static func shared():
	if _shared == null:
		_shared = load(SELF_PATH).new()
	return _shared


## Re-read every file (debug hot reload). Existing references keep the old copy.
static func reload_data():
	_shared = load(SELF_PATH).new()
	return _shared


static func lv(value, level: int):
	if value is Array:
		if value.is_empty(): return 0
		return value[clampi(level - 1, 0, value.size() - 1)]
	return value


static func vec(value) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size() >= 2: return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _init() -> void:
	var raw := {}
	for name: String in FILES:
		var path: String = DIR + name + ".json"
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			errors.append("無法讀取 %s" % path)
			raw[name] = {}
			continue
		var json := JSON.new()
		if json.parse(text) != OK:
			errors.append("%s 第 %d 行格式錯誤：%s" % [path, json.get_error_line(), json.get_error_message()])
			raw[name] = {}
			continue
		raw[name] = json.data if json.data is Dictionary else {}
	tuning = raw.tuning
	enemies = raw.enemies
	spawns = raw.spawns
	regions = raw.regions
	habits = raw.habits
	items = raw.items
	shop = raw.shop
	night = raw.night_levels
	events = raw.events.get("events", [])
	unlocks = raw.unlocks.get("conditions", [])
	categories = raw.cards.get("categories", {})
	card_list = raw.cards.get("cards", [])
	evolutions = raw.cards.get("evolutions", [])
	for card: Dictionary in card_list + evolutions:
		cards[str(card.get("id", ""))] = card
	validate()


func region_order() -> Array:
	var ids: Array = regions.keys()
	ids.sort_custom(func(a, b): return int(regions[a].get("order", 0)) < int(regions[b].get("order", 0)))
	return ids


func event(id: String) -> Dictionary:
	for entry: Dictionary in events:
		if entry.get("id", "") == id: return entry
	return {}


## Cumulative modifiers for a night level (0 = standard).
func night_mods(level: int) -> Dictionary:
	var mods := {}
	for entry: Dictionary in night.get("levels", []):
		if int(entry.get("level", 0)) > level: continue
		for key: String in entry.get("mods", {}):
			var value = entry.mods[key]
			if key == "boss_phase2": mods[key] = float(value)
			else: mods[key] = float(mods.get(key, 0.0)) + float(value)
	return mods


func night_desc(level: int) -> Array:
	var lines: Array = []
	for entry: Dictionary in night.get("levels", []):
		if int(entry.get("level", 0)) <= level: lines.append(str(entry.get("desc", "")))
	return lines


func _check_effects(owner: String, effects) -> void:
	if not effects is Array:
		errors.append("%s 的 effects 必須是陣列" % owner)
		return
	for effect in effects:
		if not effect is Dictionary:
			errors.append("%s 有非物件的效果" % owner)
			continue
		match str(effect.get("type", "")):
			"stat":
				if not STATS.has(str(effect.get("stat", ""))): errors.append("%s 使用未知數值 %s" % [owner, effect.get("stat", "")])
				if not effect.has("value"): errors.append("%s 的數值效果缺少 value" % owner)
			"trigger":
				if str(effect.get("hook", "")) not in HOOKS: errors.append("%s 使用未知時機 %s" % [owner, effect.get("hook", "")])
				if str(effect.get("action", "")) not in ACTIONS: errors.append("%s 使用未知動作 %s" % [owner, effect.get("action", "")])
				for source in effect.get("sources", []):
					if str(source) not in SOURCES: errors.append("%s 使用未知傷害來源 %s" % [owner, source])
				if effect.get("hook", "") == "tick" and not effect.has("interval"): errors.append("%s 的 tick 缺少 interval" % owner)
				if effect.get("hook", "") == "move" and not effect.has("every_distance"): errors.append("%s 的 move 缺少 every_distance" % owner)
				var params = effect.get("params", {})
				if not params is Dictionary: errors.append("%s 的 params 必須是物件" % owner)
				elif effect.get("action", "") == "buff" and not STATS.has(str(params.get("stat", ""))):
					errors.append("%s 的 buff 使用未知數值 %s" % [owner, params.get("stat", "")])
			_:
				errors.append("%s 有未知效果類型 %s" % [owner, effect.get("type", "")])


func validate() -> Array[String]:
	for key: String in ["world", "player", "claw", "pounce", "roam", "ult", "xp", "build", "map", "feel", "fairness", "effects"]:
		if not tuning.has(key): errors.append("tuning.json 缺少 %s" % key)
	for id: String in enemies:
		var enemy: Dictionary = enemies[id]
		if str(enemy.get("ai", "")) not in AIS: errors.append("敵人 %s 使用未知行為 %s" % [id, enemy.get("ai", "")])
		if str(enemy.get("role", "")) not in ROLES: errors.append("敵人 %s 使用未知角色 %s" % [id, enemy.get("role", "")])
		if float(enemy.get("hp", 0)) <= 0.0 or float(enemy.get("radius", 0)) <= 0.0: errors.append("敵人 %s 的生命或半徑不合理" % id)
		for key: String in ["summon"]:
			if enemy.has(key) and not enemies.has(str(enemy[key])): errors.append("敵人 %s 召喚未知敵人 %s" % [id, enemy[key]])
		for key: String in ["support1", "support2"]:
			for other in enemy.get(key, []):
				if not enemies.has(str(other)): errors.append("守關 %s 的支援 %s 不存在" % [id, other])
	for kind: String in ["hunt", "den", "boss", "practice"]:
		if not spawns.has(kind): errors.append("spawns.json 缺少 %s" % kind)
		else:
			var fodder: Dictionary = spawns[kind].get("fodder", {})
			if not enemies.has(str(fodder.get("kind", ""))): errors.append("spawns.%s 的雜兵種類不存在" % kind)
	for id: String in regions:
		var region: Dictionary = regions[id]
		for list_key: String in ["specials", "targets", "elites"]:
			for enemy_id in region.get(list_key, []):
				if not enemies.has(str(enemy_id)): errors.append("區域 %s 的 %s 引用不存在的敵人 %s" % [id, list_key, enemy_id])
		var boss: String = str(region.get("boss", ""))
		if not enemies.has(boss) or enemies[boss].get("role", "") != "boss": errors.append("區域 %s 的守關 %s 不存在" % [id, boss])
		var requires: String = str(region.get("requires", ""))
		if not requires.is_empty() and not regions.has(requires): errors.append("區域 %s 需要不存在的區域 %s" % [id, requires])
		for item_id in region.get("chest_pool", []):
			if not items.has(str(item_id)): errors.append("區域 %s 的寶箱物品 %s 不存在" % [id, item_id])
		for obstacle in region.get("obstacles", []):
			if not (obstacle is Dictionary and (obstacle.has("rect") or obstacle.has("circle"))): errors.append("區域 %s 有格式錯誤的障礙" % id)
	var seen := {}
	for card: Dictionary in card_list + evolutions:
		var id: String = str(card.get("id", ""))
		if id.is_empty() or seen.has(id): errors.append("卡片 ID 空白或重複：%s" % id)
		seen[id] = true
		if not categories.has(str(card.get("category", ""))): errors.append("卡片 %s 的類別不存在" % id)
		_check_effects("卡片 " + id, card.get("effects", []))
	for card: Dictionary in card_list:
		if str(card.get("rarity", "")) not in ["common", "rare"]: errors.append("卡片 %s 的稀有度不合理" % card.get("id", ""))
		if not card.get("desc", []) is Array or card.desc.size() != int(tuning.get("build", {}).get("max_level", 3)):
			errors.append("卡片 %s 的說明數量要等於等級上限" % card.get("id", ""))
	for evolution: Dictionary in evolutions:
		var requires: Array = evolution.get("requires", [])
		if requires.size() != 2: errors.append("進化 %s 需要剛好兩張卡" % evolution.get("id", ""))
		for card_id in requires:
			if not cards.has(str(card_id)) or str(card_id).begins_with("EV"): errors.append("進化 %s 需要不存在的卡 %s" % [evolution.get("id", ""), card_id])
	for id: String in habits:
		_check_effects("習性 " + id, habits[id].get("effects", []))
		for category in habits[id].get("bias", []):
			if not categories.has(str(category)): errors.append("習性 %s 偏向不存在的類別 %s" % [id, category])
	for id: String in items:
		var item: Dictionary = items[id]
		_check_effects("寶物 " + id, item.get("effects", []))
		if str(item.get("slot", "")) not in ["habit", "charm"]: errors.append("寶物 %s 的格位不合理" % id)
		if item.get("slot", "") == "habit" and not habits.has(str(item.get("habit", ""))): errors.append("寶物 %s 對應不存在的習性" % id)
	for entry: Dictionary in events:
		for region_id in entry.get("regions", []):
			if not regions.has(str(region_id)): errors.append("事件 %s 引用不存在的區域 %s" % [entry.get("id", ""), region_id])
		if entry.get("options", []).size() < 2: errors.append("事件 %s 至少要有兩個選項" % entry.get("id", ""))
		for option: Dictionary in entry.get("options", []):
			for key: String in option.get("requires", {}):
				if key not in EVENT_REQUIRES: errors.append("事件 %s 使用未知條件 %s" % [entry.get("id", ""), key])
			for effect: Dictionary in option.get("effects", []):
				if str(effect.get("type", "")) not in EVENT_EFFECTS: errors.append("事件 %s 使用未知效果 %s" % [entry.get("id", ""), effect.get("type", "")])
				if effect.get("type", "") == "next_battle" and str(effect.get("mod", "")) not in NEXT_BATTLE_MODS:
					errors.append("事件 %s 使用未知下一場修正 %s" % [entry.get("id", ""), effect.get("mod", "")])
	for entry: Dictionary in night.get("levels", []):
		for key: String in entry.get("mods", {}):
			if key not in NIGHT_MODS: errors.append("夜深 %s 使用未知修正 %s" % [entry.get("level", "?"), key])
	var unlock_targets := {}
	for condition: Dictionary in unlocks:
		var target: String = str(condition.get("unlock", ""))
		if not cards.has(target) and not items.has(target): errors.append("解鎖條件 %s 指向不存在的 %s" % [condition.get("id", ""), target])
		unlock_targets[target] = true
		match str(condition.get("type", "")):
			"counter":
				if str(condition.get("counter", "")) not in COUNTERS: errors.append("解鎖條件 %s 使用未知計數 %s" % [condition.get("id", ""), condition.get("counter", "")])
			"win":
				if condition.has("habit") and not habits.has(str(condition.habit)): errors.append("解鎖條件 %s 的習性不存在" % condition.get("id", ""))
				if condition.has("region") and not regions.has(str(condition.region)): errors.append("解鎖條件 %s 的區域不存在" % condition.get("id", ""))
			_:
				errors.append("解鎖條件 %s 的類型不存在" % condition.get("id", ""))
	for card: Dictionary in card_list:
		if not bool(card.get("starter", false)) and not unlock_targets.has(str(card.id)):
			errors.append("卡片 %s 不是起始卡，卻沒有解鎖條件" % card.id)
	for id: String in items:
		if items[id].get("source", "") == "unlock" and not unlock_targets.has(id):
			errors.append("寶物 %s 標為解鎖取得，卻沒有解鎖條件" % id)
	return errors


## Drop the shared copy (tests call this before quitting).
static func release() -> void:
	_shared = null
