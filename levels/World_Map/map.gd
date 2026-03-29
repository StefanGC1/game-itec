extends Node2D

const HOME_VILLAGE_NAME := "HomeVillage"
const TRADE_MENU_UI_SCENE := preload("res://ui/trade_menu_ui.tscn")
const VILLAGE_DISPLAY_NAMES := {
	"Village1": "Ys",
	"Village2": "El Dorado",
	"Village3": "Camelot",
	"Village4": "Shambhala",
	"Village5": "Lemuria"
}
const MAP_BACKGROUND_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.02, 0.07, 0.10, 1.0);
uniform vec4 warm_color : source_color = vec4(0.23, 0.18, 0.08, 1.0);
uniform vec4 accent_color : source_color = vec4(0.80, 0.70, 0.35, 1.0);
uniform float line_density = 56.0;
uniform float drift_speed = 0.04;

void fragment() {
	vec2 uv = UV;
	float diag_wave = 0.5 + 0.5 * sin((uv.x + uv.y * 0.7 + TIME * drift_speed) * 9.0);
	float shimmer = 0.5 + 0.5 * sin((uv.y * 11.0 - TIME * drift_speed * 2.4) + uv.x * 5.0);
	float scan_lines = smoothstep(0.88, 1.0, 0.5 + 0.5 * sin((uv.x + TIME * drift_speed) * line_density));
	vec3 base = mix(deep_color.rgb, warm_color.rgb, smoothstep(0.0, 1.0, uv.y));
	base += accent_color.rgb * scan_lines * 0.11;
	base += vec3(0.06, 0.07, 0.05) * diag_wave * 0.45;
	base += vec3(0.03, 0.03, 0.02) * shimmer * 0.25;

	float dist = distance(uv, vec2(0.5, 0.5));
	float vignette = 1.0 - smoothstep(0.2, 0.85, dist);
	base *= 0.72 + vignette * 0.34;

	COLOR = vec4(base, 1.0);
}
"""

@onready var home_village_button: Button = $HomeVillage
@onready var village_buttons: Array[Button] = [
	$Village1,
	$Village2,
	$Village3,
	$Village4,
	$Village5
]
@onready var forestry_area_buttons: Array[Button] = [
	$"Butterfly Grove North",
	$"Butterfly Grove West"
]

var trade_menu: CanvasLayer
var status_label: Label
var map_buttons: Array[Button] = []
var background_layer: CanvasLayer
var background_rect: ColorRect


func _ready() -> void:
	_create_map_background()
	_setup_map_buttons()

	trade_menu = TRADE_MENU_UI_SCENE.instantiate() as CanvasLayer
	add_child(trade_menu)
	trade_menu.buy_requested.connect(_on_trade_buy_requested)
	trade_menu.sell_requested.connect(_on_trade_sell_requested)
	trade_menu.close_requested.connect(_on_trade_close_requested)

	home_village_button.pressed.connect(_on_home_village_pressed)
	for button in village_buttons:
		button.pressed.connect(_on_remote_village_pressed.bind(button.name))

	for button in forestry_area_buttons:
		button.pressed.connect(_on_forestry_area_pressed.bind(button.name))

	status_label = Label.new()
	status_label.text = "Select a village to trade, or gather from forestry areas."
	status_label.position = Vector2(24, 24)
	status_label.size = Vector2(860, 30)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90, 0.95))
	status_label.add_theme_color_override("font_outline_color", Color(0.07, 0.08, 0.10, 0.95))
	status_label.add_theme_constant_override("outline_size", 3)
	add_child(status_label)


func _unhandled_input(event: InputEvent) -> void:
	if not trade_menu:
		return

	if event.is_action_pressed("ui_cancel") and trade_menu.visible:
		_on_trade_close_requested()
		get_viewport().set_input_as_handled()


func _on_home_village_pressed() -> void:
	GameMaster.go_to(GameMaster.Location.VILLAGE)


func _on_remote_village_pressed(village_name: String) -> void:
	if not has_node("/root/GameState"):
		status_label.text = "GameState autoload is missing. Add it in project settings."
		return

	var game_state := get_node("/root/GameState")
	var snapshot := game_state.call("get_trade_snapshot", village_name) as Dictionary
	_set_map_buttons_enabled(false)
	trade_menu.open_for_village(village_name, snapshot)
	status_label.text = "Opened trade menu for " + _get_display_name(village_name) + "."


func _on_forestry_area_pressed(area_name: String) -> void:
	if not has_node("/root/GameState"):
		status_label.text = "GameState autoload is missing. Add it in project settings."
		return

	var game_state := get_node("/root/GameState")
	var result := game_state.call("gather_from_forest", area_name) as Dictionary
	status_label.text = str(result.get("message", "Gathered resources."))


func _on_trade_buy_requested(village_id: String, item_id: String, quantity: int) -> void:
	if not has_node("/root/GameState"):
		return

	var game_state := get_node("/root/GameState")
	var result := game_state.call("buy_item", village_id, item_id, quantity) as Dictionary
	var snapshot := game_state.call("get_trade_snapshot", village_id) as Dictionary
	trade_menu.set_snapshot(snapshot)
	trade_menu.set_status(str(result.get("message", "Trade completed.")))
	status_label.text = str(result.get("message", "Trade completed."))


func _on_trade_sell_requested(village_id: String, item_id: String, quantity: int) -> void:
	if not has_node("/root/GameState"):
		return

	var game_state := get_node("/root/GameState")
	var result := game_state.call("sell_item", village_id, item_id, quantity) as Dictionary
	var snapshot := game_state.call("get_trade_snapshot", village_id) as Dictionary
	trade_menu.set_snapshot(snapshot)
	trade_menu.set_status(str(result.get("message", "Trade completed.")))
	status_label.text = str(result.get("message", "Trade completed."))


func _on_trade_close_requested() -> void:
	trade_menu.close_menu()
	_set_map_buttons_enabled(true)
	status_label.text = "Trade menu closed. Choose another destination."


func _set_map_buttons_enabled(enabled: bool) -> void:
	home_village_button.disabled = not enabled
	for button in village_buttons:
		button.disabled = not enabled
	for button in forestry_area_buttons:
		button.disabled = not enabled

	for button in map_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		if not enabled:
			_set_map_button_visible(button, false)


func _setup_map_buttons() -> void:
	map_buttons = [home_village_button]
	map_buttons.append_array(village_buttons)
	map_buttons.append_array(forestry_area_buttons)

	for button in map_buttons:
		_style_map_button(button)
		_set_map_button_visible(button, false)
		if not button.mouse_entered.is_connected(_on_map_button_mouse_entered):
			button.mouse_entered.connect(_on_map_button_mouse_entered.bind(button))
		if not button.mouse_exited.is_connected(_on_map_button_mouse_exited):
			button.mouse_exited.connect(_on_map_button_mouse_exited.bind(button))


func _style_map_button(button: Button) -> void:
	button.text = _get_display_name(button.name)
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.97, 0.96, 0.90, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.83, 1.0))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.05, 0.11, 0.16, 0.45)
	normal_style.border_color = Color(0.78, 0.70, 0.42, 0.0)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(16)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.10, 0.20, 0.28, 0.62)
	hover_style.border_color = Color(0.93, 0.84, 0.50, 0.95)
	hover_style.set_border_width_all(3)
	hover_style.set_corner_radius_all(16)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.11, 0.24, 0.31, 0.75)
	pressed_style.border_color = Color(0.97, 0.89, 0.58, 1.0)
	pressed_style.set_border_width_all(3)
	pressed_style.set_corner_radius_all(16)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", normal_style)


func _get_display_name(node_name: String) -> String:
	return str(VILLAGE_DISPLAY_NAMES.get(node_name, node_name))


func _set_map_button_visible(button: Button, make_visible: bool) -> void:
	button.modulate = Color(1.0, 1.0, 1.0, 1.0 if make_visible else 0.0)


func _on_map_button_mouse_entered(button: Button) -> void:
	if button.disabled:
		return
	_set_map_button_visible(button, true)


func _on_map_button_mouse_exited(button: Button) -> void:
	if button.disabled:
		return
	_set_map_button_visible(button, false)


func _create_map_background() -> void:
	background_layer = CanvasLayer.new()
	background_layer.name = "MapBackgroundLayer"
	background_layer.layer = -100
	add_child(background_layer)

	background_rect = ColorRect.new()
	background_rect.name = "MapBackground"
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_rect.color = Color.WHITE
	background_rect.size = get_viewport_rect().size

	var shader := Shader.new()
	shader.code = MAP_BACKGROUND_SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	background_rect.material = shader_material

	background_layer.add_child(background_rect)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	if background_rect:
		background_rect.size = get_viewport_rect().size
