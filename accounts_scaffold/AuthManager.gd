extends Node
## SCAFFOLD — não está registrado como autoload ainda.
##
## Ponto de partida pra login com Apple/Google via Firebase Auth. Veja
## AUTH_GUIDE.md pro passo a passo completo (criar projeto Firebase,
## configurar Sign In with Apple do lado da Apple, instalar o plugin).
##
## As classes Firebase/FirebaseAuth só existem DEPOIS de instalar o
## plugin "Firebase Plugin" (autor: cengiz) pelo AssetLib e ativar em
## Projeto > Configurações do Projeto > Plugins.
##
## Depois de instalar o plugin:
##   1. mova este arquivo pra res://scripts/autoload/AuthManager.gd
##   2. registre como autoload "AuthManager"
##   3. confirme os nomes exatos dos métodos/sinais na documentação do
##      plugin — pode ter mudado desde que este scaffold foi escrito

signal signed_in(uid: String, display_name: String)
signal signed_out()
signal auth_error(reason: String)

var current_uid: String = ""
var current_display_name: String = ""
var is_signed_in: bool:
	get: return current_uid != ""

# var _firebase_auth # referência ao node FirebaseAuth (filho do node Firebase na cena)


func _ready() -> void:
	# _firebase_auth = get_node("/root/Firebase/FirebaseAuth")  # ajuste o caminho conforme sua cena
	# _firebase_auth.auth_state_changed.connect(_on_auth_state_changed)
	# _firebase_auth.sign_in_failed.connect(_on_sign_in_failed)
	#
	# Entra anônimo automaticamente se ninguém nunca logou — isso dá um uid
	# estável mesmo pra quem "joga como convidado", o que facilita migrar
	# pra uma conta de verdade depois sem perder o progresso (ver
	# link_with_apple/link_with_google abaixo, em vez de sign_in do zero).
	# if _firebase_auth.current_user == null:
	# 	_firebase_auth.sign_in_anonymously()
	pass


func sign_in_with_apple() -> void:
	# O token de identidade da Apple precisa vir do fluxo nativo
	# (AuthenticationServices no iOS) — o plugin cuida disso por baixo.
	# _firebase_auth.sign_in_with_apple()
	pass


func sign_in_with_google() -> void:
	# _firebase_auth.sign_in_with_google()
	pass


## Chame isso em vez de sign_in_with_* quando o jogador já está "logado"
## anônimo (guest) e quer transformar essa conta numa de verdade, SEM
## perder o progresso que já estava vinculado ao uid anônimo.
func link_with_apple() -> void:
	# _firebase_auth.link_with_apple()
	pass

func link_with_google() -> void:
	# _firebase_auth.link_with_google()
	pass


func sign_out() -> void:
	# _firebase_auth.sign_out()
	current_uid = ""
	current_display_name = ""
	signed_out.emit()


## Obrigatório pela política da Apple assim que o app tiver criação de
## conta: precisa dar pra excluir a conta e os dados de dentro do app,
## não só por e-mail. Implemente chamando o delete do FirebaseAuth E
## apagando o documento em saves/{uid} no Firestore antes de deslogar.
func delete_account() -> void:
	# _firebase_auth.delete_user()
	# CloudSaveManager.delete_cloud_save(current_uid)
	pass


func _on_auth_state_changed(user) -> void:
	if user == null:
		current_uid = ""
		current_display_name = ""
		return
	current_uid = user.uid
	current_display_name = user.get("display_name", "")
	signed_in.emit(current_uid, current_display_name)


func _on_sign_in_failed(reason: String) -> void:
	auth_error.emit(reason)
