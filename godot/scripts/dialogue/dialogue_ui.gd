class_name DialogueUI
extends Control

signal choice_selected(choice_id: String)
signal portrait_changed(portrait: Dictionary)
signal dialogue_result(result: Dictionary)

const PortraitControllerScript = preload("res://scripts/dialogue/portrait_controller.gd")

var director: DialogueDirector
var speaker_label: Label
var line_label: Label
var choice_box: VBoxContainer
var continue_button: Button
var portrait_path := ""


func _ready() -> void:
	_build_minimal_surface()


func bind_director(value: DialogueDirector) -> void:
	director = value
	if not director.node_changed.is_connected(_on_node_changed):
		director.node_changed.connect(_on_node_changed)
	if not director.dialogue_finished.is_connected(_on_dialogue_finished):
		director.dialogue_finished.connect(_on_dialogue_finished)
	var node := director.current_node()
	if not node.is_empty():
		_render_node(node)


func _build_minimal_surface() -> void:
	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	speaker_label = Label.new()
	speaker_label.name = "Speaker"
	speaker_label.add_theme_font_size_override("font_size", 22)
	column.add_child(speaker_label)
	line_label = Label.new()
	line_label.name = "Line"
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size = Vector2(0, 120)
	line_label.add_theme_font_size_override("font_size", 18)
	column.add_child(line_label)
	choice_box = VBoxContainer.new()
	choice_box.name = "Choices"
	choice_box.add_theme_constant_override("separation", 8)
	column.add_child(choice_box)
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = "继续"
	continue_button.pressed.connect(_on_continue_pressed)
	column.add_child(continue_button)


func _on_node_changed(node: Dictionary) -> void:
	_render_node(node)


func _render_node(node: Dictionary) -> void:
	if speaker_label == null:
		return
	var speaker_id := str(node.get("speaker_id", "旁白"))
	var portrait := PortraitControllerScript.resolve(speaker_id,
			str(node.get("outfit", "default")), str(node.get("expression", "")))
	speaker_label.text = str(portrait.get("display_name", speaker_id))
	line_label.text = str(node.get("text", ""))
	portrait_path = str(portrait.get("portrait_path", ""))
	portrait_changed.emit(portrait.duplicate(true))
	for child in choice_box.get_children():
		child.queue_free()
	var is_choice := str(node.get("type", "")) == "choice"
	continue_button.visible = not is_choice
	if is_choice and director != null:
		for choice in director.choices():
			var button := Button.new()
			button.text = str(choice.get("text", "继续"))
			button.disabled = not bool(choice.get("available", true))
			button.set_meta("choice_id", str(choice.get("id", "")))
			button.pressed.connect(_on_choice_pressed.bind(button))
			choice_box.add_child(button)


func _on_choice_pressed(button: Button) -> void:
	if director == null:
		return
	var choice_id := str(button.get_meta("choice_id", ""))
	choice_selected.emit(choice_id)
	director.choose(choice_id)


func _on_continue_pressed() -> void:
	if director != null:
		director.advance()


func _on_dialogue_finished(result: Dictionary) -> void:
	dialogue_result.emit(result.duplicate(true))
