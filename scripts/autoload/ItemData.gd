extends Node
## Dados estáticos da cadeia de produção. Autoload "ItemData".
## Sem estado de jogo aqui — só descrição de itens e cache de texturas.

const ITEMS := [
	{"key": "cacau",             "name": "Cacau"},
	{"key": "cacau_torrado",     "name": "Cacau Torrado"},
	{"key": "pasta_cacau",       "name": "Pasta de Cacau"},
	{"key": "bombom",            "name": "Bombom"},
	{"key": "barra",             "name": "Barra de Chocolate"},
	{"key": "tablete_premium",   "name": "Tablete Premium"},
	{"key": "caixa_bombom",      "name": "Caixa de Bombom"},
	{"key": "caixa_there",       "name": "Caixa There",             "brand_label": "THERE"},
	{"key": "palete",            "name": "Palete de Distribuição"},
	{"key": "caixa_supermercado","name": "Caixa para Supermercados","brand_label": "SUPERMERCADO"},
]

# Fixo em vez de ITEMS.size() porque `const` exige expressão constante em
# tempo de compilação. Atualizar junto com ITEMS.
const MAX_LEVEL := 10

static func get_item(level: int) -> Dictionary:
	return ITEMS[level - 1]

static func get_texture_path(level: int) -> String:
	return "res://assets/items/%s.png" % ITEMS[level - 1]["key"]

static func get_brand_label(level: int) -> String:
	return ITEMS[level - 1].get("brand_label", "")

## Renda/s de um item nesse nível. Curva não-linear (expoente 1.6) pra
## recompensar fusão em vez de acúmulo de itens baixos.
static func item_income(level: int) -> float:
	return round(pow(level, 1.6) * 1.5 * 10.0) / 10.0


# ---- Cache de texturas ----
# Evita reload() a cada redraw do tabuleiro (custa caro em mobile).

var _texture_cache: Dictionary = {}

func get_cached_texture(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path)
	return _texture_cache[path]

func get_item_texture(level: int) -> Texture2D:
	return get_cached_texture(get_texture_path(level))

func preload_all_textures() -> void:
	for level in range(1, MAX_LEVEL + 1):
		get_item_texture(level)
	get_cached_texture("res://assets/golden/caixa_dourada.png")
	get_cached_texture("res://assets/effects/efeito_normal.png")
	get_cached_texture("res://assets/effects/efeito_fornada.png")
	get_cached_texture("res://assets/effects/efeito_lote.png")
	get_cached_texture("res://assets/items/caixa_supermercado.png")


func _ready() -> void:
	preload_all_textures()
