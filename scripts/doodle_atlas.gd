extends RefCounted

const SHEET = preload("res://assets/characters/doodle_layers.png")
static var parts: Array[AtlasTexture] = []

static func get_part(index: int) -> AtlasTexture:
	if parts.is_empty():
		var source := SHEET.get_image()
		var cell := Vector2i(source.get_width() / 3, source.get_height() / 3)
		for i in 9:
			var origin := Vector2i(i % 3, i / 3) * cell
			var used := source.get_region(Rect2i(origin, cell)).get_used_rect()
			var part := AtlasTexture.new()
			part.atlas = SHEET
			part.region = Rect2(origin + used.position, used.size)
			part.filter_clip = true
			parts.append(part)
	return parts[index]
