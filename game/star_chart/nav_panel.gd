## NavPanel
## Nutzt die vorbereiteten Buttons als Vorlagen, erstellt für jeden Körper eine Kopie,
## sortiert nach Entfernung und verdrahtet focus_body().

extends PanelContainer

# Fold-Container (für folded-Property)
@onready var _planet_fold: Node = $VBox/ScrollContainer/VBoxContainer/PlanetButtons
@onready var _dwarf_fold:  Node = $VBox/ScrollContainer/VBoxContainer/DwarfButtons
@onready var _moon_fold:   Node = $VBox/ScrollContainer/VBoxContainer/MoonButtons

# Button-Container (innere VBoxContainer bzw. StarButton direkt)
@onready var _star_box:   VBoxContainer = $VBox/StarButton
@onready var _planet_box: VBoxContainer = $VBox/ScrollContainer/VBoxContainer/PlanetButtons/VBoxContainer
@onready var _dwarf_box:  VBoxContainer = $VBox/ScrollContainer/VBoxContainer/DwarfButtons/VBoxContainer
@onready var _moon_box:   VBoxContainer = $VBox/ScrollContainer/VBoxContainer/MoonButtons/VBoxContainer

var _solar_map: Node = null


func setup(solar_map: Node) -> void:
	_solar_map = solar_map
	var registry: GameObjectRegistry = _solar_map.get_game_object_registry()
	var all_defs: Array[BodyDef]     = registry.get_all_body_defs()

	var stars:   Array[BodyDef] = all_defs.filter(func(d: BodyDef) -> bool: return d.type == "star")
	var planets: Array[BodyDef] = all_defs.filter(func(d: BodyDef) -> bool: return d.type == "planet")
	var dwarfs:  Array[BodyDef] = all_defs.filter(func(d: BodyDef) -> bool: return d.type == "dwarf")
	var moons:   Array[BodyDef] = all_defs.filter(func(d: BodyDef) -> bool: return d.type == "moon")

	planets.sort_custom(func(a: BodyDef, b: BodyDef) -> bool:
		return _orbital_distance(a) < _orbital_distance(b))

	moons.sort_custom(func(a: BodyDef, b: BodyDef) -> bool:
		var pa := _orbital_distance_of(a.parent_id, registry)
		var pb := _orbital_distance_of(b.parent_id, registry)
		if not is_equal_approx(pa, pb):
			return pa < pb
		return _orbital_distance(a) < _orbital_distance(b))

	_fill(_star_box,   stars,   registry, false)
	_fill(_planet_box, planets, registry, false)
	_fill(_dwarf_box,  dwarfs,  registry, false)
	_fill(_moon_box,   moons,   registry, true)

	_set_fold(_planet_fold, false)
	_set_fold(_dwarf_fold,  true)
	_set_fold(_moon_fold,   true)


# ── Befüllen ──────────────────────────────────────────────────────────────────

func _fill(box: VBoxContainer, defs: Array[BodyDef], registry: GameObjectRegistry, show_parent: bool) -> void:
	# Vorlage: erster Button-Child
	var template: Button = null
	for child in box.get_children():
		if child is Button:
			template = child as Button
			break
	if not template:
		return

	var new_buttons: Array[Button] = []
	for def: BodyDef in defs:
		var btn: Button = template.duplicate() as Button
		btn.text = _format_name(def, registry, show_parent)
		var icon_path := "res://assets/map_icons/" + def.subtype + ".png"
		if not ResourceLoader.exists(icon_path):
			icon_path = "res://assets/map_icons/default.png"
		btn.icon = load(icon_path) as Texture2D
		btn.pressed.connect(_on_body_pressed.bind(def.id))
		new_buttons.append(btn)

	for child in box.get_children():
		if child is Button:
			box.remove_child(child)
			child.queue_free()

	for btn in new_buttons:
		box.add_child(btn)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _format_name(def: BodyDef, registry: GameObjectRegistry, show_parent: bool) -> String:
	if not show_parent or def.parent_id.is_empty():
		return def.name
	var parent_obj: GameObject = registry.get_game_object(def.parent_id)
	var parent_name := parent_obj.body_def.name if parent_obj and parent_obj.body_def else def.parent_id
	return def.name + "  (" + parent_name + ")"


func _orbital_distance(def: BodyDef) -> float:
	if def.motion is Kepler2DMotionDef:
		return (def.motion as Kepler2DMotionDef).semi_major_axis_km
	if def.motion is CircularMotionDef:
		return (def.motion as CircularMotionDef).orbital_radius_km
	return 0.0


func _orbital_distance_of(id: String, registry: GameObjectRegistry) -> float:
	var obj: GameObject = registry.get_game_object(id)
	return _orbital_distance(obj.body_def) if obj and obj.body_def else 0.0


func _set_fold(container: Node, folded: bool) -> void:
	if "folded" in container:
		container.set("folded", folded)
	elif container.has_method("set_collapsed"):
		container.set_collapsed(folded)


# ── Callback ──────────────────────────────────────────────────────────────────

func _on_body_pressed(id: String) -> void:
	if _solar_map:
		_solar_map.focus_body(id)
