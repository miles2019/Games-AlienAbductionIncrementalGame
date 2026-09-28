extends Node
## Content-Generator: legt alle Spieldaten als .tres-Resources an.
## Aufruf (einmalig bzw. zum Zurücksetzen der Balance):
##   godot --headless --path . --script res://tools/build_data.gd
## ACHTUNG: überschreibt res://data/targets, planets, upgrades, achievements.
## Danach Werte bequem im Godot-Inspector ändern.

const SPR := "res://assets/sprites/"
const ICO := "res://assets/icons/"

var _targets: Dictionary = {}

## Zielart je Ziel (Standard: Mensch)
const KINDS := {
	"cow": 1, "dog": 1, "cat": 1, "bird": 1, "camel": 1, "penguin": 1, "giant_cow": 1, "golden_cow": 1, "gummy_cow": 1,
	"car": 2, "jeep": 2, "candy_car": 2, "robot": 3, "droid": 3, "cactus_being": 4, "ice_crystal": 4,
}

## Regionen je Planet: [id, Name, Beschreibung, ab Level, Kapazität, Nachschub, Wert, Gewichte, Transport, Transportname, Kartografie-Ziel]
const REGIONS := {
	"earth": [
		["village", "Dorf", "Ländlich und ruhig: viele Kühe, wenige Menschen.", 1, 0.75, 0.8, 1.0, {&"cow": 3.0, &"dog": 1.5, &"human": 0.6, &"car": 0.4}, &"truck", "Viehtransporter", 120],
		["city", "Großstadt", "Dicht besiedelt: Menschenmassen, Autos und Prominente.", 4, 1.6, 1.6, 0.85, {&"human": 2.5, &"car": 2.2, &"celebrity": 2.0, &"cat": 1.5, &"cow": 0.15}, &"bus", "Linienbus", 250],
		["area51", "Sperrgebiet", "Kaum jemand hier – aber jedes Ziel ist wertvoll.", 10, 0.45, 0.55, 2.5, {&"spy": 4.0, &"robot": 3.0, &"human": 0.5, &"cow": 0.3}, &"truck", "Militärlaster", 80],
	],
	"desert": [
		["dunes", "Dünenmeer", "Endlose Dünen voller Kamele.", 1, 0.7, 0.8, 1.0, {&"camel": 3.0, &"cactus_being": 2.0, &"nomad": 0.7}, &"caravan", "Karawane", 120],
		["bazaar", "Großer Basar", "Gedränge, Feilschen, Hupkonzerte.", 4, 1.6, 1.6, 0.85, {&"nomad": 2.5, &"car": 2.0, &"celebrity": 2.0, &"camel": 0.5}, &"bus", "Basar-Shuttle", 250],
		["oasis", "Verborgene Oase", "Nur wenige finden hierher – dafür lohnt es sich.", 10, 0.45, 0.55, 2.5, {&"spy": 4.0, &"robot": 2.0, &"bird": 2.0}, &"caravan", "Karawane", 80],
	],
	"ice": [
		["floe", "Eisscholle", "Pinguine, so weit das Auge reicht.", 1, 0.7, 0.8, 1.0, {&"penguin": 3.0, &"ice_crystal": 1.5, &"parka": 0.6}, &"truck", "Schneemobil-Konvoi", 120],
		["station", "Forschungsstation", "Viele Forscher in dicken Jacken.", 4, 1.5, 1.5, 0.85, {&"parka": 2.5, &"car": 2.0, &"celebrity": 1.5, &"penguin": 0.5}, &"train", "Eisbahn", 250],
		["glacier", "Gletscherspalte", "Eisig, einsam und voller seltener Funde.", 10, 0.45, 0.55, 2.5, {&"ice_crystal": 3.0, &"spy": 3.0, &"robot": 2.0}, &"truck", "Schneemobil-Konvoi", 80],
	],
	"robot": [
		["scrapyard", "Schrottplatz", "Rostige Droiden suchen Ersatzteile.", 1, 0.7, 0.8, 1.0, {&"droid": 2.5, &"robot": 1.5, &"engineer": 0.6}, &"truck", "Schrottlaster", 120],
		["factory", "Megafabrik", "Schichtwechsel! Ingenieure überall.", 4, 1.6, 1.6, 0.85, {&"engineer": 2.5, &"droid": 2.0, &"car": 2.0}, &"train", "Fließband-Zug", 250],
		["server", "Serverfarm", "Kühl, leise und voller Geheimnisse.", 10, 0.45, 0.55, 2.5, {&"spy": 4.0, &"robot": 3.0}, &"train", "Datenzug", 80],
	],
	"candy": [
		["fields", "Lollifelder", "Gummikühe grasen auf Zuckerwiesen.", 1, 0.7, 0.8, 1.0, {&"gummy_cow": 3.0, &"bird": 1.5, &"candy_person": 0.6}, &"truck", "Zuckerwatte-Laster", 120],
		["town", "Zuckerstadt", "Ein süßes Gewusel aus Bonbon-Bewohnern.", 4, 1.6, 1.6, 0.85, {&"candy_person": 2.5, &"candy_car": 2.2, &"celebrity": 2.0}, &"bus", "Bonbon-Bus", 250],
		["fountain", "Schokobrunnen", "Ein exklusiver Treffpunkt der Süßen und Schönen.", 10, 0.45, 0.55, 2.5, {&"spy": 4.0, &"celebrity": 3.0, &"cat": 2.0}, &"train", "Schoko-Express", 80],
	],
	"mini": [
		["minifarm", "Mini-Farm", "Winzige Kühe auf winzigen Weiden.", 1, 0.75, 0.8, 1.0, {&"cow": 3.0, &"dog": 1.5, &"human": 0.6}, &"truck", "Spielzeuglaster", 150],
		["minicity", "Mini-Metropole", "Tausende Winzlinge auf Modellstraßen.", 4, 1.6, 1.6, 0.85, {&"human": 2.5, &"car": 2.2, &"celebrity": 2.0}, &"train", "Modelleisenbahn", 300],
		["museum", "Miniaturmuseum", "Wenige Besucher, aber sehr exklusive.", 10, 0.45, 0.55, 2.5, {&"spy": 4.0, &"robot": 3.0}, &"bus", "Museumsbus", 100],
	],
}


func _ready() -> void:
	print("targets..."); _build_targets()
	print("planets..."); _build_planets()
	print("upgrades..."); _build_upgrades()
	print("ach..."); _build_achievements()
	print("Content erzeugt.")
	get_tree().quit()


func _tex(path: String) -> Texture2D:
	return load(path)


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Konnte %s nicht speichern: %s" % [path, error_string(err)])


# ---------------------------------------------------------------- Ziele

func _target(id: String, props: Dictionary) -> TargetData:
	var t := TargetData.new()
	t.id = StringName(id)
	t.kind = KINDS.get(id, TargetData.Kind.HUMAN)
	print("  target ", id)
	var texs: Array[Texture2D] = []
	for p in props.get("textures", [id]):
		texs.append(_tex(SPR + p + ".png"))
	t.textures = texs
	for key in props:
		if key == "textures":
			continue
		if key == "scene":
			t.scene = load("res://scenes/targets/%s.tscn" % props[key])
		elif key == "reaction_lines" or key == "abduct_lines":
			var arr: Array[String] = []
			arr.assign(props[key])
			t.set(key, arr)
		else:
			t.set(key, props[key])
	_save(t, "res://data/targets/%s.tres" % id)
	_targets[id] = load("res://data/targets/%s.tres" % id)
	return t


func _build_targets() -> void:
	var R := TargetData.Reaction
	var M := TargetData.Movement
	var human_lines := ["AAAH!", "Mama!", "Nicht schon wieder!", "Ich hab Rechte!", "WAS?!", "Ich zahle Steuern!", "Nimm den Nachbarn!"]
	_target("human", {"display_name": "Mensch", "textures": ["human_0", "human_1", "human_2", "human_3", "human_4", "human_5"],
		"scene": "human_target", "base_hp": 1.0, "credits": 1.0, "xp": 1.0, "mothership_charge": 1.0, "speed_min": 30.0, "speed_max": 55.0,
		"reaction": R.PANIC, "spawn_weight": 55.0, "sound": &"slurp", "reaction_lines": human_lines,
		"abduct_lines": ["Der erste Mensch! Er riecht nach... Kaffee?"]})
	_target("cow", {"display_name": "Kuh", "scene": "cow_target", "base_hp": 2.0, "weight": 1.8, "credits": 3.0, "biomass": 2.0,
		"xp": 2.0, "mothership_charge": 2.0, "speed_min": 12.0, "speed_max": 24.0, "shadow_width": 22.0, "reaction": R.STARE,
		"spawn_weight": 30.0, "sound": &"moo", "reaction_lines": ["Muh?", "MUH!", "...muh.", "Muuuh!"],
		"abduct_lines": ["Keiner hat die Kuh kommen sehen!"]})
	_target("dog", {"display_name": "Hund", "pixel_scale": 2.6, "credits": 2.0, "biomass": 1.0, "xp": 1.5, "speed_min": 60.0, "speed_max": 95.0,
		"reaction": R.PANIC, "required_upgrade": &"r_pets", "spawn_weight": 10.0, "sound": &"bark", "shadow_width": 14.0,
		"abduct_lines": ["Ein Hund! Er wedelt noch. Ich glaube, er mag uns."]})
	_target("cat", {"display_name": "Katze", "pixel_scale": 2.6, "credits": 2.5, "biomass": 1.0, "data_chance": 0.04, "xp": 1.5,
		"speed_min": 30.0, "speed_max": 90.0, "reaction": R.FLEE, "required_upgrade": &"r_pets", "spawn_weight": 8.0, "sound": &"meow",
		"shadow_width": 12.0, "abduct_lines": ["Die Katze schaut uns an, als wären WIR die Entführten."]})
	_target("bird", {"display_name": "Vogel", "scene": "bird_target", "pixel_scale": 2.5, "fly_height": 60.0, "credits": 1.5, "biomass": 0.5,
		"xp": 1.0, "mothership_charge": 0.5, "movement": M.FLOCK, "group_size": 5, "speed_min": 110.0, "speed_max": 130.0,
		"reaction": R.FLEE, "required_upgrade": &"r_birds", "spawn_weight": 5.0, "sound": &"tweet", "shadow_width": 8.0,
		"escape_chance": 0.06, "abduct_lines": ["Ein Vogel. Er hat sich einfach mitziehen lassen."]})
	_target("car", {"display_name": "Auto", "textures": ["car_0", "car_1", "car_2"], "scene": "car_target", "base_hp": 6.0, "weight": 2.5,
		"credits": 15.0, "xp": 5.0, "mothership_charge": 4.0, "movement": M.DRIVE, "speed_min": 90.0, "speed_max": 140.0,
		"reaction": R.HONK, "required_upgrade": &"r_cars", "spawn_weight": 7.0, "sound": &"honk", "shadow_width": 32.0,
		"escape_chance": 0.0, "abduct_lines": ["Ein Auto! Wer hat den Führerschein gemacht? Ich nicht."]})
	_target("spy", {"display_name": "Alien-Spion", "scene": "human_target", "base_hp": 2.0, "credits": 20.0, "alien_data": 3.0, "xp": 10.0,
		"mothership_charge": 3.0, "speed_min": 30.0, "speed_max": 50.0, "reaction": R.PANIC, "is_rare": true,
		"required_upgrade": &"r_spies", "spawn_weight": 1.6, "reaction_lines": ["Ich bin ein ganz normaler Mensch.", "Blubb... äh, Hallo!", "Tarnung aktiv!"],
		"abduct_lines": ["Enttarnt! Das ist einer von uns. Peinlich."]})
	_target("celebrity", {"display_name": "Prominenter", "scene": "human_target", "base_hp": 3.0, "credits": 150.0, "alien_data": 2.0,
		"xp": 15.0, "mothership_charge": 8.0, "speed_min": 50.0, "speed_max": 70.0, "lifetime": 16.0, "reaction": R.PANIC, "is_rare": true,
		"required_upgrade": &"r_celebs", "spawn_weight": 0.9, "reaction_lines": ["Keine Fotos!", "Wissen Sie, wer ich bin?!", "Mein Agent hört davon!"],
		"abduct_lines": ["Ein Promi! Autogramm bitte!"]})
	_target("robot", {"display_name": "Roboter", "base_hp": 25.0, "min_power": 5.0, "weight": 2.2, "credits": 80.0, "alien_data": 2.0,
		"xp": 20.0, "mothership_charge": 6.0, "speed_min": 20.0, "speed_max": 35.0, "reaction": R.RESIST, "required_upgrade": &"r_robots",
		"spawn_weight": 2.5, "sound": &"clank", "escape_chance": 0.0, "abduct_lines": ["Ein Roboter! Blib will ihn sofort aufschrauben."]})
	_target("golden_cow", {"display_name": "Goldene Kuh", "scene": "golden_target", "base_hp": 1.0, "weight": 1.5, "credits": 60.0,
		"biomass": 15.0, "alien_data": 1.0, "xp": 10.0, "mothership_charge": 10.0, "speed_min": 80.0, "speed_max": 110.0, "lifetime": 14.0,
		"reaction": R.FLEE, "is_golden": true, "spawn_weight": 0.0, "sound": &"gold", "shadow_width": 22.0,
		"abduct_lines": ["GOLD! Der Chef wird stolz auf uns sein!"]})
	_target("jeep", {"display_name": "Militär-Jeep", "scene": "car_target", "base_hp": 12.0, "min_power": 3.0, "weight": 2.5, "credits": 40.0,
		"xp": 8.0, "mothership_charge": 3.0, "movement": M.DRIVE, "speed_min": 50.0, "speed_max": 70.0, "reaction": R.HONK,
		"spawn_weight": 0.0, "sound": &"honk", "shadow_width": 32.0, "escape_chance": 0.0,
		"abduct_lines": ["Wir haben einen Jeep der Armee. Das gibt Ärger. Oder Punkte!"]})
	_target("giant_cow", {"display_name": "Riesenkuh", "scene": "boss_target", "pixel_scale": 7.0, "base_hp": 200.0, "weight": 4.0,
		"credits": 2500.0, "biomass": 250.0, "alien_data": 10.0, "xp": 100.0, "mothership_charge": 30.0, "speed_min": 10.0, "speed_max": 14.0,
		"lifetime": 45.0, "reaction": R.STARE, "is_boss": true, "spawn_weight": 0.0, "sound": &"moo", "shadow_width": 70.0, "escape_chance": 0.0,
		"reaction_lines": ["MUUUUUH!", "Ich bin größer als euer Schiff!", "Probiert's doch!"]})
	# Wüste
	_target("nomad", {"display_name": "Wüstenhändler", "textures": ["nomad_0", "nomad_1"], "scene": "human_target", "credits": 1.5, "xp": 1.0,
		"speed_min": 35.0, "speed_max": 60.0, "reaction": R.PANIC, "spawn_weight": 50.0, "reaction_lines": ["Sand in den Augen!", "Meine Ware!", "Kein Rabatt für Aliens!"]})
	_target("camel", {"display_name": "Kamel", "scene": "cow_target", "base_hp": 3.0, "weight": 2.0, "credits": 4.0, "biomass": 3.0, "xp": 2.0,
		"mothership_charge": 2.0, "speed_min": 15.0, "speed_max": 28.0, "shadow_width": 22.0, "reaction": R.STARE, "spawn_weight": 28.0,
		"sound": &"moo", "reaction_lines": ["Pffft!", "*spuckt*", "Hmpf."]})
	_target("cactus_being", {"display_name": "Kaktuswesen", "scene": "human_target", "base_hp": 2.0, "credits": 3.0, "biomass": 2.0,
		"data_chance": 0.03, "xp": 2.0, "speed_min": 20.0, "speed_max": 40.0, "reaction": R.PANIC, "spawn_weight": 15.0,
		"reaction_lines": ["Pieks!", "Nicht anfassen!", "Ich bin stachelig!"]})
	# Eis
	_target("parka", {"display_name": "Polarforscher", "textures": ["parka_0", "parka_1"], "scene": "human_target", "credits": 1.5, "xp": 1.0,
		"speed_min": 30.0, "speed_max": 50.0, "reaction": R.PANIC, "spawn_weight": 45.0, "reaction_lines": ["Brrr!", "Ist das ein Polarlicht?", "Mein Iglu!"]})
	_target("penguin", {"display_name": "Pinguin", "scene": "cow_target", "pixel_scale": 2.8, "base_hp": 1.5, "credits": 3.0, "biomass": 2.0,
		"xp": 2.0, "speed_min": 20.0, "speed_max": 35.0, "reaction": R.STARE, "spawn_weight": 30.0, "sound": &"tweet",
		"reaction_lines": ["Kwak?", "*watschel*", "Frack sitzt!"]})
	_target("ice_crystal", {"display_name": "Eiskristall", "base_hp": 5.0, "weight": 1.5, "credits": 12.0, "data_chance": 0.15, "xp": 4.0,
		"movement": M.STATIONARY, "lifetime": 22.0, "reaction": R.NONE, "spawn_weight": 5.0, "sound": &"coin", "escape_chance": 0.0})
	# Roboterplanet
	_target("engineer", {"display_name": "Ingenieur", "textures": ["engineer_0", "engineer_1"], "scene": "human_target", "credits": 1.5,
		"xp": 1.0, "speed_min": 30.0, "speed_max": 55.0, "reaction": R.PANIC, "spawn_weight": 40.0, "reaction_lines": ["Systemfehler!", "Wer hat das programmiert?!"]})
	_target("droid", {"display_name": "Droide", "base_hp": 3.0, "credits": 6.0, "data_chance": 0.05, "xp": 3.0, "speed_min": 40.0, "speed_max": 70.0,
		"reaction": R.PANIC, "spawn_weight": 30.0, "sound": &"clank"})
	# Süßigkeitenplanet
	_target("candy_person", {"display_name": "Zuckerwesen", "textures": ["candy_0", "candy_1"], "scene": "human_target", "credits": 1.5,
		"xp": 1.0, "speed_min": 30.0, "speed_max": 55.0, "reaction": R.PANIC, "spawn_weight": 50.0, "reaction_lines": ["Iiiih, klebrig!", "Nicht abschlecken!"]})
	_target("gummy_cow", {"display_name": "Gummikuh", "textures": ["gummy_bear_cow"], "scene": "cow_target", "base_hp": 2.0, "weight": 1.6,
		"credits": 4.0, "biomass": 3.0, "xp": 2.0, "speed_min": 12.0, "speed_max": 22.0, "shadow_width": 22.0, "reaction": R.STARE,
		"spawn_weight": 30.0, "sound": &"boing", "reaction_lines": ["Muh... Zucker!", "*wabbel*"]})
	_target("candy_car", {"display_name": "Bonbon-Auto", "scene": "car_target", "base_hp": 5.0, "weight": 2.2, "credits": 14.0, "xp": 5.0,
		"mothership_charge": 4.0, "movement": M.DRIVE, "speed_min": 70.0, "speed_max": 110.0, "reaction": R.HONK, "spawn_weight": 7.0,
		"sound": &"honk", "shadow_width": 32.0, "escape_chance": 0.0})


# ---------------------------------------------------------------- Planeten

func _planet(id: String, props: Dictionary, target_ids: Array) -> void:
	var p := PlanetData.new()
	p.id = StringName(id)
	for key in props:
		p.set(key, props[key])
	var arr: Array[TargetData] = []
	for tid in target_ids:
		arr.append(_targets[tid])
	p.targets = arr
	p.golden_target = _targets["golden_cow"]
	var regions: Array[RegionData] = []
	for r in REGIONS.get(id, []):
		var reg := RegionData.new()
		reg.id = StringName(r[0])
		reg.display_name = r[1]
		reg.description = r[2]
		reg.unlock_level = r[3]
		reg.capacity = r[4]
		reg.resupply = r[5]
		reg.value_multiplier = r[6]
		reg.weight_multipliers = r[7]
		reg.transport = r[8]
		reg.transport_name = r[9]
		reg.map_goal = r[10]
		regions.append(reg)
	p.regions = regions
	_save(p, "res://data/planets/%s.tres" % id)


func _build_planets() -> void:
	var earth := ["human", "cow", "dog", "cat", "bird", "car", "spy", "celebrity", "robot"]
	_planet("earth", {"display_name": "Erde", "order": 0, "icon": _tex(ICO + "planet_earth.png"),
		"description": "Ein blauer Planet voller ahnungsloser Menschen und Kühe.", "rule_text": "Klassisch: Menschen, Kühe & Co.",
		"ground_color": Color(0.47, 0.73, 0.35), "ground_color_2": Color(0.42, 0.67, 0.3), "detail_color": Color(0.33, 0.57, 0.25),
		"detail_color_2": Color(1, 1, 1), "detail_style": &"grass"}, earth)
	_planet("desert", {"display_name": "Wüstenplanet", "order": 1, "icon": _tex(ICO + "planet_desert.png"),
		"description": "Heiß, trocken und voller Händler.", "rule_text": "Hitze: Alle Ziele sind 30 % schneller.",
		"credit_multiplier": 3.0, "target_speed_multiplier": 1.3,
		"ground_color": Color(0.93, 0.8, 0.55), "ground_color_2": Color(0.88, 0.74, 0.48), "detail_color": Color(0.82, 0.66, 0.4),
		"detail_color_2": Color(0.7, 0.55, 0.35), "detail_style": &"sand"},
		["nomad", "camel", "cactus_being", "dog", "car", "spy", "celebrity", "robot", "bird"])
	_planet("ice", {"display_name": "Eisplanet", "order": 2, "icon": _tex(ICO + "planet_ice.png"),
		"description": "Glatt, kalt, voller Pinguine.", "rule_text": "Glatteis: Ziele rutschen unkontrolliert.",
		"credit_multiplier": 10.0, "slippery": true,
		"ground_color": Color(0.9, 0.95, 1.0), "ground_color_2": Color(0.83, 0.9, 0.98), "detail_color": Color(0.62, 0.8, 0.95),
		"detail_color_2": Color(1, 1, 1), "detail_style": &"snow"},
		["parka", "penguin", "ice_crystal", "dog", "car", "spy", "celebrity", "robot"])
	_planet("robot", {"display_name": "Roboterplanet", "order": 3, "icon": _tex(ICO + "planet_robot.png"),
		"description": "Fabriken, Droiden und Sicherheitsprotokolle.", "rule_text": "Gepanzert: Alle Ziele haben doppelte HP.",
		"credit_multiplier": 30.0, "target_hp_multiplier": 2.0,
		"ground_color": Color(0.42, 0.45, 0.52), "ground_color_2": Color(0.38, 0.41, 0.48), "detail_color": Color(0.32, 0.34, 0.4),
		"detail_color_2": Color(0.95, 0.8, 0.3), "detail_style": &"metal"},
		["engineer", "droid", "robot", "car", "spy", "celebrity"])
	_planet("candy", {"display_name": "Süßigkeitenplanet", "order": 4, "icon": _tex(ICO + "planet_candy.png"),
		"description": "Alles ist essbar. Wirklich alles.", "rule_text": "Klebrig: Ziele sind langsam, der Strahl lädt langsamer.",
		"credit_multiplier": 100.0, "target_speed_multiplier": 0.6, "beam_cooldown_multiplier": 1.25,
		"ground_color": Color(1.0, 0.82, 0.9), "ground_color_2": Color(0.98, 0.74, 0.86), "detail_color": Color(1, 0.6, 0.8),
		"detail_color_2": Color(1, 1, 1), "detail_style": &"candy"},
		["candy_person", "gummy_cow", "candy_car", "cat", "bird", "celebrity", "spy"])
	_planet("mini", {"display_name": "Miniaturplanet", "order": 5, "icon": _tex(ICO + "planet_mini.png"),
		"description": "Alles ist winzig – aber es gibt Unmengen davon.", "rule_text": "Winzig: 3x so viele Ziele, alle klein.",
		"credit_multiplier": 300.0, "target_scale": 0.55, "max_targets_multiplier": 3.0, "spawn_rate_multiplier": 3.0,
		"ground_color": Color(0.55, 0.8, 0.45), "ground_color_2": Color(0.5, 0.75, 0.4), "detail_color": Color(0.4, 0.63, 0.32),
		"detail_color_2": Color(1, 0.9, 1), "detail_style": &"grass"}, earth)


# ---------------------------------------------------------------- Upgrades

var _order: int = 0


func _up(id: String, cat: UpgradeData.Category, props: Dictionary) -> void:
	var u := UpgradeData.new()
	u.id = StringName(id)
	u.category = cat
	u.sort_order = _order
	_order += 1
	for key in props:
		match key:
			"icon":
				u.icon = _tex(ICO + props[key] + ".png")
			"requirements":
				var arr: Array[String] = []
				arr.assign(props[key])
				u.requirements = arr
			"effect":
				var e: Array = props[key]
				u.effect_stat = e[0]
				u.effect_mode = e[1]
				u.effect_value = e[2]
			"effect2":
				var e2: Array = props[key]
				u.effect2_stat = e2[0]
				u.effect2_mode = e2[1]
				u.effect2_value = e2[2]
			_:
				u.set(key, props[key])
	var folder: String = ["ufo", "crew", "crew", "biolab", "research", "skills", "ruf", "cosmetic"][cat]
	_save(u, "res://data/upgrades/%s/%s.tres" % [folder, id])


func _build_upgrades() -> void:
	var C := UpgradeData.Category
	var ADD := UpgradeData.EffectMode.ADD
	var PCT := UpgradeData.EffectMode.PERCENT
	var MUL := UpgradeData.EffectMode.MULTIPLY
	var UNL := UpgradeData.EffectMode.UNLOCK
	var LIN := UpgradeData.CostFormula.LINEAR
	var FIX := UpgradeData.CostFormula.FIXED
	# --- UFO
	_up("power", C.UFO, {"display_name": "Saugkraft", "description": "+1 Saugkraft (Schaden pro Strahl) und +15 % Credits.", "icon": "power",
		"base_cost": 10.0, "cost_scaling": 1.45, "max_level": 100, "effect": [&"click_power", ADD, 1.0], "effect2": [&"credit_mult", PCT, 0.15],
		"flavor": "Mehr Saugkraft! Die Kühe werden es lieben. Oder fürchten."})
	_up("range", C.UFO, {"display_name": "Saug-Reichweite", "description": "Größerer Fangradius – schnelle und fliehende Ziele lassen sich leichter abfangen.", "icon": "range",
		"base_cost": 20.0, "cost_scaling": 1.55, "max_level": 40, "effect": [&"capture_radius", ADD, 7.0]})
	_up("speed", C.UFO, {"display_name": "UFO-Geschwindigkeit", "description": "UFO fliegt schneller, Strahl lädt 7 % schneller nach.", "icon": "speed",
		"base_cost": 15.0, "cost_scaling": 1.5, "max_level": 30, "effect": [&"beam_cooldown", MUL, 0.93], "effect2": [&"ufo_speed", PCT, 0.1]})
	_up("lift", C.UFO, {"display_name": "Saug-Turbo", "description": "Ziele werden 12 % schneller eingesaugt.", "icon": "beam",
		"base_cost": 30.0, "cost_scaling": 1.5, "max_level": 25, "effect": [&"lift_speed", PCT, 0.12]})
	_up("multi", C.UFO, {"display_name": "Mehrfach-Sauger", "description": "+1 Ziel, das ein Strahl gleichzeitig erfassen kann.", "icon": "multi",
		"base_cost": 120.0, "cost_scaling": 3.0, "max_level": 12, "effect": [&"max_captures", ADD, 1.0],
		"flavor": "Zwei auf einen Streich! Blib hat den Strahl gegabelt."})
	_up("lure", C.UFO, {"display_name": "Lockstoff", "description": "+2 max. Ziele auf dem Feld, +8 % Spawnrate.", "icon": "lure",
		"base_cost": 60.0, "cost_scaling": 1.6, "max_level": 30, "effect": [&"max_targets", ADD, 2.0], "effect2": [&"spawn_rate", PCT, 0.08]})
	_up("crit", C.UFO, {"display_name": "Kritische Entführung", "description": "+2 % Chance auf eine kritische Entführung (x5 Credits).", "icon": "crit",
		"base_cost": 250.0, "cost_scaling": 1.7, "max_level": 25, "effect": [&"crit_chance", ADD, 0.02]})
	_up("magnet", C.UFO, {"display_name": "Anlock-Signal", "description": "+3 % Chance, dass Entführte neue Ziele anlocken.", "icon": "magnet",
		"base_cost": 500.0, "cost_scaling": 1.8, "max_level": 20, "effect": [&"lure_chance", ADD, 0.03]})
	_up("energy_cap", C.UFO, {"display_name": "Energiespeicher", "description": "+25 maximale Energie für Gadgets.", "icon": "battery",
		"base_cost": 400.0, "cost_scaling": 1.7, "max_level": 20, "requirements": ["r_gadgets"], "effect": [&"energy_max", ADD, 25.0]})
	_up("energy_regen", C.UFO, {"display_name": "Solarsegel", "description": "+25 % Energie-Aufladung.", "icon": "solar",
		"base_cost": 350.0, "cost_scaling": 1.7, "max_level": 20, "requirements": ["r_gadgets"], "effect": [&"energy_regen", PCT, 0.25]})
	# --- Crew (Automatisierung)
	_up("drone", C.CREW, {"display_name": "Mini-Drohne", "description": "Fliegt herum und saugt schwache Ziele automatisch ein.", "icon": "t_drone",
		"base_cost": 40.0, "cost_scaling": 1.15, "max_level": 4, "effect": [&"drone_count", ADD, 1.0], "flavor": "Die erste Drohne! Sie heißt Kevin."})
	_up("patrol", C.CREW, {"display_name": "Patrouillen-UFO", "description": "5x Drohnen-Stärke, saugt bis zu 3 Ziele auf einmal.", "icon": "t_patrol",
		"base_cost": 700.0, "cost_scaling": 1.16, "max_level": 2, "requirements": ["drone:4"], "effect": [&"patrol_count", ADD, 1.0],
		"flavor": "Patrouille startklar. Sie hat sogar Blaulicht. Also, Rotlicht."})
	_up("laser", C.CREW, {"display_name": "Laser-Satellit", "description": "Fegt regelmäßig einen Laser über das ganze Feld. Mehr Satelliten = öfter.", "icon": "laser",
		"base_cost": 9000.0, "cost_scaling": 1.18, "max_level": 5, "requirements": ["patrol:2"], "effect": [&"laser_count", ADD, 1.0],
		"flavor": "Satellit im Orbit. Bitte nicht in den Laser schauen."})
	_up("beiboot", C.CREW, {"display_name": "Mutterschiff-Beiboot", "description": "Saugt ganze Gruppen ein und lädt das Mutterschiff passiv auf.", "icon": "t_beiboot",
		"base_cost": 120000.0, "cost_scaling": 1.2, "max_level": 1, "requirements": ["laser:2"], "effect": [&"beiboot_count", ADD, 1.0],
		"effect2": [&"mothership_passive", ADD, 0.6]})
	_up("crew_zorg", C.CREW_MEMBER, {"display_name": "Zorg, Pilot", "description": "Drohnen & Patrouillen fliegen 50 % schneller.", "icon": "crew_zorg",
		"base_cost": 1500.0, "cost_formula": FIX, "max_level": 1, "requirements": ["drone:1"], "effect": [&"drone_speed", PCT, 0.5],
		"flavor": "Zorg hier! Ich fliege seit 300 Jahren unfallfrei. Fast."})
	_up("crew_glorp", C.CREW_MEMBER, {"display_name": "Glorp, Kommentator", "description": "Seltene & goldene Ziele erscheinen 50 % häufiger. Kommentiert alles.", "icon": "crew_glorp",
		"base_cost": 4000.0, "cost_formula": FIX, "max_level": 1, "effect": [&"rare_mult", PCT, 0.5], "effect2": [&"golden_chance", PCT, 0.5],
		"flavor": "GLORP IST AUF SENDUNG! Was für ein Tag für Entführungen!"})
	_up("crew_xul", C.CREW_MEMBER, {"display_name": "Mama Xul, Köchin", "description": "+50 % Biomasse.", "icon": "crew_xul",
		"base_cost": 6000.0, "cost_formula": FIX, "max_level": 1, "effect": [&"biomass_mult", PCT, 0.5],
		"flavor": "Biomasse? Ich nenne das Zutaten, Schätzchen."})
	_up("crew_blib", C.CREW_MEMBER, {"display_name": "Blib, Technikerin", "description": "Laser-Satelliten doppelt so stark.", "icon": "crew_blib",
		"base_cost": 20000.0, "cost_formula": FIX, "max_level": 1, "requirements": ["laser:1"], "effect": [&"laser_power", PCT, 1.0],
		"flavor": "Ich hab den Laser getunt. Nicht reinschauen. Ernsthaft."})
	_up("crew_quix", C.CREW_MEMBER, {"display_name": "Quix, Buchhalter", "description": "+10 % Credits und +25 % Alien-Daten.", "icon": "crew_quix",
		"base_cost": 60000.0, "cost_formula": FIX, "max_level": 1, "effect": [&"credit_mult", PCT, 0.1], "effect2": [&"data_mult", PCT, 0.25],
		"flavor": "Laut meinen Büchern schulden uns die Kühe noch was."})
	# --- Bio-Labor
	_up("bio_digest", C.BIOLAB, {"display_name": "Saugmagen", "description": "+10 % Credits.", "icon": "biomass", "currency": &"biomass",
		"base_cost": 8.0, "cost_scaling": 1.5, "max_level": 50, "effect": [&"credit_mult", PCT, 0.1]})
	_up("bio_tentacle", C.BIOLAB, {"display_name": "Drohnen-Tentakel", "description": "+1 Drohnen-Stärke, +5 % Drohnentempo.", "icon": "dna", "currency": &"biomass",
		"base_cost": 20.0, "cost_scaling": 1.6, "max_level": 30, "effect": [&"drone_power", ADD, 1.0], "effect2": [&"drone_speed", PCT, 0.05]})
	_up("bio_brain", C.BIOLAB, {"display_name": "Gehirnwellen", "description": "+15 % Erfahrung.", "icon": "eye", "currency": &"biomass",
		"base_cost": 25.0, "cost_scaling": 1.55, "max_level": 30, "effect": [&"xp_mult", PCT, 0.15]})
	_up("bio_metabolism", C.BIOLAB, {"display_name": "Hyper-Stoffwechsel", "description": "+12 % Mutterschiff-Ladung.", "icon": "charge", "currency": &"biomass",
		"base_cost": 30.0, "cost_scaling": 1.6, "max_level": 25, "effect": [&"charge_mult", PCT, 0.12]})
	_up("bio_mutagen", C.BIOLAB, {"display_name": "Gold-Mutagen", "description": "+15 % goldene Ziele.", "icon": "star", "currency": &"biomass",
		"base_cost": 40.0, "cost_scaling": 1.7, "max_level": 20, "effect": [&"golden_chance", PCT, 0.15]})
	_up("bio_energy", C.BIOLAB, {"display_name": "Energie-Symbiont", "description": "+20 % Energie-Aufladung.", "icon": "energy", "currency": &"biomass",
		"base_cost": 50.0, "cost_scaling": 1.7, "max_level": 20, "requirements": ["r_gadgets"], "effect": [&"energy_regen", PCT, 0.2]})
	# --- Forschung (Alien-Daten, einmalig, bleibt beim Prestige)
	var research := [
		["r_pets", "Haustier-Studie", "Hunde und Katzen tauchen auf.", "t_dog", 2.0, [], []],
		["r_gadgets", "Gadget-Werkstatt", "Energie & Gadgets: Überladung, Zeitlupe, Goldrausch (Tasten 1-3).", "charge", 3.0, [], [&"unlock_gadgets", UNL, 1.0]],
		["r_birds", "Ornithologie", "Vogelschwärme fliegen übers Feld.", "t_bird", 5.0, ["r_pets"], []],
		["r_events", "Chaostheorie", "Zufallsereignisse: Kuh-Parade, Goldrausch, Breaking News, Alien-Urlauber ...", "clock", 6.0, [], [&"unlock_events", UNL, 1.0]],
		["r_cars", "Fahrzeugtechnik", "Autos: schwer einzusaugen, aber wertvoll.", "t_car_0", 10.0, ["r_pets"], []],
		["r_spies", "Spionage-Netzwerk", "Getarnte Alien-Spione – sie bringen viele Alien-Daten.", "t_spy", 15.0, ["r_birds"], []],
		["r_gadgets2", "Gadget-Werkstatt II", "Zielverdopplung & Sofortaufladung (Tasten 4-5).", "double", 20.0, ["r_gadgets"], [&"unlock_gadgets2", UNL, 1.0]],
		["r_celebs", "Paparazzi-Modul", "Prominente tauchen kurz auf – großer Bonus!", "t_celebrity", 25.0, ["r_cars"], []],
		["r_military", "Militärforschung", "Militär-Events: Jeeps schützen Ziele, sind aber selbst wertvoll.", "t_jeep", 30.0, ["r_events"], [&"unlock_military", UNL, 1.0]],
		["r_deepscan", "Tiefenscan", "Doppelte Chance auf Alien-Daten.", "data", 35.0, ["r_spies"], [&"data_mult", PCT, 1.0]],
		["r_robots", "Robotik", "Roboter tauchen auf: brauchen 5 Saugkraft, geben viel.", "t_robot", 40.0, ["r_cars"], []],
		["r_autopilot", "Autopilot", "Drohnen & Patrouillen fliegen 25 % schneller, das Mutterschiff lädt 10 % schneller.", "clock", 45.0, ["r_events"], [&"drone_speed", PCT, 0.25]],
		["r_boss", "Kryptozoologie", "Event 'Riesiger Schatten': eine gigantische Kuh erscheint.", "t_giant_cow", 60.0, ["r_military"], [&"unlock_boss", UNL, 1.0]],
		["r_mothership_ai", "Mutterschiff-KI", "Das Mutterschiff wird automatisch gerufen, sobald es bereit ist.", "t_beiboot", 80.0, ["r_boss"], [&"auto_mothership", UNL, 1.0]],
	]
	for r in research:
		var props := {"display_name": r[1], "description": r[2], "icon": r[3], "currency": &"data", "base_cost": r[4],
			"cost_formula": FIX, "max_level": 1, "requirements": r[5], "resets_on_prestige": false}
		if not (r[6] as Array).is_empty():
			props["effect"] = r[6]
		if r[0] == "r_autopilot":
			props["effect2"] = [&"charge_mult", PCT, 0.1]
		_up(r[0], C.RESEARCH, props)
	# --- Skilltree (Skillpunkte, bleibt beim Prestige)
	var S := {"currency": &"skill_points", "resets_on_prestige": false, "cost_formula": LIN, "base_cost": 1.0, "cost_scaling": 1.0}
	var skills := [
		["sk_root", "Alien-Instinkt", "+10 % Credits und Erfahrung. Der Anfang von allem.", "skillpoint", 4, Vector2(0, 0), 1, [], [&"credit_mult", PCT, 0.1], [&"xp_mult", PCT, 0.1], 1.0],
		# Saugtechnik
		["sk_suck1", "Stärkerer Sog", "+1 Saugkraft pro Rang.", "power", 0, Vector2(0, -140), 5, ["sk_root"], [&"click_power", ADD, 1.0], [], 0.0],
		["sk_wide", "Weitwinkel-Strahl", "+10 % Fangradius pro Rang.", "range", 0, Vector2(-120, -250), 5, ["sk_suck1"], [&"capture_radius", PCT, 0.1], [], 0.0],
		["sk_turbo", "Turbo-Spule", "Strahl lädt 8 % schneller pro Rang.", "speed", 0, Vector2(120, -250), 5, ["sk_suck1"], [&"beam_cooldown", MUL, 0.92], [], 0.0],
		["sk_beam", "Beam me up!", "Ein Klick saugt eine kleine Gruppe ein: +2 Ziele pro Strahl.", "multi", 0, Vector2(-190, -370), 1, ["sk_wide"], [&"max_captures", ADD, 2.0], [], 3.0],
		["sk_critsuck", "Kritischer Sog", "+2 kritischer Multiplikator und +2 % Krit-Chance pro Rang.", "crit", 0, Vector2(40, -390), 3, ["sk_turbo"], [&"crit_mult", ADD, 2.0], [&"crit_chance", ADD, 0.02], 0.0],
		["sk_physics", "Unfaire Physik", "10 % Chance pro Rang, dass ein Treffer benachbarte Ziele mitreißt.", "double", 0, Vector2(200, -370), 3, ["sk_turbo"], [&"chain_chance", ADD, 0.1], [], 0.0],
		["sk_singularity", "Singularität", "x3 Schaden gegen Bosse und +50 % Saugkraft.", "charge", 0, Vector2(0, -520), 1, ["sk_critsuck"], [&"boss_damage", MUL, 3.0], [&"click_power", PCT, 0.5], 5.0],
		# Tarnung
		["sk_silent", "Leise Triebwerke", "Ziele erschrecken sich später (-20 % Schreck-Radius) und fliehen 10 % langsamer (pro Rang).", "eye", 1, Vector2(140, 0), 3, ["sk_root"], [&"scare_radius", PCT, -0.2], [&"flee_speed", MUL, 0.9], 0.0],
		["sk_fear", "Angst vor Aliens", "Ziele unter dem Fadenkreuz erstarren vor Angst.", "eye", 1, Vector2(255, -115), 1, ["sk_silent"], [&"freeze_under_ufo", UNL, 1.0], [], 2.0],
		["sk_cloak", "Tarnkappe", "-1 % Fluchtchance und +25 % Reaktionszeit, bevor seltene Ziele fliehen (pro Rang).", "lock", 1, Vector2(255, 115), 3, ["sk_silent"], [&"escape_chance", ADD, -0.01], [&"warn_time", PCT, 0.25], 0.0],
		["sk_timewarp", "Zeitdehnung", "Ziele bewegen sich 10 % langsamer pro Rang.", "clock", 1, Vector2(390, -200), 3, ["sk_fear"], [&"target_speed", MUL, 0.9], [], 0.0],
		["sk_radar", "Radar-Störer", "Militär-Schutzschilde 35 % kleiner pro Rang.", "t_jeep", 1, Vector2(405, 0), 2, ["sk_fear"], [&"shield_radius", PCT, -0.35], [], 0.0],
		["sk_goldtiming", "Goldenes Timing", "Goldene Ziele bleiben 50 % länger und erscheinen 25 % häufiger (pro Rang).", "star", 1, Vector2(390, 200), 3, ["sk_cloak"], [&"golden_linger", PCT, 0.5], [&"golden_chance", PCT, 0.25], 0.0],
		["sk_ghostfleet", "Unsichtbare Flotte", "+20 % Drohnentempo und +25 % Drohnen-Stärke pro Rang.", "t_drone", 1, Vector2(530, 0), 3, ["sk_radar"], [&"drone_speed", PCT, 0.2], [&"drone_power", PCT, 0.25], 0.0],
		# Alien-Wirtschaft
		["sk_trade", "Intergalaktischer Handel", "+10 % Credits pro Rang.", "coin", 2, Vector2(0, 140), 10, ["sk_root"], [&"credit_mult", PCT, 0.1], [], 0.0],
		["sk_goldrush", "Goldgräber", "+50 % Belohnung von goldenen Zielen pro Rang.", "star", 2, Vector2(-120, 250), 3, ["sk_trade"], [&"gold_reward", PCT, 0.5], [], 0.0],
		["sk_combo", "Combo-Kunst", "+25 maximale Combo und längeres Combo-Fenster pro Rang.", "multi", 2, Vector2(120, 250), 3, ["sk_trade"], [&"combo_cap", ADD, 25.0], [&"combo_window", ADD, 0.3], 0.0],
		["sk_sleep", "Wache Flotte", "+15 % Drohnen-Stärke und +10 % Drohnentempo pro Rang. Die Flotte arbeitet nur, solange das Spiel läuft.", "clock", 2, Vector2(-190, 370), 4, ["sk_goldrush"], [&"drone_power", PCT, 0.15], [&"drone_speed", PCT, 0.1], 0.0],
		["sk_datatrade", "Datenhandel", "+50 % Alien-Daten pro Rang.", "data", 2, Vector2(40, 390), 3, ["sk_combo"], [&"data_mult", PCT, 0.5], [], 0.0],
		["sk_cowmagnet", "Kuhmagnet", "Kühe erscheinen doppelt so oft, Biomasse x2.", "t_cow", 2, Vector2(200, 370), 1, ["sk_combo"], [&"biomass_mult", MUL, 2.0], [], 2.0],
		["sk_compound", "Zinseszins", "Verdoppelt den Bonus aller Erfolge.", "trophy", 2, Vector2(0, 520), 1, ["sk_datatrade"], [], [], 5.0],
		# Mutterschiff-Technologie
		["sk_charge", "Schnell-Ladung", "+15 % Mutterschiff-Ladung pro Rang.", "charge", 3, Vector2(-140, 0), 5, ["sk_root"], [&"charge_mult", PCT, 0.15], [], 0.0],
		["sk_massbeam", "Massenbeam+", "+50 % Belohnung beim Mutterschiff-Event pro Rang.", "t_beiboot", 3, Vector2(-255, -115), 3, ["sk_charge"], [&"event_reward", PCT, 0.5], [], 0.0],
		["sk_wave", "Große Welle", "+8 zusätzliche Ziele beim Mutterschiff-Event pro Rang.", "double", 3, Vector2(-255, 115), 3, ["sk_charge"], [&"event_extra", ADD, 8.0], [], 0.0],
		["sk_core", "Energiekern", "+25 maximale Energie pro Rang.", "battery", 3, Vector2(-390, -200), 3, ["sk_massbeam"], [&"energy_max", ADD, 25.0], [], 0.0],
		["sk_overcharge", "Überladung+", "Gadgets halten 25 % länger pro Rang.", "energy", 3, Vector2(-405, 0), 3, ["sk_massbeam"], [&"gadget_duration", PCT, 0.25], [], 0.0],
		["sk_planet", "Planetenkenner", "+15 % Kosmischer Ruf pro Rang.", "planet_earth", 3, Vector2(-390, 200), 3, ["sk_wave"], [&"ruf_mult", PCT, 0.15], [], 0.0],
		["sk_sun", "Bitte nicht die Sonne", "Schaltet ein geheimes Ereignis frei. Was kann schon schiefgehen?", "solar", 3, Vector2(-530, 0), 1, ["sk_overcharge"], [&"sun_event", UNL, 1.0], [], 3.0],
	]
	for s in skills:
		var props := S.duplicate()
		props["display_name"] = s[1]
		props["description"] = s[2]
		props["icon"] = s[3]
		props["branch"] = s[4]
		props["tree_position"] = s[5]
		props["max_level"] = s[6]
		props["requirements"] = s[7]
		if not (s[8] as Array).is_empty():
			props["effect"] = s[8]
		if not (s[9] as Array).is_empty():
			props["effect2"] = s[9]
		if float(s[10]) > 0.0:
			props["cost_formula"] = FIX
			props["base_cost"] = s[10]
		if s[0] == "sk_sun":
			props["secret"] = true
		_up(s[0], C.SKILL, props)
	# --- Ruf-Shop (Kosmischer Ruf, bleibt)
	var ruf := [
		["ruf_greed", "Kosmische Gier", "Credits x1.5 pro Stufe.", "ruf", 1.0, 2.0, 20, [&"credit_mult", MUL, 1.5], []],
		["ruf_start", "Startkapital", "Starte jeden Planeten mit +2.000 Credits pro Stufe.", "coin", 1.0, 1.8, 10, [&"start_credits", ADD, 2000.0], []],
		["ruf_veteran", "Veteranen-Drohnen", "Starte jeden Planeten mit 1 Mini-Drohne pro Stufe.", "t_drone", 2.0, 2.0, 4, [&"start_drones", ADD, 1.0], []],
		["ruf_warp", "Warp-Antrieb", "Strahl 10 % schneller, Drohnen 10 % schneller pro Stufe.", "speed", 1.0, 1.9, 10, [&"beam_cooldown", MUL, 0.9], [&"drone_speed", PCT, 0.1]],
		["ruf_heritage", "Mutterschiff-Erbe", "+25 % Mutterschiff-Ladung pro Stufe.", "charge", 2.0, 2.0, 8, [&"charge_mult", PCT, 0.25], []],
		["ruf_eternal", "Ewige Energie", "Energie-Aufladung x1.5 pro Stufe.", "energy", 2.0, 2.2, 5, [&"energy_regen", MUL, 1.5], []],
		["ruf_archive", "Datenarchiv", "+2 Alien-Daten pro Mutterschiff-Event pro Stufe.", "data", 3.0, 2.0, 10, [&"data_per_event", ADD, 2.0], []],
	]
	for r in ruf:
		var props := {"display_name": r[1], "description": r[2], "icon": r[3], "currency": &"ruf", "base_cost": r[4], "cost_scaling": r[5],
			"max_level": r[6], "effect": r[7], "resets_on_prestige": false}
		if not (r[8] as Array).is_empty():
			props["effect2"] = r[8]
		_up(r[0], C.RUF, props)
	# --- Dekoration
	var deco := [
		["skin_rusty", "UFO: Rostlaube", "Ein Klassiker mit Charakter. Und Rost.", "skin_rusty", 2500.0],
		["beam_pink", "Strahl: Pink", "Für stilvolle Entführungen.", "beam_pink", 4000.0],
		["beam_blue", "Strahl: Eisblau", "Kühl. Sehr kühl.", "beam_blue", 4000.0],
		["skin_disco", "UFO: Disco-Kugel", "Samstagabend im Orbit.", "skin_disco", 15000.0],
		["skin_cow", "UFO: Kuh-Tarnung", "Die Kühe werden es nie merken.", "skin_cow", 60000.0],
		["beam_gold", "Strahl: Gold", "Nur das Beste für die Beute.", "beam_gold", 80000.0],
		["beam_rainbow", "Strahl: Regenbogen", "Alle Farben. Gleichzeitig.", "beam_rainbow", 300000.0],
		["skin_gold", "UFO: Goldenes Schiff", "Der Chef ist neidisch.", "skin_gold", 1000000.0],
	]
	for d in deco:
		_up(d[0], C.COSMETIC, {"display_name": d[1], "description": d[2], "icon": d[3], "base_cost": d[4], "cost_formula": FIX,
			"max_level": 1, "resets_on_prestige": false})


# ---------------------------------------------------------------- Erfolge

func _build_achievements() -> void:
	var list := [
		["first", "Erster Kontakt", "Entführe dein erstes Ziel.", &"abductions", 1.0, "t_human_0", false],
		["cow1", "Keiner hat die Kuh kommen sehen", "Entführe eine Kuh.", &"abducted_cow", 1.0, "t_cow", false],
		["click100", "Kleine Hände, großer Sauger", "Klicke 100 Mal.", &"clicks", 100.0, "power", false],
		["abd1000", "Beam-Anfänger", "Sauge 1.000 Ziele ein.", &"abductions", 1000.0, "multi", false],
		["abd10k", "Menschheit fast erledigt", "10.000 Entführungen.", &"abductions", 10000.0, "multi", false],
		["abd100k", "Wer macht das Licht aus?", "100.000 Entführungen.", &"abductions", 100000.0, "multi", false],
		["gold1", "Glänzender Fund", "Entführe ein goldenes Ziel.", &"golden", 1.0, "t_golden_cow", false],
		["gold10", "Goldgräber", "Entführe 10 goldene Ziele.", &"golden", 10.0, "t_golden_cow", false],
		["gold100", "Midas-Touch", "Entführe 100 goldene Ziele.", &"golden", 100.0, "t_golden_cow", false],
		["combo25", "Combo-Künstler", "Erreiche eine 25er-Combo.", &"best_combo", 25.0, "crit", false],
		["combo60", "Tierisch effizient", "Erreiche eine 60er-Combo.", &"best_combo", 60.0, "crit", false],
		["combo150", "Klick-Gott", "Erreiche eine 150er-Combo.", &"best_combo", 150.0, "crit", false],
		["cred1k", "Taschengeld", "Verdiene insgesamt 1.000 Credits.", &"credits_total", 1000.0, "coin", false],
		["cred1m", "Millionär aus dem All", "Verdiene insgesamt 1 Million Credits.", &"credits_total", 1.0e6, "coin", false],
		["cred1b", "Kosmischer Milliardär", "Verdiene insgesamt 1 Milliarde Credits.", &"credits_total", 1.0e9, "coin", false],
		["cred1t", "Galaktischer Großinvestor", "Verdiene insgesamt 1 Billion Credits.", &"credits_total", 1.0e12, "coin", false],
		["drone1", "Kleine Helfer", "Kaufe eine Mini-Drohne.", &"drones", 1.0, "t_drone", false],
		["drone25", "Schwarmintelligenz", "Besitze die maximale Anzahl Mini-Drohnen (4).", &"drones", 4.0, "t_drone", false],
		["crew100", "Armada", "Stelle die komplette Flotte auf (12 Einheiten).", &"crew_total", 12.0, "t_patrol", false],
		["mother1", "Mama ist da", "Rufe das Mutterschiff.", &"mothership_calls", 1.0, "t_beiboot", false],
		["mother10", "Stammgast", "Rufe das Mutterschiff 10 Mal.", &"mothership_calls", 10.0, "t_beiboot", false],
		["prestige1", "Planetenraub", "Stiehl deinen ersten Planeten.", &"prestiges", 1.0, "planet_earth", false],
		["prestige5", "Serientäter", "Stiehl 5 Planeten.", &"prestiges", 5.0, "planet_mini", false],
		["escape1", "Rutschige Hände", "Ein Ziel entkommt im letzten Moment.", &"escapes", 1.0, "t_human_0", false],
		["level10", "Aufsteiger", "Erreiche Level 10.", &"level", 10.0, "skillpoint", false],
		["level25", "Kommandant", "Erreiche Level 25.", &"level", 25.0, "skillpoint", false],
		["skills10", "Verzweigt", "Investiere 10 Skillpunkte.", &"skill_ranks", 10.0, "skillpoint", false],
		["research5", "Wissensdurst", "Schließe 5 Forschungen ab.", &"research", 5.0, "research", false],
		["dog10", "Wer ist ein guter Junge?", "Entführe 10 Hunde.", &"abducted_dog", 10.0, "t_dog", false],
		["bird50", "Vogelfrei", "Entführe 50 Vögel.", &"abducted_bird", 50.0, "t_bird", false],
		["car1", "Führerschein entzogen", "Entführe ein Auto.", &"abducted_car", 1.0, "t_car_0", false],
		["spy1", "Falscher Alarm", "Enttarne einen Alien-Spion.", &"abducted_spy", 1.0, "t_spy", false],
		["celeb1", "Autogramm bitte!", "Entführe einen Prominenten.", &"abducted_celebrity", 1.0, "t_celebrity", false],
		["robot1", "Blechschaden", "Entführe einen Roboter.", &"abducted_robot", 1.0, "t_robot", false],
		["boss1", "Riesiger Schatten", "Entführe eine Riesenkuh.", &"boss_kills", 1.0, "t_giant_cow", false],
		["crit100", "Kritische Masse", "100 kritische Entführungen.", &"crits", 100.0, "crit", false],
		["gadget10", "Knöpfchendrücker", "Benutze 10 Gadgets.", &"gadgets_used", 10.0, "charge", false],
		["events10", "Chaos-Magnet", "Erlebe 10 Zufallsereignisse.", &"events", 10.0, "clock", false],
		["offline1", "Willkommen zurück", "Kehre nach einer Pause zu deiner Crew zurück.", &"returns", 1.0, "clock", false],
		["misses100", "Daneben ist auch vorbei", "Verfehle 100 Mal.", &"misses", 100.0, "lock", true],
		["sun1", "Bitte nicht die Sonne", "Du hast es tatsächlich getan.", &"sun_events", 1.0, "solar", true],
		# [.., Belohnungs-Kosmetik, Crew-Spruch]
		["panic50", "Massenpanik", "Entführe 50 Ziele innerhalb von 30 Sekunden.", &"best_30s", 50.0, "multi", false, &"skin_neon", "Neon-Lack aufgetragen! Jetzt sieht uns wirklich jeder."],
		["clean40", "Keine Pause", "Halte eine 40er-Combo ohne einen einzigen Fehlschuss.", &"best_clean_combo", 40.0, "crit", false, &"skin_ghost", "Kein Fehlschuss? Ich hab dir ein Geister-UFO lackiert."],
		["sweep1", "Leer gefegt", "Entführe alle gerade sichtbaren Ziele.", &"field_cleared", 1.0, "range", false, &"beam_void", "Leer. Komplett leer. Hier, ein Strahl in Leere-Violett."],
		["stats10k", "Die Statistik lügt nicht", "Entführe 10.000 Menschen und 10.000 Tiere.", &"humans_and_animals", 10000.0, "trophy", false, &"", "Quix hat nachgezählt. Zweimal. Stimmt alles."],
		["goldlast", "Goldene Gelegenheit", "Erwische ein goldenes Ziel im letzten Moment.", &"gold_last_moment", 1.0, "t_golden_cow", true, &"beam_sparkle", "In letzter Sekunde! Der Strahl glitzert jetzt vor Stolz."],
		["cowcombo20", "Kuhmagnet bestätigt", "Entführe 20 Kühe in einer einzigen Combo.", &"best_cow_combo", 20.0, "t_cow", true, &"beam_milk", "Zwanzig Kühe! Der Strahl riecht jetzt nach Milch."],
		["robotpoke", "Bitte nicht anfassen", "Klicke einen Roboter an, obwohl der Strahl zu schwach ist.", &"robot_deflects", 1.0, "t_robot", true, &"", "KLONK. Der Roboter hat sich beschwert. Schriftlich."],
		["dodge1", "Fliegender Wechsel", "Erwische ein Ziel mitten in einer Ausweichbewegung.", &"dodge_catches", 1.0, "speed", false, &"", "Haken geschlagen – und trotzdem erwischt!"],
		["close1", "Das war knapp", "Entführe ein Ziel weniger als eine Sekunde vor seiner Flucht.", &"close_calls", 1.0, "clock", false, &"", "Eine Sekunde später und es wäre weg gewesen!"],
		["news5", "Breaking News", "Löse fünf Breaking-News-Ereignisse aus.", &"news_events", 5.0, "eye", false, &"skin_news", "Wir sind Dauergast im Fernsehen. Hier, ein Übertragungswagen-Lack."],
		["newscow", "Kuh im Bild", "Entführe eine Kuh während einer Breaking-News-Sendung.", &"news_cows", 1.0, "t_cow", true, &"", "Live im Fernsehen! Die Kuh hat gewunken."],
		["convoy1", "Militärisches Missverständnis", "Sauge einen geschützten Militär-Konvoi ein.", &"abducted_jeep", 1.0, "t_jeep", true, &"", "Wir haben einen Jeep. Weiß jemand, wie man den fährt?"],
		["vacation1", "Urlaub auf der Erde", "Lass das Helfer-UFO während seines Besuchs mindestens 12 Ziele einsaugen.", &"vacation_full", 1.0, "star", true, &"", "Der Urlauber schreibt uns eine Postkarte: 'Beste Reise ever.'"],
		["physics1", "Unfaire Physik", "Entführe ein Ziel, dessen Flugbahn gerade verändert wurde.", &"physics_catches", 1.0, "double", true, &"", "Newton würde weinen."],
		["mistake1", "Das war nicht geplant", "Sauge ein Ziel nach einem Entführungsfehler erneut ein.", &"mistake_catches", 1.0, "t_human_0", true, &"", "Zurück an Bord. Diesmal mit Anschnallgurt."],
		["species1", "Vollständige Speziesliste", "Entdecke jeden Zieltyp eines Planeten.", &"species_complete", 1.0, "research", false, &"beam_dna", "Katalog komplett! Der Strahl schimmert jetzt in DNA-Lila."],
		["mapper1", "Kartograf", "Kartografiere alle Regionen eines Planeten vollständig.", &"planets_mapped", 1.0, "planet_earth", false, &"skin_map", "Karte fertig! Das UFO bekommt einen Tarnlack im Kartenlook."],
		["skins10", "UFO-Fan", "Schalte zehn verschiedene UFO-Skins frei.", &"skins_owned", 10.0, "skin_disco", false, &"", "Zehn Skins. Der Hangar ist jetzt offiziell ein Modehaus."],
		["crewboss", "Crew-Chef", "Heuere auf einem Planeten alle Crew-Mitglieder an.", &"crew_members", 5.0, "crew_zorg", false, &"", "Die ganze Crew an Bord! Wer kocht heute?"],
		["energymax", "Viel zu viel Energie", "Zünde eine Überladung mit komplett gefülltem Energiespeicher.", &"overload_full", 1.0, "battery", true, &"", "Voller Speicher, volle Überladung. Die Sicherungen glühen."],
		["sunskin", "Sonnenbrand", "Erlebe das geheime Sonnen-Event dreimal.", &"sun_events", 3.0, "solar", true, &"skin_sun", "Wir haben die Sonne angefasst. Das UFO ist jetzt... orange."],
		["planetall", "Planetensammler", "Führe auf jedem Planeten mindestens einen Planetenraub durch.", &"planets_prestiged", 6.0, "planet_mini", false, &"", "Jeder Planet einmal eingepackt. Die Sammlung ist komplett!"],
	]
	var i := 0
	for a in list:
		var ach := AchievementData.new()
		ach.id = StringName(a[0])
		ach.display_name = a[1]
		ach.description = a[2]
		ach.stat = a[3]
		ach.threshold = a[4]
		ach.icon = _tex(ICO + a[5] + ".png")
		ach.secret = a[6]
		ach.bonus = 0.03 if a[6] else 0.02
		ach.sort_order = i
		if a.size() > 7:
			ach.reward_cosmetic = a[7]
			ach.reward_line = a[8]
		i += 1
		_save(ach, "res://data/achievements/%s.tres" % a[0])
