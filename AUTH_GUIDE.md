# Guia de Contas — Login de Verdade + Save na Nuvem (Android + iOS)

## O que isso adiciona (e o que NÃO muda)

Hoje o jogo funciona 100% sem conta — abre e já joga, save fica só no
aparelho. **Isso continua exatamente assim.** Conta vai ser uma opção
adicional, não uma barreira na entrada — ninguém deveria ser obrigado a
fazer login pra jogar um idle/merge, isso mata a conversão logo na
primeira tela. O fluxo que vamos construir:

1. Jogador abre o app → joga imediatamente como "convidado" (igual hoje)
2. Em algum momento, no menu de pausa → aba "Conta" → "Entrar com Apple"
   ou "Entrar com Google"
3. A partir daí, o save passa a subir pra nuvem também (continua salvando
   local igual antes — a nuvem é uma cópia extra, não substitui)
4. Se a pessoa reinstalar o jogo ou trocar de aparelho, faz login de novo
   e recupera o progresso

## Plugin recomendado

Pesquisei antes de recomendar, porque essa área muda rápido. A opção mais
atual e mais adequada pro que vocês têm hoje (Godot 4.7):

**[Firebase Plugin (cengiz)](https://store.godotengine.org/asset/cengiz/firebase-plugin/)**
— um único plugin, interface unificada em GDScript pra Android e iOS,
arquitetura em nodes (você adiciona um node `Firebase` com filhos
`FirebaseAuth` e `Firestore`). Suporta autenticação anônima, Google, Apple,
vinculação de conta (linka a conta anônima existente com Google/Apple sem
perder o progresso — útil!), e Cloud Firestore pra guardar os saves.

Alternativa, se preferir plugins separados por plataforma (mais controle,
um pouco mais de configuração): **GodotFirebaseAndroid** +
**Godot Firebase iOS** (Somni Game Studios) — os dois são feitos pra
expor a mesma API, então trocar de um pro outro não deveria doer muito.

## Passo a passo

### 1. Criar o projeto no Firebase

1. [console.firebase.google.com](https://console.firebase.google.com) →
   Criar projeto.
2. Adiciona um app Android (precisa do Bundle ID/package name que vocês
   já escolheram) → baixa o `google-services.json`.
3. Adiciona um app iOS (mesmo Bundle ID do lado iOS) → baixa o
   `GoogleService-Info.plist`.
4. Em **Authentication → Sign-in method**, habilita os provedores:
   **Anonymous**, **Google**, e **Apple**.
5. Em **Firestore Database**, cria o banco (modo produção, com as regras
   de segurança — veja seção 4 abaixo).

### 2. Configurar "Sign In with Apple" do lado da Apple

1. No [developer.apple.com](https://developer.apple.com), no mesmo App ID
   que vocês já registraram, marca a capability **Sign In with Apple**
   (reaparece aquela tela de capabilities que vimos antes — dessa vez tem
   algo pra marcar de verdade).
2. Segue o assistente do próprio Firebase (Authentication → Apple → tem um
   passo a passo linkado) pra gerar a Service ID, a chave privada, e
   conectar tudo — essa parte tem bastante vai-e-vem entre os dois
   painéis, é meio chata mas o Firebase guia direitinho.

### 3. Instalar o plugin no Godot

1. **AssetLib** → procura "Firebase Plugin" (autor: cengiz) → instala.
2. Ativa em **Projeto → Configurações do Projeto → Plugins**.
3. Coloca o `google-services.json` e o `GoogleService-Info.plist` nos
   lugares que a documentação do plugin pedir (geralmente dentro da pasta
   `addons/` do plugin, ou nas pastas de build específicas do Android/iOS
   — confirma no guia de instalação do plugin, isso muda entre versões).
4. Adiciona um node `Firebase` na cena principal (ou num autoload próprio)
   com filhos `FirebaseAuth` e `Firestore`, conforme a doc do plugin.

### 4. Modelo de dados no Firestore

Um documento por jogador, guardado em `saves/{uid}` (o `uid` vem do
Firebase Auth depois do login) — com **o mesmo JSON que já usamos pro
save local** (é literalmente a saída de `GameState.serialize()`).

**Regra de segurança do Firestore** (cole em Firestore → Regras): cada
jogador só pode ler/escrever o próprio documento, nunca o de outra pessoa:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /saves/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Os scaffolds deste pacote

Igual fizemos com anúncios e compras: os arquivos abaixo estão em
`accounts_scaffold/`, **não registrados como autoload ainda** (as classes
do plugin Firebase só existem depois de instalado — registrar antes disso
quebraria o projeto que já está validado e funcionando).

- **`AuthManager.gd`** — login com Apple/Google, logout, estado de "quem
  está logado", vinculação de conta anônima → conta de verdade.
- **`CloudSaveManager.gd`** — sobe/baixa o save do Firestore, e faz a
  checagem de conflito (próxima seção).

Depois de instalar o plugin e configurar tudo:
1. move os dois arquivos pra `scripts/autoload/`
2. registra como autoload (`AuthManager`, depois `CloudSaveManager` —
   nessa ordem, porque o segundo depende do primeiro)
3. adiciona uma aba "Conta" no menu de pausa (`PauseTabs` em `Main.tscn`),
   parecida com a aba "Config" que já existe — com botões "Entrar com
   Apple", "Entrar com Google", e um label mostrando se está logado
4. conecta os botões em `Main.gd` chamando
   `AuthManager.sign_in_with_apple()` / `sign_in_with_google()`

## Estratégia de conflito (a parte que mais importa acertar)

O maior risco de save na nuvem é **perder progresso por sobrescrever a
coisa errada**. A lógica que os scaffolds implementam:

1. Jogador toca "Entrar com Apple/Google".
2. `CloudSaveManager` busca `saves/{uid}` no Firestore.
3. **Não existe save na nuvem ainda** → sobe o save local. Pronto, sem
   perguntar nada (não tem conflito possível).
4. **Existe save na nuvem** → compara `lifetime_coins` do local com o da
   nuvem (é um número que só cresce, então serve como proxy razoável de
   "quanto progresso" cada um tem). Se forem bem diferentes, o
   `CloudSaveManager` emite um sinal `conflict_detected(local_summary,
   cloud_summary)` — a UI deve mostrar uma escolha simples pro jogador
   ("Continuar com o progresso deste aparelho" vs. "Continuar com o
   progresso da nuvem"), **nunca decide sozinho**. Perder o progresso de
   alguém sem perguntar é o tipo de bug que gera avaliação 1 estrela.
5. Depois do login, todo autosave local (a cada 5s, igual já funciona)
   também tenta subir pra nuvem em segundo plano — silenciosamente, sem
   travar o jogo se a internet cair no meio.

## O que fica de fora por enquanto

- **Recuperação de senha / troca de e-mail**: não se aplica — login é só
  via Apple/Google, não tem senha pra gerenciar.
- **Exclusão de conta**: a Apple **exige** que apps com criação de conta
  ofereçam uma forma de excluir a conta e os dados de dentro do próprio
  app (não vale só "manda um e-mail pra gente") — isso é obrigatório pra
  aprovação na App Store assim que vocês tiverem contas de verdade. Não
  esqueçam de adicionar um botão "Excluir minha conta" no menu de pausa
  quando isso for pra produção — não incluí ainda porque depende do
  plugin instalado e configurado primeiro.
