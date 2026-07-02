# openrouter_npc.gd — временный LLM-NPC слой поверх OpenRouter
extends RefCounted

const EnvLoader := preload("res://game/env_loader.gd")

const API_HOST := "openrouter.ai"
const API_PORT := 443
const CHAT_COMPLETIONS_PATH := "/api/v1/chat/completions"
const DEFAULT_CA_BUNDLE := "/etc/ssl/cert.pem"
const CONNECT_TIMEOUT_MS := 8000
const RESPONSE_TIMEOUT_MS := 30000
const MAX_EVENT_TEXT_CHARS := 900


func generate_event_text(llm_context: Dictionary) -> Dictionary:
	var config := EnvLoader.openrouter_config()
	var api_key: String = config.get("api_key", "")
	if api_key.is_empty():
		return _failure("OPENROUTER_API_KEY не задан.")

	var payload := {
		"model": config.get("model", EnvLoader.DEFAULT_OPENROUTER_MODEL),
		"messages":
		[
			{"role": "system", "content": _system_prompt()},
			{"role": "user", "content": _user_prompt(llm_context)},
		],
		"temperature": 0.75,
		"max_tokens": 220,
	}

	var response := _post_json(api_key, payload)
	if not response.get("ok", false):
		return response

	var parsed = JSON.parse_string(response["body"])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("OpenRouter вернул не JSON.")

	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		return _failure("OpenRouter не вернул вариантов ответа.")

	var message: Dictionary = choices[0].get("message", {})
	var content := _message_content_to_text(message.get("content", ""))
	if content.is_empty():
		return _failure("OpenRouter вернул пустой текст.")

	return {
		"ok": true,
		"text": content.left(MAX_EVENT_TEXT_CHARS),
		"model": parsed.get("model", payload["model"]),
	}


func _post_json(api_key: String, payload: Dictionary) -> Dictionary:
	var client := HTTPClient.new()
	var connected := _connect_client(client)
	if not connected.get("ok", false):
		return connected

	var sent := _send_request(client, api_key, payload)
	if not sent.get("ok", false):
		client.close()
		return sent

	var response := _read_response(client)
	client.close()
	return response


func _connect_client(client: HTTPClient) -> Dictionary:
	var err := client.connect_to_host(API_HOST, API_PORT, _tls_options())
	if err != OK:
		return _failure("Не удалось начать TLS-соединение с OpenRouter: %d." % err)

	var connect_deadline := Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		if Time.get_ticks_msec() > connect_deadline:
			client.close()
			return _failure("Таймаут соединения с OpenRouter.")
		OS.delay_msec(50)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return _failure("OpenRouter недоступен.")

	return {"ok": true}


func _send_request(client: HTTPClient, api_key: String, payload: Dictionary) -> Dictionary:
	var headers := [
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
		"HTTP-Referer: https://local.bearconomy",
		"X-Title: Bearconomy Demidov Prototype",
	]
	var err := client.request(
		HTTPClient.METHOD_POST, CHAT_COMPLETIONS_PATH, headers, JSON.stringify(payload)
	)
	if err != OK:
		return _failure("Не удалось отправить запрос в OpenRouter.")
	return {"ok": true}


func _read_response(client: HTTPClient) -> Dictionary:
	var body := PackedByteArray()
	var response_deadline := Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() > response_deadline:
			return _failure("Таймаут ожидания OpenRouter.")
		OS.delay_msec(50)

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(50)
		else:
			body.append_array(chunk)
		if Time.get_ticks_msec() > response_deadline:
			return _failure("Таймаут чтения ответа OpenRouter.")

	var code := client.get_response_code()
	var text := body.get_string_from_utf8()
	if code < 200 or code >= 300:
		return _failure("OpenRouter вернул HTTP %d: %s" % [code, text.left(180)])

	return {"ok": true, "body": text}


func _tls_options() -> TLSOptions:
	var cert := X509Certificate.new()
	if cert.load(DEFAULT_CA_BUNDLE) == OK:
		return TLSOptions.client(cert)
	return TLSOptions.client()


func _message_content_to_text(content) -> String:
	if typeof(content) == TYPE_STRING:
		return content.strip_edges()
	if typeof(content) == TYPE_ARRAY:
		var parts: Array[String] = []
		for item in content:
			if typeof(item) == TYPE_DICTIONARY and item.get("type", "") == "text":
				parts.append(str(item.get("text", "")).strip_edges())
		return "\n".join(parts).strip_edges()
	return str(content).strip_edges()


func _system_prompt() -> String:
	return (
		"Ты временный narrative renderer экономического симулятора о петровской "
		+ "и раннепослепетровской России 1700-1745 годов. "
		+ "Игрок вдохновлён домом Антуфьевых-Демидовых, но не обязан быть "
		+ "буквально Никитой или Акинфием. "
		+ "Пиши живым русским языком: жёсткий деловой XVIII век без клюквы "
		+ "и тяжёлого канцелярита. "
		+ "Не меняй правила, числа, эффекты и варианты выбора. "
		+ "Не называй внутренние эффекты баллами, параметрами или JSON-полями. "
		+ "Не добавляй новых исторических фактов как канон. "
		+ "Верни только описание текущего события на 2-4 коротких предложения."
	)


func _user_prompt(llm_context: Dictionary) -> String:
	return "Контекст события и состояния симуляции:\n%s" % JSON.stringify(llm_context)


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"text": "",
		"error": message,
	}
