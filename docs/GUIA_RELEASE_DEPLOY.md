# Guia de Release e Deploy (quinta → segunda) — v2

> **Versão 2 — 25/09/2026.** Consolidado dos guias internos do time, do canal de releases e do que
> aconteceu na primeira quinta real de montagem (24/09) e no treino do deploy neste repositório (25/09).
> Agenda: **quinta = montagem** · **sexta = suporte testa** · **segunda = deploy**. A versão da release
> é a data do deploy.
>
> **Versão pública:** valores internos viraram marcadores. `<ORG>` organização · `<REPO_R3>`/`<REPO_R1>`
> repositórios · `<PROD>` = `master` num, `main` no outro · `<HOMOLOG_R3>`/`<HOMOLOG_R1>` endereços ·
> `<CANAL_PRS>`, `<CANAL_TECH>`, `<CANAL_RELEASES>` · **tech lead** = quem aprova o deploy e tem acesso
> a produção · **sênior de infra** = quem acionar em trava de ambiente.
>
> 🆕 marca o que foi aprendido na prática.

---

## Parte 0 — Antes de tudo

### A esteira

```
feature/bugfix ──PR──▶ develop ──PR──▶ homolog ──PR──▶ master (R3) / main (R1)
   (o dev)          (integração)    (suporte testa)      (CLIENTE — produção)
```

- **develop**: onde cada dev entrega o card.
- **homolog**: ensaio. O merge nela **publica sozinho** o ambiente de teste.
- **master/main**: produção. **O merge nela É o deploy.** Não existe tela de "confirmar" depois.

⚠️ **R3 = `master`. R1 = `main`.**

### Seu papel

> Você **empacota e publica o que já está pronto**. Você **cobra**, não conserta.

| Não é seu | É de quem |
|---|---|
| corrigir código de card alheio | autor da PR |
| caçar revisor para PR alheia | autor da PR |
| conflito de **regra de negócio** (fiscal, valores, os dois lados mudaram a mesma regra) | autor da PR |
| decidir se um card "podia" entrar | autor / tech lead |
| fechar conversa de review alheia **sem verificar** | autor / revisor |
| decidir derrubar processo em banco, furar trava de deploy | sênior de infra / tech lead |

### Parâmetros

| | R3 | R1 |
|---|---|---|
| Pasta de deploy | `~/deploy/r3-deploy` | `~/deploy/r1-deploy` |
| Repo | `<ORG>/<REPO_R3>` | `<ORG>/<REPO_R1>` |
| Produção | **`master`** | **`main`** |
| Job de build | `build_push` | `build` |
| Scripts de banco | `migrations/`, `varlib/comandos/`, `docs/scripts/*.sql` | `comandos/` |
| Homolog | `<HOMOLOG_R3>` | `<HOMOLOG_R1>` |
| Conferir versão publicada 🆕 | `<homolog>/version` → `R3 homolog <sha8>` | `<homolog>/version` → sha completo |
| Título das PRs | `MODULO \| ...` | `MODULO \| ...` |

**Canais:** `<CANAL_PRS>` · `<CANAL_TECH>` e
`<CANAL_RELEASES>` (lista do suporte, release notes, backmerges).

**Pessoas:** o tech lead decide o que entra, dá o "sim" do deploy e tem acesso a produção.
🆕 o **sênior de infra** é quem acionar em qualquer trava de deploy/ambiente.

---

## Parte 1 — As regras do GitHub que explicam as travas

Ruleset `protecao-branches-principais` (develop, homolog, master/main):

| Regra | O que acontece na prática |
|---|---|
| **1 aprovação obrigatória** | o GitHub bloqueia com menos. Nas PRs de homolog e de release o time busca **2** |
| 🆕 **O autor não aprova a própria PR** | regra do GitHub. Se você abriu a PR de homolog, **outra pessoa** tem que aprovar |
| `dismiss_stale_reviews_on_push` | 🆕 **push que RESOLVE CONFLITO derruba a aprovação**, mesmo resolvendo só o CHANGELOG (verificado em PRs reais). 🆕 **"Update branch" limpo, sem conflito, NÃO derruba** (verificado em PRs reais) |
| `require_last_push_approval: false` 🆕 | quem deu o push **pode** aprovar (se não for o autor) |
| `required_review_thread_resolution` | **botão cinza** enquanto houver conversa sem *Resolve conversation* |
| 🆕 **PR precisa estar atualizada com a base** (R3) | erro *"head branch is not up to date"*. Resolve com **Update branch** (se a compare não for protegida) |
| sem bypass | **nunca** use `--admin`, nem peça para alguém "mergear por cima" |
| 🆕 checks (`validate_*`) | não são obrigatórios, mas **espere ficarem verdes** antes de mergear |

### 🆕 Conversa aberta ≠ mudança pedida

| | **Mudança pedida** (*Request changes*) | **Conversa** (*thread*) |
|---|---|---|
| O que é | veredito do revisor sobre a PR inteira | comentário preso a uma linha |
| Como sai | **só o próprio revisor** re-revisando (aprovação de outra pessoa não anula) | alguém clica em *Resolve conversation* |
| Bloqueia? | sim | **qualquer uma** bloqueia, até sugestão de nome |

Um revisor pode **aprovar e deixar a conversa aberta**. É o caso mais comum de botão cinza.

**Conversa esquecida:** a linha foi alterada (`isOutdated`) **e** o revisor aprovou **depois** do
comentário. É sinal forte, **não prova**: num dia real, duas PRs tinham esse sinal e a autora
disse que as conversas estavam vivas. **Antes de fechar: ler o comentário, conferir no código atual
que foi resolvido, e responder na própria conversa explicando o porquê.** Na dúvida, pergunte ao
autor ("posso fechar essas conversas?").

### Conflito: quem resolve 

| Tipo | Quem | Quando |
|---|---|---|
| CHANGELOG, `.gitignore`, linha em branco | **avisa o dono** primeiro | nós resolvemos **~17h**, se a PR estiver aprovada e sem conversa aberta |
| real, mas óbvio e seguro | idem | idem |
| regra de negócio | **sempre o autor** | — |

**Por que não resolver cedo:** cada merge na develop recria o conflito de CHANGELOG em **todas** as
PRs abertas. Em 24/09, uma resolução feita ao meio-dia ficou velha às 14h.

🆕 **"Aceitar os dois lados" garante que nada suma, não que fique no lugar certo.** Depois de resolver,
leia os títulos das seções em volta: no treino, uma linha foi parar embaixo do hotfix errado.

---

## Parte 2 — QUINTA: montagem

### 09:00 — Passo 1: a casa está arrumada?

```bash
for p in "R3 develop...master" "R3 develop...homolog" "R1 develop...main" "R1 develop...homolog"; do
  set -- $p; R=<ORG>/<REPO_$1>
  echo "$1 $2 ahead=$(gh api repos/$R/compare/$2 --jq .ahead_by) arquivos=$(gh api repos/$R/compare/$2 --jq '[.files[]]|length')"
done
```

🆕 **Olhe os arquivos, não só a contagem.** `develop...homolog` costuma dar > 0  com
**0 arquivos**: são só os commits de merge das releases anteriores. Não precisa de backmerge.
`develop...master` > 0 **com arquivos** = hotfix que não voltou.

**Esta medição é só para saber.** 🆕 O backmerge, se precisar, é feito **depois do corte** (hotfix pode
entrar no meio do dia: num dia real, um hotfix foi direto para a produção às 12:42).

### 09:00 — Passo 2: levantar as PRs

Aprovação, conflito e **conversas abertas** (o que mais trava):

```bash
for r in R3 R1; do
gh api graphql -f query='query($n:String!){repository(owner:"<ORG>",name:$n){pullRequests(states:OPEN,first:100){nodes{number isDraft author{login} reviewDecision mergeStateStatus reviewThreads(first:50){nodes{isResolved}}}}}}' \
  -f n=<REPO_$r> \
  --jq '.data.repository.pullRequests.nodes|sort_by(.number)[]|"'$r' #\(.number) \(.author.login) \(.reviewDecision//"-") \(.mergeStateStatus) conversas=\([.reviewThreads.nodes[]|select(.isResolved==false)]|length) draft=\(.isDraft)"'
done
```

**Onde** está o conflito de cada PR (separa CHANGELOG de código):

```bash
cd ~/deploy/r3-deploy && git fetch -q origin '+refs/pull/*/head:refs/remotes/pr/*' && git fetch -q origin
git merge-tree --write-tree --name-only origin/develop pr/<N> | grep '^CONFLICT'
```

| `mergeStateStatus` | significa |
|---|---|
| `CLEAN` | pode mergear |
| `DIRTY` | conflito |
| `BEHIND` | atrás da develop. 🆕 No R3 **impede** o merge → *Update branch* |
| `BLOCKED` | falta aprovação, check ou conversa |
| `UNKNOWN` | ainda calculando, rode de novo |

### 09:00 — Passo 3: cobrar (canal + DM)

No `<CANAL_PRS>`, com a lista **inteira** e a pendência de cada PR dita com precisão: "conflito no
CHANGELOG", "conflito em código (arquivo)", "N conversas abertas", "mudanças pedidas por Fulano",
"falta review". 🆕 "Mudanças pedidas por Fulano" é muito mais útil que "falta aprovação".

DM por dono, juntando os dois repos.

### 09:00 — Passo 4: scripts de banco

Por **arquivo**:

```bash
for n in $(gh pr list -R <ORG>/<REPO_R3> --state open --json number --jq '.[].number'); do
  gh api "repos/<ORG>/<REPO_R3>/pulls/$n/files?per_page=100" --jq '.[].filename' \
    | grep -E '(^|/)migrations/|varlib/comandos/|\.sql$' | sed "s|^|#$n: |"
done
```

🆕 **E pelo TEXTO da PR.** Script pode estar só na descrição ("Saneamento (fora do PR)", `UPDATE ...`).
Num dia real, isso bloqueou a PR de homolog:

```bash
for n in <PRs>; do gh pr view $n -R <REPO> --json body --jq .body \
  | grep -inE 'UPDATE |INSERT INTO|ALTER TABLE|saneamento|fora do PR|--apply|dry-run|backfill' | sed "s/^/#$n: /"; done
```

🆕 Para achar a PR de origem de um arquivo que ainda não está na master, passe a branch (`sha=`):

```bash
gh api "repos/<REPO>/commits?sha=homolog&path=<ARQUIVO>&per_page=1" --jq '.[0].sha' \
  | xargs -I{} gh api repos/<REPO>/commits/{}/pulls --jq '.[]|"#\(.number) — \(.user.login) — \(.title)"'
```

Para cada script: dono, comando exato, banco, **idempotente?**, **antes ou depois do deploy** (Parte 4),
o que acontece se não rodar.

🆕 **Script na homolog:** a pergunta é *"o suporte consegue ver o card sem o script?"*. Se não
(ex.: migration que cria rótulo/coluna/permissão), rode na homolog ou avise na lista. Saneamento de
dados antigos de produção não precisa.

### 14:00 — 2º toque

**Recalcule tudo.** Em 5 horas do dia 24: 4 PRs entraram, duas prontas voltaram a conflitar, uma PR
ganhou conflito em código, 2 PRs novas apareceram e um hotfix foi direto para produção no R1.
Resposta **na thread** da manhã + DM só para quem ainda aparece.

### ~17:00 — destravar o que dá

**PR aprovada, sem conversa, presa só por CHANGELOG** — uma de cada vez:

1. resolver localmente, com prova:
   ```bash
   git switch -C <branch> origin/<branch> && git merge origin/develop
   grep -c '^<<<<<<<' CHANGELOG.md; wc -l CHANGELOG.md
   # resolver mantendo os dois lados
   grep -nE '^(<<<<<<<|=======|>>>>>>>)' CHANGELOG.md || echo NENHUM
   wc -l CHANGELOG.md            # antes − depois = 3 × blocos (ou 2 × blocos, se acrescentou linha em branco)
   git add CHANGELOG.md && git commit --no-edit
   git show --remerge-diff --format= --name-only HEAD   # tem que ser SÓ o CHANGELOG
   ```
2. conferir que a branch e a develop não mudaram desde o merge local, e dar push (normal, sem force)
3. **re-aprovar**: se o código é o mesmo que o revisor aprovou, você pode aprovar (não é o autor).
   Na tela: *Files changed* → *Review changes / Submit review* → *Approve*, com justificativa
4. **esperar os checks** → merge
5. **só então a próxima**: o merge recria o conflito nas outras

**PR aprovada, sem conflito, mas `BEHIND`** → *Update branch* (não derruba a aprovação) → checks → merge.

**PR aprovada, presa por conversa esquecida** → verificar no código, responder na conversa com o
porquê, *Resolve*, e seguir. Ordem na PR com conversa **e** CHANGELOG: **conversa primeiro, CHANGELOG
por último** (é o push do CHANGELOG que derruba a aprovação).

Combinar os **2 revisores** da PR de homolog **antes das 18h**. 🆕 Se você for abrir a PR, você não
pode aprovar: garanta duas outras pessoas, ou pelo menos uma.

### 17:30 — 3º toque (só canal)

### 18:00 — o corte

Mergear pela tela o que estiver verde. Mensagem **nova** no `<CANAL_PRS>`:

```
:lock: *Corte das 18h encerrado — release v<DATA>*

*Entraram na develop* :white_check_mark:
*R3* (N PRs)
• #N — Dono — CARD Descrição curta
*R1*
• #N — Dono — CARD Descrição curta

*Ficaram de fora* — entram no corte da próxima quinta, sem precisar refazer nada
*R3*
• #N — Dono — motivo (mudanças pedidas / conversas abertas / falta review)

*Às 19h* abro as PRs develop → homolog. Perto do horário mando aqui o link do Meet.
Preciso de 2 aprovações em cada PR.
```

Depois do corte: **refaça os scripts** (arquivos + texto) e **os compares**. Backmerge
`<PROD> → develop` só se `develop...<PROD>` tiver arquivos.

### ~19:00 — PR develop → homolog

Simule antes:

```bash
git merge-tree --write-tree --name-only origin/homolog origin/develop | grep '^CONFLICT' || echo LIMPO
```

🆕 **R3: abra a partir de uma branch intermediária `homolog-cut/<DATA>`.** A develop fica atrás da
homolog nos commits de merge, e o R3 exige a PR atualizada. Com a `develop` na compare, o
*Update branch* gravaria na develop (protegida). É o padrão já usado pelo time:

```bash
git switch -C homolog-cut/<DATA> origin/homolog   # nasce da homolog
git merge --no-edit origin/develop               # recebe a develop
git rev-list --count HEAD..origin/develop         # 0
git diff --stat origin/develop HEAD               # vazio = conteúdo idêntico à develop
git push -u origin homolog-cut/<DATA>
```

PR: **base `homolog`** ← **compare `homolog-cut/<DATA>`**. Título `INFRA | MERGE | Develop -> homolog`.
Descrição: tabela das PRs (nº, card, descrição, autor), scripts de banco, validação.

**R1:** direto da develop funcionou .

### Acompanhar o Actions

`build_push`/`build` + `deploy_homolog` verdes; os de produção `skipped`. 🆕 **Confira o `/version`**
da homolog: tem que responder o sha do merge.

🆕 **Exit 42 — "Rollout bloqueado: RecalcKrdx ativo em <tenant>":** trava do próprio workflow
(`.github/scripts/assert-no-kardex-rebuild.sh`). Enquanto um recálculo de Kardex segura o lock MySQL
`R3:recalc-kardex:<tenant>`, nenhum deploy troca a versão. **Dev e homolog usam o mesmo MySQL**,
então trava os dois. Não é defeito da release. **Acione o sênior de infra.** Em 24/09, era um recálculo em
**loop** do de uma filial desde 17:39; ele derrubou a conexão (só homolog/dev). Depois: **Re-run failed
jobs** no run do `ci-oke`. Se falhar de novo com 42, alguém relançou o recálculo: chame o sênior de infra.

### A lista para o suporte (<CANAL_TECH> e <CANAL_RELEASES>)

**Só depois do `deploy_homolog` verde E do `/version` conferido nos dois repos.**

- cards do **git**, nunca do status do Jira. Jira só para tipo (Erro/Bug → bugs, Tarefa → melhorias) e cliente
- separar por módulo/sistema, descrição em português de gente
- 🆕 **⚠️ em card que depende de script** ("fichas antigas só corrigem com o script de segunda", "depende de script, aviso quando liberar")
- 🆕 **fora da lista:** hotfix já em produção, card de infra sem tela, provisionamento automático
- 🆕 **confirme os endereços** das homologs (`/version`)
- 🆕 **postar pela API**: colado à mão, o Slack não renderiza `<url|CARD>`

---

## Parte 3 — SEXTA

1. Você testa (cálculo fiscal, fechamento, valores, o que você resolveu de conflito).
2. **Pergunte uma vez** na thread da lista. **Silêncio = aprovado.**
3. Erro sem correção a tempo → o tech lead decide (a regra histórica é cancelar o deploy inteiro).
4. 🆕 PR emergencial direto na homolog pode entrar hoje: ela **vai junto** na segunda, mesmo sem estar na lista de quinta.

---

## Parte 4 — SEGUNDA: deploy

### 🆕 Ordem dos scripts (a pergunta que o tech lead faz)

| Tipo | Quando | Por quê |
|---|---|---|
| **adiciona** estrutura (coluna, tabela, índice, permissão, rótulo) | ✅ **ANTES do merge** | o código antigo ignora o novo; o código novo precisa que já exista. Depois = tela quebrada em produção até rodar |
| **corrige dados** (saneamento, `UPDATE` de registros ruins) | ✅ **DEPOIS do deploy** | primeiro sobe o código que para de gerar o erro, depois limpa |
| **remove** estrutura | ✅ depois, de preferência na release seguinte | só quando nenhum código usa |

Não idempotente → **confira antes** (`SHOW COLUMNS FROM ... LIKE ...`) e rode uma vez só.

### Os 12 passos (faça nos dois repos)

**1. Medir** (só leitura):
```bash
git fetch origin
git rev-list --left-right --count origin/<PROD>...origin/homolog   # A = hotfixes a absorver | B = o que sobe
git merge-tree --write-tree origin/homolog origin/<PROD> | grep '^CONFLICT' || echo LIMPO
git log origin/<PROD>..origin/homolog --oneline | grep -oE '[A-Z]+-[0-9]+' | sort -u
```

**2. Reconferir os scripts** (PR emergencial na homolog pode ter trazido script novo):
```bash
git diff --name-status origin/<PROD> origin/homolog | grep -iE 'varlib/comandos|migrations/|comandos/|\.sql$|seed'
```
+ o texto das PRs novas. Confirmar quem roda e a ordem (antes/depois).

**3. Branch de release — nasce da HOMOLOG.** Pela tela: seletor de branch → **troque para `homolog`
primeiro** → digite `release/v<DATA>` → *"Create branch ... from homolog"* (confira o "from homolog").
Terminal: `git switch -c release/v<DATA> origin/homolog`.

**4 + 6. Trazer a produção + PR de release.** 🆕 Pela tela, os dois viram um: abra
`https://github.com/<ORG>/<REPO>/compare/<PROD>...release/v<DATA>?expand=1` (base `<PROD>` ← compare
`release/v<DATA>`), título `MODULO | RELEASE | v<DATA>`. Se der conflito,
**Resolve conflicts funciona** (a compare é sua, não protegida): manter os dois lados, ler as seções,
*Mark as resolved* → *Commit merge*. ⚠️ **Conflito em código → terminal**, com calma
(`git merge origin/<PROD>` na branch de release).

**5. As provas:**
```bash
git rev-list --count origin/release/v<DATA>..origin/<PROD>    # ⭐ 0
git rev-list --count origin/release/v<DATA>..origin/homolog   #    0
git show --remerge-diff --format= --name-only origin/release/v<DATA>   # só texto
```
🆕 Prova 1 pela tela: `.../compare/release/v<DATA>...<PROD>` tem que dizer *"There isn't anything to compare"*.

**6. Descrição da PR:** tabela das PRs, hotfixes absorvidos, emergenciais da homolog, e **Rollout**
(script | card/PR | como rodar | idempotente? | antes/depois | se não rodar), provas.

**7. Portão** 🛑 — resumo para o tech lead:
```
Release v<DATA> pronta para o deploy — PRs #N (R3) e #N (R1).
*Sobem N cards:* ...
*Validação:* lista enviada ao suporte na quinta; <retorno ou "sem retorno (silêncio = aprovado)">.
*Scripts:* <lista, com antes/depois> — quem roda: <confirmado>.
*Provas:* release contém 100% da produção e da homolog; conflito só no CHANGELOG.
*Sinalizo, para a decisão de vocês:* <emergencial que não passou pela lista> · <hotfix que não passou pela homolog> · <testes que o QA não rodou> · <card REPROVADO EM QA>
Posso seguir com o merge?
```
**2 aprovações de outras pessoas + "sim" explícito.** Se perguntarem algo que você não sabe: *"vou
confirmar e te volto"*. Nunca mergear para ver.

**Scripts do tipo "antes"** → rodar agora.

**8. Merge = DEPLOY** (sem volta). `build_push`, `deploy_production` e `deploy_legacy_production`
verdes nos dois repos. Exit 42 → sênior de infra. Outro vermelho → tech lead, não mexa.
**Scripts do tipo "depois"** → rodar agora (dry-run → conferir → apply).

**9. Tag + Release no GitHub** 🆕 pela tela: *Releases → Draft a new release* → *Choose a tag*:
`v<DATA>` → *"Create new tag on publish"* → **Target = `<PROD>`** → título
`v<DATA> — <apelido> (<N> cards)` → descrição (abertura, cards em tabela, "Pós-deploy" com os scripts)
→ *Publish*. Confira que a tag aponta para o commit atual da produção.

**10. Backmerges** (4: `<PROD> → homolog` e `<PROD> → develop` nos dois repos). Título
`INFRA | MERGE | Backmerge v<DATA>`. Simule antes. Limpo → link direto
(`.../compare/<destino>...<PROD>?expand=1`). Conflito (o normal é `→ develop`, porque a develop recebeu
cards depois do corte) → 🆕 **intermediária pela tela**: crie `backmerge/<PROD>-para-develop-<DATA>`
**a partir da `<PROD>`**, abra PR base `develop` ← compare essa branch, *Resolve conflicts* (funciona,
a branch é sua), merge. (No terminal, o guia interno cria a intermediária a partir do destino; o resultado
é o mesmo. A base nunca muda.) Conflito em código → terminal + autor do card.

**11. Prova:**
```bash
for r in R3:master R1:main; do R=<ORG>/<REPO_${r%%:*}>; P=${r##*:}
  for d in homolog develop; do echo "${r%%:*} $d...$P $(gh api repos/$R/compare/$d...$P --jq .ahead_by)"; done; done
```
**Os quatro = 0.**

**12. Comunicar** no <CANAL_RELEASES> e no <CANAL_TECH>: (1) release notes
(`:package: _Release notes do deploy de DD/MM/AAAA_`, por sistema, Correções/Melhorias, avisos de
script) e (2) backmerges (`:arrows_counterclockwise:`, as 4 PRs, os 4 zeros, a tag).

---

## Se algo der errado

| Situação | O que fazer |
|---|---|
| botão de merge cinza, aprovação ok | conversa aberta. Verificar se é viva ou esquecida |
| "changes requested" que não sai | só quem pediu retira. Leve a informação que falta e peça para reavaliar (foi o caso de um QA na PR de homolog) |
| *"head branch is not up to date"* 🆕 | *Update branch*. Se a compare for protegida → branch intermediária |
| *Resolve conflicts* desabilitado | a compare é protegida → branch intermediária |
| não aparece *Approve* 🆕 | você é o autor. Chame outra pessoa por DM (mensagem no canal às 19h some) |
| exit 42 RecalcKrdx 🆕 | acionar o sênior de infra → re-run depois de liberar |
| o GitHub sugere `--admin` 🆕 | **nunca**. Leia a mensagem: diz o que falta |
| API de commits volta vazia 🆕 | o arquivo não está na branch padrão: acrescente `sha=<branch>` |
| comando com `<...>` 🆕 | trocar o marcador pelo valor real |
| travou num conflito | `git merge --abort` |
| abriu o vim | `:wq` (faltou `--no-edit`) |
| depois do merge na produção | não há desfazer simples: é hotfix de reversão, decisão do tech lead |

---

## Resumo de bolso

```
QUINTA
09:00  compares (conteúdo, não contagem) · PRs + conversas + onde conflita · canal + DMs · scripts (arquivo + TEXTO)
14:00  RECALCULA tudo · thread + DMs
17:00  destrava 1 por vez: CHANGELOG → push → re-aprova → checks → merge · BEHIND → Update branch · conversa esquecida → verifica e responde
       combina 2 revisores (quem abre a PR não aprova)
17:30  3º toque (só canal)
18:00  CORTE (mensagem nova, com donos e motivos) · scripts + compares de novo · backmerge se precisar
19:00  PR para homolog (R3 via homolog-cut/<DATA>) · aprovações · merge · Actions · /version
       exit 42 → sênior de infra → re-run
       lista do suporte (⚠️ nos cards com script) pela API

SEXTA  você testa · pergunta 1x · silêncio = aprovado

SEGUNDA (x2 repos)
 1 medir  2 scripts (antes/depois)  3 release/v<DATA> da homolog  4+6 PR de release, conflito resolvido
 5 provas (compare release...PROD vazio)  7 resumo + 2 aprovações + "SIM"  → scripts "antes"
 8 MERGE = DEPLOY → 3 jobs verdes → scripts "depois"  9 tag + Release (target PROD)
10 backmerges (intermediária pela tela)  11 compares = 0  12 release notes + backmerges
```

---
