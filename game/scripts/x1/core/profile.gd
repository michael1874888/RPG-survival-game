extends RefCounted
## The player's X1 profile: owned items, unlocks, records, settings and the resumable run.
## Every change goes through commit(), which writes a verified file before updating memory.

const Data := preload("res://scripts/x1/core/data.gd")
const SaveStore := preload("res://scripts/x1/core/save_store.gd")
const Progress := preload("res://scripts/x1/core/progress.gd")
const LegacyProfile := preload("res://scripts/r1_profile.gd")

const VERSION := 1
const DEFAULT_SETTINGS := {"volume": 0.7, "vibration": true, "shake": true, "low_flash": false, "controls": "medium", "assist": false}

var store
var data: Dictionary = {}
var load_failed := false
var last_error := ""
var notice := ""
var legacy_path := ""
var legacy_old_path := ""


func _init(path: String = "user://nana-x1.save", old_r1: String = "user://nana-r1.save", old_treasure: String = "user://treasure-collection.json") -> void:
	store = SaveStore.new(path, valid)
	legacy_path = old_r1
	legacy_old_path = old_treasure
	load_profile()


static func default_data() -> Dictionary:
	var region_night := {}
	for id: String in Data.shared().regions: region_night[id] = -1
	return {"version": VERSION, "owned": ["U01", "U02"], "equip": {"habit": "", "charm": ""}, "target": "",
		"unlocked": [], "progress": Progress.empty_counters(), "wins": [], "region_night": region_night,
		"history": [], "active": {}, "settings": DEFAULT_SETTINGS.duplicate(), "tutorial_done": false,
		"bell_given": false, "last_setup": {}}


static func valid(value) -> bool:
	if not value is Dictionary or int(value.get("version", 0)) != VERSION: return false
	for key: String in ["owned", "unlocked", "wins", "history"]:
		if not value.get(key) is Array: return false
	for key: String in ["equip", "progress", "region_night", "active", "settings", "last_setup"]:
		if not value.get(key) is Dictionary: return false
	if not value.get("target") is String or not value.get("tutorial_done") is bool or not value.get("bell_given") is bool: return false
	var items: Dictionary = Data.shared().items
	for id in value.owned:
		if not items.has(str(id)): return false
	for slot: String in ["habit", "charm"]:
		var selected: String = str(value.equip.get(slot, ""))
		if not selected.is_empty() and (not items.has(selected) or selected not in value.owned or items[selected].slot != slot): return false
	return true


func load_profile() -> bool:
	load_failed = false
	last_error = ""
	notice = ""
	var result: Dictionary = store.read()
	match str(result.status):
		"ok":
			data = result.data
		"recovered":
			data = result.data
			notice = "已從前一份有效存檔復原"
		"failed":
			load_failed = true
			data = default_data()
			last_error = "存檔無法讀取，原始資料已保留"
			return false
		_:
			data = default_data()
			_migrate()
	for key: String in DEFAULT_SETTINGS:
		if not data.settings.has(key): data.settings[key] = DEFAULT_SETTINGS[key]
	for id: String in Data.shared().regions:
		if not data.region_night.has(id): data.region_night[id] = -1
	return true


## First X1 launch: keep items found in v0.19 / v0.20. The old files are only read.
func _migrate() -> void:
	if not FileAccess.file_exists(legacy_path) and not FileAccess.file_exists(legacy_old_path): return
	var legacy = LegacyProfile.new(legacy_path, legacy_old_path)
	if legacy.load_failed:
		notice = "舊版收藏無法讀取，已保留原檔"
		return
	var items: Dictionary = Data.shared().items
	for id in legacy.data.get("owned", []):
		if items.has(str(id)) and str(id) not in data.owned: data.owned.append(str(id))
	if "H03" in data.owned: data.bell_given = true
	notice = "已從舊版帶回 %d 件收藏" % data.owned.size()


func commit(next: Dictionary) -> bool:
	if load_failed:
		last_error = "存檔無法讀取，不覆蓋原資料"
		return false
	if not store.write(next):
		last_error = store.last_error
		return false
	data = next.duplicate(true)
	last_error = ""
	return true


func _change(callback: Callable) -> bool:
	var next := data.duplicate(true)
	callback.call(next)
	return commit(next)


# ---- queries ---------------------------------------------------------------------------------

func region_unlocked(region_id: String) -> bool:
	var requires: String = str(Data.shared().regions[region_id].get("requires", ""))
	return requires.is_empty() or int(data.region_night.get(requires, -1)) >= 0


func max_night(region_id: String) -> int:
	return mini(int(Data.shared().night.get("max", 8)), int(data.region_night.get(region_id, -1)) + 1)


func owned(id: String) -> bool:
	return id in data.owned


func unlocked_cards() -> Array:
	return data.unlocked.duplicate()


# ---- changes ---------------------------------------------------------------------------------

func set_equip(slot: String, id: String) -> bool:
	if not id.is_empty() and (not owned(id) or Data.shared().items[id].slot != slot): return false
	return _change(func(next): next.equip[slot] = id)


func set_target(id: String) -> bool:
	if not id.is_empty() and (owned(id) or Data.shared().items.get(id, {}).get("source", "") != "chest"): return false
	return _change(func(next): next.target = id)


func set_setting(key: String, value) -> bool:
	return _change(func(next): next.settings[key] = value)


func remember_setup(setup: Dictionary) -> bool:
	return _change(func(next): next.last_setup = setup.duplicate(true))


func finish_tutorial() -> bool:
	return _change(func(next): next.tutorial_done = true)


func save_active(snapshot: Dictionary) -> bool:
	return _change(func(next): next.active = snapshot)


func clear_active() -> bool:
	return _change(func(next): next.active = {})


## Item choice from a chest: saved together with the run so it cannot be claimed twice.
func acquire_item(id: String, snapshot: Dictionary) -> bool:
	if not Data.shared().items.has(id): return false
	return _change(func(next):
		if id not in next.owned: next.owned.append(id)
		if next.target == id: next.target = ""
		if id == "H03": next.bell_given = true
		next.active = snapshot)


## Records a finished run, applies unlocks and clears the active run. Returns the unlock report.
func finish_run(summary: Dictionary) -> Dictionary:
	var report: Dictionary = Progress.apply(Data.shared(), data, summary)
	var next: Dictionary = report.profile
	next.active = {}
	next.history.append(summary.duplicate(true))
	while next.history.size() > 30: next.history.pop_front()
	if not commit(next): return {"saved": false, "unlocked": [], "near": []}
	return {"saved": true, "unlocked": report.unlocked, "near": report.near}


func best_record(region_id: String) -> Dictionary:
	var best := {}
	for entry: Dictionary in data.history:
		if entry.get("region", "") != region_id or not entry.get("won", false) or entry.get("practice", false): continue
		if best.is_empty() or int(entry.night) > int(best.night) or (int(entry.night) == int(best.night) and float(entry.time) < float(best.time)):
			best = entry
	return best
