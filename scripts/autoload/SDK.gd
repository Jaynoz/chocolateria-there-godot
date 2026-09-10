extends Node
## Autoload "SDK" — camada única entre o jogo e as plataformas.
##
## POR QUE ISSO EXISTE
## O jogo precisa rodar em iPhone/iPad (App Store), Android (Play Store) e
## Google Play Games para PC. Cada uma dessas tem SDK próprio pra anúncio,
## compra, login e save na nuvem, e nenhum deles existe dentro do Godot
## puro — são plugins que você instala depois (AdMob, godot-iap, etc.).
##
## Se a UI chamasse esses plugins direto, o jogo quebraria em toda
## plataforma onde o plugin não está instalado, e você teria `if
## OS.get_name() == ...` espalhado por todo canto. Este arquivo resolve
## isso: a UI chama SEMPRE o SDK, e o SDK decide o que fazer:
##
##   plugin instalado      → usa o plugin de verdade
##   plugin não instalado  → cai num modo de demonstração seguro e avisa
##                           no console; o jogo continua rodando
##
## Ou seja: dá pra desenvolver e testar no PC sem nenhum plugin, publicar
## na Play com AdMob, e publicar na App Store com StoreKit, sem tocar em
## uma linha da UI.
##
## COMO REGISTRAR
## Já está em project.godot como autoload, DEPOIS de GameState (ele lê
## GameState.no_ads e salva o jogo em alguns eventos de ciclo de vida).
##
## COMO LIGAR OS PLUGINS DE VERDADE (quando chegar a hora)
## 1. instale o plugin pelo AssetLib
## 2. mova monetization_scaffold/AdManager.gd → scripts/autoload/AdManager.gd
##    (idem StoreManager, AuthManager, CloudSaveManager) e registre como
##    autoload
## 3. pronto — este arquivo detecta sozinho e passa a delegar pra eles.
##    Nada na UI muda.

signal rewarded_ad_finished(reward_id: String, granted: bool)
signal purchase_finished(product_id: String, success: bool, message: String)
signal auth_changed(signed_in: bool, display_name: String)
signal cloud_save_loaded(data: Dictionary)
signal app_paused()
signal app_resumed()
signal display_mode_changed(is_desktop: bool)

enum Platform { IOS, ANDROID, ANDROID_PC, WINDOWS, MACOS, LINUX, WEB, UNKNOWN }

## Loja onde o build vai ser distribuído — muda o texto de alguns botões e
## quais métodos de login aparecem.
enum Store { APP_STORE, PLAY_STORE, PLAY_GAMES_PC, NONE }

const STORE_URL := "https://therechocolates.com.br/"

## Limite de FPS por plataforma. No celular, deixar solto só esquenta o
## aparelho e come bateria num jogo de tabuleiro estático como este.
const MAX_FPS_MOBILE := 60
const MAX_FPS_PC := 0    # 0 = sem limite, deixa o v-sync mandar

var platform: Platform = Platform.UNKNOWN
var store: Store = Store.NONE
var verbose := true      # imprime no console o que o SDK está fazendo/simulando

var _ad_manager: Node = null
var _store_manager: Node = null
var _auth_manager: Node = null
var _cloud_manager: Node = null


# =========================================================================
# CICLO DE VIDA
# =========================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # ciclo de vida do app não pode parar no menu de pausa
	platform = _detect_platform()
	store = _detect_store()
	Engine.max_fps = MAX_FPS_MOBILE if is_mobile() else MAX_FPS_PC
	_rebind_managers()
	apply_display_mode()
	_log("plataforma=%s loja=%s tela=%s" % [platform_name(), store_name(), effective_display_mode()])
	_log("anúncios=%s compras=%s login=%s nuvem=%s" % [
		"plugin" if has_ads() else "demo",
		"plugin" if has_iap() else "demo",
		"plugin" if has_auth() else "demo",
		"plugin" if has_cloud_save() else "demo",
	])

## Os managers são autoloads opcionais — podem não existir. Guardar a
## referência uma vez evita um get_node por frame (a UI consultava o
## AuthManager a cada quadro antes desta camada existir).
func _rebind_managers() -> void:
	_ad_manager = get_node_or_null("/root/AdManager")
	_store_manager = get_node_or_null("/root/StoreManager")
	_auth_manager = get_node_or_null("/root/AuthManager")
	_cloud_manager = get_node_or_null("/root/CloudSaveManager")

	if _store_manager and _store_manager.has_signal("purchase_succeeded"):
		if not _store_manager.purchase_succeeded.is_connected(_on_plugin_purchase_ok):
			_store_manager.purchase_succeeded.connect(_on_plugin_purchase_ok)
			_store_manager.purchase_failed.connect(_on_plugin_purchase_fail)

	if _auth_manager and _auth_manager.has_signal("signed_in"):
		if not _auth_manager.signed_in.is_connected(_on_plugin_signed_in):
			_auth_manager.signed_in.connect(_on_plugin_signed_in)
			_auth_manager.signed_out.connect(_on_plugin_signed_out)

	if _ad_manager and _ad_manager.has_signal("rewarded_completed"):
		if not _ad_manager.rewarded_completed.is_connected(_on_plugin_ad_completed):
			_ad_manager.rewarded_completed.connect(_on_plugin_ad_completed)

## Android e iOS matam o app em segundo plano sem aviso. Estes sinais são o
## único momento garantido pra salvar — por isso o GameState escuta eles.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			app_paused.emit()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			app_resumed.emit()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			app_paused.emit()


# =========================================================================
# DETECÇÃO DE PLATAFORMA
# =========================================================================

func _detect_platform() -> Platform:
	match OS.get_name():
		"iOS":
			return Platform.IOS
		"Android":
			# Google Play Games para PC roda o MESMO APK do celular dentro de
			# um emulador x86_64 no Windows. Do lado do jogo continua sendo
			# "Android", mas sem tela de toque e com teclado — o que muda o
			# layout ideal e alguns textos ("toque" vs "clique").
			return Platform.ANDROID_PC if _looks_like_play_games_pc() else Platform.ANDROID
		"Windows":
			return Platform.WINDOWS
		"macOS":
			return Platform.MACOS
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return Platform.LINUX
		"Web":
			return Platform.WEB
	return Platform.UNKNOWN

## Heurística — o Google não expõe uma flag oficial acessível pelo Godot.
## Um Android x86_64 sem tela de toque é, na prática, Play Games para PC
## (ou um Chromebook, que também roda em janela e tem teclado: o mesmo
## tratamento serve pros dois).
func _looks_like_play_games_pc() -> bool:
	if DisplayServer.is_touchscreen_available():
		return false
	var arch := Engine.get_architecture_name()
	return arch.contains("x86")

func platform_name() -> String:
	return ["iOS", "Android", "Android PC", "Windows", "macOS", "Linux", "Web", "?"][platform]

func store_name() -> String:
	return ["App Store", "Play Store", "Play Games PC", "nenhuma"][store]

func _detect_store() -> Store:
	match platform:
		Platform.IOS:
			return Store.APP_STORE
		Platform.ANDROID:
			return Store.PLAY_STORE
		Platform.ANDROID_PC:
			return Store.PLAY_GAMES_PC
	return Store.NONE

func is_mobile() -> bool:
	return platform == Platform.IOS or platform == Platform.ANDROID

## "Parece PC": tela grande, teclado, mouse, janela redimensionável. Vale
## pro Play Games para PC, pro desktop e pro Chromebook.
func is_pc_like() -> bool:
	return effective_display_mode() == "desktop"

## O que o aparelho parece ser, ignorando a escolha manual do jogador.
func detected_display_mode() -> String:
	if platform in [Platform.ANDROID_PC, Platform.WINDOWS, Platform.MACOS, Platform.LINUX]:
		return "desktop"
	if platform == Platform.WEB:
		return "mobile" if DisplayServer.is_touchscreen_available() else "desktop"
	return "mobile"

## O modo que vale de fato: a escolha do jogador no menu de pausa vence a
## detecção automática. Um tablet Android ligado num monitor, ou um celular
## num navegador de desktop, são casos que a detecção erra e o jogador
## consegue corrigir na mão.
func effective_display_mode() -> String:
	if GameState.display_mode == "auto":
		return detected_display_mode()
	return GameState.display_mode

## Reaplica escala da interface e qualidade de textura. Chamado no início e
## toda vez que o jogador troca a opção no menu de pausa.
func apply_display_mode() -> void:
	var desktop := effective_display_mode() == "desktop"
	var win := get_window()

	# No desktop a interface fica ~25% maior: alvo de mouse é mais preciso
	# que o dedo, mas a tela está bem mais longe dos olhos.
	win.content_scale_factor = 1.25 if desktop else 1.0

	# Qualidade por tela. As imagens dos itens têm 256px:
	#  - celular: desenhadas a ~70px, uma redução forte. Sem mipmap isso
	#    serrilha e "ferve" durante as animações de fusão.
	#  - desktop: desenhadas bem maiores, mipmap só borraria à toa.
	var filtro := (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR if desktop
		else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	)
	get_viewport().canvas_item_default_texture_filter = filtro

	# Numa janela de verdade (desktop, Play Games para PC), abre num tamanho
	# confortável em vez de herdar os 420x900 pensados pra celular.
	if desktop and not is_mobile():
		var tela := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var alvo := Vector2i(560, mini(1040, tela.size.y - 80))
		if win.size.x < alvo.x or win.size.y < alvo.y:
			win.size = alvo
			win.move_to_center()

	display_mode_changed.emit(desktop)

func has_touch() -> bool:
	if GameState.display_mode == "desktop":
		return false
	if GameState.display_mode == "mobile":
		return true
	return DisplayServer.is_touchscreen_available()

## Texto de instrução que muda conforme o aparelho, pra não escrever
## "toque" em quem está de mouse na mão.
func tap_word() -> String:
	return tr("toque") if has_touch() else tr("clique")

## Área útil da tela descontando notch, ilha dinâmica, câmera furada e a
## barra de gestos. Sem isso, o topo da UI fica embaixo do notch no iPhone
## e a base fica embaixo da barra do Android 15 (que força edge-to-edge).
## Os valores voltam em UNIDADES DA VIEWPORT (as mesmas 420x900 em que a
## UI é montada), não em pixels de tela. O notch de um iPhone tem ~130px
## reais; aplicar esse número cru numa viewport de 420 de largura empurraria
## a interface pra fora da tela.
func safe_area_margins() -> Dictionary:
	var zero := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if not is_mobile():
		return zero

	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0 or win.x <= 0 or win.y <= 0:
		return zero

	var view := get_viewport().get_visible_rect().size
	var sx := view.x / float(win.x)
	var sy := view.y / float(win.y)

	return {
		"left": int(maxi(0, safe.position.x) * sx),
		"top": int(maxi(0, safe.position.y) * sy),
		"right": int(maxi(0, win.x - (safe.position.x + safe.size.x)) * sx),
		"bottom": int(maxi(0, win.y - (safe.position.y + safe.size.y)) * sy),
	}

## Vibração curta de retorno tátil. Só faz sentido no celular; no PC é
## ignorado silenciosamente.
func haptic(ms: int = 20) -> void:
	if is_mobile():
		Input.vibrate_handheld(ms)


# =========================================================================
# ANÚNCIOS
# =========================================================================

func has_ads() -> bool:
	return _ad_manager != null

## `true` se dá pra mostrar um anúncio premiado agora. Falso se o jogador
## comprou "sem anúncios" ou se está no PC (o AdMob não roda em Play Games
## para PC — anúncio nessa build simplesmente não existe).
func is_rewarded_ad_available() -> bool:
	if GameState.no_ads:
		return false
	if platform == Platform.ANDROID_PC or platform == Platform.WEB:
		return false
	return true

## Mostra um anúncio premiado. O resultado NUNCA volta na hora — chega pelo
## sinal `rewarded_ad_finished(reward_id, granted)`. A UI só entrega o
## prêmio quando `granted == true`.
##
## reward_id é um rótulo livre ("offline_double", "spawn_boost") que volta
## no sinal pra UI saber qual botão foi.
func show_rewarded_ad(reward_id: String) -> void:
	if not is_rewarded_ad_available():
		rewarded_ad_finished.emit(reward_id, false)
		return

	if _ad_manager and _ad_manager.has_method("show_rewarded"):
		_ad_manager.show_rewarded(reward_id)
		return   # o resultado chega por rewarded_completed, não aqui

	# Modo demonstração: sem plugin instalado, finge um anúncio de 1s pra
	# você conseguir testar o fluxo inteiro da UI no PC.
	_log("anúncio '%s' simulado (plugin não instalado)" % reward_id)
	await get_tree().create_timer(1.0).timeout
	rewarded_ad_finished.emit(reward_id, true)


# =========================================================================
# COMPRAS (IAP)
# =========================================================================

func has_iap() -> bool:
	return _store_manager != null

## IDs dos produtos. Precisam ser os MESMOS cadastrados no App Store
## Connect e no Play Console, senão a consulta volta vazia.
const PRODUCT_REMOVE_ADS := "remove_ads"
const PRODUCT_GEMS_SMALL := "gems_small"
const PRODUCT_GEMS_MEDIUM := "gems_medium"
const PRODUCT_GEMS_LARGE := "gems_large"

func purchase(product_id: String) -> void:
	if _store_manager and _store_manager.has_method("purchase"):
		_store_manager.purchase(product_id)
		return

	# Sem plugin: não dá pra cobrar de ninguém, então o modo demonstração
	# concede o produto só em build de depuração. Num build de release sem
	# plugin, a compra falha de propósito — é melhor o botão não funcionar
	# do que distribuir item pago de graça na loja.
	if OS.is_debug_build():
		_log("compra '%s' concedida em modo demo (build de depuração)" % product_id)
		_grant_demo_product(product_id)
		purchase_finished.emit(product_id, true, "demo")
	else:
		purchase_finished.emit(product_id, false, tr("Loja indisponível neste build"))

## A Apple EXIGE um botão "Restaurar compras" visível em todo app com
## compra não-consumível (é motivo de rejeição não ter). O botão da UI
## chama isto.
func restore_purchases() -> void:
	if _store_manager and _store_manager.has_method("restore_purchases"):
		_store_manager.restore_purchases()
	elif _store_manager and _store_manager.has_method("get_available_purchases"):
		_store_manager.get_available_purchases()
	else:
		purchase_finished.emit("", false, tr("Loja indisponível neste build"))

func _grant_demo_product(product_id: String) -> void:
	match product_id:
		PRODUCT_REMOVE_ADS:
			GameState.buy_no_ads()
		PRODUCT_GEMS_SMALL:
			GameState.add_gems(30)
		PRODUCT_GEMS_MEDIUM:
			GameState.add_gems(150)
		PRODUCT_GEMS_LARGE:
			GameState.add_gems(500)

func _on_plugin_purchase_ok(product_id: String) -> void:
	purchase_finished.emit(product_id, true, "")

func _on_plugin_purchase_fail(product_id: String, reason: String) -> void:
	purchase_finished.emit(product_id, false, reason)


# =========================================================================
# LOGIN
# =========================================================================

func has_auth() -> bool:
	return _auth_manager != null

func is_signed_in() -> bool:
	return _auth_manager != null and _auth_manager.get("is_signed_in") == true

func display_name() -> String:
	if not is_signed_in():
		return ""
	return str(_auth_manager.get("current_display_name"))

## Quais botões de login mostrar. Regra da App Store: se o app oferece
## login social de terceiros (Google), ele é OBRIGADO a oferecer também o
## "Entrar com Apple" no iOS — sem isso a submissão é rejeitada.
func available_sign_in_methods() -> PackedStringArray:
	match platform:
		Platform.IOS, Platform.MACOS:
			return PackedStringArray(["apple", "google"])
		Platform.ANDROID, Platform.ANDROID_PC:
			return PackedStringArray(["google"])
	# No PC de desenvolvimento, mostra os dois pra dar pra testar o layout.
	return PackedStringArray(["google", "apple"])

func sign_in(method: String) -> void:
	var fn := "sign_in_with_%s" % method
	if _auth_manager and _auth_manager.has_method(fn):
		_auth_manager.call(fn)
	else:
		_log("login '%s' indisponível (veja AUTH_GUIDE.md)" % method)
		auth_changed.emit(false, "")

func sign_out() -> void:
	if _auth_manager and _auth_manager.has_method("sign_out"):
		_auth_manager.sign_out()
	auth_changed.emit(false, "")

## Excluir conta é exigência das duas lojas desde 2022 — todo app com
## criação de conta precisa oferecer exclusão de dentro do próprio app.
func delete_account() -> void:
	if _auth_manager and _auth_manager.has_method("delete_account"):
		_auth_manager.delete_account()
	auth_changed.emit(false, "")

func _on_plugin_signed_in(_uid: String, name_from_plugin: String) -> void:
	auth_changed.emit(true, name_from_plugin)

func _on_plugin_signed_out() -> void:
	auth_changed.emit(false, "")

func _on_plugin_ad_completed(reward_id: String, granted: bool) -> void:
	rewarded_ad_finished.emit(reward_id, granted)


# =========================================================================
# SAVE NA NUVEM
# =========================================================================

func has_cloud_save() -> bool:
	return _cloud_manager != null

## O CloudSaveManager lê o GameState por conta própria — por isso não
## recebe parâmetro. Chamar com argumento aqui derrubaria o jogo em runtime.
func upload_save() -> void:
	if _cloud_manager and _cloud_manager.has_method("upload_save"):
		_cloud_manager.upload_save()

## Baixar é responsabilidade do próprio CloudSaveManager, que já sincroniza
## sozinho ao detectar login. Este método existe pro caso de um botão
## "sincronizar agora" na UI.
func sync_cloud_now() -> void:
	if _cloud_manager and _cloud_manager.has_method("force_sync"):
		_cloud_manager.force_sync()
	else:
		upload_save()


# =========================================================================
# LOJA / AVALIAÇÃO
# =========================================================================

func open_store_page() -> void:
	OS.shell_open(STORE_URL)

## Pedido de avaliação nativo (SKStoreReviewController / Play In-App
## Review). Sem plugin, abre a página da loja como alternativa.
func request_review() -> void:
	if Engine.has_singleton("GodotPlayInAppReview"):
		Engine.get_singleton("GodotPlayInAppReview").call("request_review")
	elif Engine.has_singleton("StoreKit"):
		Engine.get_singleton("StoreKit").call("request_review")
	else:
		_log("avaliação nativa indisponível neste build")


func _log(msg: String) -> void:
	if verbose:
		print("[SDK] ", msg)
