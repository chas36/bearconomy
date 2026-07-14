# gen_assets.gd — доступ к AI-ассетам с обязательным фолбэком.
# Файла нет — возвращаем null, вызывающий код рисует процедурно.
extends RefCounted

const ROOT := "res://ui/assets/gen"

static var _cache := {}


static func texture(relative_path: String) -> Texture2D:
	if _cache.has(relative_path):
		return _cache[relative_path]
	var path := "%s/%s" % [ROOT, relative_path]
	var result: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		result = load(path)
	_cache[relative_path] = result
	return result


static func has(relative_path: String) -> bool:
	return texture(relative_path) != null
