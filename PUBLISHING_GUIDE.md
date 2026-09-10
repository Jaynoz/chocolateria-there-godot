# Manual — Publicar no Google Play (tudo pelo Windows)

Diferente do iOS, o Android **não precisa de Mac nem de serviço na nuvem**
— o Godot exporta um `.aab` assinado direto do seu Windows, e você sobe
esse arquivo no Play Console. Esse manual é o caminho completo, do zero.

## 1. Preparar o ambiente (uma vez só)

1. **JDK 17** — baixe o [Eclipse Temurin JDK 17](https://adoptium.net/) e instale.
2. **Android SDK** — mais fácil instalar via [Android Studio](https://developer.android.com/studio) (o instalador já traz o SDK Manager, `adb`, build tools).
3. No Godot: **Editor → Gerenciar Templates de Exportação** → baixa/instala o template da **mesma versão** do seu Godot (4.7.1).
4. No Godot: **Editor → Configurações do Editor → Exportação → Android** → aponta o caminho do SDK e do JDK 17.

## 2. Gerar a keystore de assinatura (uma vez só, e guarde bem)

Abra o **Prompt de Comando** (ou PowerShell) e rode:

```
keytool -genkeypair -v -keystore chocolateria-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias chocolateria
```

Ele vai pedir uma senha e algumas informações (nome, organização, etc — pode
preencher com dados reais da Therê Chocolates). No final, vai ter um
arquivo `chocolateria-release.jks` na pasta onde você rodou o comando.

⚠️ **Guarde esse arquivo e a senha em local seguro, fora da pasta do
projeto/repositório.** Se perder, não tem como atualizar o app na Play
Store depois com o mesmo pacote — é literalmente insubstituível. Não
comita esse arquivo no Git (já deixei o `.gitignore` bloqueando `.jks`
por segurança, mas vale conferir).

## 3. Configurar a keystore no Godot (pelo editor, não por arquivo)

1. Abre o projeto no Godot → **Projeto → Exportar...**
2. Seleciona o preset **"Android"** na lista à esquerda
3. Na aba/seção de assinatura (**Keystore**), preenche:
   - **Release Keystore**: aponta pro arquivo `.jks` que você gerou
   - **Release User**: o "alias" que você escolheu (`chocolateria`, no exemplo acima)
   - **Release Password**: a senha que você definiu
4. Fecha a janela de exportação (não precisa exportar ainda) — o Godot salva essa configuração

## 4. Exportar o `.aab`

1. **Projeto → Exportar...** → seleciona o preset **"Android"**
2. Clica em **"Export Project"** (não "Export PCK/ZIP")
3. Escolhe onde salvar, com extensão **`.aab`**
4. Aguarda a exportação terminar — gera um arquivo tipo `chocolateria.aab`

## 5. Google Play Console

1. Acessa [play.google.com/console](https://play.google.com/console) — se ainda não tem conta de desenvolvedor, taxa única de US$25.
2. **Criar app** → nome "Chocolateria Therê", idioma padrão Português-BR, marca como **Grátis**.
3. Preenche a **Ficha da loja** (obrigatório antes de avançar):
   - Descrição curta e longa (posso ajudar a escrever, se quiser)
   - Ícone 512×512 — já temos pronto em `assets/icons/android/icon_main_192.png` (redimensiona pra 512 se pedir esse tamanho específico)
   - Gráfico de destaque 1024×500
   - Pelo menos 2 screenshots de celular (print do jogo rodando)
4. **Classificação de conteúdo** — questionário automático, o jogo é livre pra todas as idades.
5. **Formulário de segurança de dados** — declare "não coletamos dados" por enquanto (os sistemas de anúncio/conta ainda são só scaffold, não estão ativos).
6. **Preços e distribuição** — marca os países, confirma "Grátis".
7. Vai em **Teste → Teste interno**, cria uma versão nova, sobe o `.aab`, adiciona seu e-mail como testador.
8. Aguarda o Google revisar essa versão de teste (geralmente rápido, minutos a poucas horas).
9. Testa no celular de verdade (o Google manda um link de opt-in).
10. Se estiver tudo bem, promove a mesma versão pra **Produção** — sem precisar subir o arquivo de novo.

## Sobre anúncios e compras (ainda não ativos)

O jogo hoje **não tem AdMob nem compras de verdade integradas** — só os
scaffolds preparados (veja `MONETIZATION_GUIDE.md`). Pra essa primeira
publicação, isso não bloqueia nada — só marque no formulário de segurança
de dados que o app não coleta dados ainda, e atualiza depois quando
integrar os anúncios/compras de verdade.

## Um ponto de atenção

O visual fofo do jogo (mascote Estopa, arte kawaii) tem apelo bem
infantil. Se isso for intencional, o Google tem uma **Política de
Famílias** com regras extras (tipo de anúncio permitido, dados coletados)
— vale revisar antes de ativar anúncios de verdade:
[play.google.com/console/about/families](https://play.google.com/console/about/families/)
