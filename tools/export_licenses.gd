extends SceneTree

func _initialize() -> void:
	var notices:=FileAccess.open("res://web/GODOT_THIRD_PARTY.json",FileAccess.WRITE)
	notices.store_string(JSON.stringify({"components":Engine.get_copyright_info(),"licenses":Engine.get_license_info()},"  "))
	quit()
