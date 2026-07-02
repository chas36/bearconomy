# env_loader.gd — чтение локальных настроек без вывода секретов
extends RefCounted

const DEFAULT_OPENROUTER_MODEL := "openai/gpt-oss-20b:free"


static func openrouter_config() -> Dictionary:
	var file_values := _read_env_file("res://.env")
	var api_key := OS.get_environment("OPENROUTER_API_KEY")
	if api_key.is_empty():
		api_key = file_values.get("OPENROUTER_API_KEY", "")

	var model := OS.get_environment("OPENROUTER_MODEL")
	if model.is_empty():
		model = file_values.get("OPENROUTER_MODEL", DEFAULT_OPENROUTER_MODEL)

	return {
		"api_key": api_key.strip_edges(),
		"model": model.strip_edges(),
	}


static func _read_env_file(path: String) -> Dictionary:
	var result := {}
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return result

	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return result

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or not line.contains("="):
			continue

		var split_at := line.find("=")
		var key := line.substr(0, split_at).strip_edges()
		var value := line.substr(split_at + 1).strip_edges()
		if value.length() >= 2 and value.begins_with('"') and value.ends_with('"'):
			value = value.substr(1, value.length() - 2)
		if not key.is_empty():
			result[key] = value

	return result
