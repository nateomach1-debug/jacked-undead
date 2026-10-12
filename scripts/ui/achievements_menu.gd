extends Control
## Achievements screen: progress bars for every achievement and the reticle rewards.

const ACH_PATH: String = "res://scripts/managers/achievements.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"


## Flat progress bar: yellow while in progress, green when unlocked.
class ProgressStrip extends Control:
    var frac: float = 0.0
    var done: bool = false

    func _init() -> void:
        custom_minimum_size = Vector2(0, 14)
        size_flags_horizontal = Control.SIZE_EXPAND_FILL

    func _draw() -> void:
        var w: float = size.x
        var h: float = size.y
        draw_rect(Rect2(0, 0, w, h), Color(0.106, 0.110, 0.130))
        var col: Color = Color(0.3, 0.85, 0.35) if done else Color(1.0, 0.769, 0.0)
        draw_rect(Rect2(0, 0, w * clampf(frac, 0.0, 1.0), h), col)
        draw_rect(Rect2(0, 0, w, h), Color(0.25, 0.26, 0.30), false, 1.0)


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    var bd_script = load(BACKDROP_PATH)
    var bd = null
    if bd_script != null:
        bd = bd_script.new()
    if bd is Control:
        add_child(bd)
        (bd as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        var bg := ColorRect.new()
        bg.color = Color(0.055, 0.055, 0.067, 1.0)
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
    title.theme_type_variation = "TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outer.add_child(title)

    var dv_script = load(DIVIDER_PATH)
    if dv_script != null:
        var dv = dv_script.new()
        if dv is Control:
            outer.add_child(dv)

    var script = load(ACH_PATH)
    var ach = null
    if script != null:
        ach = script.new()

    var summary := Label.new()
    summary.theme_type_variation = "GoldLabel"
    summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outer.add_child(summary)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 10)
    scroll.add_child(list)

    if ach == null:
        summary.text = "ACHIEVEMENTS FAILED TO LOAD"
        summary.theme_type_variation = "DangerLabel"
    else:
        var done: int = 0
        for id in ach.ids():
            if ach.is_unlocked(str(id)):
                done += 1
            _add_row(list, ach, str(id))
        summary.text = "%d / %d UNLOCKED   |   RETICLES: %d / %d" % [
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

    var panel := PanelContainer.new()
    panel.theme_type_variation = "CardPanelOwned" if unlocked else "CardPanel"
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_child(panel)

    var pad := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        pad.add_theme_constant_override("margin_" + side, 12)
    panel.add_child(pad)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    pad.add_child(box)

    var head := HBoxContainer.new()
    box.add_child(head)
    var name_l := Label.new()
    name_l.text = str(ach.title(id)).to_upper()
    name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if unlocked:
        name_l.theme_type_variation = "GoodLabel"
    else:
        name_l.add_theme_font_size_override("font_size", 24)
    head.add_child(name_l)
    var status := Label.new()
    status.text = "UNLOCKED" if unlocked else "%d / %d" % [progress, target]
    if unlocked:
        status.theme_type_variation = "OwnedTag"
    else:
        status.theme_type_variation = "TagLabel"
    head.add_child(status)

    var desc := Label.new()
    desc.text = ach.description(id)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.theme_type_variation = "SmallLabel"
    box.add_child(desc)

    var reward: String = ach.reward_text(id)
    if reward != "":
        var r := Label.new()
        r.text = reward
        r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        r.theme_type_variation = "GoldLabel"
        r.add_theme_font_size_override("font_size", 16)
        box.add_child(r)

    var bar := ProgressStrip.new()
    bar.frac = float(progress) / maxf(float(target), 1.0)
    bar.done = unlocked
    box.add_child(bar)
