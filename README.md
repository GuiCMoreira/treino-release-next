# Treino de Release e Deploy

Repositório **fictício** para treinar, pela tela do GitHub, o fluxo de release semanal
`develop → homolog → master` usado no time: corte das PRs, conflitos, backmerges,
PR de homologação, branch de release, deploy de produção e tag.

Nada aqui é código real. O "projeto" é um mini-ERP de restaurante inventado, e os cards
`TRE-*`, os clientes e os nomes das pessoas também são inventados.

> **Quem fez e por quê:** montado em 23–24/09/2026 para a primeira release do Guilherme como
> responsável pelo rodízio. Quem pega o rodízio pela primeira vez normalmente nunca abriu uma
> PR de release, um backmerge ou uma branch intermediária **pela tela**. Aqui dá para errar à
> vontade: nada vai para cliente nenhum.

---

## Sumário

1. [Como o repositório imita o de verdade](#1-como-o-repositório-imita-o-de-verdade)
2. [Os conceitos em 5 minutos](#2-os-conceitos-em-5-minutos)
3. [Montar o seu próprio treino](#3-montar-o-seu-próprio-treino)
4. [Roteiro da QUINTA — montagem da release](#4-roteiro-da-quinta--montagem-da-release)
5. [Roteiro da SEGUNDA — deploy](#5-roteiro-da-segunda--deploy)
6. [Glossário da tela do GitHub](#6-glossário-da-tela-do-github)
7. [Documentos](#7-documentos)

---

## 1. Como o repositório imita o de verdade

| No sistema real | Aqui no treino |
|---|---|
| branches `develop`, `homolog`, `master` | as mesmas três |
| ruleset `protecao-branches-principais` nas três branches | **o mesmo nome e as mesmas regras**, com uma diferença (abaixo) |
| workflow `ci-oke` com `build_push`, `deploy_develop`, `deploy_homolog`, `deploy_production`, `deploy_legacy_production` | os mesmos 5 jobs, com os mesmos nomes. Eles só imprimem mensagens, não publicam nada |
| `CHANGELOG.md` onde cada PR escreve no topo | o mesmo, e é ele que gera quase todos os conflitos, como na vida real |
| scripts de banco em `migrations/` e `varlib/comandos/` | as mesmas pastas |
| título de PR `MODULO \| TIPO \| CARD Descrição` | o mesmo padrão |

**A única diferença no ruleset: 0 aprovações obrigatórias em vez de 1.** No GitHub ninguém
aprova a própria PR, e o treino é feito por uma pessoa só. As outras regras estão todas ativas:

| Regra | O que você vai sentir na tela |
|---|---|
| exige PR para `develop`, `homolog` e `master` | não dá para dar push direto. Tudo passa por PR |
| `dismiss_stale_reviews_on_push` | todo push na PR derruba as aprovações (no treino não aparece, porque são 0) |
| `required_review_thread_resolution` | **botão de merge cinza** enquanto houver comentário de review sem *Resolve conversation* |
| sem bypass | ninguém fura a regra, nem o dono do repo |

> Por que o repositório é **público**: no plano gratuito do GitHub, as regras de proteção só
> valem em repositório público. Num privado gratuito você não veria nenhuma das travas.

---

## 2. Os conceitos em 5 minutos

### A esteira

```
feature/bugfix ──PR──▶ develop ──PR──▶ homolog ──PR──▶ master
   (o dev)          (integração)    (suporte testa)    (CLIENTE — produção)
```

- **develop**: onde cada dev entrega o card.
- **homolog**: o ensaio. O merge nela **publica sozinho** o ambiente de teste do suporte.
- **master**: produção. **O merge nela É o deploy.** Não existe tela de "confirmar" depois.

### A agenda

| Dia | O que acontece |
|---|---|
| **Quinta** | cobrança das PRs, corte às 18h, backmerges pendentes, PR `develop → homolog`, lista para o suporte |
| **Sexta** | suporte testa. Silêncio vale como aprovado |
| **Segunda** | branch de release, PR para `master` (= deploy), tag, Release no GitHub, 4 backmerges, comunicação |

### O papel de quem está no rodízio

> Você **empacota e publica o que já está pronto**. Você **cobra**, não conserta.

| Não é seu | É de quem |
|---|---|
| corrigir código de card alheio | autor da PR |
| caçar revisor para PR alheia | autor da PR |
| resolver conflito de **regra de negócio** (fiscal, valores, dois lados mudando a mesma regra) | autor da PR |
| decidir se um card "podia" entrar | autor / tech lead |
| rodar script de banco em produção | só quem tem acesso a produção |

**Conflito de CHANGELOG** (duas entradas disputando o mesmo lugar): primeiro você **avisa o dono**.
Se por volta das **17h** a PR estiver aprovada, sem conversa aberta e presa **só** por isso, você
resolve. Resolver mais cedo é retrabalho: **cada merge na develop recria o conflito em todas as
outras PRs**.

### As três armadilhas que mais travam

1. **O push derruba a aprovação**, mesmo quando você resolveu só o CHANGELOG. Verificado em PRs
   reais: a aprovação caiu no mesmo minuto do push. Então **resolva o conflito primeiro e peça
   review depois**, e avise o revisor para re-aprovar.
2. **Botão cinza com aprovação em ordem** quase sempre é conversa sem *Resolve conversation*.
3. **O botão "Resolve conflicts" desabilitado não é bug.** Ele gravaria a resolução na branch
   `compare`, e quando ela é protegida (`master`, `develop`) o GitHub não deixa. A saída é a
   **branch intermediária**:

   > A `base` da PR **nunca muda**: é sempre o destino. A branch intermediária **nasce do destino**,
   > recebe o merge da origem e entra no campo **`compare`**.

### O único ponto sem volta

Tudo na quinta é reversível (`git merge --abort`, fechar PR, botão *Revert*). O único passo sem
volta é o **merge na master na segunda**. Antes dele existe um portão humano: você apresenta o
resumo e espera um **"sim" explícito** do tech lead.

---

## 3. Montar o seu próprio treino

O script [`scripts/setup_treino.sh`](scripts/setup_treino.sh) cria uma cópia deste cenário **na
sua conta do GitHub**, no estado de "quinta de manhã".

**Pré-requisitos:** `git`, `python3` e o `gh` logado na sua conta (`gh auth status` precisa
mostrar o escopo `repo`).

```bash
git clone https://github.com/GuiCMoreira/treino-release-next.git
cd treino-release-next
bash scripts/setup_treino.sh
```

O script cria o repositório `treino-release-next` na **sua** conta, as branches, 9 PRs, um
comentário de review e o ruleset, e clona tudo em `~/meu-treino-release`. Se já existir um repo
com esse nome na sua conta, ele para antes de mexer em qualquer coisa.

**Para recomeçar do zero:** apague o repositório no GitHub (*Settings → Danger Zone → Delete this
repository*) e rode o script de novo.

> ⚠️ O script apaga e recria a pasta local `~/meu-treino-release`. Não use esse caminho para
> outra coisa.

---

## 4. Roteiro da QUINTA — montagem da release

### O cenário ("quinta de manhã")

| PR | Card | Dono (fictício) | O que tem |
|---|---|---|---|
| #1 | TRE-206 | Elisa | ? |
| #4 | TRE-203 | Diego | ? |
| #6 | TRE-201 | Ana | ? |
| #7 | TRE-202 | Carla | ? |
| #8 | TRE-204 | Bruno | ? |
| #9 | TRE-205 | — | ? |
| #2, #3, #5 | TRE-150, TRE-199, TRE-200 | — | já mergeadas (histórico) |

Cada situação que aparece numa quinta real está aqui pelo menos uma vez. Tente descobrir sozinho
antes de abrir o gabarito.

<details>
<summary><b>Gabarito do cenário</b></summary>

| PR | Situação | Balde |
|---|---|---|
| #6 TRE-201 | limpa | **entra** no corte |
| #8 TRE-204 | limpa, mas traz `migrations/…_add_ncm_produto.sql` | **entra**, e o script vai para a lista de scripts de banco |
| #7 TRE-202 | comentário de review sem resposta | **cobrar**: botão cinza até alguém clicar em *Resolve conversation* |
| #4 TRE-203 | conflito só no `CHANGELOG.md` | **cobrar**; se às 17h ainda estiver só com isso, você resolve |
| #1 TRE-206 | conflito em `Fiscal.class.php`: ela e o TRE-199 mudaram **a mesma regra de ICMS** | **devolver** à autora. Escolher o lado é decidir imposto |
| #9 TRE-205 | draft | ignora |

E mais: a `master` tem um hotfix (TRE-150) que a `develop` não tem. É isso que o Passo 1 pega.

</details>

### Passo 1 — a casa está arrumada?

```bash
gh api repos/<SEU_USUARIO>/treino-release-next/compare/develop...master  --jq '"develop<-master  \(.ahead_by)"'
gh api repos/<SEU_USUARIO>/treino-release-next/compare/develop...homolog --jq '"develop<-homolog \(.ahead_by)"'
```

Os dois deveriam dar `0`. Aqui `develop<-master` dá **2**: o hotfix TRE-150 foi direto para a
produção e não voltou (são 2 commits porque o GitHub conta o do hotfix e o do merge da PR).
Dá para ver na tela: `https://github.com/<SEU_USUARIO>/treino-release-next/compare/develop...master`.

**Por que é perigoso:** a partir daqui, todo card aberto da develop nasce sem a correção. Um dia
alguém mexe no mesmo arquivo e desfaz o hotfix **em silêncio**. **O que fazer:** backmerge
`master → develop` depois do corte e antes de subir a homolog (Exercício 4).

### Passo 2 — triagem e cobrança

Na vida real quem está no rodízio levanta a lista (com `gh` ou com o Claude) e manda no canal de
PRs, com a lista **inteira**, e uma DM por dono. Aqui, abra cada PR e leia a **caixa de merge**
(logo acima do botão verde) — ver o [glossário](#6-glossário-da-tela-do-github).

Modelo da mensagem no canal:

```
@here Bom dia! Sou eu no deploy desta semana.

*Corte hoje às 18h*
O que não estiver aprovado e mergeado na develop até lá fica para a release da semana que vem.

:eyes: N PRs abertas — M com pendência

• #N — dono — link (pendência)

Por favor, verifiquem suas respectivas PRs.
```

Toques: **09h** (canal + DM), **14h** (recalcula, canal + DM só para quem ainda aparece),
**17h30** (só canal). **Recalcule a lista a cada toque:** cada merge muda o estado das outras PRs.

### Exercício 1 — botão cinza por conversa aberta (#7)

1. Abra a #7 e leia a caixa de merge **antes de mexer**.
2. No comentário em `class/RelatorioEstoque.class.php`, clique em **Resolve conversation**.
3. Volte à caixa de merge. O botão ficou verde. **Não mergeie ainda.**

> Na vida real esse clique é do **dono ou do revisor**. Resolver a conversa de outra pessoa pode
> encerrar uma pergunta que o revisor queria ver respondida. Sua parte é reconhecer e cobrar.

### Exercício 2 — conflito de CHANGELOG pela tela (#4)

Cenário: 17h, o dono não resolveu, a PR não tem outra pendência.

1. Na caixa de merge, **Resolve conflicts**.
2. No editor: entre `<<<<<<<` e `=======` está o que **a PR** trouxe; entre `=======` e
   `>>>>>>>` está o que **a develop** já tem.
3. **Mantenha as duas linhas**, apague só as três linhas de marcador.
4. **Mark as resolved** → **Commit merge**.

<details>
<summary><b>Por que aqui o botão funciona e no backmerge não?</b></summary>

O commit que o botão cria se chama `Merge branch 'develop' into feature/TRE-203`: ele é gravado
**na branch do card**, que não é protegida. No backmerge `master → develop`, o commit iria para a
`master` (a *compare*), que é protegida. Por isso lá o botão vem desabilitado.

</details>

### Exercício 3 — o corte das 18h

Mergeie **pela tela**, uma de cada vez, as PRs verdes (#4, #6, #7, #8). **Antes de cada clique,
olhe a caixa de merge de novo.** Não toque na #1 nem na #9.

- **Não clique em "Delete branch"** depois do merge. A branch é do dono. No repositório real
  ninguém apaga (nenhuma das últimas 30 PRs teve a branch apagada).
- Depois do corte, **refaça o levantamento de scripts de banco**: o `.sql` do TRE-204 entrou na
  develop sem nenhum aviso. Nenhum job de CI roda script de banco.

### Exercício 4 — backmerge `master → develop` com branch intermediária

1. Abra `https://github.com/<SEU_USUARIO>/treino-release-next/compare/develop...master?expand=1`,
   título `INFRA | MERGE | Backmerge master -> develop`, **Create pull request**.
2. Veja que dá conflito e que **Resolve conflicts está desabilitado**.
3. No terminal:

```bash
cd ~/meu-treino-release && git fetch origin
git switch -c backmerge/master-para-develop-<DATA> origin/develop   # nasce do DESTINO
git merge origin/master                                             # traz a origem
grep -c '^<<<<<<<' CHANGELOG.md; wc -l CHANGELOG.md                 # anote os números
code CHANGELOG.md                                                   # "Accept Both Changes" e salve
grep -nE '^(<<<<<<<|=======|>>>>>>>)' CHANGELOG.md || echo "NENHUM — OK"
wc -l CHANGELOG.md          # linhas antes − depois = 3 × nº de blocos. Mais que isso = apagou conteúdo
git add CHANGELOG.md && git commit --no-edit                        # --no-edit evita abrir o vim
git push -u origin backmerge/master-para-develop-<DATA>
```

4. **Feche a PR do passo 1** (*Close pull request*, não quebra nada).
5. Abra a PR nova com **base: `develop`** ← **compare: `backmerge/master-para-develop-<DATA>`**,
   mesmo título, e mergeie.
6. Prove: `develop...master` tem que dar **0**. "Eu fiz" não é evidência — criar a PR não basta,
   o código só chega no merge.

> Travou no meio? `git merge --abort` volta tudo como estava.

### Exercício 5 — PR `develop → homolog`

1. Simule antes: `git merge-tree --write-tree origin/homolog origin/develop | grep CONFLICT || echo LIMPO`
2. Limpo → `https://github.com/<SEU_USUARIO>/treino-release-next/compare/homolog...develop?expand=1`
3. Confira **base: `homolog`** ← **compare: `develop`**. Título `INFRA | MERGE | Develop -> homolog`.
   Descrição: as PRs que sobem, o que ficou de fora e os scripts de banco.
4. Mergeie e vá em **Actions → ci-oke**:

| Job | Esperado |
|---|---|
| `build_push` | ✅ |
| `deploy_homolog` | ✅ |
| `deploy_develop`, `deploy_production`, `deploy_legacy_production` | ⚪ skipped — a prova de que ninguém tocou em produção |

`build_push` verde **sozinho** não basta: espere o `deploy_homolog`.

Depois disso `develop...homolog` dá **1**, e não é problema: é o próprio commit de merge da PR,
que só existe na homolog. Com o tempo esses commits se acumulam (no sistema real havia 9, com
**0 arquivos de diferença**). O que importa é o diff de conteúdo, não a contagem.

### Exercício 6 — a lista para o suporte

**Só depois do `deploy_homolog` verde.** Se sair antes, o suporte testa a versão velha e responde
"ok" — e "ok" (ou silêncio) vale como aprovado.

Fonte dos cards: **o git**, nunca o status do Jira (o Jira não acompanha o código). Do Jira sai só
o tipo (Erro → *Bugs para validar*, Tarefa → *Melhorias para validar*), o cliente e a descrição.

<details>
<summary><b>Mensagem modelo e as duas decisões do treino</b></summary>

```
Olá!

Pessoal, seguem as tasks liberadas para teste no ambiente de homologação.

*Ambiente:*
• homolog.treino.example.com

*Bugs para validar*
• TRE-204 — Padaria Sol — Cadastro de produto passa a ter o campo NCM (obrigatório para a NFC-e) :warning: depende de script de banco na homolog, aviso aqui quando estiver liberado

*Melhorias para validar*
• TRE-199 — Cantina Bella — ICMS calculado conforme a alíquota de cada estado
• TRE-203 — Cantina Bella — Taxa de serviço configurável por loja (antes era sempre 10%)
• TRE-201 — Burger do Zé — Desconto por cupom no pedido (BEMVINDO10 e FIDELIDADE5)
• TRE-200 — Alerta quando o estoque de um produto fica abaixo do mínimo
• TRE-202 — Relatório de produtos abaixo do estoque mínimo

Se faltar o ambiente de algum cliente no homolog, me avisem que eu sincronizo.

Obrigado!
```

1. **O TRE-150 fica fora da lista.** Ele já está em produção (foi hotfix). Entra nas release notes
   de segunda, não no teste.
2. **O TRE-204 entra com aviso.** Na homolog, em regra, script de banco não roda. A exceção é
   quando a feature não funciona sem ele — aqui a coluna `ncm` não existiria, e o suporte
   reportaria bug num card que está certo. Peça para rodarem a migration na homolog antes.

Juntar os cards do mesmo cliente e explicar em linguagem de negócio ("antes era sempre 10%")
poupa uma rodada de "como eu testo isso?".

</details>

---

## 5. Roteiro da SEGUNDA — deploy

> Ainda não treinado. Antes de começar, simule o "fim de semana": um hotfix direto na `master`
> e uma PR emergencial direto na `homolog` (de preferência trazendo um script em
> `varlib/comandos/`). É isso que gera o conflito no merge da produção na branch de release.

Resumo dos passos (o detalhe está no [guia](docs/GUIA_RELEASE_DEPLOY.md), Parte 3):

1. **Medir**: `git rev-list --left-right --count origin/master...origin/homolog` e simular com
   `git merge-tree`.
2. **Reconferir scripts de banco** (PR emergencial pode ter trazido script novo).
3. `git switch -c release/v<DATA> origin/homolog` — **nasce da homolog**.
4. `git merge origin/master` — traz os hotfixes de produção para dentro da release (simule antes).
5. **Provas**: `git rev-list --count origin/release/v<DATA>..origin/master` **= 0** e o mesmo
   contra a homolog.
6. PR `master ← release/v<DATA>`, título `MODULO | RELEASE | v<DATA>`, com seção *Rollout* (scripts).
7. 🛑 Aprovações + resumo + **"sim" explícito** do tech lead.
8. **Merge = deploy.** `build_push`, `deploy_production` e `deploy_legacy_production` verdes.
9. Tag `v<DATA>` + Release no GitHub.
10. **Os backmerges** `master → homolog` e `master → develop` — o passo mais esquecido, e o único
    cujo esquecimento não dá erro na hora.
11. **Provar**: os compares `homolog...master` e `develop...master` **= 0**.
12. Comunicar: release notes + backmerges concluídos.

---

## 6. Glossário da tela do GitHub

| O que a caixa de merge diz | O que significa | Na API (`mergeable_state`) |
|---|---|---|
| ✅ *This branch has no conflicts with the base branch* | pode mergear | `clean` |
| ⚠️ *This branch has conflicts that must be resolved* | conflito (lista os arquivos) | `dirty` |
| 🔒 *Merging is blocked* | falta aprovação, check ou conversa resolvida | `blocked` |
| *This branch is out-of-date with the base branch* | atrás da base, mas pode mergear se não houver conflito | `behind` |
| etiqueta **Draft** | rascunho — ignora | — |

| Termo | Quer dizer |
|---|---|
| **base** | para onde o código vai (destino) |
| **compare** | de onde vem (o que você está levando) |
| **backmerge** | devolver a produção para `homolog` e `develop` depois de um deploy ou hotfix |
| **branch intermediária** | branch não protegida, nascida do destino, usada para resolver conflito quando a *compare* é protegida |
| **corte** | o horário depois do qual nada mais entra na release da semana |
| **`ahead_by`** | quantos commits um lado tem que o outro não tem |
| **`merge-tree`** | simula um merge na memória, sem mexer em nada |
| **remerge-diff** | `git show --remerge-diff <commit>`: mostra só o que foi resolvido à mão num merge |

---

## 7. Documentos

| Arquivo | O que é |
|---|---|
| [`docs/GUIA_RELEASE_DEPLOY.md`](docs/GUIA_RELEASE_DEPLOY.md) | o guia completo, quinta → sexta → segunda, com comandos e mensagens modelo |
| [`docs/RELATO_2026-09-24.md`](docs/RELATO_2026-09-24.md) | o que aconteceu no primeiro treino e na primeira quinta real, com as lições |
| [`scripts/setup_treino.sh`](scripts/setup_treino.sh) | monta o cenário na sua conta |

> **Versão interna.** Este repositório é público, então os nomes de repositórios, domínios,
> canais, pessoas e links internos foram trocados por marcadores (`<REPO>`, `<HOMOLOG>`,
> `<CANAL_PRS>`…). A versão com os valores reais está nos Canvas *"Guia da segunda"* e
> *"Guia da quarta"* do José, no Slack, e com o Guilherme.
