# llm_smoke.gd — headless-проверка временного OpenRouter LLM слоя
extends SceneTree

const Gameplay := preload("res://sim/gameplay.gd")
const OpenRouterNpc := preload("res://game/openrouter_npc.gd")


func _init() -> void:
	var gameplay := Gameplay.new()
	gameplay.setup()
	while not gameplay.has_pending_event() and gameplay.economy.tick_count < 6:
		gameplay.advance_tick()

	if not gameplay.has_pending_event():
		print("[LLM] Событие для проверки не поднялось.")
		quit(1)
		return

	var client := OpenRouterNpc.new()
	var result := client.generate_event_text(gameplay.to_llm_context())
	if result.get("ok", false):
		gameplay.set_pending_event_narrative(result["text"])
		print("[LLM] model=%s" % result.get("model", ""))
		print("[LLM] event=%s" % gameplay.pending_event_title())
		print("[LLM] text=%s" % gameplay.pending_event_body())
		quit()
	else:
		print("[LLM] fallback=%s" % result.get("error", "unknown"))
		print("[LLM] event=%s" % gameplay.pending_event_title())
		print("[LLM] text=%s" % gameplay.pending_event_body())
		quit(2)
