# Revisão do projeto — erros corrigidos, SDK e imagens

Documento do que foi encontrado e alterado. Tudo já está aplicado nos
arquivos; esta é a explicação do porquê.

---

## 1. O arquivo SDK — `scripts/autoload/SDK.gd`

Camada única entre o jogo e as três plataformas (App Store, Play Store e
Google Play Games para PC). Já registrado como autoload em
`project.godot`, depois do `GameState`.

**O problema que ele resolve.** Anúncio, compra, login e save na nuvem não
existem no Godot puro — são plugins instalados depois. Antes, a UI
procurava esses plugins na mão (`get_node_or_null("/root/AuthManager")`
espalhado pelo `Main.gd`) e cada botão tinha que se virar sozinho quando o
plugin não estava lá. Agora a UI chama sempre o `SDK`, e ele decide:

| situação | o que acontece |
|---|---|
| plugin instalado | usa o plugin de verdade |
| plugin ausente | modo demonstração seguro + aviso no console; o jogo continua |
| build de release sem plugin | a compra **falha de propósito** (melhor botão morto do que item pago liberado de graça) |

**O que ele expõe:**

- **Plataforma** — `platform_name()`, `is_mobile()`, `is_pc_like()`,
  `has_touch()`, `tap_word()` (escreve "toque" ou "clique" conforme o
  aparelho). Detecta Play Games para PC separando Android x86_64 sem tela
  de toque do Android comum.
- **Área segura** — `safe_area_margins()` devolve o recorte de notch, ilha
  dinâmica e barra de gestos **já convertido pras unidades da viewport**
  (420×900). Em pixels crus o notch de ~130px jogaria a UI pra fora da
  tela.
- **Anúncios** — `show_rewarded_ad(reward_id)`; o resultado volta pelo
  sinal `rewarded_ad_finished(reward_id, granted)`.
- **Compras** — `purchase()`, `restore_purchases()`, IDs dos produtos.
- **Login** — `sign_in()`, `sign_out()`, `delete_account()`,
  `available_sign_in_methods()`.
- **Nuvem, loja, avaliação, vibração** e os sinais de ciclo de vida do app.

Pra ligar os plugins de verdade depois: instale pelo AssetLib, mova o
scaffold correspondente pra `scripts/autoload/`, registre como autoload —
o SDK detecta sozinho e passa a delegar. **Nada na UI muda.**

---

## 2. Erros corrigidos

### Graves (quebravam funcionalidade em produção)

**Prazos salvos em `Time.get_ticks_msec()`** — `GameState.gd`
`boost_until_ms`, `ad_cooldown_until_ms` e `spawn_boost_until_ms` iam pro
disco como instante final, mas esse relógio conta desde que o app abriu e
**volta pra zero a cada execução**. Na prática: um boost de 30s reaparecia
ativo na sessão seguinte, o cooldown de anúncio travava o botão sem
motivo, e o "sem anúncios" (que era um boost de 1 ano em ticks) expirava
sozinho. Agora vai pro save como *tempo restante* e é reconstruído no
load; `no_ads` virou uma flag permanente de verdade.

**Localização inteira inerte** — `project.godot` não tinha
`locale/translations`. Sem essa lista os arquivos de tradução nunca
carregam e todo `tr()` devolve o texto original em português. O CSV com 6
idiomas estava pronto e simplesmente não era usado. Corrigido, mais 14
chaves que faltavam.

**O aviso de renda offline nunca aparecia** — o cálculo roda no `_ready()`
do autoload, ou seja, antes da cena principal existir. O sinal era emitido
pra ninguém. Agora fica guardado em `pending_offline_*` e a UI busca
quando ela mesma está pronta.

**Esc não fechava o menu de pausa** — o nó `Main` era pausável, então
`_unhandled_input` parava de rodar exatamente quando a tela de pausa
abria. Passou a `process_mode = ALWAYS` (com o `_process` se contendo
sozinho enquanto pausado). Era um requisito do selo "Otimizado" do Play
Games para PC que estava documentado como pronto e não funcionava.

**Progresso perdido ao trocar de app** — o autosave era só de tempo em
tempo. iOS e Android matam o app em segundo plano sem aviso. Agora
`GameState._notification` salva em `APPLICATION_PAUSED`, `FOCUS_OUT`,
`CLOSE_REQUEST` e `GO_BACK_REQUEST` (e o intervalo do autosave subiu de 5s
pra 15s, porque não precisa mais ser a única rede de proteção).

**Recompensa de anúncio entregue sem anúncio** — `_on_watch_ad_pressed`
concedia o bônus no clique. Agora o prêmio só sai em
`_on_rewarded_ad_finished` com `granted == true`; fechar o vídeo no meio
não paga. O `AdManager` ganhou o sinal `rewarded_completed(reward_id,
granted)` pra isso.

**SDK chamando o CloudSaveManager errado** — `upload_save()` do scaffold
não recebe parâmetro. Alinhado (era erro de runtime na hora que o plugin
fosse ligado).

### Compatibilidade multiplataforma

- **Área segura aplicada** no `Main.gd` (`_apply_safe_area`), reagindo
  também a mudança de tamanho de janela. Antes havia uma margem fixa de
  52px no topo, que erra pra mais no Android e pra menos no iPhone com
  ilha dinâmica.
- **`window/stretch/aspect="expand"`** — o padrão `keep` deixava tarja
  preta. Com `expand` o mesmo layout serve do iPhone SE ao iPad e à janela
  do Play Games para PC.
- **`emulate_touch_from_mouse=true`** — Play Games para PC e Chromebook
  entregam mouse, não dedo.
- **`config/features`** estava em `"4.2"` enquanto o `export_presets.cfg`
  já usava chaves da 4.5+ e o CI baixa a 4.7.1. Alinhado pra `"4.7"`.
- **Chaves legadas duplicadas** no `export_presets.cfg`
  (`custom_template/use_custom_build` + `export_format`) removidas — o
  preset dizia AAB numa chave e APK na outra.
- **Botão "Restaurar compras"** adicionado. A Apple rejeita app com compra
  não-consumível que não ofereça restauração — é um dos motivos de
  rejeição mais comuns.
- **`hard_reset()` não apaga mais o `no_ads`** — apagar progresso não pode
  tirar do jogador algo que ele pagou.
- **Idioma padrão** virou automático (idioma do aparelho). Estava fixo em
  `"en"`: um celular em português abria o jogo em inglês.
- **`Engine.max_fps = 60`** no celular. Sem limite, um jogo de tabuleiro
  estático desenha a 120fps e só esquenta o aparelho.

### Menores

- `_refresh_account_ui()` rodava a 60x por segundo (com `get_node` e
  reescrita de label dentro). Agora só roda quando o login muda.
- Quando o login existia mas o jogador estava deslogado, o texto de status
  nunca era atualizado (faltava o `else`).
- Animação de "pop" da fusão crescia a partir do canto (faltava
  `pivot_offset`), a peça parecia escorregar.
- Parâmetros não usados em `Board.gd` renomeados com `_` (tiram aviso do
  editor).
- Vibração curta no toque das peças e mais forte ao fechar uma vitrine.

### Fora do código

- **CI: passo de importação de assets.** O repositório não versiona
  `.godot/` nem os `.import` (correto — é cache de máquina), mas exportar
  direto num clone limpo pega o projeto com zero assets importados: o
  build sai sem imagem ou falha com "resource not found". Adicionado
  `godot --headless --import` (duas vezes, pra resolver dependências entre
  recursos) antes do export.
- **CI: workflow Android completo** (`android-workflow`), com keystore por
  variável de ambiente, instalação do build template e **patch automático
  do `AndroidManifest.xml`** marcando `touchscreen` como não obrigatório.
  Esse era o passo listado no guia como "só dá pra fazer na sua máquina" —
  agora roda no CI. Sem ele a Play Store não oferece o jogo no Play Games
  para PC nem em Chromebook.

---

## 3. Imagens

### Itens (10) e caixa dourada

Estavam em resoluções e proporções completamente diferentes (de 377×314 a
825×468) e desenhados numa célula de 70px: o cacau aparecia gigante e o
palete minúsculo, sem relação com o nível do item.

- recorte pela caixa alfa, canvas quadrado de 256×256 com margem uniforme
  → **todos ocupam o mesmo espaço visual**
- contorno quente + sombra de contato → chocolate escuro para de sumir no
  fundo escuro do tabuleiro
- franja semitransparente das bordas limpa
- **2,7 MB → 620 KB** (o `cacau.png` sozinho caiu de 511 KB pra 70 KB), e
  mais nítido, porque 256px reamostrado com Lanczos bate 825px reduzido na
  força bruta pela GPU

### Ícones do app

Eram uma flor **vermelho-escura sobre fundo magenta** — quase invisível a
48px na gaveta de apps. Refeitos a partir da flor da marca em creme sobre
gradiente magenta, com o traço engrossado pra sobreviver aos tamanhos
pequenos.

- `icon_adaptive_monochrome_432` estava colorido; o ícone temático do
  Android 13+ pede silhueta branca (o sistema recolore)
- `icon_adaptive_background_432` era chapado; virou gradiente radial
- foreground e monochrome dentro da zona segura (66% centrais), pra
  nenhuma máscara de launcher cortar a flor
- os 11 ícones do iOS regerados do mesmo mestre de 1024, **sem canal
  alfa** (a Apple rejeita ícone com transparência)

### Mascote e efeitos

Padronizados em canvas quadrado (256 e 192), com sombra de contato no
Estopa. Sem contorno quente nele — descaracterizava o desenho.

---

## 4. `index.html` (versão web / CrazyGames)

É uma base de código separada do Godot — mesma lógica reescrita em JS, com
o SDK da CrazyGames. Revisado e reconstruído também. **496 KB → 319 KB.**

### Erros corrigidos

**Anúncio premiado pagava sem anúncio.** O botão "Watch Ad" concedia o
bônus no clique, direto. O SDK da CrazyGames estava carregado na página e
nunca era chamado pra exibir anúncio nenhum — ou seja, o jogo pedia pra
assistir, pagava de graça, e a plataforma não registrava exibição (nem
receita). Agora passa por `SDK.ad.requestAd('rewarded')` e o bônus só sai
no `adFinished`, com `gameplayStop/Start` em volta, como a documentação
deles pede. Fora da CrazyGames (teste local) segue o modo demo.

**A fábrica parava com a aba em segundo plano.** Navegador estrangula
`setInterval` em aba escondida (chega a 1x por minuto), e o cálculo de
renda offline só roda ao carregar a página. Resultado: deixar a aba aberta
atrás de outra não rendia nada e também não contava como tempo offline —
um buraco num jogo idle. Agora há `catchUp()` no `visibilitychange`, com o
mesmo teto de 8h.

**A vitrine não atualizava ao ser completada.** `vitrineCompleted` não
redesenhava nada; o círculo só virava colorido no próximo evento de
progresso.

**Música nunca tocava.** Todo navegador bloqueia áudio antes do primeiro
gesto do usuário. A chamada inicial falhava e o `.catch(()=>{})` engolia o
erro sem nunca tentar de novo — o jogo ficava mudo a partida inteira.
Agora destrava no primeiro toque/tecla.

**"Sem anúncios" expirava.** Mesmo problema da versão Godot, aqui na forma
de um prazo de 1 ano: quem voltasse depois disso perdia o bônus pago. E o
`hardReset` apagava a compra. Corrigidos os dois.

**Progresso perdido ao fechar a aba** — o autosave era só de 5 em 5
segundos. Adicionado save em `visibilitychange` e `pagehide` (este último
é o que funciona no Safari/iOS, onde `beforeunload` não dispara).

**`savedAtUnix` entrava no estado do jogo** no `load()` — metadado do
arquivo virando propriedade do jogo.

### Melhorias

- **Prestígio ganhou interface.** A classe `Game` já tinha
  `doPrestige()`/`canPrestige()` completos e nenhum botão chamava — código
  morto, e o sistema de progressão de longo prazo que existe no Godot
  simplesmente não existia na web. Painel adicionado, espelhando o do
  Godot.
- **Todas as imagens trocadas** pelas versões padronizadas (itens a 160px,
  mascote a 110px), codificadas como PNG de 8 bits com alfa: visualmente
  idêntico ao de 32 bits e ~4x mais leve. Só as imagens caíram de 358 KB
  para 181 KB.
- **Favicon, apple-touch-icon, theme-color e meta description** — a página
  não tinha ícone nenhum (aparecia com o ícone genérico na aba e ao salvar
  na tela de início).

---

## 5. Idioma e modo de tela no menu de pausa

### Godot

O seletor de idioma já existia — mas **escolher "Português (BR)" deixava o
jogo em inglês**. O CSV não tinha coluna `pt_BR`, então o Godot caía no
idioma reserva, que é o inglês. Adicionada a coluna com o texto de origem
em português e registrado o `.translation` no `project.godot`. Português e
espanhol subiram pro topo da lista, logo abaixo de "Automático".

Trocar de idioma agora também redesenha os textos que o script escreve na
mão (custo de upgrade, status da conta, estado do forno) — esses não são
retraduzidos sozinhos como os que vêm da cena, e ficavam no idioma antigo
até a próxima atualização de tela.

**Novo: "🖥️ Modo de tela"** (Automático / Celular / Desktop) na aba
Configurações. A escolha manual vence a detecção automática — útil num
tablet ligado ao monitor ou num celular que o sistema reporta errado. O
que muda:

- **escala da interface**: 1.25x no desktop (o mouse é mais preciso que o
  dedo, mas a tela está mais longe dos olhos)
- **filtro de textura**: no celular as imagens de 256px são desenhadas a
  ~70px, uma redução forte — sem mipmap isso serrilha e "ferve" durante as
  animações. No desktop elas aparecem grandes e o mipmap só borraria.
- **tamanho da janela**: no desktop abre em 560x1040 em vez de herdar os
  420x900 pensados pra celular
- `SDK.has_touch()` e `tap_word()` seguem a escolha, então os textos falam
  "toque" ou "clique" conforme o caso

### Web (`index.html`)

Não tinha seletor nenhum, e a interface inteira era fixa em inglês.
Adicionados os dois no menu de pausa.

**Idioma** (Automático / Português (BR) / Español / English). O automático
segue o idioma do navegador. Traduzida a interface inteira — incluindo as
**27 piadas do Estopa em cada idioma**, adaptadas e não traduzidas ao pé
da letra, porque piada literal não tem graça. Qualquer chave que falte cai
no inglês em vez de sumir da tela.

**Modo de tela** (Automático / Celular / Desktop). O automático usa
ponteiro grosso (dedo) ou janela estreita como sinal. Redimensionar a
janela só reavalia se estiver em automático — quem escolheu na mão não
quer o layout mudando sozinho.

No desktop a coluna de 420px virava uma tirinha no meio de um monitor
inteiro, com o tabuleiro minúsculo. Agora ela vira uma grade de 900px em
duas colunas — tabuleiro à esquerda, pedidos, prestígio e loja à direita —
com fontes, células, vitrines e botões maiores.

**Qualidade por tela:** as imagens embutidas subiram de 160px para 256px,
porque no desktop as células ficam ~2x maiores e 160px começava a borrar.
No celular elas são reduzidas e o navegador suaviza; no desktop aparecem
quase no tamanho nativo, com a suavização desligada pra não borrar de
graça. O arquivo ficou em **455 KB** — ainda menor que os 496 KB do
original, que tinha metade da resolução e nenhum dos dois seletores.

---

## 6. Ajustes pedidos na revisão

**Inglês virou o idioma padrão** nas duas versões. Antes o padrão era
seguir o idioma do aparelho. Agora todo mundo abre o jogo em inglês na
primeira execução, e "Automático" continua disponível como opção no menu
de pausa, junto de Português (BR) e Español.

**Flor ao lado do nome / gôndola nas vitrines: já era assim.** Conferi as
imagens byte a byte nos dois projetos:

| lugar | imagem |
|---|---|
| topo, ao lado de "Chocolateria Therê" | flor da marca (`logo_game_icon`) |
| linha do mascote, com o balão de fala | Estopa (o cachorro) |
| as 5 vitrines de progresso | gôndola (`caixa_supermercado`), P&B → colorida |

O cachorro só aparece na linha do balão de fala, nunca ao lado do nome.
Se você viu o cachorro no topo, provavelmente era uma versão anterior à
revisão — vale conferir no pacote novo.

**O que estava mesmo errado na vitrine: a cor aparecia num piscar.** No
Godot o valor do shader era trocado de uma vez, então a passagem de preto
e branco para colorido acontecia num único quadro. A versão web já animava
(0,4s no `clip-path`) e a do Godot não — o momento mais comemorativo do
jogo passava despercebido. Agora tem tween de 0,45s com desaceleração, um
tween por miniatura (dois eventos seguidos não brigam pelo mesmo valor), e
o caminho de volta (prestígio, reinício) continua instantâneo, porque
animar uma vitrine "descolorindo" só confundiria.

As miniaturas também cresceram (52 → 58px no Godot, 44 → 52px na web): é o
indicador de progresso principal do jogo e a gôndola ficava ilegível.

---

## 7. Segunda passada nas imagens (auditoria no tamanho real)

A primeira passada padronizou tamanho e peso, mas eu não tinha conferido
cada imagem **no tamanho em que ela realmente aparece na tela**. Fazendo
isso, apareceram quatro problemas — três deles causados por mim na
padronização.

**Mascote ampliado.** O Estopa tinha 220x166 e virou 256x256. Ampliar não
cria detalhe: só borra a arte e engorda o arquivo (33 KB → 77 KB). E ele é
desenhado no máximo a 64px, então a resolução original já sobrava.
Refeito a partir do original, sem ampliar: 178x178 e 33 KB.

**Sombra do mascote cortada.** A margem que sobrou no canvas (8px) era
menor que o alcance da sombra (deslocamento 6 + desfoque 6 = 12px): ela
batia na borda e terminava num corte reto em vez de sumir. Agora a margem
é calculada a partir do alcance da sombra, e um teste confere que o alfa
chega a zero nas quatro bordas de todos os assets.

**Efeitos de fusão ilegíveis.** Os três brilhos que aparecem na fusão são
pinceladas finas; a 70px da célula viravam um borrão escuro. Reforçados
com traço mais grosso, alfa e saturação maiores. O `efeito_normal` também
era cinza-azulado, destoando de uma paleta inteira de chocolate e ouro —
agora é dourado.

**O brilho da fusão nascia fora da peça.** `_flash_effect` anima a escala
de 0,3 até 1,4 num Control com pivô no canto superior esquerdo, então o
efeito crescia pra fora da célula em vez de estourar em cima dela. Mesmo
bug que eu já tinha corrigido na animação da peça, e que passou aqui.

**Conferido e sem problema:** itens a 70px e 42px, gôndola da vitrine a
58px, molduras de botão e painel (as margens de nine-patch do
`theme.tres` estão corretas), barras de progresso, e os 11 ícones do iOS —
a flor continua legível a 29px.

**Sobrando:** `assets/logos/logo_brand.png` (18 KB) não é referenciado por
nenhuma cena nem script. Deixei no projeto por ser material de marca, mas
dá pra remover do build se quiser economizar.

---

## 8. Flor no cabeçalho, gôndola nas vitrines

O print mostrou o cachorro ao lado do nome e a **flor da marca dentro das
5 rodelas** — as duas imagens trocadas de lugar. Fui atrás e achei a
causa, que era um erro meu no processamento do `index.html`.

**A causa: troca de imagem por posição.** O script trocava as imagens
embutidas contando a ordem em que aparecem no arquivo (a 7ª, a 8ª...).
Funcionou até eu inserir o favicon no `<head>` — como ele entra **antes**
de todas as outras, empurrou a numeração inteira em +1 e cada imagem foi
gravada no slot da vizinha: o cachorro subiu pro cabeçalho, a flor desceu
pras vitrines, a caixa dourada virou item, e assim por diante.

Reescrito: agora cada troca localiza o **elemento que usa a imagem**
(`<img class="logo">`, `.icon-cacau`, `estopa_feliz:`) por expressão
regular, com asserção que falha se a âncora não existir. Inserir novas
imagens não afeta mais nada.

**Vitrine com asset próprio.** Antes as 5 rodelas reaproveitavam o ícone
do item nível 10 — a imagem do tabuleiro e a do medidor de progresso
estavam presas uma na outra, e trocar uma trocava a outra junto. Criei
`assets/vitrine/vitrine_gondola.png`: a gôndola já vem dentro da moldura
redonda, no mesmo enquadramento circular do print, e o preto e branco →
colorido continua funcionando por cima dela.

Estado final, conferido extraindo as imagens do arquivo pronto e olhando
uma a uma:

| lugar | imagem |
|---|---|
| ao lado de "Chocolateria Therê" | **flor da marca** |
| as 5 rodelas de progresso | **gôndola**, P&B → colorida |
| balão de fala | Estopa (único lugar onde o cachorro aparece) |

---

## 9. Balanceamento: o pulo de nível estava saindo demais

O pulo (fundir dois nível 1 e sair um nível 3) estava em 5% por fusão.
Parece pouco no papel, mas numa partida se fazem dezenas de fusões por
minuto — 1 em 20 acontecia o tempo todo e o pulo deixava de ser surpresa.

Baixar a porcentagem sozinha não resolveria: sorteio independente forma
grupos, e **dois pulos seguidos** são justamente o que dá a sensação de
excesso. Então foram duas mudanças juntas:

- chance de 5% → **2%**
- **intervalo mínimo de 12 fusões** entre dois pulos

Resultado medido em 200 mil fusões simuladas, nas duas versões: **1 pulo a
cada ~61 fusões** (era 1 a cada 20) e **nenhum par agrupado**. O bônus de
moedas ficou intacto em 10%, então a frequência de recompensa em geral não
mudou — só o pulo de nível ficou raro de novo.

Os três números são constantes nomeadas (`JUMP_CHANCE`, `BONUS_CHANCE`,
`MIN_MERGES_BETWEEN_JUMPS`) no topo da lógica de fusão, nos dois projetos,
caso você queira ajustar depois de testar.

---

## 10. Verificação final antes do envio

Passada completa nos dois projetos.

**Godot — verificado automaticamente:**

- os 43 nós de nome único da cena batem com os usados nos scripts
- todos os 48 caminhos `res://` citados existem em disco
- ordem dos autoloads correta (SDK depois de GameState, de quem ele
  depende no `_ready`)
- nenhuma conexão de sinal com número de argumentos incompatível (18
  sinais conferidos)
- todo membro de autoload chamado pela UI existe
- os 7 idiomas registrados no `project.godot` batem com as colunas do CSV
- nenhum `tr()` sem tradução correspondente

**Corrigido nesta passada:** o CSV tinha a chave `v1.0 · protótipo`
duplicada (linhas 27 e 75). O Godot usa a última e ignora a primeira em
silêncio — não quebra, mas é o tipo de coisa que confunde depois. Ficaram
75 chaves.

**Web — partida simulada de ponta a ponta** (400 rodadas de produzir,
fundir, embarcar e redesenhar num DOM de teste): 14 verificações, todas
passando — sem exceção em nenhum caminho de render, troca de idioma e de
modo de tela no meio da partida, save/load sem corromper estado,
prestígio, economia, e a frequência do pulo confirmada em 1 a cada 61
fusões sem agrupamento. Os 4 blocos de script passam na checagem de
sintaxe.

Também conferi por âncora que cada imagem está no slot certo no arquivo
final — flor no topo, gôndola nas vitrines, mascote só no balão.

**Três coisas que continuam sem tradução, de propósito:** "Chocolateria
Therê" (nome da marca), o endereço do site, e o `+0/s` do cabeçalho, que é
só um valor inicial sobrescrito em tempo de execução.

---

## 11. SDK da versão web

O `index.html` não tinha camada equivalente: a integração com a CrazyGames
estava espalhada em quatro lugares — um bloco de init no topo, a variável
`crazySdkReady` consultada dentro do handler do botão de anúncio, três
funções soltas (`crazyGameplayStart/Stop/Happytime`) chamadas no rodapé, e
o save indo direto no `localStorage`.

Agora existe um objeto `SDK` com **a mesma API do `SDK.gd`**: mesmos
nomes, mesma ideia de "usa o portal se houver, cai num modo de
demonstração seguro se não houver". Quem lê um projeto entende o outro.

| | Godot (`SDK.gd`) | Web (`index.html`) |
|---|---|---|
| plataforma | `is_mobile()`, `is_pc_like()`, `tap_word()` | `isMobile()`, `isPcLike()`, `tapWord()` |
| anúncios | `show_rewarded_ad(id)` → sinal | `showRewardedAd(id)` → evento |
| compras | `purchase()`, `restore_purchases()` | idem (responde indisponível na web) |
| conta | `sign_in()`, `sign_out()` | idem, via conta do portal |
| ciclo de vida | `app_paused` / `app_resumed` | `gameplayStop` / `gameplayStart` |

**Um problema real que a camada resolveu:** o save ia direto pro
`localStorage`. Dentro do iframe de um portal isso pode estar bloqueado ou
particionado por domínio — o jogador perderia o progresso **sem nenhum
erro visível**, porque o `try/catch` engolia a falha. Agora o
armazenamento do portal tem prioridade e o `localStorage` é só reserva.

Também entrou: `gameplayStop` automático quando a aba é escondida (sem
isso o portal contabiliza como tempo de jogo quem deixou a aba aberta
atrás de outra), vibração curta na fusão e na vitrine, e
`showInterstitial()` disponível mas **não chamado por ninguém** — está lá
pra quando vocês decidirem monetizar mais, não pra ligar sozinho.

O arquivo `sdk-web.js` entregue junto é uma cópia desse bloco só pra
leitura; o jogo usa o que está embutido no HTML.

---

## 12. Requisitos de submissão da CrazyGames

Auditoria item por item da versão web.

### Reprovava antes — corrigido

**Conteúdo legível nos tamanhos de iframe.** Este era o problema sério.
Os dez tamanhos que eles listam são **todos 16:9 deitados** (de 800x450 a
1920x1080), e o jogo era uma coluna vertical de ~900px de altura: em
907x510 o jogador teria que rolar a página pra ver o tabuleiro.

Agora o jogo tem uma caixa de projeto fixa (1000x563 deitado, 420x880 em
pé) escalada por `transform` pra caber inteira na viewport, e o layout
deitado reorganiza a interface em duas colunas — tabuleiro à esquerda,
mascote, vitrines, pedidos e loja à direita. Nenhum elemento mudou de
lugar no HTML; é só área de grid, então o layout em pé continua idêntico.

Medido nos dez tamanhos: todos cabem sem rolagem, e o menor texto da
interface fica em **12px** no pior caso (800x450) e 28px no melhor. As
fontes do layout deitado foram subidas pra nenhuma ficar abaixo de 15px
de base, justamente pra sobreviver ao pior fator de escala.

**Idioma pelo SDK.** Eles exigem seguir o `locale` do método de
informações do sistema, com inglês como reserva. Adicionado
`SDK.systemLocale()`, e dentro do portal o padrão passa a ser automático
(portal → navegador → inglês). **Fora** do portal o padrão continua sendo
inglês, como você pediu — e escolha manual no menu nunca é sobrescrita.

**Nota de desenvolvimento no rodapé.** Aparecia "Standalone JS rebuild —
mirrors the Godot project's logic" na tela, visível pra quem revisasse o
jogo. Virou "© Therê Chocolates".

### Já atendia

- **Física consistente em 144/165 Hz** — as duas animações por
  `requestAnimationFrame` (moeda voando, partículas) calculam a posição a
  partir do **tempo decorrido**, não de um passo por quadro, então a
  velocidade não muda com a taxa de atualização. A renda usa
  `setInterval`, que também não depende disso.
- **Localização em inglês** e traduções de qualidade em pt-BR e es.
- **Controles intuitivos** — só toque e clique; nenhuma tecla capturada,
  então não esbarra na lista de teclas restritas.
- **Desempenho** — arquivo único de 457 KB, sem requisição externa além
  da fonte e do próprio SDK.
- **Sem botão de tela cheia próprio** — verificado por busca no arquivo.
- **Sem promoção cruzada** — não há link externo acionável na interface.
  O `openStorePage()` existe no SDK mas nada o chama.
- **PEGI 12** — fusão de chocolate, sem violência, sem conteúdo sensível.

### Você precisa decidir

**Originalidade** é avaliação humana deles, não dá pra verificar por
código. O jogo é um merge de 10 níveis com tema de chocolataria de marca
real, mascote próprio e sistema de vitrines — mas *merge* é um gênero
lotado. Vale entrar preparado pra esse ser o ponto questionado.

---

## 13. "Nenhuma funcionalidade do SDK detectada" — corrigido

O verificador do portal reportou zero funcionalidades. Era erro meu, na
ordem de inicialização.

A documentação do SDK v3 é explícita: `init()` precisa ser aguardado
**antes** de qualquer outro módulo (`game`, `ad`, `user`, `data`). Eu
tinha escrito assim:

```js
window.CrazyGames.SDK.game.loadingStart();   // <- antes do init
await window.CrazyGames.SDK.init();
```

`loadingStart()` antes do init lança erro. E como o `try/catch` em volta
engolia tudo em silêncio, a variável `pronto` ficava `false` — o SDK
inteiro era tratado como indisponível dali em diante. Anúncio, gameplay,
conta, armazenamento: nada era chamado. Daí o "nenhuma funcionalidade".

Simulei o portal com um duplo de teste que rejeita chamadas antes do
init, e o código antigo registrou **0 chamadas**, confirmando o
diagnóstico.

O que mudou:

- `init()` primeiro, aguardado, e só então os outros módulos
- falha de init agora vai pro console como **erro**, não engolida — se
  quebrar de novo, dá pra ver o motivo
- cada chamada seguinte em seu próprio `try`, pra uma falhar não derrubar
  as outras (`getUser()` lança quando ninguém está logado, por exemplo)
- `loadingStop()` saiu do bloco de init e passou pro fim da
  inicialização do jogo, quando a interface já está montada — a ordem que
  o portal espera é init → loadingStart → loadingStop → gameplayStart

Com o portal simulado, a ordem registrada agora é: `init`,
`game.loadingStart`, `user.getUser`, `game.loadingStop`,
`game.gameplayStart`, `game.gameplayStop`, `ad.requestAd`,
`data.setItem` — **8 funcionalidades distintas**.

---

## 14. Segundo retorno do QA

**1. Corte em tela normal e cheia — a causa era minha.** A caixa de
projeto tinha altura FIXA (563px) e `overflow: hidden`. Eu tinha
*estimado* a altura do conteúdo em vez de medir, e mandado cortar o que
passasse. Quando a estimativa errou, o excesso sumiu em silêncio em vez de
aparecer — foi literalmente eu esconder o meu próprio erro.

Agora a largura continua fixa, mas a **altura é medida em tempo real** e a
escala sai dessa medida. Não existe mais estimativa pra errar. Junto com
isso:

- `overflow: hidden` saiu do `#game` e da coluna da direita. Se algo
  passar, tem que aparecer pra ser corrigido.
- Um `ResizeObserver` reajusta a escala quando o conteúdo muda de altura
  sozinho durante a partida — a fala do mascote tem 1 ou 2 linhas conforme
  o idioma, o painel de prestígio aparece depois de um tempo, os pedidos
  mudam. Só reagir ao `resize` deixaria o jogo cortado justamente nesses
  momentos.
- Reajuste também quando as fontes terminam de carregar, que mudam a
  altura do texto depois do primeiro desenho.

Testado com cinco alturas de conteúdo diferentes (520 a 820px) contra os
dez tamanhos de iframe: 50 combinações, todas cabendo.

**2. Tutorial.** Não existia nenhum. Agora tem um de quatro passos na
primeira partida — produzir, fundir iguais, entregar pedidos, completar as
vitrines — pulável, e sempre disponível pelo menu de pausa. Traduzido nos
três idiomas.

**3. Descrição e controles.** Botão "📖 Como jogar" no menu de pausa, com
resumo, controles, objetivo e três dicas. E o texto para os campos de
metadados do portal está em `6-portal-crazygames/`, pronto pra colar, em
inglês, português e espanhol.

**4. "Mais polimento".** Esse é vago e não dá pra resolver por dedução —
precisa voltar pro QA e perguntar o que especificamente incomodou.

**Erro grave achado pelos testes durante esta rodada:** o gatilho do
tutorial estava no bootstrap, antes da declaração de `tutPasso`. Ler um
`let` antes da linha que o declara lança erro — o jogo travaria na
primeira partida de **todo jogador novo**. É o terceiro erro desse mesmo
tipo nesta base de código; vale como padrão a observar.

---

## 15. Auditoria contra as diretrizes de qualidade

As diretrizes (o documento separado dos requisitos obrigatórios) apontam
boa parte do que "mais polimento" provavelmente significa. Três achados
concretos.

### O tutorial estava contra a própria diretriz

Elas pedem, literalmente: *"Implemente o processo de integração durante a
jogabilidade"* e *"Priorize elementos visuais e limite o uso de texto"*.
Eu tinha feito o oposto — quatro telas de texto bloqueando o jogo antes
de começar.

Refeito como **integração durante a partida**: nada bloqueia, cada passo
destaca o elemento de verdade na tela com um pulso e uma linha curta, e
avança sozinho quando o jogador faz a ação. Quatro passos (produzir,
fundir, entregar, vitrines), pulável, e ação fora de ordem não pula etapa.
Quem já sabe jogar quase não percebe. O painel "Como jogar" continua no
menu de pausa pra quem quiser o texto completo.

### Áudio: o balanço estava invertido

*"Os níveis de áudio são consistentes. Os sons não são muito altos nem
muito baixos."* Medi os oito efeitos: todos normalizados no mesmo pico
(-0,9 dB), mas o volume **percebido** variando de -5,7 a -14,3 dB. E o
código não definia volume nenhum, então tudo tocava a 100% contra uma
música a 35%.

O resultado era o pior arranjo possível: `merge`, o som que se ouve
centenas de vezes por partida, era o **mais alto de todos**; e
`vitrine_complete`, o momento de recompensa, o **mais baixo**.

Agora cada som tem volume próprio, calculado pra equalizar o volume
percebido e criar hierarquia — som repetido discreto, conquista alta:

| som | antes | depois | vs. música |
|---|---|---|---|
| click | -7,5 dB | -22,4 dB | +2,5 dB |
| merge | -5,7 dB | -19,7 dB | +5,2 dB |
| deliver | -10,5 dB | -14,9 dB | +9,9 dB |
| vitrine_complete | -14,3 dB | -14,3 dB | +10,6 dB |

### Imagens: artefato de compressão

*"Jogos de qualidade são isentos de defeitos gráficos, como artefatos de
compressão."* Eu tinha usado PNG de 8 bits (200 cores) pra economizar
peso. Medindo contra o original, 5% dos pixels saíam visivelmente
alterados — 14% na gôndola, que é justamente a imagem do medidor de
progresso.

Troquei por **WebP q94**: cinco vezes menos alteração (1% dos pixels) por
54 KB a mais. O favicon segue em PNG, porque o iOS não é confiável com
WebP em `apple-touch-icon`. O arquivo foi de 471 KB para 541 KB.

### Conferido e sem problema

- objetivos claros, controles consistentes, sem tecla restrita
- botões rotulados, e o de anúncio **não** é maior que os outros nem tem
  atraso artificial — a diretriz cita isso explicitamente
- nome próprio e único, sem risco de confusão com outro jogo
- jogo de partida solo, sem dependência de outros jogadores

### Uma inconsistência que eu não posso resolver

A diretriz pede que *"o estilo estético permaneça consistente e não
alterne entre visuais, ou seja, passando de realista para cartunesco"*.
Os produtos de chocolate são renders fotorrealistas e o Estopa é uma
ilustração cartunesca. É material de marca de vocês, então não mexi — mas
se o QA insistir em "polimento visual", é o candidato mais provável.

---

## 16. O que ainda depende de você

1. **Abrir no Godot 4.7** uma vez pra gerar o cache de importação e os
   arquivos `.translation` a partir do CSV.
2. **Instalar os plugins** de anúncio/compra/login quando for monetizar
   (`MONETIZATION_GUIDE.md`, `AUTH_GUIDE.md`) e mover os scaffolds pra
   `scripts/autoload/`.
3. **Cadastrar os produtos** com os mesmos IDs nas duas lojas.
4. **Criar o grupo `android_keystore`** no Codemagic com as quatro
   variáveis descritas no `codemagic.yaml`.
5. ~~**Decidir sobre o nome do pacote**~~ — **resolvido em 2026-09-10**:
   estava `br.com.therechocolates.chocolatar**i**a` (com "i") e foi
   corrigido para `br.com.therechocolates.chocolateria` em
   `export_presets.cfg`, `codemagic.yaml` e nos guias de publicação. Se
   você já tinha registrado o App ID/Bundle ID antigo na Apple, ou algum
   produto/listagem na Play Console com o valor errado, é preciso refazer
   esse cadastro com o identificador novo antes do primeiro envio.
