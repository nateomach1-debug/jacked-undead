extends Control
## Achievements screen: progress bars for every achievement and the reticle rewards.

const ACH_PATH: String = "res://scripts/managers/achievements.gd"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "ACHIEVEMENTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer.add_child(title)

	var script = load(ACH_PATH)
	var ach = null
	if script != null:
		ach = script.new()

	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 22)
	outer.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	if ach == null:
		summary.text = "ACHIEVEMENTS FAILED TO LOAD"
		summary.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		var done: int = 0
		for id in ach.ids():
			if ach.is_unlocked(str(id)):
				done += 1
			_add_row(list, ach, str(id))
		summary.text = "%d / %d unlocked   |   Reticles: %d / %d" % [
			done, ach.ids().size(), ach.unlocked_reticles().size(), ach.RETICLES.size()]

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(queue_free)
	outer.add_child(back)


func _add_row(list: VBoxContainer, ach, id: String) -> void:
	var unlocked: bool = ach.is_unlocked(id)
	var target: int = ach.target(id)
	var progress: int = mini(ach.progress(id), target)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	list.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var name_l := Label.new()
	name_l.text = ach.title(id)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 24)
	if unlocked:
		name_l.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	head.add_child(name_l)
	var status := Label.new()
	status.text = "UNLOCKED" if unlocked else "%d / %d" % [progress, target]
	status.add_theme_font_size_override("font_size", 22)
	if unlocked:
		status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	head.add_child(status)

	var desc := Label.new()
	desc.text = ach.description(id)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	box.add_child(desc)

	var reward: String = ach.reward_text(id)
	if reward != "":
		var r := Label.new()
		r.text = reward
		r.add_theme_font_size_override("font_size", 16)
		r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		box.add_child(r)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(target)
	bar.value = float(progress)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	box.add_child(bar)
