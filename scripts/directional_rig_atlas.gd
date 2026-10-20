extends RefCounted

const SHEET = preload("res://assets/characters/directional_rig.png")
static var parts: Array[AtlasTexture] = []

static func get_part(index: int) -> AtlasTexture:
	if parts.is_empty():
		_build()
	return parts[clampi(index, 0, parts.size() - 1)]

static func _build() -> void:
	var image := SHEET.get_image()
	var cell := Vector2i(image.get_width() / 4, image.get_height() / 4)
	for index in 16:
		var origin := Vector2i(index % 4, index / 4) * cell
		var used := image.get_region(Rect2i(origin, cell)).get_used_rect()
		var texture := AtlasTexture.new()
		texture.atlas = SHEET
		texture.region = Rect2(origin + used.position, used.size)
		texture.filter_clip = true
		parts.append(texture)
