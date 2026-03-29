extends Control

func _ready() -> void:
	# Meniul trebuie să fie ascuns când pornește nivelul
	hide()
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # "ui_cancel" este tasta ESC by default
		toggle_pause()
func toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused # Arată meniul dacă e pauză, ascunde-l dacă nu
func _on_back_to_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://levels/Npc_test_dialogue/MainMenu/main_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	toggle_pause()
