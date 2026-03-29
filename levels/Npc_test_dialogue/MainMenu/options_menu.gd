extends Control

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/Npc_test_dialogue/MainMenu/main_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()



	
