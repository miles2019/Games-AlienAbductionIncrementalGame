# Abduct-O-Matic – Alien Abduction Incremental (Godot 4.7)

Ein chaotisches 2D-Incremental-Game: Als UFO entführst du Menschen, Kühe, Autos und am Ende ganze Planeten.

## Starten

1. Godot 4.7 öffnen → **Importieren** → `alien-abduction/project.godot`
2. **F5** (Hauptszene: `scenes/main/main.tscn`)

## Steuerung

| Eingabe | Aktion |
|---|---|
| Linksklick / gedrückt halten | Traktorstrahl (Dauerfeuer beim Halten) |
| 1–5 | Gadgets (Überladung, Zeitlupe, Goldrausch, Zielverdopplung, Sofortaufladung) |
| M | Mutterschiff rufen |
| T | Skilltree |
| B | Shop ein-/ausklappen |
| ESC / Rechtsklick | Fenster schließen |

## Inhalt (alle 5 Meilensteine)

**M1 – Core Loop:** UFO folgt der Maus, Ziele laufen frei über das ganze Feld (Top-Down), Klick → gebogener Line2D-Traktorstrahl → Ziel wird per Tween wackelnd ins UFO gezogen → Credits, Floating Text, fliegende Münzen.

**M2 – Wirtschaft:** `UpgradeData`-Resources mit Kostenformeln (exponentiell, linear, polynomiell, logarithmisch, fix). UFO-Shop: Saugkraft, Saug-Reichweite, UFO-Geschwindigkeit, Saug-Turbo, Mehrfach-Sauger, Lockstoff, Kritische Entführung, Anlock-Signal, Energie. x1/x10/x100/MAX-Kauf. Goldene Kuh (selten, glitzert, flieht vor dem Cursor, Zeitlupe).

**M3 – Juice:** Menschen rennen panisch weg und winken, Kühe glotzen in die Kamera, Autos hupen, Roboter machen KLONK. Squash & Stretch am UFO bei schweren Zielen, Strahl biegt sich, Combo mit Pitch-Shift und dynamischer Musik (Hype-Spur blendet ein), bouncy Floating Text, Screenshake, Zoom-Punch, Partikel.

**M4 – Automatisierung & Mutterschiff:** Mini-Drohnen, Patrouillen-UFOs, Laser-Satelliten, Beiboote (fliegen selbst herum und saugen ein). Crew-Mitglieder mit Kommentaren. Mutterschiff-Balken → Event in Stufen (Massenbeam → Stadtentführung → Kontinentalbeam).

**M5 – Skilltree & Prestige:** Federnder 4-Äste-Skilltree (Saugtechnik, Tarnung, Alien-Wirtschaft, Mutterschiff-Tech) mit Gummiseil-Verbindungen, Pan & Zoom. Planetenraub-Prestige mit Animation → Kosmischer Ruf + Ruf-Shop. 6 Planeten (Erde, Wüste, Eis, Roboter, Süßigkeiten, Miniatur) mit eigenen Zielen und Regeln. JSON-Speichersystem mit Backup, Autosave und Offline-Einnahmen.

**Extras:** Bio-Labor (Biomasse), Forschung (Alien-Daten) schaltet neue Zieltypen/Events frei, 8 Zufallsereignisse (Kuh-Parade, Goldrausch, Militär mit Schutzschilden, Alien-Urlauber, Entführungsfehler, Breaking News, Riesenkuh-Boss, geheimes Sonnen-Event), 41 Erfolge mit Dauerbonus, Level/XP, Statistik, Optionen, Deko-Shop (UFO-Skins, Strahlfarben), Crew-Funk mit Sprüchen.

## Architektur

```
autoload/
  game_manager.gd      Spielzustand, globale Signale, Belohnungen, Combo, Level, Mutterschiff,
                       Buffs/Gadgets, Erfolge, Freischaltungen, Planeten/Prestige, Offline, Speichern
  resource_manager.gd  Credits, Biomasse, Alien-Daten, Skillpunkte, Kosmischer Ruf, Energie
  upgrade_manager.gd   Lädt alle UpgradeData, speichert Stufen, berechnet Werte über stat(&"name")
  audio_manager.gd     Prozedurale Sounds, Combo-Pitch, dynamische Musik
data/
  target_data.gd / upgrade_data.gd / planet_data.gd / achievement_data.gd   (Custom Resources)
  targets/*.tres  planets/*.tres  upgrades/<kategorie>/*.tres  achievements/*.tres
scenes/
  main/     main.tscn, spawner.gd, event_director.gd, world_ground.gd
  ufo/      ufo.tscn, tractor_beam.gd (Line2D), helper_ufo.tscn (Drohnen), laser_satellite, mothership
  targets/  base_target.tscn (Area2D + Sprite2D + CollisionShape2D) + vererbte Szenen für
            Mensch, Kuh, Auto, Vogel, Goldziel, Boss
  ui/       hud.tscn, shop_panel, shop_item, skill_tree_panel, mothership_bar, overlay_panel, ...
  effects/  floating_text.tscn, abduction_particles.tscn, screen_shake.gd, mass_beam_overlay.gd
scripts/utils/  math_utils.gd, save_system.gd, ui_style.gd
tools/          make_sprites.py (Pixel-Art-Generator), build_data.gd/.tscn (Content-Generator)
```

Kommunikation läuft über Signale (`GameManager.target_abducted`, `ResourceManager.resource_changed`, `UpgradeManager.upgrade_purchased`, `GameManager.floating_text_requested` ...). Szenen greifen nie über `../../..` aufeinander zu.

## Neue Inhalte im Editor anlegen

**Neue Einheit (z. B. Feuerwehrauto):**
1. Rechtsklick in `data/targets/` → *Neu → Resource → TargetData*.
2. Im Inspector: `id`, Name, Texturen (Spritesheet mit 4 Frames: Laufen 1, Laufen 2, Reaktion, Eingesaugt), HP, Credits, Bewegung, Reaktion, Spawn-Gewicht, optional `scene` (z. B. `car_target.tscn` für Hup-Verhalten) und `required_upgrade` (Forschung).
3. Die Resource im Planeten (`data/planets/earth.tres` → `targets`) hinzufügen. Fertig.

**Neues Upgrade / neuer Skill:** Neue `UpgradeData` in `data/upgrades/<ordner>/` anlegen, Kategorie wählen, `effect_stat` auf einen Wert aus `UpgradeManager.BASE_STATS` setzen (z. B. `click_power`, `credit_mult`, `drone_speed`), Modus ADD/PERCENT/MULTIPLY. Skills bekommen zusätzlich `branch` und `tree_position`. Wird automatisch geladen.

**Neuer Planet / Erfolg:** analog mit `PlanetData` bzw. `AchievementData`.

## Werkzeuge

- `python3 tools/make_sprites.py` – erzeugt alle Pixel-Sprites neu (überschreibt `assets/`).
- `godot --headless --path . res://tools/build_data.tscn` – erzeugt alle `.tres` neu (**überschreibt** eigene Änderungen an den Daten!).

Spielstand: `user://abduct_o_matic_save.json` (Windows: `%APPDATA%\Godot\app_userdata\Abduct-O-Matic\`).
