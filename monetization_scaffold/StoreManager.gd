extends Node
## SCAFFOLD — não está registrado como autoload ainda.
##
## Ponto de partida pra quando você instalar o godot-iap
## (https://github.com/hyochan/godot-iap — plugin que segue a
## especificação aberta OpenIAP, fala com StoreKit 2 no iOS e Play Billing
## no Android através da MESMA API em GDScript). Veja MONETIZATION_GUIDE.md.
##
## As classes/nós desse plugin só existem DEPOIS de instalar pelo AssetLib
## e ativar em Projeto > Configurações do Projeto > Plugins.
##
## Depois de instalar o plugin:
##   1. mova este arquivo pra res://scripts/autoload/StoreManager.gd
##   2. registre como autoload "StoreManager"
##   3. cadastre os produtos abaixo NAS DUAS lojas (Play Console E App
##      Store Connect) com os MESMOS IDs antes de testar — sem isso
##      cadastrado, a consulta de produtos volta vazia
##   4. confirme os nomes exatos dos métodos/sinais na documentação do
##      projeto (godot-iap ainda é relativamente novo — a API pode evoluir
##      mais rápido que plugins mais antigos e estabelecidos)

const PRODUCT_REMOVE_ADS := "remove_ads"          # não consumível
const PRODUCT_GEMS_SMALL := "gems_small"          # consumível, +30 gemas
const PRODUCT_GEMS_MEDIUM := "gems_medium"        # consumível, +150 gemas
const PRODUCT_GEMS_LARGE := "gems_large"          # consumível, +500 gemas

const GEM_AMOUNTS := {
	"gems_small": 30,
	"gems_medium": 150,
	"gems_large": 500,
}

const ALL_PRODUCT_IDS := [
	PRODUCT_REMOVE_ADS, PRODUCT_GEMS_SMALL, PRODUCT_GEMS_MEDIUM, PRODUCT_GEMS_LARGE
]

# var iap # referência ao node/singleton do plugin (nome exato conforme a doc)

signal store_ready()
signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)


func _ready() -> void:
	# iap = OpenIAP  # ou o nome que o plugin registrar como singleton
	# iap.connection_updated.connect(_on_connection_updated)
	# iap.purchase_updated.connect(_on_purchase_updated)
	# iap.purchase_error.connect(_on_purchase_error)
	# iap.init_connection()
	pass


func _on_connection_updated(connected: bool) -> void:
	if not connected:
		return
	# iap.fetch_products(ALL_PRODUCT_IDS)
	# iap.get_available_purchases() # recupera compras já feitas (reinstalou o app, etc.)
	store_ready.emit()


## Chame pela UI: StoreManager.purchase(StoreManager.PRODUCT_GEMS_MEDIUM)
func purchase(product_id: String) -> void:
	# iap.request_purchase(product_id)
	pass


func _on_purchase_updated(purchase) -> void:
	var product_id: String = purchase.product_id
	_grant_product(product_id)
	# Toda compra PRECISA ser finalizada, senão a loja reembolsa sozinha
	# depois de alguns dias. Consumível (gemas) vs não-consumível
	# (remove_ads) costumam ter chamadas diferentes — confirme na doc:
	# if GEM_AMOUNTS.has(product_id):
	# 	iap.finish_transaction(purchase, true)  # true = consumível
	# else:
	# 	iap.finish_transaction(purchase, false)


func _grant_product(product_id: String) -> void:
	if product_id == PRODUCT_REMOVE_ADS:
		# buy_no_ads() já cuida do bônus permanente e do save. O código
		# antigo simulava isso com um prazo de 1 ano medido em
		# Time.get_ticks_msec(), que zera toda vez que o app reabre.
		GameState.buy_no_ads()
		purchase_succeeded.emit(product_id)
	elif GEM_AMOUNTS.has(product_id):
		GameState.add_gems(GEM_AMOUNTS[product_id])
		purchase_succeeded.emit(product_id)


func _on_purchase_error(product_id: String, error_message: String) -> void:
	purchase_failed.emit(product_id, error_message)
