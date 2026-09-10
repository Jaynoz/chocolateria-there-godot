# Guia de Monetização — Anúncios de Verdade e Compra de Gemas

## Onde as coisas estão hoje (só simulado)

No `GameState.gd` atual, três funções fingem que um anúncio/compra
aconteceu e já dão a recompensa na hora, sem chamar nenhum SDK de verdade:

- `watch_ad_for_income_boost()` — deveria mostrar um anúncio premiado
- `buy_no_ads()` — deveria abrir uma compra de verdade na Play Store
- `buy_spawn_boost()` — gasta gemas que **hoje só vêm da caixa dourada**;
  não existe nenhuma forma de comprar gemas com dinheiro de verdade ainda

Isso foi proposital até aqui (pra você testar o loop do jogo sem precisar
configurar conta de desenvolvedor). Agora que vai pra produção, esses três
pontos precisam virar chamadas reais.

## As duas peças que faltam

| Peça | Plugin recomendado | Pra quê |
|---|---|---|
| Anúncios | [AdMob (Poing Studios)](https://github.com/poingstudios/godot-admob-plugin) — via AssetLib no editor | anúncio premiado (dobrar renda offline, boost de 30s) — funciona em Android **e** iOS |
| Compras | [godot-iap](https://github.com/hyochan/godot-iap) — via AssetLib | remover anúncios, comprar pacotes de gemas — **uma API só pra Android e iOS** |

Ambos exigem o **Custom Build** já instalado (Android: veja
`PUBLISHING_GUIDE.md`; iOS: o export gera projeto Xcode, os plugins se
integram lá — veja `IOS_PUBLISHING_GUIDE.md`).

> **Atualização**: antes eu tinha recomendado o GodotGooglePlayBilling
> (só Android) pra compras. Como agora o plano é lançar pra iPhone
> também, troquei pra recomendação pro **godot-iap** — ele segue a
> especificação aberta OpenIAP e fala com o StoreKit 2 (iOS) e o Google
> Play Billing (Android) através da mesma chamada em GDScript, então você
> não escreve a lógica de compra duas vezes.


## Passo a passo

### 1. Anúncios (AdMob)

1. Crie uma conta em [admob.google.com](https://admob.google.com), cadastre
   o app, e crie as unidades de anúncio do tipo **Premiado (Rewarded)** —
   uma pra "dobrar renda offline", outra (ou a mesma) pro boost de 30s.
2. No Godot: **AssetLib** → procura "AdMob" → instala o da **Poing
   Studios**. Ative em **Projeto → Configurações do Projeto → Plugins**.
3. Baixe as bibliotecas Android via **Projeto → Ferramentas → AdMob
   Manager → Android → Download & Install** (o plugin também empacota o
   lado iOS, integrado automaticamente no export pra Xcode).
4. Configure seu **App ID** do AdMob nas configurações do plugin
   (**Projeto → Configurações do Projeto → Admob**) — você vai precisar
   de um App ID pra Android e outro pra iOS, o AdMob gera os dois
   separados na mesma conta.
5. **No iOS especificamente**: anúncios personalizados exigem o prompt de
   App Tracking Transparency antes de qualquer coisa — veja
   `IOS_PUBLISHING_GUIDE.md` (seção 5) pra entender se vale a complexidade
   ou se compensa começar só com anúncios não personalizados.
6. Use o scaffold `monetization_scaffold/AdManager.gd` deste pacote como
   ponto de partida — ele já está estruturado do jeito que o plugin espera
   (carregar → mostrar → só recompensar depois que o anúncio realmente
   terminar). **Não está registrado como autoload ainda** de propósito,
   pra não quebrar seu projeto atual antes de você instalar o plugin.
   Depois de instalado:
   - mova `AdManager.gd` pra `scripts/autoload/`
   - registre como autoload (igual `ItemData`/`GameState`)
   - troque as chamadas de `GameState.watch_ad_for_income_boost()` no
     `Main.gd` pra chamar `AdManager.show_rewarded_income_boost()` em vez
     disso — só quando o anúncio for assistido até o fim que o script
     chama `GameState.watch_ad_for_income_boost()` de verdade

### 2. Compras (gemas + remover anúncios)

1. Cadastre os produtos **nas duas lojas** (os IDs devem ser idênticos
   nos dois lugares, pra o mesmo código funcionar em ambas):
   - **Google Play Console** → Monetização → Produtos no app
   - **App Store Connect** → seu app → Recursos do app → Compras no app

   | ID do produto | Tipo | Preço sugerido | Efeito |
   |---|---|---|---|
   | `remove_ads` | Não consumível | R$ 9,90 | `GameState.no_ads = true` |
   | `gems_small` | Consumível | R$ 4,90 | +30 gemas |
   | `gems_medium` | Consumível | R$ 14,90 | +150 gemas |
   | `gems_large` | Consumível | R$ 39,90 | +500 gemas |

2. No Godot: **AssetLib** → procura "godot-iap" → instala (de hyochan,
   segue a especificação OpenIAP). Ative em **Plugins**.
3. Use `monetization_scaffold/StoreManager.gd` como ponto de partida —
   mesma lógica de sempre: conecta na loja, consulta os produtos
   cadastrados, processa a compra, e só credita gemas / desliga anúncios
   depois que a loja confirma o pagamento.
4. **Importante**: toda compra precisa ser **reconhecida/consumida**
   (acknowledge/consume) ou a plataforma reembolsa automaticamente depois
   de alguns dias — o scaffold já inclui esse passo, não pule.
5. Adicione uma aba "Gemas" na loja do jogo (parecido com a aba
   "Upgrades"/"Bônus" que já existe) com os 3 pacotes acima, cada botão
   chamando `StoreManager.purchase("gems_small")` etc.

## Por que não venho já com isso tudo funcionando

Sem o plugin instalado no seu projeto, qualquer código que chame classes
como `MobileAds` ou `GodotGooglePlayBilling` quebra a compilação — essas
classes só existem depois que você instala o plugin pelo AssetLib. Por
isso os scaffolds ficam numa pasta separada, comentados, prontos pra você
mover assim que instalar cada plugin. As APIs exatas (nomes de método,
assinatura de sinais) podem mudar entre versões do plugin — sempre
confira a documentação oficial linkada acima se algo não bater.
