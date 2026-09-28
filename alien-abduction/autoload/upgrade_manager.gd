extends Node
## Lädt alle UpgradeData-Resources, speichert Stufen (Upgrades, Crew, Forschung, Skills, Ruf-Shop)
## und berechnet daraus die Spielwerte (stat()).

signal upgrade_purchased(upgrade: UpgradeData, new_level: int)
signal levels_changed

const DATA_DIR := "res://data/upgrades"

## Grundwerte aller Spielwerte. Upgrades addieren/multiplizieren darauf.
const BASE_STATS := {
	&"click_power": 1.0,
	&"lift_speed": 1.0,
	&"capture_radius": 34.0,
	&"max_captures": 1.0,
	&"beam_cooldown": 0.42,
	&"ufo_speed": 7.0,
	&"crit_chance": 0.0,
	&"crit_mult": 5.0,
	&"lure_chance": 0.0,
	&"spawn_rate": 1.3,
	&"max_targets": 24.0,
	&"energy_max": 100.0,
	&"energy_regen": 2.0,
	&"credit_mult": 1.0,
	&"biomass_mult": 1.0,
	&"data_mult": 1.0,
	&"xp_mult": 1.0,
	&"golden_chance": 0.012,
	&"rare_mult": 1.0,
	&"charge_mult": 1.0,
	&"escape_chance": 0.0,
	&"target_speed": 1.0,
	&"scare_radius": 1.0,
	&"combo_bonus": 0.02,
	&"combo_cap": 50.0,
	&"combo_window": 1.6,
	&"drone_count": 0.0,
	&"drone_power": 1.0,
	&"drone_speed": 1.0,
	&"patrol_count": 0.0,
	&"laser_count": 0.0,
	&"laser_power": 12.0,
	&"beiboot_count": 0.0,
	&"flee_speed": 1.0,
	&"warn_time": 1.0,
	&"event_reward": 1.0,
	&"event_extra": 0.0,
	&"gadget_duration": 1.0,
	&"ruf_mult": 1.0,
	&"gold_reward": 1.0,
	&"golden_linger": 1.0,
	&"freeze_under_ufo": 0.0,
	&"chain_chance": 0.0,
	&"boss_damage": 1.0,
	&"event_rate": 1.0,
	&"mothership_passive": 0.0,
	&"start_credits": 0.0,
	&"start_drones": 0.0,
	&"data_per_event": 1.0,
	&"shield_radius": 110.0,
	&"auto_mothership": 0.0,
}

var upgrades: Dictionary = {}   # StringName -> UpgradeData
var levels: Dictionary = {}     # StringName -> int
var _cache: Dictionary = {}
## Temporäre/externe Multiplikatoren (Buffs, Planet): stat -> {quelle: faktor}
var _modifiers: Dictionary = {}


func _ready() -> void:
	_load_dir(DATA_DIR)


func _load_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Upgrade-Ordner fehlt: %s" % path)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		var full := path.path_join(file)
		if dir.current_is_dir():
			if not file.begins_with("."):
				_load_dir(full)
		elif file.ends_with(".tres") or file.ends_with(".tres.remap") or file.ends_with(".res"):
			var res := load(full.trim_suffix(".remap"))
			if res is UpgradeData:
				var u: UpgradeData = res
				upgrades[u.id] = u
				if not levels.has(u.id):
					levels[u.id] = 0
		file = dir.get_next()
	dir.list_dir_end()


# ---------------------------------------------------------------- Abfragen

func get_upgrade(id: StringName) -> UpgradeData:
	return upgrades.get(id)


func by_category(category: UpgradeData.Category) -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	for u: UpgradeData in upgrades.values():
		if u.category == category:
			out.append(u)
	out.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.sort_order < b.sort_order)
	return out


func level(id: StringName) -> int:
	return int(levels.get(id, 0))


func has(id: StringName) -> bool:
	return level(id) > 0


func is_maxed(u: UpgradeData) -> bool:
	return u.max_level > 0 and level(u.id) >= u.max_level


func requirements_met(u: UpgradeData) -> bool:
	for req in u.requirements:
		var parts := req.split(":")
		var need := 1 if parts.size() < 2 else int(parts[1])
		if level(StringName(parts[0])) < need:
			return false
	return true


func cost(u: UpgradeData, amount: int = 1) -> float:
	return u.cost_for(level(u.id), amount)


## amount_mode: 1, 10, 100 oder -1 für Max. Gibt die tatsächlich kaufbare Menge zurück (>= 1 für Anzeige).
func resolve_amount(u: UpgradeData, amount_mode: int) -> int:
	var remaining := u.remaining_levels(level(u.id))
	if amount_mode < 0:
		return maxi(1, mini(remaining, u.max_affordable(level(u.id), ResourceManager.get_amount(u.currency))))
	return maxi(1, mini(amount_mode, remaining))


func can_buy(u: UpgradeData, amount: int = 1) -> bool:
	if is_maxed(u) or not requirements_met(u):
		return false
	return ResourceManager.can_afford(u.currency, cost(u, amount))


func buy(id: StringName, amount: int = 1) -> bool:
	var u := get_upgrade(id)
	if u == null:
		return false
	amount = mini(amount, u.remaining_levels(level(id)))
	if amount <= 0 or not requirements_met(u):
		return false
	var price := cost(u, amount)
	if not ResourceManager.spend(u.currency, price):
		return false
	levels[id] = level(id) + amount
	_cache.clear()
	upgrade_purchased.emit(u, levels[id])
	levels_changed.emit()
	return true


func set_level(id: StringName, value: int) -> void:
	levels[id] = value
	_cache.clear()
	levels_changed.emit()


# ---------------------------------------------------------------- Werte

func stat(stat_name: StringName) -> float:
	if _cache.has(stat_name):
		return _cache[stat_name]
	var base: float = BASE_STATS.get(stat_name, 0.0)
	var add := 0.0
	var pct := 0.0
	var mult := 1.0
	for id in levels:
		var lvl: int = levels[id]
		if lvl <= 0:
			continue
		var u: UpgradeData = upgrades.get(id)
		if u == null:
			continue
		if u.effect_stat == stat_name:
			var r := _apply(u.effect_mode, u.effect_value, lvl)
			add += r.x; pct += r.y; mult *= r.z
		if u.effect2_stat == stat_name:
			var r2 := _apply(u.effect2_mode, u.effect2_value, lvl)
			add += r2.x; pct += r2.y; mult *= r2.z
	var value := (base + add) * (1.0 + pct) * mult
	var mods: Dictionary = _modifiers.get(stat_name, {})
	for source in mods:
		value *= float(mods[source])
	_cache[stat_name] = value
	return value


func flag(stat_name: StringName) -> bool:
	return stat(stat_name) > 0.0


func _apply(mode: UpgradeData.EffectMode, value: float, lvl: int) -> Vector3:
	match mode:
		UpgradeData.EffectMode.ADD:
			return Vector3(value * lvl, 0.0, 1.0)
		UpgradeData.EffectMode.PERCENT:
			return Vector3(0.0, value * lvl, 1.0)
		UpgradeData.EffectMode.MULTIPLY:
			return Vector3(0.0, 0.0, pow(value, lvl))
		_:
			return Vector3(1.0, 0.0, 1.0)


func set_modifier(stat_name: StringName, source: StringName, factor: float) -> void:
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = {}
	_modifiers[stat_name][source] = factor
	_cache.clear()


func clear_modifier(stat_name: StringName, source: StringName) -> void:
	if _modifiers.has(stat_name):
		_modifiers[stat_name].erase(source)
	_cache.clear()


func clear_all_modifiers() -> void:
	_modifiers.clear()
	_cache.clear()


# ---------------------------------------------------------------- Prestige & Speichern

func total_skill_ranks() -> int:
	var n := 0
	for u in by_category(UpgradeData.Category.SKILL):
		n += level(u.id)
	return n


func reset_for_prestige() -> void:
	for u: UpgradeData in upgrades.values():
		if u.resets_on_prestige:
			levels[u.id] = 0
	_cache.clear()
	levels_changed.emit()


func reset_all() -> void:
	for id in levels:
		levels[id] = 0
	clear_all_modifiers()
	levels_changed.emit()


func to_dict() -> Dictionary:
	var out := {}
	for id in levels:
		if levels[id] > 0:
			out[String(id)] = levels[id]
	return out


func from_dict(d: Dictionary) -> void:
	for id in levels:
		levels[id] = 0
	for key in d:
		var id := StringName(key)
		if upgrades.has(id):
			levels[id] = int(d[key])
	_cache.clear()
	levels_changed.emit()
