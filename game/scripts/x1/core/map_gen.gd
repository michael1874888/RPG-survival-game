extends RefCounted
## Builds the night patrol map: 7 visible layers of 2-3 nodes, every node reachable, then the boss.

const Rng := preload("res://scripts/x1/core/rng_streams.gd")


static func generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var layer_count: int = int(cfg.layers)
	var rows: Array = []
	var nodes := {}
	var den_seen := false
	for layer in layer_count:
		var width := rng.randi_range(int(cfg.width_min), int(cfg.width_max))
		var row: Array = []
		for i in width:
			var kind: String
			if layer == 0:
				kind = str(cfg.first_layer[rng.randi_range(0, cfg.first_layer.size() - 1)])
			elif layer == layer_count - 1:
				kind = "bed" if i == 0 else str(cfg.last_layer[rng.randi_range(0, cfg.last_layer.size() - 1)])
			else:
				var weights: Dictionary = cfg.weights.duplicate()
				if layer == int(cfg.den_before_layer) - 1 and not den_seen and i == 0:
					kind = "den"
				else:
					kind = Rng.weighted(rng, weights)
			if kind == "den": den_seen = true
			var id := "L%d_%d" % [layer + 1, i]
			nodes[id] = {"id": id, "layer": layer + 1, "index": i, "kind": kind, "links": []}
			row.append(id)
		rows.append(row)
	for layer in layer_count - 1:
		var current: Array = rows[layer]
		var next: Array = rows[layer + 1]
		for i in current.size():
			var j := int(round(float(i) * (next.size() - 1) / maxf(1.0, current.size() - 1.0)))
			_link(nodes, current[i], next[j])
			var extra := j + (1 if rng.randf() < 0.5 else -1)
			if extra >= 0 and extra < next.size() and rng.randf() < 0.5: _link(nodes, current[i], next[extra])
		for j in next.size():
			var has_parent := false
			for id in current:
				if next[j] in nodes[id].links: has_parent = true
			if not has_parent:
				var i := int(round(float(j) * (current.size() - 1) / maxf(1.0, next.size() - 1.0)))
				_link(nodes, current[i], next[j])
	for id in rows[layer_count - 1]: nodes[id].links = ["boss"]
	nodes["boss"] = {"id": "boss", "layer": layer_count + 1, "index": 0, "kind": "boss", "links": []}
	for id in nodes: nodes[id].links.sort()
	return {"rows": rows, "nodes": nodes}


static func _link(nodes: Dictionary, from: String, to: String) -> void:
	if to not in nodes[from].links: nodes[from].links.append(to)
