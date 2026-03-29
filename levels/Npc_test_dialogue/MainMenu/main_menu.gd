extends CanvasLayer



func _on_start_game_button_pressed() -> void:
	MusicController.get_node("AudioStreamPlayer2D").stop()
	GameMaster.go_to(GameMaster.Location.INTRO_CUTSCENE)


func _on_optionst_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/Npc_test_dialogue/MainMenu/options_menu.tscn")


func _on_quit_game_button_pressed() -> void:
	get_tree().quit()
