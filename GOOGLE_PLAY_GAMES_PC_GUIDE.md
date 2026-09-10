# Selo "Otimizado" — Google Play Games para PC

Checklist de tudo que o Google exige pra passar do nível básico
("Jogável") pro nível "Otimizado" (selo melhor, mais visibilidade na loja
de PC deles), com o que já está pronto e o que ainda precisa ser feito.

## ✅ Já resolvido

- **x86_64 incluído no build** (`export_presets.cfg`) — antes só tinha as
  arquiteturas de celular (ARM), agora inclui a de PC também
- **Suporte de teclado** — Enter/Espaço aciona "Produzir Cacau", Esc abre/
  fecha o menu de pausa (`Main.gd`, função `_unhandled_input`)
- **Input SDK: não precisamos integrar** — essa é a parte mais pesada do
  processo, mas o Google isenta explicitamente jogos que só usam o botão
  esquerdo do mouse (ou toque simples equivalente), que é exatamente o
  nosso caso — nenhuma ação do jogo usa botão direito, scroll, ou
  combinação de teclas
- **Renderizar a 60Hz** — o Godot já liga v-sync por padrão, sem
  configuração extra necessária; isso já acompanha o monitor
- **Scoped storage** — o save (`user://savegame.json`) já usa a pasta
  privada do app automaticamente; e a Play Store já exige que todo app
  novo tenha `target_sdk` recente o bastante pra isso valer sozinho
- **Custom Build ativado** (`export_presets.cfg` →
  `custom_template/use_custom_build=true`) — necessário pro próximo passo

## ✅ Passo do AndroidManifest — agora automatizado no CI

O passo abaixo era manual. O `codemagic.yaml` ganhou um workflow Android
que instala o build template e aplica o patch do manifesto sozinho
(`uses-feature touchscreen required="false"`), então **exportando pelo
Codemagic não é preciso fazer nada disso na mão**. As instruções seguem
aqui pra quem exportar direto do Godot local.

## 🔧 Se você exportar pela sua máquina em vez do CI

Com o Custom Build já ativado, falta só isto (precisa do Godot local +
Android Studio, que você já tem configurado):

1. Abre o projeto no Godot
2. **Projeto → Instalar Componentes de Build do Android** (só na primeira
   vez — baixa o projeto Android template pra dentro da pasta do jogo,
   em `android/build/`)
3. Abre o arquivo `android/build/AndroidManifest.xml` que acabou de
   aparecer
4. Adiciona esta linha dentro da tag `<manifest>`, antes de `<application>`:
   ```xml
   <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
   ```
5. Salva e exporta normalmente (**Projeto → Exportar → Android**)

Só é necessário no export local: no Codemagic isso já roda sozinho.

## 🎨 Opcional — polimento visual pra telas grandes

O Google recomenda assets em resolução mais alta especificamente pra PC.
Isso é opcional pro selo em si (não é um bloqueio). Os itens hoje estão
padronizados em 256×256 — dimensionados pra célula de 70px do tabuleiro,
com folga pra telas de alta densidade. Se um dia mirarem o nível mais alto
ainda, dá pra gerar uma segunda leva a 512px só pro build de PC.

Também já entraram nesta revisão, e contam pro selo:

- suporte a mouse (`emulate_touch_from_mouse` no `project.godot`)
- janela redimensionável e layout que se adapta (`stretch/aspect=expand`)
- detecção da plataforma no autoload `SDK` (`is_pc_like()`), que troca
  "toque" por "clique" nos textos e desliga os anúncios, que não rodam no
  Play Games para PC

## Depois de tudo isso

O processo de certificação em si acontece depois que o jogo já está
publicado na Play Store normal — é o Google que testa e libera o selo,
não é uma configuração que "liga" sozinha. Veja o programa em
[developer.android.com/games/playgames](https://developer.android.com/games/playgames/start)
pra se inscrever formalmente depois que o app estiver no ar.
