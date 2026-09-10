# Manual — Publicar na App Store (via Codemagic, sem Mac)

Como você não tem Mac, o caminho é o **Codemagic**: um serviço que aluga
uma máquina Mac na nuvem só durante o build, compila e assina o app lá, e
te entrega o `.ipa` pronto. Esse manual já reflete tudo que testamos e
corrigimos na prática — não é só teoria.

## As três coisas que precisam existir, cada uma no seu lugar

| O quê | Onde mora | Nunca vai pra |
|---|---|---|
| Código do jogo + `codemagic.yaml` | Repositório GitHub | — |
| Credenciais da Apple (chave `.p8`, Team ID) | Grupo `app_store_credentials` no Codemagic, **marcadas como Secret** | Git, arquivo nenhum |
| Keystore/certificados manuais | Não precisa mais — a assinatura é automática | Git, arquivo nenhum |

## Passo a passo

### 1. Conta de desenvolvedor Apple

[developer.apple.com](https://developer.apple.com) → Apple Developer
Program → US$99/ano. Decida **Individual vs. Organização** — isso decide
se aparece seu nome pessoal ou "Therê Chocolates" como vendedor na loja
(Organização exige um D-U-N-S number do CNPJ, pode levar dias pra sair —
comece esse processo com antecedência se quiser o nome da marca).

### 2. Registrar o App ID

developer.apple.com → **Certificates, Identifiers & Profiles →
Identifiers → +** → escolhe **App IDs → App**:
- **Description**: texto simples, sem acento (ex: `Chocolateria There Game`)
- **Bundle ID**: `br.com.therechocolates.chocolateria` (Explicit) — **esse valor não muda depois**, é permanente
- **Capabilities**: não marca nada por enquanto (dá pra adicionar depois, quando integrar login/IAP de verdade)

### 3. Gerar a chave de API do App Store Connect

App Store Connect → **Users and Access → Integrations → App Store Connect
API** → **+** → nome tipo "Codemagic CI", acesso **App Manager** →
Generate.

⚠️ **Baixa o `.p8` na hora** — a Apple só deixa baixar uma vez. Anota o
**Key ID** e o **Issuer ID** (esse último fica escrito no topo da página,
é o mesmo pra todas as chaves da conta).

### 4. Conectar o repositório no Codemagic

[codemagic.io](https://codemagic.io) → conecta sua conta GitHub → adiciona
o app `chocolateria-there-game`.

### 5. Configurar as credenciais (nunca em arquivo)

Codemagic → **Settings** (do time, não do app) → **Global variables and
secrets** → **Add new group**:
- Nome do grupo: **`app_store_credentials`** (exatamente esse nome — é o que o `codemagic.yaml` procura)
- Em **Application access**, ativa o toggle do app `chocolateria-there-game`
- Salva o grupo primeiro, **depois** entra nele de novo pra adicionar as variáveis (se tentar tudo de uma vez, o campo de nome do grupo pode acabar virando o nome de uma variável por engano — já aconteceu)

Dentro do grupo, adiciona as 3 variáveis, **marcando o checkbox "Secret"
em cada uma** (senão elas aparecem em texto puro no log do build — já
aconteceu isso também):

| Nome | Valor |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | o Issuer ID do passo 3 |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | o Key ID do passo 3 |
| `APP_STORE_CONNECT_PRIVATE_KEY` | o conteúdo INTEIRO do arquivo `.p8` (abre num bloco de notas, copia tudo incluindo as linhas `BEGIN`/`END`) |

### 6. Subir o `codemagic.yaml`

Esse arquivo já vem pronto neste pacote, na raiz do projeto. **Substitui
o conteúdo inteiro** do arquivo no repositório (não edita só um pedaço —
problemas de indentação em YAML são fáceis de introduzir editando no
meio). Ele já está configurado pra:
- Baixar Godot **4.7.1** (a mesma versão que você usa localmente — usar
  uma versão diferente da que você testa é receita pra bug que só aparece
  no build)
- Instalar os templates de exportação (separados do editor — sem isso, dá
  o erro "No export template found")
- Buscar certificado/perfil de provisionamento automaticamente
- Gerar o `.ipa` assinado de verdade (arquivo pronto pra subir na loja)

### 7. Rodar o build

No Codemagic → **Start new build**:
1. Clica no ícone 🔄 ao lado de "Select branch" **antes** de confirmar (evita pegar um commit em cache)
2. Confirma que "Select file workflow" mostra **"iOS Build and App Store Distribution"**
3. Confirma o build

### 8. Se der erro

O log tem **checkpoints explícitos** (`===== CHECKPOINT X =====`) — o log
do passo que falhar indica rapidamente onde parou. Erros mais comuns,
pra referência:

| Sintoma | Causa provável |
|---|---|
| "Not a PNG file" / imagem corrompida | `.gitattributes` não chegou no repositório — Git tratando binário como texto |
| "This project doesn't have an `export_presets.cfg`" | Arquivo não foi commitado/pushado de verdade |
| "No export template found" | Templates não instalaram (verifica se o step de instalação rodou até o fim) |
| "Application does not have access to variable group(s)" | Grupo de credenciais sem o toggle do app ativado |
| Log mostra versão/script diferente do que você editou | `git push` foi rejeitado silenciosamente, ou você estava numa pasta local diferente — roda `git log --oneline -5` e `git remote -v` pra confirmar |
| "Workflow ... does not exist" | O nome do workflow mudou no arquivo; escolhe o novo nome no dropdown ao iniciar o build |

### 9. App Store Connect — ficha da loja

Depois que o build gerar o `.ipa` com sucesso:
1. Cria o app em [appstoreconnect.apple.com](https://appstoreconnect.apple.com) com o mesmo Bundle ID
2. Preenche nome, descrição, screenshots (várias telas de iPhone), categoria
3. **App Privacy** — declare os mesmos dados que os anúncios/contas ainda inativos justificam (por enquanto, "não coletamos dados")
4. Manda primeiro pro **TestFlight** (mesmo processo, revisão bem mais rápida que produção) — testa no iPhone de verdade antes de liberar geral

## Sobre a exclusão de conta (obrigatório mais pra frente)

Assim que o login com Apple/Google estiver de verdade ativo (hoje é só
scaffold, veja `AUTH_GUIDE.md`), a Apple **exige** um botão de "excluir
minha conta" dentro do próprio app — o botão já está preparado na
interface, só falta o backend real por trás. Não esquece disso antes de
ativar contas de verdade em produção.
