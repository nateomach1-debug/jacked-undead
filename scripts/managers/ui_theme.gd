extends Node
## UITheme (autoload): builds ONE gym-poster Theme and sets it on the whole
## window, so every menu restyles at once. Menus can opt into special looks
## with theme_type_variation: TitleLabel, GoldLabel, SmallLabel, DangerLabel,
## GoodLabel, TagLabel, OwnedTag, LockedTag, MainButton, DangerButton,
## OwnedButton, CardPanel, CardPanelOwned, CardPanelLocked.

const BG := Color("#0e0e11")
const STEEL := Color("#1b1c21")
const STEEL_HI := Color("#23242a")
const STEEL_LO := Color("#141519")
const EDGE := Color("#2c2d34")
const BAR_IDLE := Color("#3a3a42")
const YELLOW := Color("#ffc400")
const YELLOW_HI := Color("#ffd23d")
const YELLOW_LO := Color("#e6b000")
const GREY := Color("#8a8a93")
const TEXT := Color("#e8e8ec")
const DARK_TEXT := Color("#111114")
const RED := Color("#e5484d")
const RED_DARK := Color("#2a1214")
const GREEN := Color("#3ddc84")
const GREEN_DARK := Color("#10281a")
const CHIP := Color("#26272e")

# Text feel. Set LETTER_SPACING = 0 and EMBOLDEN = 0.0 to go back to plain text.
const LETTER_SPACING: int = 2
const TITLE_SPACING: int = 5
const EMBOLDEN: float = 0.55


## Steel panel with a thin border and a colored bar on the left (buttons)
## or on the top (cards).
class PosterBox extends StyleBox:
    var bg: Color = Color("#1b1c21")
    var edge: Color = Color("#2c2d34")
    var bar: Color = Color("#3a3a42")
    var bar_top: bool = false
    var bar_size: float = 4.0
    var edge_size: float = 1.0

    func _draw(to_canvas_item: RID, rect: Rect2) -> void:
        if edge_size > 0.0:
            RenderingServer.canvas_item_add_rect(to_canvas_item, rect, edge)
        var inner: Rect2 = rect.grow(-edge_size)
        RenderingServer.canvas_item_add_rect(to_canvas_item, inner, bg)
        var strip: Rect2
        if bar_top:
            strip = Rect2(inner.position, Vector2(inner.size.x, bar_size))
        else:
            strip = Rect2(inner.position, Vector2(bar_size, inner.size.y))
        RenderingServer.canvas_item_add_rect(to_canvas_item, strip, bar)


func _ready() -> void:
    var theme: Theme = build_theme()
    get_tree().root.theme = theme
    # Also merge into the engine default theme so controls under a
    # CanvasLayer (like the game over screen) get the look too.
    var base: Theme = ThemeDB.get_default_theme()
    if base != null:
        base.merge_with(theme)
        if theme.default_font != null:
            base.default_font = theme.default_font


func build_theme() -> Theme:
    var t := Theme.new()
    var body: Font = _make_font(LETTER_SPACING, EMBOLDEN)
    var title: Font = _make_font(TITLE_SPACING, EMBOLDEN + 0.15)
    if body != null:
        t.default_font = body
    _build_labels(t, title)
    _build_buttons(t)
    _build_panels(t)
    _build_inputs(t)
    _build_scroll(t)
    _build_tabs(t)
    _build_misc(t)
    return t


# ---------- helpers ----------

func _make_font(spacing: int, embolden: float) -> Font:
    var base: Font = ThemeDB.fallback_font
    if base == null:
        return null
    var fv := FontVariation.new()
    fv.base_font = base
    fv.variation_embolden = embolden
    fv.spacing_glyph = spacing
    return fv


func _flat(bg: Color, border: Color, border_w: int, radius: int, margin: float) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(border_w)
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(margin)
    return s


func _tex(w: int, h: int, col: Color) -> ImageTexture:
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(col)
    return ImageTexture.create_from_image(img)


# ---------- labels ----------

func _build_labels(t: Theme, title: Font) -> void:
    t.set_color("font_color", "Label", TEXT)

    _label_var(t, "TitleLabel", YELLOW)
    t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.85))
    t.set_constant("shadow_offset_x", "TitleLabel", 3)
    t.set_constant("shadow_offset_y", "TitleLabel", 4)
    if title != null:
        t.set_font("font", "TitleLabel", title)

    _label_var(t, "GoldLabel", YELLOW)
    _label_var(t, "SmallLabel", GREY)
    _label_var(t, "DangerLabel", RED)
    _label_var(t, "GoodLabel", GREEN)

    _tag(t, "TagLabel", YELLOW, CHIP)
    _tag(t, "OwnedTag", GREEN, GREEN_DARK)
    _tag(t, "LockedTag", RED, RED_DARK)


func _label_var(t: Theme, type_name: String, col: Color) -> void:
    t.set_type_variation(type_name, "Label")
    t.set_color("font_color", type_name, col)


## Small price-tag chip.
func _tag(t: Theme, type_name: String, text_col: Color, bg: Color) -> void:
    _label_var(t, type_name, text_col)
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.set_corner_radius_all(2)
    s.content_margin_left = 10.0
    s.content_margin_right = 10.0
    s.content_margin_top = 4.0
    s.content_margin_bottom = 4.0
    t.set_stylebox("normal", type_name, s)


# ---------- buttons ----------

func _btn(bg: Color, edge: Color, bar: Color) -> PosterBox:
    var b := PosterBox.new()
    b.bg = bg
    b.edge = edge
    b.bar = bar
    b.bar_top = false
    b.bar_size = 4.0
    b.edge_size = 1.0
    b.content_margin_left = 14.0
    b.content_margin_right = 10.0
    b.content_margin_top = 8.0
    b.content_margin_bottom = 8.0
    return b



class BloodFocusBox extends StyleBox:
    var blood: Color = Color("#e5484d")
    var dark: Color = Color("#24090b")
    var edge_size: float = 2.0

    func _draw(to_canvas_item: RID, rect: Rect2) -> void:
        # Dark outline underneath the blood-red border.
        RenderingServer.canvas_item_add_rect(to_canvas_item, rect, dark)

        var inner := rect.grow(-edge_size)
        if inner.size.x <= 0.0 or inner.size.y <= 0.0:
            return
        RenderingServer.canvas_item_add_rect(to_canvas_item, inner, blood)

        # Dark inset keeps the red edge crisp.
        var center := inner.grow(-1.0)
        if center.size.x > 0.0 and center.size.y > 0.0:
            RenderingServer.canvas_item_add_rect(
                to_canvas_item,
                center,
                Color("#1b0d10")
            )

        # Uneven blood drips along the lower edge.
        var x := rect.position.x + 5.0
        var drip_index := 0
        while x < rect.end.x - 5.0:
            var drip_height := 3.0
            if drip_index % 3 == 0:
                drip_height = 7.0
            elif drip_index % 3 == 1:
                drip_height = 4.0

            var drip_width := 3.0
            var drip_rect := Rect2(
                Vector2(x, rect.end.y - 1.0),
                Vector2(drip_width, drip_height)
            )
            RenderingServer.canvas_item_add_rect(
                to_canvas_item,
                drip_rect,
                dark
            )
            RenderingServer.canvas_item_add_rect(
                to_canvas_item,
                drip_rect.grow(-1.0),
                blood
            )

            x += 11.0
            drip_index += 1


func _focus_box() -> StyleBox:
    return BloodFocusBox.new()



func _button_type(t: Theme, type_name: String, s: Dictionary) -> void:
    if type_name != "Button":
        t.set_type_variation(type_name, "Button")
    t.set_stylebox("normal", type_name, _btn(s["bg"], s["edge"], s["bar"]))
    t.set_stylebox("hover", type_name, _btn(s["bg_hi"], s["edge"], s["bar_lit"]))
    t.set_stylebox("pressed", type_name, _btn(s["bg_press"], s["edge"], s["bar_lit"]))
    t.set_stylebox("hover_pressed", type_name, _btn(s["bg_press"], s["edge"], s["bar_lit"]))
    t.set_stylebox("disabled", type_name, _btn(s["bg_dis"], s["edge_dis"], s["bar_dis"]))
    t.set_stylebox("focus", type_name, _focus_box())
    t.set_color("font_color", type_name, s["text"])
    t.set_color("font_hover_color", type_name, s["text_hi"])
    t.set_color("font_pressed_color", type_name, s["text_press"])
    t.set_color("font_hover_pressed_color", type_name, s["text_press"])
    t.set_color("font_focus_color", type_name, s["text"])
    t.set_color("font_disabled_color", type_name, s["text_dis"])


func _build_buttons(t: Theme) -> void:
    # Plain steel button: grey bar, lights yellow on hover/press.
    _button_type(t, "Button", {
        "bg": STEEL, "bg_hi": STEEL_HI, "bg_press": Color("#2a2b32"), "bg_dis": STEEL_LO,
        "edge": EDGE, "edge_dis": EDGE,
        "bar": BAR_IDLE, "bar_lit": YELLOW, "bar_dis": Color("#26272e"),
        "text": TEXT, "text_hi": Color.WHITE, "text_press": YELLOW, "text_dis": Color("#55555c"),
    })
    # Main action (PLAY, BUY...): solid yellow, dark text.
    _button_type(t, "MainButton", {
        "bg": YELLOW, "bg_hi": YELLOW_HI, "bg_press": YELLOW_LO, "bg_dis": Color("#4a410f"),
        "edge": YELLOW_LO, "edge_dis": Color("#4a410f"),
        "bar": Color("#14140f"), "bar_lit": Color("#14140f"), "bar_dis": Color("#2a2508"),
        "text": DARK_TEXT, "text_hi": DARK_TEXT, "text_press": DARK_TEXT, "text_dis": Color("#8a7a30"),
    })
    # Danger / locked: red bar and text.
    _button_type(t, "DangerButton", {
        "bg": STEEL, "bg_hi": STEEL_HI, "bg_press": Color("#2a2b32"), "bg_dis": STEEL_LO,
        "edge": EDGE, "edge_dis": EDGE,
        "bar": Color("#8f2a2a"), "bar_lit": RED, "bar_dis": Color("#5a2020"),
        "text": Color("#ff7b7f"), "text_hi": Color("#ff9a9d"), "text_press": RED, "text_dis": Color("#7a4446"),
    })
    # Owned: green on dark green, same look in every state.
    _button_type(t, "OwnedButton", {
        "bg": GREEN_DARK, "bg_hi": GREEN_DARK, "bg_press": GREEN_DARK, "bg_dis": GREEN_DARK,
        "edge": Color("#1d4a2e"), "edge_dis": Color("#1d4a2e"),
        "bar": GREEN, "bar_lit": GREEN, "bar_dis": GREEN,
        "text": GREEN, "text_hi": GREEN, "text_press": GREEN, "text_dis": GREEN,
    })


# ---------- panels and cards ----------

func _build_panels(t: Theme) -> void:
    t.set_stylebox("panel", "Panel", _flat(STEEL, EDGE, 1, 2, 12.0))
    t.set_stylebox("panel", "PanelContainer", _flat(STEEL, EDGE, 1, 2, 12.0))
    _card(t, "CardPanel", YELLOW)
    _card(t, "CardPanelOwned", GREEN)
    _card(t, "CardPanelLocked", RED)


## Dark card with a 3px colored strip along the top.
func _card(t: Theme, type_name: String, strip: Color) -> void:
    t.set_type_variation(type_name, "PanelContainer")
    var b := PosterBox.new()
    b.bg = Color("#16171b")
    b.edge = EDGE
    b.bar = strip
    b.bar_top = true
    b.bar_size = 3.0
    b.edge_size = 1.0
    b.content_margin_left = 14.0
    b.content_margin_right = 14.0
    b.content_margin_top = 15.0
    b.content_margin_bottom = 12.0
    t.set_stylebox("panel", type_name, b)


# ---------- text fields and sliders ----------

func _build_inputs(t: Theme) -> void:
    var normal := _flat(BG, EDGE, 1, 2, 0.0)
    normal.content_margin_left = 10.0
    normal.content_margin_right = 10.0
    normal.content_margin_top = 6.0
    normal.content_margin_bottom = 6.0
    var focus := normal.duplicate() as StyleBoxFlat
    focus.border_color = YELLOW
    var ro := normal.duplicate() as StyleBoxFlat
    ro.bg_color = STEEL_LO
    t.set_stylebox("normal", "LineEdit", normal)
    t.set_stylebox("focus", "LineEdit", focus)
    t.set_stylebox("read_only", "LineEdit", ro)
    t.set_color("font_color", "LineEdit", TEXT)
    t.set_color("font_selected_color", "LineEdit", DARK_TEXT)
    t.set_color("font_placeholder_color", "LineEdit", GREY)
    t.set_color("font_uneditable_color", "LineEdit", GREY)
    t.set_color("caret_color", "LineEdit", YELLOW)
    t.set_color("selection_color", "LineEdit", Color(1.0, 0.77, 0.0, 0.5))

    _slider(t, "HSlider", false)
    _slider(t, "VSlider", true)


func _track(col: Color, vertical: bool) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = col
    s.set_corner_radius_all(2)
    s.set_content_margin_all(0.0)
    if vertical:
        s.content_margin_left = 3.0
        s.content_margin_right = 3.0
    else:
        s.content_margin_top = 3.0
        s.content_margin_bottom = 3.0
    return s


func _slider(t: Theme, type_name: String, vertical: bool) -> void:
    t.set_stylebox("slider", type_name, _track(CHIP, vertical))
    t.set_stylebox("grabber_area", type_name, _track(YELLOW, vertical))
    t.set_stylebox("grabber_area_highlight", type_name, _track(YELLOW_HI, vertical))
    var w: int = 14
    var h: int = 26
    if vertical:
        w = 26
        h = 14
    t.set_icon("grabber", type_name, _tex(w, h, YELLOW))
    t.set_icon("grabber_highlight", type_name, _tex(w, h, YELLOW_HI))
    t.set_icon("grabber_disabled", type_name, _tex(w, h, BAR_IDLE))


# ---------- scroll bars ----------

func _build_scroll(t: Theme) -> void:
    _scrollbar(t, "VScrollBar", true)
    _scrollbar(t, "HScrollBar", false)


func _scrollbar(t: Theme, type_name: String, vertical: bool) -> void:
    var track := StyleBoxFlat.new()
    track.bg_color = STEEL_LO
    track.set_content_margin_all(0.0)
    if vertical:
        track.content_margin_left = 5.0
        track.content_margin_right = 5.0
    else:
        track.content_margin_top = 5.0
        track.content_margin_bottom = 5.0
    t.set_stylebox("scroll", type_name, track)
    t.set_stylebox("scroll_focus", type_name, track)
    t.set_stylebox("grabber", type_name, _grabber(BAR_IDLE))
    t.set_stylebox("grabber_highlight", type_name, _grabber(GREY))
    t.set_stylebox("grabber_pressed", type_name, _grabber(YELLOW))


func _grabber(col: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = col
    s.set_corner_radius_all(2)
    s.set_content_margin_all(0.0)
    return s


# ---------- tabs ----------

func _tab_box(bg: Color, strip: Color, strip_w: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = strip
    s.border_width_top = strip_w
    s.set_corner_radius_all(0)
    s.content_margin_left = 16.0
    s.content_margin_right = 16.0
    s.content_margin_top = 8.0
    s.content_margin_bottom = 8.0
    return s


func _build_tabs(t: Theme) -> void:
    for type_name in ["TabContainer", "TabBar"]:
        t.set_stylebox("tab_selected", type_name, _tab_box(STEEL, YELLOW, 3))
        t.set_stylebox("tab_unselected", type_name, _tab_box(STEEL_LO, EDGE, 1))
        t.set_stylebox("tab_hovered", type_name, _tab_box(STEEL_HI, BAR_IDLE, 1))
        t.set_stylebox("tab_disabled", type_name, _tab_box(STEEL_LO, EDGE, 1))
        t.set_color("font_selected_color", type_name, YELLOW)
        t.set_color("font_unselected_color", type_name, GREY)
        t.set_color("font_hovered_color", type_name, Color.WHITE)
        t.set_color("font_disabled_color", type_name, Color("#55555c"))
    t.set_stylebox("panel", "TabContainer", _flat(STEEL, EDGE, 1, 0, 12.0))


# ---------- progress bars, dividers, rich text ----------

func _build_misc(t: Theme) -> void:
    var bg := StyleBoxFlat.new()
    bg.bg_color = CHIP
    bg.set_corner_radius_all(2)
    bg.set_content_margin_all(3.0)
    var fill := StyleBoxFlat.new()
    fill.bg_color = YELLOW
    fill.set_corner_radius_all(2)
    fill.set_content_margin_all(3.0)
    t.set_stylebox("background", "ProgressBar", bg)
    t.set_stylebox("fill", "ProgressBar", fill)
    t.set_color("font_color", "ProgressBar", TEXT)
    t.set_color("font_outline_color", "ProgressBar", BG)
    t.set_constant("outline_size", "ProgressBar", 4)

    var hline := StyleBoxLine.new()
    hline.color = EDGE
    hline.thickness = 1
    t.set_stylebox("separator", "HSeparator", hline)
    t.set_constant("separation", "HSeparator", 12)
    var vline := StyleBoxLine.new()
    vline.color = EDGE
    vline.thickness = 1
    vline.vertical = true
    t.set_stylebox("separator", "VSeparator", vline)
    t.set_constant("separation", "VSeparator", 12)

    t.set_color("default_color", "RichTextLabel", TEXT)
