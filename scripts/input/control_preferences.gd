class_name ControlPreferences
extends RefCounted

const SECTION := "controls"
const DEFAULT_PATH := "user://control_settings.cfg"

var mode := TouchControlRouter.Mode.CLASSIC
var handedness := TouchControlRouter.Handedness.RIGHT
var path := DEFAULT_PATH

func _init(path_value := DEFAULT_PATH) -> void:
	path = path_value

func load_settings() -> void:
	mode = TouchControlRouter.Mode.CLASSIC
	handedness = TouchControlRouter.Handedness.RIGHT
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var loaded_mode = config.get_value(SECTION, "mode", mode)
	var loaded_hand = config.get_value(SECTION, "handedness", handedness)
	if loaded_mode is int and int(loaded_mode) >= TouchControlRouter.Mode.CLASSIC and int(loaded_mode) <= TouchControlRouter.Mode.SIDE:
		mode = int(loaded_mode)
	if loaded_hand is int and int(loaded_hand) >= TouchControlRouter.Handedness.RIGHT and int(loaded_hand) <= TouchControlRouter.Handedness.LEFT:
		handedness = int(loaded_hand)

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, "mode", mode)
	config.set_value(SECTION, "handedness", handedness)
	return config.save(path)
