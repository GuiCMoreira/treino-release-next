# Guia de Release e Deploy (quinta → segunda)

> Consolidado a partir dos Canvas *"Guia da segunda"* e *"Guia da quarta"* do José (20/08/2026),
> do canal de releases do time e da primeira quinta conduzida pelo Guilherme (24/09/2026).
> Adaptado para a agenda atual: **montagem na quinta, deploy na segunda**.
>
> **Versão pública:** valores internos viraram marcadores. Troque antes de usar:
>
> | Marcador | O que é |
> |---|---|
> | `<ORG>` | organização no GitHub |
> | `<REPO_R3>` / `<REPO_R1>` | os dois repositórios que sobem juntos na release |
> | `<PROD>` | branch de produção: `master` num repo, `main` no outro — **não troque um pelo outro** |
> | `<HOMOLOG_R3>` / `<HOMOLOG_R1>` | endereços dos ambientes de homologação |
> | `<CANAL_PRS>` | canal de cobrança de PRs |
> | `<CANAL_TECH>` / `<CANAL_RELEASES>` | canais onde vão a lista do suporte e as release notes |
> | `<JIRA>` | endereço do Jira |
> | **tech lead** | quem dá o "sim" do deploy e quem tem acesso para rodar script em produção |
> | `<DATA>` | data do **deploy** (a segunda), no formato `2026-09-28` |

---

## Parte 0 — Antes de tudo

### Seu papel

> Você **empacota e publica o que já está pronto**. Você **cobra**, não conserta.

| Não é seu | É de quem | O que você faz |
|---|---|---|
| corrigir código de card alheio (inclusive reprovado em QA) | autor da PR | sinaliza no resumo do deploy |
| caçar revisor | autor da PR | lista quem falta revisar |
| conflito de **regra de negócio** | autor da PR | devolve, pelo nome |
| decidir se um card "podia" entrar | autor / tech lead | leva o que tem aprovação |
| rodar script de banco em produção | tech lead | levanta e entrega a lista |

**A única coisa que impede um merge é não ter a aprovação** (e o que o GitHub bloqueia).
Card sem documentação, PR com título fora do padrão, commit sujo: você sinaliza em uma linha e segue.

### Conflito: quem resolve

| Tipo | Quem resolve | Quando |
|---|---|---|
| **CHANGELOG, `.gitignore`, linha em branco** | primeiro **avisa o dono** | você resolve **por volta das 17h**, se a PR estiver aprovada, sem conversa aberta e presa só por isso |
| real, mas com resolução óbvia e segura | idem | idem |
| **regra de negócio** (fiscal, valores, os dois lados mudaram a mesma regra) | **sempre o autor** | — |

O teste prático: se, ao olhar o conflito, você pensa *"é isso"*, resolve. Se pensa
*"acho que é isso"*, devolve.

**Por que não resolver cedo:** cada merge na develop recria o conflito de CHANGELOG em **todas**
as PRs abertas. Na primeira quinta, uma resolução feita ao meio-dia ficou velha às 14h, porque
entraram mais três PRs. E cada resolução derruba a aprovação.

### As regras do GitHub que explicam 90% das travas

O ruleset `protecao-branches-principais` vale em `develop`, `homolog` e `<PROD>`:

| Regra | Na prática |
|---|---|
| **1 aprovação** | o GitHub bloqueia com menos de 1. Nas PRs de homolog e de release, **peça 2** (hábito do time) |
| `dismiss_stale_reviews_on_push` | **todo push derruba a aprovação — inclusive resolvendo só o CHANGELOG** (verificado em PRs reais: caiu no mesmo minuto do push). Resolver conflito PRIMEIRO, pedir review DEPOIS |
| `required_review_thread_resolution` | botão cinza com aprovação ok = conversa sem *Resolve conversation* |
| sem bypass | ninguém fura, nem admin |

Mais duas coisas que confundem:
- **"Changes requested" não sai com a aprovação de outra pessoa.** Só quem pediu mudança retira
  (re-revisando). Se três pessoas revisaram e uma pediu mudança, a PR segue bloqueada.
- **`behind`** (atrás da develop) **não impede o merge** se não houver conflito.

### Tabela de parâmetros

| | `<REPO_R3>` | `<REPO_R1>` |
|---|---|---|
| Pasta de deploy | `~/deploy/r3-deploy` | `~/deploy/r1-deploy` |
| `<PROD>` | **`master`** | **`main`** |
| Job de build | `build_push` | `build` |
| Scripts de banco | `migrations/`, `varlib/comandos/` | `comandos/` |
| Homolog | `<HOMOLOG_R3>` | `<HOMOLOG_R1>` |

**Use uma pasta só para deploy**, separada da pasta onde você desenvolve. Zero chance de misturar
merge de release com card em andamento:

```bash
mkdir -p ~/deploy && cd ~/deploy
gh repo clone <ORG>/<REPO_R3> r3-deploy
gh repo clone <ORG>/<REPO_R1> r1-deploy
```

### O único ponto sem volta

Tudo na quinta é reversível. **O merge na `<PROD>` na segunda não é**, e antes dele existe um portão
humano: resumo apresentado e **"sim" explícito** do tech lead.

---

## Parte 1 — QUINTA: montagem

Objetivo: fechar o pacote na `develop`, publicar na `homolog` e mandar a lista para o suporte.

### 09:00 — Passo 1: a casa está arrumada?

O deploy anterior terminou com os backmerges? Os quatro têm que dar `0`:

```bash
for p in "<REPO_R3> develop...master" "<REPO_R3> develop...homolog" "<REPO_R1> develop...main" "<REPO_R1> develop...homolog"; do
  set -- $p; echo "$1 $2 ahead=$(gh api repos/<ORG>/$1/compare/$2 --jq .ahead_by)"
done
```

| Resultado | O que fazer |
|---|---|
| `develop<-<PROD>` > 0 | hotfix subiu direto em produção → **backmerge `<PROD> → develop`** depois do corte e antes de subir a homolog |
| `develop<-homolog` > 0 | olhe **o conteúdo**, não só a contagem (abaixo) |

**`develop<-homolog` > 0 nem sempre é problema.** Cada PR `develop → homolog` cria um commit de merge
que só existe na homolog. Com o tempo eles se acumulam. Confira se há **diferença de arquivos**:

```bash
gh api repos/<ORG>/<REPO_R3>/compare/develop...homolog --jq '[.files[].filename]|length'
```

`0` arquivos = só commits de merge, sem código faltando. Simule o merge da noite para confirmar
(`git merge-tree`, abaixo) e siga.

### 09:00 — Passo 2: levantar as PRs pendentes

Para cada PR: dono, link e pendência. Use o `reviewDecision` para a aprovação, o
`mergeable_state` (API REST) para o conflito e **as conversas abertas**, que são o que mais trava:

```bash
gh api graphql -f query='query($n:String!){repository(owner:"<ORG>",name:$n){pullRequests(states:OPEN,first:100){nodes{number isDraft author{login} reviewDecision mergeStateStatus reviewThreads(first:50){nodes{isResolved}}}}}}' \
  -f n=<REPO_R3> \
  --jq '.data.repository.pullRequests.nodes|sort_by(.number)[]|"#\(.number) \(.author.login) \(.reviewDecision//"-") \(.mergeStateStatus) conversas_abertas=\([.reviewThreads.nodes[]|select(.isResolved==false)]|length) draft=\(.isDraft)"'
```

Para saber **em que arquivo** está o conflito de cada PR (e separar CHANGELOG de código):

```bash
cd ~/deploy/r3-deploy && git fetch origin '+refs/pull/*/head:refs/remotes/pr/*' && git fetch origin
git merge-tree --write-tree --name-only origin/develop pr/<N> | grep '^CONFLICT'
```

| `mergeable_state` | significa |
|---|---|
| `clean` | pode mergear |
| `dirty` | conflito |
| `behind` | atrás da develop (não impede o merge) |
| `blocked` | falta aprovação, check ou conversa resolvida |
| `unknown` | o GitHub ainda não calculou — rode de novo em alguns segundos |

### 09:00 — Passo 3: cobrar (canal + DM)

**`<CANAL_PRS>`**, com a lista **inteira** (sem "...e mais X"):

```
@here Bom dia! Sou eu no deploy desta semana.

*Corte hoje às 18h*
O que não estiver aprovado e mergeado na develop até lá fica para a release da semana que vem.

:eyes: N PRs abertas — M com pendência. Atenção: se o botão está cinza com aprovação em ordem,
é conversa de review sem "Resolve conversation".

*<REPO_R3>*
• #N — dono — link (pendência: conflito no CHANGELOG / conflito em código / N conversas abertas / mudanças pedidas por X / falta review)

*<REPO_R1>*
• #N — dono — link (pendência)

Por favor, verifiquem suas respectivas PRs.
```

**DM por dono**, juntando os dois repos numa mensagem só. Diga **qual** é a pendência e **de quem**
depende ("mudanças pedidas por Fulano" é mais útil que "falta review").

### 09:00 — Passo 4: ⭐ scripts de banco

PRs podem trazer `.sql` ou script PHP que **não roda sozinho no deploy**. Levante quais são,
de qual PR vieram, quem é o dono, se precisa mesmo rodar (só `SELECT` não precisa), o comando
exato, se é idempotente e o que acontece se não rodar:

```bash
for n in $(gh pr list -R <ORG>/<REPO_R3> --state open --json number --jq '.[].number'); do
  gh api "repos/<ORG>/<REPO_R3>/pulls/$n/files?per_page=100" --jq '.[].filename' \
    | grep -E '(^|/)migrations/|varlib/comandos/|\.sql$' | sed "s|^|#$n: |"
done
```

Monte o arquivo `<DATA>_SCRIPTS-DA-RELEASE.md` e avise o tech lead. **Refaça depois do corte**: as
PRs que entrarem durante o dia podem trazer script novo.

> **Script na homolog:** em regra não é preciso rodar. **A exceção** é quando a feature não
> funciona sem ele — nesse caso, peça para rodarem na homolog **antes** de mandar a lista ao
> suporte, senão ele reporta bug num card que está certo.

### 14:00 — Passo 5: segundo toque

**Recalcule tudo** — não repita a lista da manhã. Em um dia real, entre 9h e 14h: quatro PRs
entraram, duas prontas passaram a conflitar no CHANGELOG, uma PR ganhou conflito em código que não
tinha, duas PRs novas foram abertas e um hotfix foi direto para produção em um dos repos.

Resposta **na thread** da mensagem da manhã + DM só para quem ainda tem pendência.

### ~17:00 — combinar revisores e destravar o CHANGELOG

- Combine os **2 revisores** da PR `develop → homolog` **agora**, não às 19h.
- PRs aprovadas, sem conversa aberta, presas **só** por CHANGELOG: resolva **uma por vez**:
  resolve → push → **revisor re-aprova** → merge → **só então** a próxima (o merge da primeira
  recria o conflito na segunda). Combine com o revisor **antes** de começar.

Resolver o CHANGELOG localmente, com prova:

```bash
cd ~/deploy/r3-deploy && git fetch origin
git switch -C <branch-da-pr> origin/<branch-da-pr>
git merge origin/develop                      # conflito no CHANGELOG
grep -c '^<<<<<<<' CHANGELOG.md; wc -l CHANGELOG.md
# resolva mantendo os dois lados (VS Code: "Accept Both Changes")
grep -nE '^(<<<<<<<|=======|>>>>>>>)' CHANGELOG.md || echo "NENHUM — OK"
wc -l CHANGELOG.md                            # antes − depois = 3 × nº de blocos
git add CHANGELOG.md && git commit --no-edit
git show --remerge-diff --format= --name-only HEAD   # tem que listar SÓ o CHANGELOG.md
git push
```

### 17:30 — Passo 6: terceiro toque

Só no canal, sem DM: *"Faltam 30 minutos para o corte das 18h..."*

### 18:00 — Passo 7: o corte

1. Mergeie **pela tela** o que estiver verde (*Merge pull request* → *Confirm merge*).
   Botão cinza → conversa aberta ou conflito. **Nunca force.**
2. **Não apague a branch** depois do merge — é do dono.
3. Avise:

```
:lock: *Corte das 18h encerrado.*

*Entraram na develop hoje:*
<REPO_R3>: #... · <REPO_R1>: #...

*Ficaram de fora:* <REPO_R3>: N PRs · <REPO_R1>: M PRs
Entram no corte da próxima quinta, sem precisar refazer nada.

Vou subir a homolog agora. Aviso aqui quando estiver no ar.
```

4. **Refaça o Passo 4** (scripts) e **os 4 compares do Passo 1**.

### Passo 8: ⭐ backmerge antes de subir (se algum compare deu > 0)

Hotfix direto em produção precisa voltar para a develop **antes** de a develop subir. Simule:

```bash
git merge-tree --write-tree --name-only origin/develop origin/<PROD> | grep '^CONFLICT' || echo LIMPO
```

- **Limpo** → PR pelo link `https://github.com/<ORG>/<REPO>/compare/develop...<PROD>?expand=1`
- **Conflito** → o botão *Resolve conflicts* vem **desabilitado** (a *compare* é a `<PROD>`,
  protegida). Use a **branch intermediária**:

```bash
git switch -c backmerge/<PROD>-para-develop-<DATA> origin/develop   # nasce do DESTINO
git merge origin/<PROD>
# resolva; prove (marcadores, conta de linhas, remerge-diff)
git add -u && git commit --no-edit
git push -u origin backmerge/<PROD>-para-develop-<DATA>
```

Feche a PR que ficou com o botão morto e abra outra com **base: `develop`** ←
**compare: `backmerge/...`**. Título: `INFRA | MERGE | Backmerge <PROD> -> develop`.

> **A regra:** a `base` nunca muda, é sempre o destino. A intermediária **nasce do destino**,
> recebe a origem e vai no **`compare`**.

### 18:30 — Passo 9: PR `develop → homolog`

É esta PR que publica o ambiente de teste. Simule; se limpo, link direto:
`https://github.com/<ORG>/<REPO>/compare/homolog...develop?expand=1`. Se der conflito, mesma lógica
da intermediária, nascendo da **homolog**: `sync/develop-para-homolog-<AAAAMMDD>`.

- Confira **base: `homolog`** ← **compare: `develop`** (ou a intermediária)
- Título: `INFRA | MERGE | Develop -> homolog`
- Descrição: PRs que sobem (nº, card, título, autor), o que ficou de fora, scripts de banco
- **2 aprovações** e merge

### 19:00 — Passo 10: acompanhar o Actions

| | `<REPO_R3>` | `<REPO_R1>` |
|---|---|---|
| build | `build_push` ✅ | `build` ✅ |
| deploy | `deploy_homolog` ✅ | `deploy_homolog` ✅ |

`deploy_production`, `deploy_legacy_production` e `deploy_develop` como **skipped** é a prova de
que ninguém tocou em produção. `build` verde sozinho **não basta**. **Job vermelho → chame o tech
lead. Não mexa.**

### 19:20 — Passo 11: comunicar

1. **`<CANAL_PRS>`**, um por repo: `:white_check_mark: *Homolog do <REPO> no ar* — PR #N — N commits · M PRs · deploy_homolog verde às HH:MM`
2. **`<CANAL_TECH>` e `<CANAL_RELEASES>`** — a lista para o suporte. ⚠️ **Só depois do
   `deploy_homolog` verde nos dois.**

Cards a partir **do git** (o status do Jira não acompanha o código: já houve card em produção
aparecendo como "A Fazer"). Do Jira sai só tipo, cliente e descrição:

```
Olá!

Pessoal, seguem as tasks liberadas para teste no ambiente de homologação.

*Ambientes:*
• <REPO_R3> — <HOMOLOG_R3>
• <REPO_R1> — <HOMOLOG_R1>

*Bugs para validar*
• <<JIRA>/browse/CARD|CARD> — Cliente — descrição curta, em português de gente

*Melhorias para validar*
• <<JIRA>/browse/CARD|CARD> — Cliente — descrição curta

Se faltar o ambiente de algum cliente no homolog, me avisem que eu sincronizo.

Obrigado!
```

- `Erro` → *Bugs para validar* · `Tarefa` → *Melhorias para validar*
- **separe por módulo** (o suporte testa em telas diferentes) e junte cards do mesmo cliente
- **hotfix que já está em produção não entra na lista de teste** (entra nas release notes)
- card que depende de script → aviso explícito, ou script rodado na homolog antes

### ✅ Fim da quinta

- [ ] `<DATA>_SCRIPTS-DA-RELEASE.md` pronto e tech lead avisado
- [ ] lista das PRs que entraram, por repo
- [ ] backmerges de hotfix feitos (compares `develop<-<PROD>` = 0)
- [ ] lista enviada ao suporte depois do `deploy_homolog` verde

---

## Parte 2 — SEXTA: suporte testa

1. **Você também testa**, priorizando cálculo fiscal, fechamento e valores (erro ali é silencioso)
   e o que você mesmo resolveu de conflito.
2. **Pergunte uma vez**, na thread da lista.
3. Classifique:

| Retorno | Ação |
|---|---|
| "testado, ok" | aprovado |
| **silêncio** | **aprovado** — não cobre duas vezes |
| erro | o **autor** corrige a tempo? Segue. Se não → leve ao tech lead. A regra histórica é **cancelar o deploy inteiro** (a release sobe como um pacote só) |

---

## Parte 3 — SEGUNDA: deploy

Faça nos dois repos (mesmos passos, troque `master` ↔ `main`).

### Passo 1: medir (só leitura)

```bash
cd ~/deploy/r3-deploy && git fetch origin && git status --short
git rev-list --left-right --count origin/<PROD>...origin/homolog
#   A  B  →  A = hotfixes em produção que não voltaram  |  B = o que vai subir
git merge-tree --write-tree origin/homolog origin/<PROD> | grep -E '^CONFLICT' || echo LIMPO
git log origin/<PROD>..origin/homolog --oneline | grep -oE '[A-Z]+-[0-9]+' | sort -u
```

### Passo 2: reconferir os scripts de banco

Entre quinta e segunda pode ter entrado **PR emergencial direto na homolog** — e a release nasce da
homolog, então ela vai junto:

```bash
git diff --name-status origin/<PROD> origin/homolog | grep -iE 'varlib/comandos|migrations/|comandos/|\.sql$|seed'
```

Confirme com o tech lead **quem roda e em que horário**.

### Passo 3: branch de release (nasce da HOMOLOG)

```bash
git switch -c release/v<DATA> origin/homolog
```

### Passo 4: ⭐ trazer a produção para dentro da release

```bash
git merge-tree --write-tree origin/homolog origin/<PROD> | grep -E '^CONFLICT' || echo LIMPO   # simula
git merge origin/<PROD>
```

- **Limpo** → `Merge made by the 'ort' strategy.` O git já commitou. **Não** rode add/commit.
- **Conflito** → anote marcadores e linhas, resolva mantendo os dois lados, prove, e
  `git add <arquivos> && git commit --no-edit`.

Duplicata no CHANGELOG é o comportamento histórico do arquivo. **Não limpe no dia do deploy.**

```bash
git push -u origin release/v<DATA>
```

### Passo 5: as provas (só leitura)

```bash
git fetch origin
git rev-list --count origin/release/v<DATA>..origin/<PROD>    # ⭐ tem que dar 0
git rev-list --count origin/release/v<DATA>..origin/homolog   #    tem que dar 0
git log origin/release/v<DATA> --oneline --grep="CARD-XXXX" | head -1   # por card
H=$(git rev-parse origin/release/v<DATA>)
T=$(git merge-tree --write-tree $(git rev-parse $H^1) $(git rev-parse $H^2) | head -1)
git diff --name-only $T $H     # só arquivos de texto. Apareceu código? PARE.
```

### Passo 6: PR de release

- `https://github.com/<ORG>/<REPO>/compare/<PROD>...release/v<DATA>?expand=1`
- **base: `<PROD>`** ← **compare: `release/v<DATA>`**
- Título: `MODULO | RELEASE | v<DATA>`
- Descrição: PRs que entram, hotfixes absorvidos, nº de commits/arquivos e **Rollout** (cada
  script: arquivo, card, PR, dono, comando, banco, o que acontece se não rodar)

### Passo 7: aprovações + portão humano

- **2 aprovações**, combinadas cedo.
- Resumo: cards · quem validou (ou "silêncio = aprovado") · scripts e quem roda · riscos ·
  **sinalizações** (card reprovado em QA no pacote, conflito resolvido e não testado). Uma linha cada.
- 🛑 **"Sim" explícito do tech lead.** Nunca "porque está tudo verde".

### Passo 8: ⚠️ merge = deploy

Publica em produção nos **dois backends**. Os três têm que ficar verdes, nos dois repos:

```
build (build_push)          ✅
deploy_production           ✅
deploy_legacy_production    ✅
```

```bash
gh run list -R <ORG>/<REPO> --branch <PROD> --limit 3
gh run watch <ID> -R <ORG>/<REPO> --exit-status
```

**Job vermelho → tech lead. Não mexa.** Depois do merge não existe desfazer simples.

### Passo 9: tag + Release no GitHub

Só depois dos três verdes:

```bash
git fetch origin && git tag v<DATA> origin/<PROD> && git push origin v<DATA>
```

Release no GitHub em cima da tag: título `v<DATA> — <apelido do pacote> (<N> cards)`, abertura com o
ciclo desde a tag anterior, cards agrupados por tema em tabela, e seção `Pós-deploy (produção)` com
os scripts.

### Passo 10: ⭐ os 4 backmerges

| `<REPO_R3>` | `<REPO_R1>` |
|---|---|
| `master → homolog` | `main → homolog` |
| `master → develop` | `main → develop` |

**É o único passo cujo esquecimento não dá erro na hora.** Sem ele, a próxima release nasce sem as
correções que estão no cliente, e um card novo pode desfazê-las em silêncio (já aconteceu com uma
correção fiscal).

Simule os quatro com `git merge-tree`. Limpos → link direto. Conflito (o comum é `→ develop`) →
branch intermediária nascendo do destino, como no Passo 8 da quinta. Aqui o conflito **pode cair em
código**: arquivo acumulativo mantém os dois lados; código, abra o bloco; mesma regra mexida dos
dois lados → chame o autor. Título: `INFRA | MERGE | Backmerge v<DATA>`.

### Passo 11: a prova de que fechou

```bash
gh api repos/<ORG>/<REPO_R3>/compare/homolog...master --jq '.ahead_by'
gh api repos/<ORG>/<REPO_R3>/compare/develop...master --jq '.ahead_by'
gh api repos/<ORG>/<REPO_R1>/compare/homolog...main   --jq '.ahead_by'
gh api repos/<ORG>/<REPO_R1>/compare/develop...main   --jq '.ahead_by'
```

**Os quatro = 0.** Cole os números na mensagem.

### Passo 12: comunicar (2 mensagens × `<CANAL_RELEASES>` e `<CANAL_TECH>`)

**Release notes:**

```
:package: _Release notes do deploy de DD/MM/AAAA_

@here Seguem os cards que sobem em produção hoje, *DD/MM/AAAA, às HHh*.
São *N cards*.

:small_blue_diamond: _<Sistema 1>_ — N cards
_Correções:_
• <<JIRA>/browse/CARD|CARD> — descrição em linguagem de negócio (cliente)
_Melhorias:_
• <<JIRA>/browse/CARD|CARD> — descrição

Avisos: scripts que NÃO rodam sozinhos (e quem roda) · feature flags que sobem desligadas
```

Se não couber, divida em "(1/2)", "(2/2)".

**Backmerges:**

```
:arrows_counterclockwise: _Backmerges da release v<DATA> — concluídos nos dois repositórios_

_<REPO_R3>_: `master → homolog` — PR # · `master → develop` — PR #
_<REPO_R1>_: `main → homolog` — PR # · `main → develop` — PR #

_Prova de que fechou_ — os quatro compares deram zero:
r3 homolog...master : 0 · r3 develop...master : 0
r1 homolog...main   : 0 · r1 develop...main   : 0

Tags publicadas nos dois repos: `v<DATA>`.
```

---

## Se algo der errado

| Situação | O que fazer |
|---|---|
| travou no meio de um conflito | `git merge --abort` |
| abriu a PR errada | *Close pull request* — não quebra nada |
| mergeou PR na develop por engano | botão *Revert* na PR + avise o dono |
| botão de merge cinza | conversa sem *Resolve conversation* |
| "changes requested" que não sai | só quem pediu retira; aprovação de outra pessoa não basta |
| PR de release ficou conflitante do nada | alguém mexeu em produção: `git fetch` + `git merge origin/<PROD>` na release |
| `fatal: branch release/... already exists` | `git switch release/v<DATA>` para continuar |
| abriu o vim | faltou `--no-edit`: `:wq` e Enter |
| job vermelho (homolog ou produção) | **tech lead. Não mexa.** |
| conflito que você não entende | devolva ao autor, pelo nome |
| backmerge errado | *Revert* existe, mas reverter um merge exige depois "reverter o revert". Prefira corrigir para frente |

---

## Resumo de bolso

```
QUINTA
09:00  4 compares (casa arrumada?) · lista de PRs · canal + DMs · scripts de banco
14:00  2º toque: RECALCULA tudo · thread + DMs só pra quem ainda aparece
17:00  combinar 2 revisores da PR de homolog · destravar CHANGELOG, uma PR por vez
17:30  3º toque (só canal)
18:00  CORTE: mergear pelo site o que está verde · refazer scripts e compares
       backmerge de hotfix se develop<-PROD > 0 (conflito? intermediária nasce da DEVELOP)
18:30  PR "INFRA | MERGE | Develop -> homolog" (conflito? intermediária nasce da HOMOLOG)
19:00  build + deploy_homolog VERDES
19:20  "homolog no ar" + lista pro suporte

SEXTA   você testa + pergunta 1x · silêncio = aprovado · erro sem correção → tech lead

SEGUNDA
 1 medir (rev-list + merge-tree)       2 reconferir scripts + quem roda
 3 release/v<DATA> de origin/homolog   4 git merge origin/<PROD> (simula antes) → push
 5 provas: release..PROD == 0, release..homolog == 0
 6 PR "MODULO | RELEASE | v<DATA>"     7 2 aprovações + resumo + 🛑 "SIM"
 8 MERGE = DEPLOY → 3 jobs verdes      9 tag + Release no GitHub
10 4 backmerges    11 4 compares == 0    12 release notes + backmerges
```
