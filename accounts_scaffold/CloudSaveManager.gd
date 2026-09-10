extends Node
## SCAFFOLD — não está registrado como autoload ainda. Depende do
## AuthManager (registre AuthManager primeiro). Veja AUTH_GUIDE.md.
##
## Filosofia deste script: NUNCA sobrescreve save sem ter certeza, e NUNCA
## trava o jogo por causa da internet. Toda falha de rede é silenciosa —
## o save local (que já funciona hoje, independente de tudo isso) continua
## sendo a fonte de verdade enquanto a nuvem não confirmar sync.
##
## IMPORTANTE: este script nunca referencia "AuthManager" como identificador
## direto — usa get_node_or_null("/root/AuthManager") em todo lugar. Isso é
## proposital: o Godot valida a sintaxe de TODO arquivo .gd do projeto, até
## os que não estão registrados como autoload. Se este arquivo escrevesse
## "AuthManager.algumacoisa" direto, o projeto inteiro deixaria de compilar
## assim que este arquivo entrasse na pasta scripts/autoload/ — mesmo antes
## de você registrar o AuthManager de verdade. Mantenha esse padrão ao
## completar as partes comentadas abaixo.

signal cloud_sync_complete()
signal cloud_sync_failed(reason: String)
## A UI deve escutar esse sinal e perguntar pro jogador qual save manter —
## nunca decida programaticamente qual dos dois "vale mais".
signal conflict_detected(local_summary: Dictionary, cloud_summary: Dictionary)

const SYNC_INTERVAL_SECONDS := 5.0

# var _firestore # referência ao node Firestore (filho do node Firebase na cena)
var _sync_accum: float = 0.0
var _pending_cloud_data: Dictionary = {}


func _get_auth_manager() -> Node:
	return get_node_or_null("/root/AuthManager")

func _is_signed_in() -> bool:
	var am := _get_auth_manager()
	return am != null and am.get("is_signed_in") == true

func _current_uid() -> String:
	var am := _get_auth_manager()
	return str(am.get("current_uid")) if am != null else ""


func _ready() -> void:
	# _firestore = get_node("/root/Firebase/Firestore")
	var am := _get_auth_manager()
	if am:
		if am.has_signal("signed_in"):
			am.connect("signed_in", _on_signed_in)
		if am.has_signal("signed_out"):
			am.connect("signed_out", _on_signed_out)


func _process(delta: float) -> void:
	if not _is_signed_in():
		return
	_sync_accum += delta
	if _sync_accum >= SYNC_INTERVAL_SECONDS:
		_sync_accum = 0.0
		upload_save()


func _on_signed_in(uid: String, _display_name: String) -> void:
	_check_and_resolve(uid)

func _on_signed_out() -> void:
	_sync_accum = 0.0


## Chamado uma vez logo após o login. Decide se sobe, baixa, ou pergunta.
func _check_and_resolve(uid: String) -> void:
	# var cloud_doc = await _firestore.get_document("saves/%s" % uid)
	# if cloud_doc == null or cloud_doc.is_empty():
	# 	upload_save()  # não existe save na nuvem ainda — sobe o local sem perguntar
	# 	return
	#
	# var cloud_data: Dictionary = cloud_doc.data
	# var local_data: Dictionary = GameState.serialize()
	#
	# var local_progress: float = local_data.get("lifetime_coins", 0.0)
	# var cloud_progress: float = cloud_data.get("lifetime_coins", 0.0)
	#
	# # Diferença pequena (ex: mesma sessão, só re-logou) — não incomoda o
	# # jogador com uma pergunta por uma diferença insignificante.
	# if abs(local_progress - cloud_progress) < max(local_progress, cloud_progress) * 0.05:
	# 	upload_save()
	# 	return
	#
	# _pending_cloud_data = cloud_data
	# conflict_detected.emit(
	# 	{"lifetime_coins": local_progress},
	# 	{"lifetime_coins": cloud_progress}
	# )
	pass


## Chame isso a partir da UI depois que o jogador escolher no diálogo de conflito.
func resolve_conflict(keep_local: bool) -> void:
	if keep_local:
		upload_save()
	else:
		_apply_cloud_data(_pending_cloud_data)
	_pending_cloud_data = {}


func upload_save() -> void:
	if not _is_signed_in():
		return
	var data := GameState.serialize()
	# _firestore.set_document("saves/%s" % _current_uid(), data, func(success):
	# 	if success: cloud_sync_complete.emit()
	# 	else: cloud_sync_failed.emit("upload failed")
	# )


func _apply_cloud_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	# GameState já expõe apply_save_data(dict) — a mesma função que usa pra
	# carregar o save local, reaproveitada aqui pros dados vindos da nuvem.
	GameState.apply_save_data(data)
	GameState.save_game() # garante que o que veio da nuvem também fica local
	cloud_sync_complete.emit()


## Apaga o save na nuvem — chame isso a partir de AuthManager.delete_account(),
## nunca sozinho (a conta em si também precisa ser excluída, não só o save).
func delete_cloud_save(uid: String) -> void:
	pass
	# _firestore.delete_document("saves/%s" % uid)
