extends Node
## Globaler Spielzustand: Belohnungen, Combo, Level, Mutterschiff, Buffs & Gadgets,
## Erfolge, Freischaltungen, Planeten/Regionen/Prestige, Sitzungs-Zusammenfassung, Speichern.
## Kein Offline-Fortschritt: Credits, Entführungen und Ressourcen gibt es nur bei geöffnetem Spiel.
## Kommunikation läuft über Signale – Szenen hängen sich nur an.

# ---------------------------------------------------------------- Signale
signal target_abducted(data: TargetData, rewards: Dictionary, world_pos: Vector2, source: StringName)
signal combo_changed(combo: int, multiplier: float)
signal mothership_changed(charge: float, goal: float)
signal mothership_ready
signal xp_changed(xp: float, needed: float, level: int)
signal level_up(level: int)
signal achievement_unlocked(achievement: AchievementData)
signal feature_unlocked(feature: StringName)
signal toast(text: String, icon: Texture2D, color: Color)
signal banner(text: String, color: Color, duration: float)
signal crew_comment(speaker: StringName, text: String)
signal buff_changed(id: StringName, remaining: float, duration: float)
signal gadget_used(id: StringName)
signal planet_changed(planet: PlanetData)
signal prestige_requested(planet: PlanetData)
signal region_changed(region: RegionData)
signal region_mapped(region: RegionData)
signal game_reset
signal floating_text_requested(world_pos: Vector2, text: String, color: Color, size: int)
signal effect_requested(kind: StringName, world_pos: Vector2, color: Color)
signal shake_requested(amount: float)
signal cosmetics_changed
signal settings_changed
@warning_ignore("unused_signal")
signal news_requested(headline: String, duration: float)
@warning_ignore("unused_signal")
signal event_announced(id: StringName, title: String)

# ---------------------------------------------------------------- Konstanten
const TARGET_DIR := "res://data/targets"
const PLANET_DIR := "res://data/planets"
const ACHIEVEMENT_DIR := "res://data/achievements"
const AUTOSAVE_SECONDS := 15.0
## Belohnungsbonus für Ziele, die auf der Flucht erwischt werden
const FLEE_BONUS := 1.25
## Ab so vielen Sekunden Abwesenheit erscheint beim Start die Zusammenfassung
const WELCOME_AFTER_SECONDS := 60.0
const CREW_IDS: Array[StringName] = [&"zorg", &"blib", &"xul", &"glorp", &"quix"]

const GADGETS: Array[Dictionary] = [
	{"id": &"overload", "name": "Überladung", "desc": "Doppelte Saugkraft & fast kein Abklingen", "cost": 40.0, "duration": 10.0, "cooldown": 25.0, "icon": "res://assets/icons/charge.png", "requires": &"unlock_gadgets"},
	{"id": &"slowmo", "name": "Zeitlupe", "desc": "Alle Ziele bewegen sich in Zeitlupe", "cost": 30.0, "duration": 8.0, "cooldown": 25.0, "icon": "res://assets/icons/clock.png", "requires": &"unlock_gadgets"},
	{"id": &"gold_rush", "name": "Goldrausch", "desc": "Viel mehr goldene Ziele", "cost": 60.0, "duration": 12.0, "cooldown": 45.0, "icon": "res://assets/icons/star.png", "requires": &"unlock_gadgets"},
	{"id": &"double", "name": "Zielverdopplung", "desc": "Sofort eine Welle neuer Ziele", "cost": 50.0, "duration": 0.0, "cooldown": 30.0, "icon": "res://assets/icons/double.png", "requires": &"unlock_gadgets2"},
	{"id": &"instant_charge", "name": "Sofortaufladung", "desc": "+35 % Mutterschiff-Ladung", "cost": 80.0, "duration": 0.0, "cooldown": 60.0, "icon": "res://assets/icons/energy.png", "requires": &"unlock_gadgets2"},
]

const COSMETICS := {
	&"skin_classic": {"type": "skin", "sprite": "res://assets/sprites/ufo_classic.png"},
	&"skin_rusty": {"type": "skin", "sprite": "res://assets/sprites/ufo_rusty.png"},
	&"skin_disco": {"type": "skin", "sprite": "res://assets/sprites/ufo_disco.png"},
	&"skin_cow": {"type": "skin", "sprite": "res://assets/sprites/ufo_cow.png"},
	&"skin_gold": {"type": "skin", "sprite": "res://assets/sprites/ufo_gold.png"},
	&"beam_green": {"type": "beam", "color": Color(0.45, 1.0, 0.55)},
	&"beam_pink": {"type": "beam", "color": Color(1.0, 0.45, 0.8)},
	&"beam_blue": {"type": "beam", "color": Color(0.35, 0.75, 1.0)},
	&"beam_gold": {"type": "beam", "color": Color(1.0, 0.85, 0.3)},
	&"beam_rainbow": {"type": "beam", "color": Color(1, 1, 1), "rainbow": true},
	# Belohnungen aus Erfolgen ("achievement" = freischaltender Erfolg, "tint" = Einfärbung des Basis-Sprites)
	&"skin_neon": {"type": "skin", "name": "UFO: Neon", "sprite": "res://assets/sprites/ufo_classic.png", "tint": Color(0.6, 1.6, 1.5), "achievement": &"panic50"},
	&"skin_ghost": {"type": "skin", "name": "UFO: Geisterschiff", "sprite": "res://assets/sprites/ufo_classic.png", "tint": Color(0.85, 0.95, 1.3, 0.55), "achievement": &"clean40"},
	&"skin_news": {"type": "skin", "name": "UFO: Übertragungswagen", "sprite": "res://assets/sprites/ufo_rusty.png", "tint": Color(1.5, 0.7, 0.7), "achievement": &"news5"},
	&"skin_map": {"type": "skin", "name": "UFO: Kartenlook", "sprite": "res://assets/sprites/ufo_cow.png", "tint": Color(0.95, 0.85, 0.55), "achievement": &"mapper1"},
	&"skin_sun": {"type": "skin", "name": "UFO: Sonnenbrand", "sprite": "res://assets/sprites/ufo_gold.png", "tint": Color(1.6, 0.8, 0.4), "achievement": &"sunskin"},
	&"beam_void": {"type": "beam", "name": "Strahl: Leere-Violett", "color": Color(0.55, 0.3, 1.0), "achievement": &"sweep1"},
	&"beam_sparkle": {"type": "beam", "name": "Strahl: Glitzer", "color": Color(1.0, 0.95, 0.7), "achievement": &"goldlast"},
	&"beam_milk": {"type": "beam", "name": "Strahl: Milch", "color": Color(0.97, 0.97, 1.0), "achievement": &"cowcombo20"},
	&"beam_dna": {"type": "beam", "name": "Strahl: DNA-Lila", "color": Color(0.85, 0.4, 1.0), "achievement": &"species1"},
}

const SPEAKERS := {
	&"computer": {"name": "Bordcomputer", "icon": "res://assets/icons/data.png"},
	&"zorg": {"name": "Zorg", "icon": "res://assets/icons/crew_zorg.png"},
	&"blib": {"name": "Blib", "icon": "res://assets/icons/crew_blib.png"},
	&"xul": {"name": "Mama Xul", "icon": "res://assets/icons/crew_xul.png"},
	&"glorp": {"name": "Glorp", "icon": "res://assets/icons/crew_glorp.png"},
	&"quix": {"name": "Quix", "icon": "res://assets/icons/crew_quix.png"},
}

const CREW_LINES := {
	&"start": ["Bordcomputer online. Mission: Kühe. Und Menschen. Hauptsächlich Kühe.", "Willkommen an Bord! Klick auf alles, was sich bewegt."],
	&"idle": [
		"Offiziell ist das hier eine Verkehrszählung.",
		"Wenn jemand fragt: Wir sind ein Wetterballon.",
		"Die Kühe haben angefangen. Ehrlich.",
		"Laut Protokoll sind das 'freiwillige Austauschschüler'.",
		"Ich hab dem Chef gesagt, wir machen nur Fotos.",
		"Offiziell: kosmische Volkszählung. Inoffiziell: Hunger.",
		"Wir geben sie zurück. Irgendwann. Vielleicht.",
		"Falls die Erde anruft: Wir sind nicht da.",
		"Kurzer Reminder: Menschen NICHT füttern.",
		"Ich schwöre, die eine Kuh hat mir zugezwinkert.",
	],
	&"golden": ["Da! Eine GOLDENE Kuh! Schnell!", "Gold! Das gibt Bonuspunkte beim Chef!", "Glitzer-Alarm! Glitzer-Alarm!"],
	&"level_up": ["Level up! Der Chef ist fast beeindruckt.", "Neuer Rang! Wir kriegen bald ein zweites Getränkefach."],
	&"mothership": ["Mama ist da! Alle festhalten!", "Das Mutterschiff! Sieht aus wie ein fliegender Parkplatz.", "Massenbeam! Niemand bleibt zurück!"],
	&"boss": ["Das ist... eine sehr große Kuh.", "Ich glaube, der Strahl braucht Verstärkung.", "Die Kuh ist größer als unser Schiff?!"],
	&"escape": ["Der hatte eine Fitnessstudio-Mitgliedschaft.", "Rutschige Hände, sorry!", "Dem geben wir einen Freiflug-Gutschein."],
	&"military": ["Militär! Tu so, als wärst du ein Flugzeug!", "Die haben Jeeps. Wir haben Laser. Nur so als Info."],
	&"prestige": ["Planet eingepackt. Der Nächste bitte!", "Die Erde war nett. Aber hast du DEN Planeten gesehen?"],
	&"purchase": ["Neues Spielzeug!", "Das bauen wir sofort ein.", "Ich hab die Anleitung verloren, aber das klappt schon.", "Blib sagt, das wird funktionieren. Wahrscheinlich."],
	&"achievement": ["Ein Erfolg! Ich rahme das ein.", "Sieh an, du bist gut darin. Beunruhigend gut."],
	&"news": ["Wir sind im Fernsehen! Winke!", "Die Menschen haben uns bemerkt. Mist."],
	&"sun": ["BITTE NICHT DIE SONNE!", "Wer hat 'Sonne' ins Zielsystem eingetippt?!"],
	&"welcome": ["Da bist du ja! Wir haben brav gewartet – ohne dich rührt hier keiner einen Strahl.", "Willkommen zurück! Die Drohnen haben nur Karten gespielt."],
	&"pause": ["Kaffeepause! Keiner saugt, keiner flieht.", "Pause. Zorg poliert solange die Scheiben."],
	&"resupply": ["Nachschub! Da kommen neue Ahnungslose.", "Sie schicken einfach mehr Leute. Perfekt.", "Frische Ziele im Anflug!"],
	&"flee": ["Da haut einer ab! Hinterher!", "Achtung, das seltene Ziel will fliehen!"],
	&"region": ["Neue Gegend, neue Opfer.", "Laut Karte sind wir richtig. Glaube ich."],
	&"robot": ["KLONK. Der Strahl ist zu schwach für den Blechkasten.", "Roboter! Mehr Saugkraft!"],
}

# ---------------------------------------------------------------- Zustand
var targets: Dictionary = {}          # StringName -> TargetData
var planets: Array[PlanetData] = []
var achievements: Array[AchievementData] = []
var current_planet: PlanetData

var stats: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var features: Dictionary = {}
var xp: float = 0.0
var level: int = 1
var combo: int = 0
var combo_timer: float = 0.0
var mothership_charge: float = 0.0
var mothership_calls: int = 0      # in diesem Durchlauf
var prestige_count: int = 0
var event_running: bool = false
var buffs: Dictionary = {}         # id -> {"remaining", "duration"}
var gadget_cooldowns: Dictionary = {}
var settings: Dictionary = {
	"master_volume": 0.8, "sfx_volume": 1.0, "music_volume": 0.5,
	"screenshake": true, "particles": true,
	"skin": "skin_classic", "beam": "beam_green",
}
var current_region: RegionData
## Zusammenfassung des letzten Spielstands – wird beim erneuten Öffnen angezeigt (kein Offline-Fortschritt)
var welcome_summary: Dictionary = {}
var auto_cps: float = 0.0
var auto_bps: float = 0.0
var cps: float = 0.0

var _income_window: Array = []     # [credits, auto_credits, auto_bio] pro Sekunde
var _income_now: Vector3 = Vector3.ZERO
var _second_timer: float = 0.0
var _autosave_timer: float = 0.0
var _idle_comment_timer: float = 40.0
var _loading: bool = false
# Erfolgs-Tracking
var _abduction_times: Array[float] = []   # Zeitstempel (s) für "Massenpanik"
var _clean_combo: int = 0                 # Combo ohne Fehlschuss
var _combo_cows: int = 0                  # Kühe in der aktuellen Combo
# Sitzung (für die Zusammenfassung beim nächsten Start)
var _session_time: float = 0.0
var _session_start_abductions: float = 0.0
var _session_start_credits: float = 0.0
var _session_best_combo: int = 0
var _session_achievements: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_targets()
	_load_planets()
	_load_achievements()
	get_tree().set_auto_accept_quit(false)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	ResourceManager.resource_changed.connect(func(_t: StringName, _a: float, _d: float) -> void: _check_features())
	_reset_state()
	load_game()
	_start_session()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


# ---------------------------------------------------------------- Daten laden

func _load_targets() -> void:
	for res in _load_resources(TARGET_DIR):
		if res is TargetData:
			targets[(res as TargetData).id] = res


func _load_planets() -> void:
	for res in _load_resources(PLANET_DIR):
		if res is PlanetData:
			planets.append(res)
	planets.sort_custom(func(a: PlanetData, b: PlanetData) -> bool: return a.order < b.order)


func _load_achievements() -> void:
	for res in _load_resources(ACHIEVEMENT_DIR):
		if res is AchievementData:
			achievements.append(res)
	achievements.sort_custom(func(a: AchievementData, b: AchievementData) -> bool: return a.sort_order < b.sort_order)


func _load_resources(path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			var res := load(path.path_join(file.trim_suffix(".remap")))
			if res:
				out.append(res)
	return out


func get_target(id: StringName) -> TargetData:
	return targets.get(id)


func get_planet(id: StringName) -> PlanetData:
	for p in planets:
		if p.id == id:
			return p
	return planets[0] if not planets.is_empty() else null


# ---------------------------------------------------------------- Hauptschleife

func _process(delta: float) -> void:
	# Pausiert: kein Fortschritt, keine Automatisierung, keine ablaufenden Timer
	if get_tree().paused:
		return
	_session_time += delta
	_process_combo(delta)
	_process_buffs(delta)
	for id in gadget_cooldowns.keys():
		gadget_cooldowns[id] = maxf(0.0, float(gadget_cooldowns[id]) - delta)
	# passive Mutterschiff-Ladung (Beiboote)
	var passive := UpgradeManager.stat(&"mothership_passive")
	if passive > 0.0 and not event_running:
		add_mothership_charge(passive * delta)
	_second_timer += delta
	if _second_timer >= 1.0:
		_second_timer -= 1.0
		_tick_second()
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SECONDS:
		_autosave_timer = 0.0
		save_game()
	_idle_comment_timer -= delta
	if _idle_comment_timer <= 0.0:
		_idle_comment_timer = randf_range(45.0, 90.0)
		comment(&"idle")


func _tick_second() -> void:
	_income_window.append(_income_now)
	_income_now = Vector3.ZERO
	if _income_window.size() > 10:
		_income_window.pop_front()
	var sum := Vector3.ZERO
	for v: Vector3 in _income_window:
		sum += v
	var n := float(maxi(1, _income_window.size()))
	cps = sum.x / n
	auto_cps = sum.y / n
	auto_bps = sum.z / n
	stats["play_time"] = get_stat(&"play_time") + 1.0
	_check_achievements()
	_check_features()


# ---------------------------------------------------------------- Entführungen

## Zentrale Belohnungsberechnung. source: player, drone, patrol, laser, beiboot, mothership, helper
## context: Zusatzinfos vom Ziel (BaseTarget.capture_context) – fleeing, dodging, close_call, trajectory, mistake, last_moment
func register_abduction(data: TargetData, world_pos: Vector2, source: StringName, reward_mult: float = 1.0, context: Dictionary = {}) -> Dictionary:
	var is_player := source == &"player"
	var is_auto := source in [&"drone", &"patrol", &"laser", &"beiboot", &"helper"]
	var mult := credit_multiplier() * reward_mult
	var crit := false
	# Fliehende Ziele geben einen kleinen Timing-Bonus
	var flee_bonus: bool = context.get("fleeing", false) and source != &"mothership"
	if flee_bonus:
		mult *= FLEE_BONUS
	if (is_player or source == &"drone" or source == &"patrol") and randf() < UpgradeManager.stat(&"crit_chance"):
		crit = true
		mult *= UpgradeManager.stat(&"crit_mult")
	if is_player:
		combo += 1
		combo_timer = UpgradeManager.stat(&"combo_window")
		stats["best_combo"] = maxf(get_stat(&"best_combo"), combo)
		mult *= combo_multiplier()
		combo_changed.emit(combo, combo_multiplier())
	if source == &"mothership":
		mult *= 3.0 * UpgradeManager.stat(&"event_reward")
	if data.is_golden:
		mult *= UpgradeManager.stat(&"gold_reward")
	var rewards := {
		"credits": data.credits * mult,
		"biomass": data.biomass * UpgradeManager.stat(&"biomass_mult") * reward_mult * (2.0 if crit else 1.0),
		"data": data.alien_data * UpgradeManager.stat(&"data_mult"),
		"xp": data.xp * UpgradeManager.stat(&"xp_mult"),
		"crit": crit,
		"combo": combo if is_player else 0,
		"lure": randf() < UpgradeManager.stat(&"lure_chance"),
		"flee_bonus": flee_bonus,
	}
	if randf() < data.data_chance * UpgradeManager.stat(&"data_mult"):
		rewards["data"] = float(rewards["data"]) + 1.0
	rewards["data"] = floor(float(rewards["data"]))
	ResourceManager.add(ResourceManager.CREDITS, rewards["credits"])
	ResourceManager.add(ResourceManager.BIOMASS, rewards["biomass"])
	ResourceManager.add(ResourceManager.DATA, rewards["data"])
	add_xp(rewards["xp"])
	if source != &"mothership":
		add_mothership_charge(data.mothership_charge * UpgradeManager.stat(&"charge_mult"))
	# Statistik
	_income_now.x += rewards["credits"]
	if is_auto:
		_income_now.y += rewards["credits"]
		_income_now.z += rewards["biomass"]
	_inc(&"abductions")
	_inc(StringName("abducted_" + String(data.id)))
	if is_player:
		_inc(&"player_abductions")
	if data.is_golden:
		_inc(&"golden")
	if data.is_boss:
		_inc(&"boss_kills")
	if crit:
		_inc(&"crits")
	_track_abduction(data, source, context)
	if get_stat(StringName("abducted_" + String(data.id))) == 1.0 and not data.abduct_lines.is_empty():
		crew_comment.emit(_speaker(), data.abduct_lines.pick_random())
	target_abducted.emit(data, rewards, world_pos, source)
	return rewards


## Statistiken für Erfolge und Kartografie
func _track_abduction(data: TargetData, source: StringName, context: Dictionary) -> void:
	var is_player := source == &"player"
	_inc(StringName("kind_" + String(TargetData.Kind.keys()[data.kind]).to_lower()))
	# Massenpanik: Entführungen der letzten 30 Sekunden (ohne Mutterschiff-Event)
	if source != &"mothership":
		var now := Time.get_ticks_msec() / 1000.0
		_abduction_times.append(now)
		while not _abduction_times.is_empty() and now - _abduction_times[0] > 30.0:
			_abduction_times.pop_front()
		stats["best_30s"] = maxf(get_stat(&"best_30s"), _abduction_times.size())
	if is_player:
		_clean_combo += 1
		stats["best_clean_combo"] = maxf(get_stat(&"best_clean_combo"), _clean_combo)
		_session_best_combo = maxi(_session_best_combo, combo)
		if _is_cow(data):
			_combo_cows += 1
			stats["best_cow_combo"] = maxf(get_stat(&"best_cow_combo"), _combo_cows)
	if _is_cow(data) and has_buff(&"news"):
		_inc(&"news_cows")
	if context.get("fleeing", false):
		_inc(&"flee_catches")
	if context.get("dodging", false):
		_inc(&"dodge_catches")
	if context.get("close_call", false):
		_inc(&"close_calls")
	if context.get("trajectory", false):
		_inc(&"physics_catches")
	if context.get("mistake", false):
		_inc(&"mistake_catches")
	if data.is_golden and context.get("last_moment", false):
		_inc(&"gold_last_moment")
	# Kartografie der aktuellen Region
	if current_region and source != &"mothership":
		var key := _map_key(current_planet, current_region)
		var before := get_stat(key)
		if before < current_region.map_goal:
			stats[key] = before + 1.0
			if before + 1.0 >= current_region.map_goal:
				_on_region_mapped(current_region)


func _is_cow(data: TargetData) -> bool:
	return data.kind == TargetData.Kind.ANIMAL and String(data.id).contains("cow")


func credit_multiplier() -> float:
	var m := UpgradeManager.stat(&"credit_mult")
	m *= 1.0 + achievement_bonus()
	m *= 1.0 + 0.1 * ResourceManager.lifetime_total(ResourceManager.RUF)
	m *= 1.0 + 0.1 * mothership_calls
	if current_planet:
		m *= current_planet.credit_multiplier
	# dünn besiedelte Regionen sind wertvoller
	if current_region:
		m *= current_region.value_multiplier
	return m


func achievement_bonus() -> float:
	var b := 0.0
	for a in achievements:
		if unlocked_achievements.has(a.id):
			b += a.bonus
	if UpgradeManager.has(&"sk_compound"):
		b *= 2.0
	return b


func combo_multiplier() -> float:
	return 1.0 + minf(combo, UpgradeManager.stat(&"combo_cap")) * UpgradeManager.stat(&"combo_bonus")


func _process_combo(delta: float) -> void:
	if combo <= 0:
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0
		_clean_combo = 0
		_combo_cows = 0
		combo_changed.emit(0, 1.0)


func register_escape(world_pos: Vector2) -> void:
	_inc(&"escapes")
	if randf() < 0.4:
		comment(&"escape")
	floating_text_requested.emit(world_pos, ["Nope!", "Heute nicht!", "Tschüss!", "Hilfe!!", "Muuh-nein!"].pick_random(), Color(1, 0.6, 0.4), 22)


func register_click(hit: bool) -> void:
	_inc(&"clicks")
	if not hit:
		_inc(&"misses")
		_clean_combo = 0


## Strahl prallt ab (zu wenig Saugkraft)
func register_deflect(data: TargetData, source: StringName) -> void:
	if source == &"player" and data.kind == TargetData.Kind.MACHINE:
		_inc(&"robot_deflects")


# ---------------------------------------------------------------- Level / XP

func xp_needed() -> float:
	return floor(12.0 * pow(1.3, level - 1))


func add_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		var points := 1 + (1 if level % 5 == 0 else 0)
		ResourceManager.add(ResourceManager.SKILL_POINTS, points)
		level_up.emit(level)
		toast.emit("Level %d! +%d Skillpunkt%s" % [level, points, "e" if points > 1 else ""], ResourceManager.icon(ResourceManager.SKILL_POINTS), UIStyle.PURPLE)
		if level % 3 == 0:
			comment(&"level_up")
	xp_changed.emit(xp, xp_needed(), level)


# ---------------------------------------------------------------- Mutterschiff

func mothership_goal() -> float:
	return round(100.0 * pow(1.45, mothership_calls))


func mothership_is_ready() -> bool:
	return mothership_charge >= mothership_goal()


func add_mothership_charge(amount: float) -> void:
	if event_running or amount <= 0.0:
		return
	var was_ready := mothership_is_ready()
	mothership_charge = minf(mothership_charge + amount, mothership_goal())
	mothership_changed.emit(mothership_charge, mothership_goal())
	if not was_ready and mothership_is_ready():
		mothership_ready.emit()


## Name der Event-Stufe (wächst mit der Anzahl der Rufe)
func mothership_stage() -> Dictionary:
	if mothership_calls >= 6:
		return {"name": "KONTINENTALBEAM", "extra": 40, "cars": true, "mult": 3.0}
	if mothership_calls >= 3:
		return {"name": "STADTENTFÜHRUNG", "extra": 28, "cars": true, "mult": 2.0}
	return {"name": "MASSENBEAM", "extra": 16, "cars": false, "mult": 1.0}


func complete_mothership() -> void:
	mothership_calls += 1
	_inc(&"mothership_calls")
	mothership_charge = 0.0
	var bonus_data := UpgradeManager.stat(&"data_per_event")
	if bonus_data > 0.0:
		ResourceManager.add(ResourceManager.DATA, bonus_data)
	mothership_changed.emit(mothership_charge, mothership_goal())
	save_game()


# ---------------------------------------------------------------- Buffs & Gadgets

func start_buff(id: StringName, duration: float) -> void:
	buffs[id] = {"remaining": duration, "duration": duration}
	_apply_buff(id, true)
	buff_changed.emit(id, duration, duration)


func has_buff(id: StringName) -> bool:
	return buffs.has(id)


func _process_buffs(delta: float) -> void:
	for id in buffs.keys():
		var b: Dictionary = buffs[id]
		b["remaining"] = float(b["remaining"]) - delta
		buff_changed.emit(id, maxf(0.0, b["remaining"]), b["duration"])
		if b["remaining"] <= 0.0:
			buffs.erase(id)
			_apply_buff(id, false)


func _apply_buff(id: StringName, on: bool) -> void:
	var src := StringName("buff_" + String(id))
	var effects := {
		&"overload": {&"click_power": 2.0, &"beam_cooldown": 0.3},
		&"slowmo": {&"target_speed": 0.35},
		&"gold_rush": {&"golden_chance": 12.0},
		&"news": {&"credit_mult": 2.0},
		&"sun": {&"credit_mult": 5.0},
		&"parade": {&"spawn_rate": 1.5},
	}
	var e: Dictionary = effects.get(id, {})
	for stat_name in e:
		if on:
			UpgradeManager.set_modifier(stat_name, src, e[stat_name])
		else:
			UpgradeManager.clear_modifier(stat_name, src)


func gadget_available(g: Dictionary) -> bool:
	return UpgradeManager.flag(g["requires"])


func gadget_cooldown(id: StringName) -> float:
	return float(gadget_cooldowns.get(id, 0.0))


func use_gadget(id: StringName) -> bool:
	for g in GADGETS:
		if g["id"] != id:
			continue
		if not gadget_available(g) or gadget_cooldown(id) > 0.0 or event_running:
			return false
		var was_full := ResourceManager.energy >= ResourceManager.energy_max() - 0.5
		if not ResourceManager.spend_energy(g["cost"]):
			return false
		if id == &"overload" and was_full:
			_inc(&"overload_full")
		gadget_cooldowns[id] = g["cooldown"]
		var duration: float = g["duration"] * UpgradeManager.stat(&"gadget_duration")
		if duration > 0.0:
			start_buff(id, duration)
		if id == &"instant_charge":
			add_mothership_charge(mothership_goal() * 0.35)
		_inc(&"gadgets_used")
		gadget_used.emit(id)
		return true
	return false


# ---------------------------------------------------------------- Kosmetik

func cosmetic_owned(id: StringName) -> bool:
	var c: Dictionary = COSMETICS.get(id, {})
	if c.has("achievement"):
		return unlocked_achievements.has(c["achievement"])
	return id == &"skin_classic" or id == &"beam_green" or UpgradeManager.has(id)


## Kosmetik, die nur über Erfolge freigeschaltet wird (nicht im Shop)
func achievement_cosmetics() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in COSMETICS:
		if COSMETICS[id].has("achievement"):
			out.append(id)
	return out


func cosmetic_name(id: StringName) -> String:
	var c: Dictionary = COSMETICS.get(id, {})
	if c.has("name"):
		return c["name"]
	var u := UpgradeManager.get_upgrade(id)
	return u.display_name if u else String(id)


func ufo_tint() -> Color:
	var c: Dictionary = COSMETICS.get(StringName(settings["skin"]), {})
	return c.get("tint", Color.WHITE)


func equip_cosmetic(id: StringName) -> void:
	if not COSMETICS.has(id) or not cosmetic_owned(id):
		return
	var c: Dictionary = COSMETICS[id]
	settings["skin" if c["type"] == "skin" else "beam"] = String(id)
	cosmetics_changed.emit()


func ufo_texture() -> Texture2D:
	var c: Dictionary = COSMETICS.get(StringName(settings["skin"]), COSMETICS[&"skin_classic"])
	return load(c["sprite"])


func beam_color(time: float = 0.0) -> Color:
	var c: Dictionary = COSMETICS.get(StringName(settings["beam"]), COSMETICS[&"beam_green"])
	if c.get("rainbow", false):
		return Color.from_hsv(fmod(time * 0.3, 1.0), 0.6, 1.0)
	return c["color"]


# ---------------------------------------------------------------- Statistik, Erfolge, Features

func get_stat(key: StringName) -> float:
	return float(stats.get(key, 0.0))


func _inc(key: StringName, amount: float = 1.0) -> void:
	stats[key] = get_stat(key) + amount


## Einheitlicher Zugriff für Erfolge und Statistik-Anzeige
func get_stat_value(key: StringName) -> float:
	match key:
		&"credits_total":
			return ResourceManager.lifetime_total(ResourceManager.CREDITS)
		&"credits_run":
			return ResourceManager.run_total(ResourceManager.CREDITS)
		&"biomass_total":
			return ResourceManager.lifetime_total(ResourceManager.BIOMASS)
		&"data_total":
			return ResourceManager.lifetime_total(ResourceManager.DATA)
		&"ruf_total":
			return ResourceManager.lifetime_total(ResourceManager.RUF)
		&"level":
			return level
		&"prestiges":
			return prestige_count
		&"drones":
			return UpgradeManager.level(&"drone")
		&"crew_total":
			return UpgradeManager.level(&"drone") + UpgradeManager.level(&"patrol") + UpgradeManager.level(&"laser") + UpgradeManager.level(&"beiboot")
		&"skill_ranks":
			return UpgradeManager.total_skill_ranks()
		&"research":
			var n := 0
			for u in UpgradeManager.by_category(UpgradeData.Category.RESEARCH):
				if UpgradeManager.has(u.id):
					n += 1
			return n
		&"achievements":
			return unlocked_achievements.size()
		&"humans_and_animals":
			return minf(get_stat(&"kind_human"), get_stat(&"kind_animal"))
		&"species_complete":
			var n := 0
			for p in planets:
				if species_complete(p):
					n += 1
			return n
		&"planets_mapped":
			var n := 0
			for p in planets:
				if planet_mapped(p):
					n += 1
			return n
		&"skins_owned":
			var n := 0
			for id: StringName in COSMETICS:
				if COSMETICS[id]["type"] == "skin" and cosmetic_owned(id):
					n += 1
			return n
		&"crew_members":
			var n := 0
			for id in CREW_IDS:
				if UpgradeManager.has(StringName("crew_" + String(id))):
					n += 1
			return n
		&"planets_prestiged":
			var n := 0
			for p in planets:
				if get_stat(StringName("prestiged_from_" + String(p.id))) > 0.0:
					n += 1
			return n
	return get_stat(key)


## Wurde jeder Zieltyp dieses Planeten (inkl. goldenem Ziel) schon einmal entführt?
func species_complete(p: PlanetData) -> bool:
	for t in p.targets:
		if get_stat(StringName("abducted_" + String(t.id))) < 1.0:
			return false
	return p.golden_target == null or get_stat(StringName("abducted_" + String(p.golden_target.id))) >= 1.0


func _check_achievements() -> void:
	for a in achievements:
		if unlocked_achievements.has(a.id):
			continue
		if get_stat_value(a.stat) >= a.threshold:
			unlock_achievement(a)


func unlock_achievement(a: AchievementData) -> void:
	if unlocked_achievements.has(a.id):
		return
	unlocked_achievements[a.id] = true
	_session_achievements += 1
	achievement_unlocked.emit(a)
	toast.emit("Erfolg: %s  (+%d %% Credits)" % [a.display_name, int(round(a.bonus * 100.0))], a.icon, UIStyle.GOLD)
	if a.reward_cosmetic != &"" and COSMETICS.has(a.reward_cosmetic):
		toast.emit("Belohnung: %s – im Deko-Shop ausrüsten!" % cosmetic_name(a.reward_cosmetic), a.icon, UIStyle.PINK)
		cosmetics_changed.emit()
	if a.reward_line != "":
		crew_comment.emit(_speaker(), a.reward_line)
	elif randf() < 0.3:
		comment(&"achievement")
	_check_features()


func achievement_by_id(id: StringName) -> AchievementData:
	for a in achievements:
		if a.id == id:
			return a
	return null


func has_feature(f: StringName) -> bool:
	return features.has(f)


func _check_features() -> void:
	if _loading:
		return
	var checks := {
		&"crew": ResourceManager.lifetime_total(ResourceManager.CREDITS) >= 25.0 or prestige_count > 0,
		&"biolab": ResourceManager.lifetime_total(ResourceManager.BIOMASS) > 0.0,
		&"research": ResourceManager.lifetime_total(ResourceManager.DATA) > 0.0,
		&"cosmetic": ResourceManager.lifetime_total(ResourceManager.CREDITS) >= 1500.0 or achievement_cosmetics().any(cosmetic_owned),
		&"skilltree": level >= 2,
		&"achievements": not unlocked_achievements.is_empty(),
		&"planets": prestige_count > 0 or (current_planet != null and ResourceManager.run_total(ResourceManager.CREDITS) >= prestige_requirement() * 0.2),
		&"gadgets": UpgradeManager.flag(&"unlock_gadgets"),
	}
	var names := {
		&"crew": "Crew & Drohnen", &"biolab": "Bio-Labor", &"research": "Forschung", &"cosmetic": "Dekoration",
		&"skilltree": "Skilltree", &"achievements": "Erfolge", &"planets": "Planetenraub", &"gadgets": "Gadgets & Energie",
	}
	for f in checks:
		if checks[f] and not features.has(f):
			features[f] = true
			feature_unlocked.emit(f)
			toast.emit("Neu freigeschaltet: %s!" % names[f], null, UIStyle.ACCENT)


# ---------------------------------------------------------------- Crew-Kommentare

func comment(trigger: StringName, speaker: StringName = &"") -> void:
	var lines: Array = CREW_LINES.get(trigger, [])
	if lines.is_empty():
		return
	crew_comment.emit(speaker if speaker != &"" else _speaker(), lines.pick_random())


func _speaker() -> StringName:
	var hired: Array[StringName] = []
	for id in [&"zorg", &"blib", &"xul", &"glorp", &"quix"]:
		if UpgradeManager.has(StringName("crew_" + String(id))):
			hired.append(id)
	if hired.is_empty():
		return &"computer"
	return hired.pick_random()


func _on_upgrade_purchased(u: UpgradeData, new_level: int) -> void:
	_inc(&"purchases")
	if u.flavor != "" and (new_level == 1 or u.category == UpgradeData.Category.CREW_MEMBER):
		var who := &"computer"
		if u.category == UpgradeData.Category.CREW_MEMBER:
			who = StringName(String(u.id).trim_prefix("crew_"))
		crew_comment.emit(who, u.flavor)
	elif randf() < 0.08:
		comment(&"purchase")
	_check_features()


# ---------------------------------------------------------------- Planeten & Prestige

func prestige_requirement() -> float:
	var mult := current_planet.credit_multiplier if current_planet else 1.0
	return 1.0e6 * mult


func can_prestige() -> bool:
	return ResourceManager.run_total(ResourceManager.CREDITS) >= prestige_requirement() and not event_running


func ruf_gain() -> float:
	var ratio := ResourceManager.run_total(ResourceManager.CREDITS) / prestige_requirement()
	if ratio < 1.0:
		return 0.0
	return floor(3.0 * sqrt(ratio) * UpgradeManager.stat(&"ruf_mult"))


func planet_unlocked(p: PlanetData) -> bool:
	return p.order <= prestige_count


## Startet die Planetenraub-Animation (Main hört zu und ruft danach perform_prestige auf)
func request_prestige(destination: PlanetData) -> void:
	if not can_prestige() or not planet_unlocked_after_prestige(destination):
		return
	prestige_requested.emit(destination)


func planet_unlocked_after_prestige(p: PlanetData) -> bool:
	return p.order <= prestige_count + 1


func perform_prestige(destination: PlanetData) -> void:
	var gain := ruf_gain()
	if current_planet:
		_inc(StringName("prestiged_from_" + String(current_planet.id)))
	ResourceManager.add(ResourceManager.RUF, gain)
	prestige_count += 1
	_inc(&"prestiges_done")
	ResourceManager.reset_for_prestige()
	UpgradeManager.reset_for_prestige()
	mothership_charge = 0.0
	mothership_calls = 0
	combo = 0
	buffs.clear()
	UpgradeManager.clear_all_modifiers()
	current_planet = destination
	current_region = _first_region(current_planet)
	_apply_start_bonuses()
	_apply_planet_modifiers()
	planet_changed.emit(current_planet)
	mothership_changed.emit(mothership_charge, mothership_goal())
	banner.emit("PLANETENRAUB!\n+%s Kosmischer Ruf" % MathUtils.format_number(gain), UIStyle.BLUE, 2.5)
	comment(&"prestige")
	save_game()


func _apply_start_bonuses() -> void:
	var sc := UpgradeManager.stat(&"start_credits")
	if sc > 0.0:
		ResourceManager.add(ResourceManager.CREDITS, sc)
	var sd := int(UpgradeManager.stat(&"start_drones"))
	if sd > 0:
		var drone_max := UpgradeManager.get_upgrade(&"drone").max_level
		if drone_max > 0:
			sd = mini(sd, drone_max)
		UpgradeManager.set_level(&"drone", maxi(UpgradeManager.level(&"drone"), sd))


func _apply_planet_modifiers() -> void:
	if current_planet == null:
		return
	UpgradeManager.set_modifier(&"spawn_rate", &"planet", current_planet.spawn_rate_multiplier)
	UpgradeManager.set_modifier(&"max_targets", &"planet", current_planet.max_targets_multiplier)
	UpgradeManager.set_modifier(&"target_speed", &"planet", current_planet.target_speed_multiplier)
	UpgradeManager.set_modifier(&"beam_cooldown", &"planet", current_planet.beam_cooldown_multiplier)


# ---------------------------------------------------------------- Regionen & Kartografie

func _first_region(p: PlanetData) -> RegionData:
	if p == null or p.regions.is_empty():
		return null
	return p.regions[0]


func get_region(p: PlanetData, id: StringName) -> RegionData:
	if p == null:
		return null
	for r in p.regions:
		if r.id == id:
			return r
	return _first_region(p)


func region_unlocked(r: RegionData) -> bool:
	return r != null and level >= r.unlock_level


func set_region(id: StringName) -> void:
	var r := get_region(current_planet, id)
	if r == null or r == current_region or not region_unlocked(r) or event_running:
		return
	current_region = r
	_inc(StringName("visited_" + String(current_planet.id) + "_" + String(r.id)))
	region_changed.emit(r)
	comment(&"region")


func _map_key(p: PlanetData, r: RegionData) -> StringName:
	return StringName("map_" + String(p.id) + "_" + String(r.id))


## 0..1 – wie weit die Region kartografiert ist
func region_map_progress(r: RegionData, p: PlanetData = null) -> float:
	var planet := p if p else current_planet
	if r == null or planet == null:
		return 0.0
	return clampf(get_stat(_map_key(planet, r)) / maxf(1.0, r.map_goal), 0.0, 1.0)


func planet_mapped(p: PlanetData) -> bool:
	if p.regions.is_empty():
		return false
	for r in p.regions:
		if region_map_progress(r, p) < 1.0:
			return false
	return true


func _on_region_mapped(r: RegionData) -> void:
	region_mapped.emit(r)
	toast.emit("Region kartografiert: %s!" % r.display_name, load("res://assets/icons/planet_earth.png"), UIStyle.BLUE)
	if planet_mapped(current_planet):
		banner.emit("%s VOLLSTÄNDIG KARTOGRAFIERT!" % current_planet.display_name.to_upper(), UIStyle.BLUE, 1.8)


# ---------------------------------------------------------------- Speichern / Laden

func _reset_state() -> void:
	stats.clear()
	unlocked_achievements.clear()
	features.clear()
	xp = 0.0
	level = 1
	combo = 0
	mothership_charge = 0.0
	mothership_calls = 0
	prestige_count = 0
	buffs.clear()
	gadget_cooldowns.clear()
	current_planet = planets[0] if not planets.is_empty() else null
	current_region = _first_region(current_planet)
	_abduction_times.clear()
	_clean_combo = 0
	_combo_cows = 0
	_apply_planet_modifiers()


func _start_session() -> void:
	_session_time = 0.0
	_session_start_abductions = get_stat(&"abductions")
	_session_start_credits = ResourceManager.lifetime_total(ResourceManager.CREDITS)
	_session_best_combo = 0
	_session_achievements = 0


## Kurzer Rückblick auf die laufende Sitzung – wird gespeichert und beim nächsten Start gezeigt
func _session_summary() -> Dictionary:
	return {
		"duration": _session_time,
		"abductions": get_stat(&"abductions") - _session_start_abductions,
		"credits": ResourceManager.lifetime_total(ResourceManager.CREDITS) - _session_start_credits,
		"best_combo": _session_best_combo,
		"achievements": _session_achievements,
		"level": level,
		"planet": current_planet.display_name if current_planet else "",
		"region": current_region.display_name if current_region else "",
		"credits_now": ResourceManager.get_amount(ResourceManager.CREDITS),
		"mothership": mothership_charge / maxf(1.0, mothership_goal()),
	}


func save_game() -> void:
	if _loading:
		return
	var gm := {
		"stats": _stringify(stats),
		"achievements": _stringify(unlocked_achievements).keys(),
		"features": _stringify(features).keys(),
		"xp": xp, "level": level,
		"mothership_charge": mothership_charge, "mothership_calls": mothership_calls,
		"prestige_count": prestige_count,
		"planet": String(current_planet.id) if current_planet else "earth",
		"region": String(current_region.id) if current_region else "",
		"settings": settings,
		"last_session": _session_summary(),
	}
	SaveSystem.save({"resources": ResourceManager.to_dict(), "upgrades": UpgradeManager.to_dict(), "game": gm})


func load_game() -> void:
	var d := SaveSystem.load_save()
	if d.is_empty():
		return
	_loading = true
	ResourceManager.from_dict(SaveSystem.get_dict(d, "resources"))
	UpgradeManager.from_dict(SaveSystem.get_dict(d, "upgrades"))
	var gm := SaveSystem.get_dict(d, "game")
	var s := SaveSystem.get_dict(gm, "stats")
	for k in s:
		stats[StringName(k)] = float(s[k])
	for k in gm.get("achievements", []):
		unlocked_achievements[StringName(k)] = true
	for k in gm.get("features", []):
		features[StringName(k)] = true
	xp = SaveSystem.get_float(gm, "xp")
	level = maxi(1, SaveSystem.get_int(gm, "level", 1))
	mothership_charge = SaveSystem.get_float(gm, "mothership_charge")
	mothership_calls = SaveSystem.get_int(gm, "mothership_calls")
	prestige_count = SaveSystem.get_int(gm, "prestige_count")
	current_planet = get_planet(StringName(str(gm.get("planet", "earth"))))
	current_region = get_region(current_planet, StringName(str(gm.get("region", ""))))
	if not region_unlocked(current_region):
		current_region = _first_region(current_planet)
	var st := SaveSystem.get_dict(gm, "settings")
	for k in st:
		settings[k] = st[k]
	_apply_planet_modifiers()
	_loading = false
	# Kein Offline-Fortschritt: statt Einnahmen gibt es eine Zusammenfassung des letzten Spielstands
	var away := Time.get_unix_time_from_system() - SaveSystem.get_float(d, "saved_at", Time.get_unix_time_from_system())
	if away >= WELCOME_AFTER_SECONDS:
		welcome_summary = SaveSystem.get_dict(gm, "last_session").duplicate()
		welcome_summary["away"] = away
		if not welcome_summary.has("planet") and current_planet:
			welcome_summary["planet"] = current_planet.display_name
			welcome_summary["level"] = level


## Spieler hat die Zusammenfassung gesehen
func acknowledge_welcome() -> void:
	if welcome_summary.is_empty():
		return
	welcome_summary.clear()
	_inc(&"returns")
	comment(&"welcome")


func reset_game() -> void:
	SaveSystem.delete_save()
	ResourceManager.reset_all()
	UpgradeManager.reset_all()
	_reset_state()
	_start_session()
	welcome_summary.clear()
	auto_cps = 0.0
	auto_bps = 0.0
	_income_window.clear()
	planet_changed.emit(current_planet)
	mothership_changed.emit(0.0, mothership_goal())
	xp_changed.emit(xp, xp_needed(), level)
	game_reset.emit()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()


func _stringify(dict: Dictionary) -> Dictionary:
	var out := {}
	for k in dict:
		out[String(k)] = dict[k]
	return out


# ---------------------------------------------------------------- Effekt-Helfer (Signale)

func float_text(world_pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 20) -> void:
	floating_text_requested.emit(world_pos, text, color, size)


func effect(kind: StringName, world_pos: Vector2, color: Color = Color.WHITE) -> void:
	effect_requested.emit(kind, world_pos, color)


func shake(amount: float) -> void:
	if settings.get("screenshake", true):
		shake_requested.emit(amount)
