extends RefCounted
## Builds the Glutamine and Collagen perk icons next to the existing HUD icons.

const ICONS: Dictionary = {
    "glutamine": "res://resources/icons/glutamine.svg",
    "collagen": "res://resources/icons/collagen.svg",
}


static func make_icon(bar: Node, template: TextureRect, id: String) -> TextureRect:
    var icon := TextureRect.new()
    icon.name = id.capitalize()
    icon.custom_minimum_size = template.custom_minimum_size
    icon.expand_mode = template.expand_mode
    icon.stretch_mode = template.stretch_mode
    icon.size_flags_horizontal = template.size_flags_horizontal
    icon.size_flags_vertical = template.size_flags_vertical
    icon.size = template.size
    var path: String = ICONS.get(id, "")
    if path != "" and ResourceLoader.exists(path):
        icon.texture = load(path) as Texture2D
    bar.add_child(icon)
    return icon
