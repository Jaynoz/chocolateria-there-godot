# Guia de Portabilidade — Chocolateria Therê (Web → Godot)

> **Já rodando e quer publicar de verdade?** Veja também
> `PUBLISHING_GUIDE.md` (Google Play), `IOS_PUBLISHING_GUIDE.md` (App
> Store — leia o aviso sobre precisar de um Mac antes de começar),
> `MONETIZATION_GUIDE.md` (anúncios e compra de gemas, Android e iOS —
> hoje ambos são só simulados), e `AUTH_GUIDE.md` (login com Apple/Google
> + save na nuvem — hoje o save é só local no aparelho).

Este pacote já é um **projeto Godot 4.x completo e pronto pra abrir** — não é
mais só uma coleção de scripts soltos. `project.godot` já registra os
autoloads e aponta pra cena principal; `scenes/Main.tscn` já tem toda a
árvore de nodes montada, com os scripts certos anexados e os nomes únicos
(`%NodeName`) já configurados. Você só precisa abrir e apertar Play.

## Passo 1 — Abrir o projeto

1. Extraia o zip inteiro numa pasta.
2. Abra o **Godot Engine 4.x** (se ainda não tiver, baixe em godotengine.org — versão estável mais recente da série 4).
3. Na tela de projetos, clique **Import**, selecione a pasta extraída (o arquivo `project.godot` dentro dela) e abra.
4. O Godot vai importar as texturas automaticamente na primeira vez (pode demorar alguns segundos) — normal.
5. Aperte **F5** (ou o botão de Play no topo) pra rodar. Deve abrir a janela em modo retrato (420×900) já com o tabuleiro, os pedidos, a vitrine e a loja funcionando.

Se pedir "qual cena rodar", selecione `scenes/Main.tscn` (mas isso já deve
vir configurado sozinho via `run/main_scene` no `project.godot`).

## O que já vem pronto

```
chocolateria-there-godot/
├── project.godot              → autoloads já registrados, cena principal já setada
├── scenes/
│   └── Main.tscn               → árvore de nodes inteira, scripts já anexados
├── assets/
│   ├── items/        → os 10 itens da cadeia (cacau.png ... caixa_supermercado.png)
│   ├── effects/       → os 3 efeitos de fusão
│   ├── mascot/        → Estopa (neutro/feliz/esperando)
│   ├── logos/         → logo do jogo + logo da marca
│   ├── golden/        → caixa dourada
│   └── shaders/reveal.gdshader → efeito "preto e branco → colorido" da vitrine
├── scripts/
│   ├── autoload/
│   │   ├── ItemData.gd    → dados estáticos dos itens
│   │   └── GameState.gd   → TODA a lógica e o estado do jogo (sem UI)
│   └── ui/
│       ├── Board.gd           → monta o tabuleiro 5x5 sozinho
│       ├── OrdersRow.gd       → monta os cards de pedidos sozinho
│       ├── SuperVitrineRow.gd → monta as 5 miniaturas da vitrine sozinho
│       └── Main.gd            → liga tudo (stats, loja, modais)
└── PORTING_GUIDE.md (este arquivo)
```

## Se algo não abrir certo

Eu montei o `.tscn` à mão (sem rodar o Godot de verdade aqui pro lado meu) e
validei a estrutura por script — todos os 60 nós, os 7 recursos externos e os
22 nomes únicos batem exatamente com o que os scripts (`Main.gd`, `Board.gd`,
etc.) esperam. Mas o Godot pode ainda assim reclamar de algum detalhe pontual
de versão (ex: se você estiver numa versão bem diferente da 4.2). Se aparecer
qualquer erro ao abrir, **me manda a mensagem exata** que eu corrijo.

## O que ainda é responsabilidade sua (estilo visual)

O projeto vem funcional mas sem estilização — botões e painéis no tema
padrão do Godot, sem cores/fontes customizadas. Isso foi proposital: a lógica
importava mais que a aparência nessa entrega. Pra dar a cara do protótipo
web (cores de chocolate, fonte arredondada, cantos arredondados), você vai
querer:

1. Criar um **Theme** (`.tres`) com as cores/fontes da paleta original (tons
   de chocolate/caramelo — veja os hex codes no `chocolateria-there.html` original, seção `:root` do CSS)
   e aplicar no node `Main` (propriedade `theme`).
2. Trocar a fonte padrão pelas do Google Fonts usadas na web (Fredoka pros
   títulos, Karla pro corpo) — baixe os `.ttf` e importe como `FontFile`.
3. Ajustar `StyleBoxFlat` dos painéis (cantos arredondados, bordas) via o
   Theme ou overrides individuais.

Nada disso afeta a lógica — pode mexer à vontade sem quebrar nada, porque
toda a lógica vive isolada em `GameState.gd`.

## Poses do Estopa que ainda não estão na cena

Já usei `estopa_feliz.png` no header e nos dois modais (bem-vindo de volta
e vitória). As outras duas poses — `estopa_neutro.png` e
`estopa_esperando.png` — estão na pasta `assets/mascot/` prontas, mas não
coloquei em nenhum lugar fixo da cena (no protótipo web, `neutro` ficava no
cabeçalho e `esperando` perto da fila de pedidos). Adicione um `TextureRect`
onde achar melhor e aponte pro arquivo — é só arrastar do painel de arquivos
do Godot direto pra cena.



## Tabela de conceitos: Web (HTML/JS) → Godot

| No protótipo web | Equivalente em Godot | Onde está aqui |
|---|---|---|
| `window.storage.get/set` | `FileAccess` lendo/escrevendo JSON em `user://` | `GameState.save_game()` / `load_game()` |
| `setInterval(tick, 1000)` | acumulador de tempo dentro de `_process(delta)` | `GameState._process()` |
| Elemento DOM de cada célula | `TextureButton` dentro de um `GridContainer` | `Board.gd` |
| `<img>` mudando de `src` | `texture_normal` / `TextureRect.texture` trocando o `Texture2D` | `Board._refresh()` |
| Emoji/SVG inline | arquivo `.png` real em `res://assets/...` | pasta `assets/` |
| CSS `clip-path: inset(...)` (revelar a vitrine) | shader canvas_item com `discard`/`mix` por `UV.x` | `assets/shaders/reveal.gdshader` |
| Animação CSS (`@keyframes merge-pop`) | `Tween` (`create_tween()...tween_property(...)`) | `Board._on_item_merged()` |
| Partículas de fogos (CSS `.firework-particle`) | `CPUParticles2D` (ou `GPUParticles2D`) | `WinFireworks` node |
| `Math.random()` | `RandomNumberGenerator` (`GameState.rng`) | `GameState.gd` |
| Sinal “re-renderizar tudo” (`render()`) | **Signals** do Godot (`coins_changed`, `board_changed`, etc.) | topo do `GameState.gd` |
| `localStorage`/sessionStorage (proibidos nos artifacts) | não se aplica — no Godot `FileAccess` é o caminho normal e correto | — |
| Objeto `state` global no JS | Autoload singleton (`GameState`) | `scripts/autoload/GameState.gd` |
| `ASSETS` (base64 embutido) | texturas de verdade importadas pelo Godot | `assets/*.png` |

## Diferenças de comportamento a decidir você mesmo

- **Toque vs. arrastar pra fundir**: mantive o mesmo esquema do protótipo (toca no primeiro item, toca no segundo pra fundir). Se preferir drag-and-drop de verdade, troque a lógica de `_on_cell_pressed` em `Board.gd` por um sistema de arrastar (usando `_gui_input` e detecção de drop entre células).
- **Sons**: não vieram nesse pacote — é um bom próximo passo (efeitos de fusão, forno, moedas).
- **Anúncios/IAP reais**: os botões de "assistir anúncio" e "remover anúncios" no `GameState` são só simulação (iguais ao protótipo). Pra produção de verdade você vai plugar um SDK de ads/IAP (AdMob, etc. — geralmente via plugin de terceiros pro Godot) nesses mesmos pontos de entrada.
- **Números de saldo como `float`**: mantive `coins` como `float` pra bater com o protótipo (que tinha renda fracionária por segundo). Se preferir inteiros "limpos", troque pra `int` e ajuste `item_income()`.

Qualquer ajuste que você fizer no editor (temas, cores, tamanhos, fontes) não
afeta a lógica — ela vive inteira em `GameState.gd`, separada da apresentação.

## Localização (idiomas)

O jogo já suporta **7 idiomas**: Português (padrão), Inglês, Espanhol,
Francês, Alemão, Italiano e Holandês — com um seletor dentro do menu de
pausa (aba Config). Todo o texto do jogo (botões, mensagens, os 10 nomes
dos itens) já está traduzido em `localization/translations.csv`.

**Único passo manual necessário** (o Godot não faz isso sozinho por CSV
solto na pasta): abra o Godot, clique uma vez em
`localization/translations.csv` no painel de Arquivos — o editor vai
importar e gerar os arquivos `.translation` automaticamente. Depois, em
**Projeto → Configurações do Projeto → Localização → Traduções**, confirme
que os 6 arquivos gerados (en, es, fr, de, it, nl) aparecem na lista — se
não aparecerem sozinhos, clica no `+` e adiciona manualmente.

Pra adicionar mais um idioma depois: abre o CSV, adiciona uma coluna nova
com o código do locale (ex: `ja` pra japonês) e as traduções, reimporta, e
adiciona a entrada correspondente na constante `LANGUAGES` do `Main.gd`.

As traduções foram feitas por mim (não são revisão de falante nativo) —
recomendo pedir pra alguém fluente em cada idioma revisar antes de
publicar, principalmente os textos mais longos (o "Sobre" e os avisos do
menu de pausa).

## Rodando build automatizado (Codemagic, GitHub Actions, etc.)

Já incluí um `export_presets.cfg` inicial (presets Android e iOS, com o
Bundle ID de vocês) — sem ele, CI automatizado falha direto com "this
project doesn't have an export_presets.cfg file". **Abra o projeto no
Godot uma vez** (Projeto → Exportar) pra preencher o App Store Team ID do
lado do iOS e deixar o próprio Godot validar/completar o arquivo antes de
rodar em CI — veja `IOS_PUBLISHING_GUIDE.md`.

Também incluí um `.gitattributes` — sem ele, o Git (principalmente no
Windows) pode corromper arquivos binários como PNG ao fazer commit,
convertendo finais de linha em arquivos que não são texto. Se vocês já
tinham um repositório Git criado **antes** desse arquivo existir, os PNGs
que já foram commitados podem estar corrompidos no histórico — depois de
adicionar o `.gitattributes`, rode:

```bash
git rm --cached -r assets/
git add assets/
git commit -m "Recadastra assets como binário (corrige corrupção de PNG)"
```


