extends Node
## SCAFFOLD — não está registrado como autoload ainda.
##
## Isso é um ponto de partida pra quando você instalar o plugin AdMob da
## Poing Studios (veja MONETIZATION_GUIDE.md). As classes MobileAds,
## RewardedAd, RewardedAdLoadCallback etc. só existem DEPOIS de instalar
## o plugin pelo AssetLib — enquanto ele não estiver instalado, este
## arquivo vai dar erro de "classe não encontrada" se for registrado como
## autoload. Por isso ele mora fora de scripts/autoload/ por enquanto.
##
## Depois de instalar o plugin:
##   1. mova este arquivo pra res://scripts/autoload/AdManager.gd
##   2. registre como autoload "AdManager" (depois de GameState)
##   3. confirme os nomes exatos das classes/métodos na doc do plugin —
##      a API pode ter mudado desde que este scaffold foi escrito
##
## Troque os IDs de unidade de anúncio de teste abaixo pelos seus reais
## do AdMob antes de publicar (os de teste só funcionam em builds de
## depuração / dispositivos de teste).

const TEST_REWARDED_AD_UNIT_ANDROID := "ca-app-pub-3940256099942544/5224354917"

var _rewarded_ad = null
var _ad_load_callback = null
var _pending_reward_type := "" # "offline_double" | "spawn_boost"

signal rewarded_ad_ready(ready: bool)
signal rewarded_ad_failed(reason: String)
## Interface que o autoload SDK escuta. granted = o jogador assistiu até o
## fim e a rede confirmou o prêmio. É o ÚNICO caminho pelo qual a UI pode
## conceder a recompensa.
signal rewarded_completed(reward_id: String, granted: bool)


func _ready() -> void:
	# _ad_load_callback = RewardedAdLoadCallback.new()
	# _ad_load_callback.on_ad_failed_to_load = func(err):
	# 	_rewarded_ad = null
	# 	rewarded_ad_failed.emit(err.message)
	# _ad_load_callback.on_ad_loaded = func(ad):
	# 	_rewarded_ad = ad
	# 	rewarded_ad_ready.emit(true)
	#
	# MobileAds.initialize(func(status): _load_rewarded_ad())
	pass


func _load_rewarded_ad() -> void:
	# var unit_id := TEST_REWARDED_AD_UNIT_ANDROID # troque pelo real antes de publicar
	# RewardedAdLoader.new().load(unit_id, AdRequest.new(), _ad_load_callback)
	pass


## Ponto de entrada único, chamado pelo autoload SDK. reward_id é um
## rótulo livre ("offline_double", "income_boost", "spawn_boost") que volta
## no sinal rewarded_completed pra UI saber qual botão foi.
func show_rewarded(reward_id: String) -> void:
	_pending_reward_type = reward_id
	_show_current_ad()


func _show_current_ad() -> void:
	# if _rewarded_ad == null:
	# 	rewarded_ad_failed.emit("Anúncio ainda não carregou")
	# 	return
	#
	# var full_screen_callback = FullScreenContentCallback.new()
	# full_screen_callback.on_ad_dismissed_full_screen_content = func():
	# 	_rewarded_ad = null
	# 	_load_rewarded_ad() # já deixa o próximo carregando
	#
	# _rewarded_ad.full_screen_content_callback = full_screen_callback
	# _rewarded_ad.show(func(reward_item):
	# 	_on_reward_earned(reward_item)
	# )
	pass


## Só é chamado quando a rede de anúncios confirma que o vídeo foi assistido
## até o fim. Fechar o anúncio no meio cai em _on_reward_denied().
func _on_reward_earned(_reward_item) -> void:
	rewarded_completed.emit(_pending_reward_type, true)
	_pending_reward_type = ""

func _on_reward_denied() -> void:
	rewarded_completed.emit(_pending_reward_type, false)
	_pending_reward_type = ""
