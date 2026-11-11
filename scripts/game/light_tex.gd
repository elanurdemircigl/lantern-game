class_name LightTex
extends RefCounted
## Tüm ışıkların paylaştığı radyal gradyan dokusu ve ışık oluşturma yardımcısı.
##
## Işık maskeleri:
##   katman 1 = zemin ve varlıklar (duvar gölgesi düşer)
##   katman 2 = duvarlar (aydınlanır ama kendi üzerine gölge düşmez)

const TEXTURE_SIZE := 256

static var _texture: GradientTexture2D


static func texture() -> Texture2D:
	if _texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_texture = GradientTexture2D.new()
		_texture.gradient = g
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
	return _texture


static func make_light(color: Color, scale: float, energy: float, shadows := true) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = texture()
	l.color = color
	l.texture_scale = scale
	l.energy = energy
	l.range_item_cull_mask = 1 | 2
	l.shadow_enabled = shadows
	l.shadow_item_cull_mask = 1
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_filter_smooth = 1.5
	return l


## Karanlıktan etkilenmeyen (her zaman görünen) çizimler için malzeme.
static func unshaded_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m
