#!/usr/bin/env bash
# Monta o cenário de treino ("quinta de manhã") NA SUA CONTA do GitHub.
# Pré-requisitos: git, python3 e o gh logado (gh auth status com escopo repo).
# Uso: bash scripts/setup_treino.sh
set -euo pipefail

OWNER=$(gh api user --jq .login)
NAME=treino-release-next
R=$OWNER/$NAME
D=$HOME/meu-treino-release   # pasta do SEU cenário (não é a pasta deste clone)
UID_GH=$(gh api user --jq .id)

if gh repo view "$R" >/dev/null 2>&1; then
  echo "Já existe https://github.com/$R — apague esse repo no GitHub antes de recriar o treino." >&2
  exit 1
fi
echo "Criando o treino em https://github.com/$R (pasta local: $D)"

rm -rf "$D"; mkdir -p "$D"; cd "$D"
git init -q -b master
git config user.name "$(gh api user --jq '.name // .login')"
git config user.email "${UID_GH}+${OWNER}@users.noreply.github.com"

# ---------------------------------------------------------------- base (v2026-09-21)
mkdir -p class migrations varlib/comandos .github/workflows
touch migrations/.gitkeep varlib/comandos/.gitkeep

cat > README.md <<'EOF'
# Treino Release Next

Mini-ERP de restaurante **fictício** para treinar o fluxo de release e deploy
(`develop` → `homolog` → `master`), no mesmo formato do sistema real.

Nada aqui é código real. Os cards `TRE-*` são inventados.

| Branch | Ambiente (simulado) |
|---|---|
| `develop` | dev |
| `homolog` | homolog.treino.example.com |
| `master`  | produção (dois backends: OKE + legado) |
EOF

cat > .gitignore <<'EOF'
# dependências
vendor/
node_modules/

# ambiente
.env
*.log
EOF

cat > CHANGELOG.md <<'EOF'
# Changelog

## [v2026-09-21]
### Correções
- TRE-120 | PEDIDO | Arredondamento do total com duas casas
### Melhorias
- TRE-118 | ESTOQUE | Baixa automática ao fechar pedido

## [v2026-09-14]
### Melhorias
- TRE-101 | PEDIDO | Cadastro de pedidos
EOF

cat > class/Pedido.class.php <<'EOF'
<?php

class Pedido
{
    private array $itens = [];

    public function adicionarItem(string $produto, float $preco, int $qtd): void
    {
        $this->itens[] = ['produto' => $produto, 'preco' => $preco, 'qtd' => $qtd];
    }

    public function subtotal(): float
    {
        $total = 0.0;
        foreach ($this->itens as $item) {
            $total += $item['preco'] * $item['qtd'];
        }
        return round($total, 2);
    }

    public function aplicarDesconto(float $percentual): float
    {
        return round($this->subtotal() * (1 - $percentual / 100), 2);
    }

    // ------------------------------------------------------------------
    // Taxa de serviço
    // ------------------------------------------------------------------

    public function calcularTaxaServico(): float
    {
        return round($this->subtotal() * 0.10, 2);
    }

    // ------------------------------------------------------------------
    // Formatação
    // ------------------------------------------------------------------

    public static function formatarValor(float $valor): string
    {
        return 'R$ ' . $valor;
    }
}
EOF

cat > class/Estoque.class.php <<'EOF'
<?php

class Estoque
{
    private array $saldos = [];

    public function entrada(string $produto, int $qtd): void
    {
        $this->saldos[$produto] = ($this->saldos[$produto] ?? 0) + $qtd;
    }

    public function baixa(string $produto, int $qtd): void
    {
        $this->saldos[$produto] = ($this->saldos[$produto] ?? 0) - $qtd;
    }

    public function saldo(string $produto): int
    {
        return $this->saldos[$produto] ?? 0;
    }
}
EOF

cat > class/Fiscal.class.php <<'EOF'
<?php

class Fiscal
{
    // Alíquota de ICMS aplicada ao pedido
    public function aliquotaIcms(string $uf): float
    {
        return 0.18;
    }

    public function calcularIcms(float $valor, string $uf): float
    {
        return round($valor * $this->aliquotaIcms($uf), 2);
    }
}
EOF

cat > .github/workflows/ci-oke.yml <<'EOF'
# Simulação do ci-oke.yml do sistema real: o mesmo workflow atende as três branches
# e decide o ambiente pela branch que disparou. Nada é publicado de verdade.
name: ci-oke

on:
  push:
    branches: [develop, homolog, master]

jobs:
  build_push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint PHP (simula o build da imagem)
        run: find . -name '*.php' -print0 | xargs -0 -n1 php -l
      - name: Push da imagem (simulado)
        run: echo "imagem treino:${GITHUB_SHA::7} publicada no registry (simulado)"

  deploy_develop:
    needs: build_push
    if: github.ref_name == 'develop'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Publicando em DEV (simulado)"

  deploy_homolog:
    needs: build_push
    if: github.ref_name == 'homolog'
    runs-on: ubuntu-latest
    environment:
      name: homolog
      url: https://homolog.treino.example.com
    steps:
      - run: sleep 20 && echo "Publicando em HOMOLOG (simulado)"

  deploy_production:
    needs: build_push
    if: github.ref_name == 'master'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://prod.treino.example.com
    steps:
      - run: sleep 20 && echo "Publicando em PRODUÇÃO - cluster OKE (simulado)"

  deploy_legacy_production:
    needs: build_push
    if: github.ref_name == 'master'
    runs-on: ubuntu-latest
    environment:
      name: production-legacy
      url: https://legado.treino.example.com
    steps:
      - run: sleep 20 && echo "Publicando em PRODUÇÃO - VM legada (simulado)"
EOF

git add -A
git commit -q -m "RETAGUARDA | INFRA | Projeto base (estado da release v2026-09-21)"
git tag v2026-09-21

gh repo create "$R" --public --description "Treino fictício do fluxo de release/deploy (develop -> homolog -> master)" \
  --source . --remote origin >/dev/null
git push -q -u origin master --tags
git push -q origin master:homolog
git push -q origin master:develop

# helper: cria branch a partir de uma base remota, aplica uma função e abre PR
nova_pr() { # nova_pr <branch> <base_remota_para_nascer> <base_da_pr> <titulo> <corpo> <func> [draft]
  local br=$1 from=$2 base=$3 title=$4 body=$5 fn=$6 draft=${7:-}
  git fetch -q origin
  git switch -q -c "$br" "origin/$from"
  $fn
  git add -A
  git commit -q -m "$title"
  git push -q -u origin "$br"
  gh pr create -R "$R" --base "$base" --head "$br" --title "$title" --body "$body" $draft >/dev/null
  gh pr list -R "$R" --head "$br" --json number --jq '.[0].number'
}
mergear() { gh pr merge "$1" -R "$R" --merge >/dev/null; }

# ---------------------------------------------------------------- funções dos cards

# F (TRE-206) nasce da base, antes do TRE-199: mexe na MESMA regra fiscal -> conflito complexo
f_tre206() {
  python3 - <<'PY'
import re
p='class/Fiscal.class.php'; s=open(p).read()
s=s.replace("        return 0.18;","        // Simples Nacional: alíquota reduzida para todo o pedido\n        return 0.04;")
open(p,'w').write(s)
PY
}

# Hotfix direto na produção (sexta passada): formatação de valor
f_tre150() {
  python3 - <<'PY'
p='class/Pedido.class.php'; s=open(p).read()
s=s.replace("        return 'R$ ' . $valor;","        return 'R$ ' . number_format($valor, 2, ',', '.');")
open(p,'w').write(s)
p='CHANGELOG.md'; s=open(p).read()
s=s.replace("# Changelog\n\n","# Changelog\n\n## [v2026-09-21-hotfix]\n### Correções\n- TRE-150 | PEDIDO | Valor aparecia sem casas decimais no cupom\n\n",1)
open(p,'w').write(s)
PY
}

# Já mergeado na develop: ICMS por UF
f_tre199() {
  python3 - <<'PY'
p='class/Fiscal.class.php'; s=open(p).read()
s=s.replace("        return 0.18;","        $porUf = ['SP' => 0.18, 'RJ' => 0.20, 'MG' => 0.18, 'RS' => 0.17];\n        return $porUf[$uf] ?? 0.18;")
open(p,'w').write(s)
p='CHANGELOG.md'; s=open(p).read()
s=s.replace("# Changelog\n\n","# Changelog\n\n## [Não lançado]\n- TRE-199 | FISCAL | ICMS passa a respeitar a alíquota de cada UF\n\n",1)
open(p,'w').write(s)
PY
}

# C (TRE-203) nasce depois do TRE-199 e antes do TRE-200 -> conflito SIMPLES no CHANGELOG
f_tre203() {
  python3 - <<'PY'
p='class/Pedido.class.php'; s=open(p).read()
s=s.replace("    public function calcularTaxaServico(): float\n    {\n        return round($this->subtotal() * 0.10, 2);",
            "    public function calcularTaxaServico(float $percentual = 10.0): float\n    {\n        return round($this->subtotal() * $percentual / 100, 2);")
open(p,'w').write(s)
p='CHANGELOG.md'; s=open(p).read()
s=s.replace("- TRE-199 | FISCAL | ICMS passa a respeitar a alíquota de cada UF\n","- TRE-199 | FISCAL | ICMS passa a respeitar a alíquota de cada UF\n- TRE-203 | PEDIDO | Taxa de serviço configurável por loja\n",1)
open(p,'w').write(s)
PY
}

# Já mergeado na develop: alerta de estoque mínimo
f_tre200() {
  python3 - <<'PY'
p='class/Estoque.class.php'; s=open(p).read()
s=s.replace("    public function saldo(string $produto): int\n    {\n        return $this->saldos[$produto] ?? 0;\n    }\n",
"    public function saldo(string $produto): int\n    {\n        return $this->saldos[$produto] ?? 0;\n    }\n\n    public function abaixoDoMinimo(string $produto, int $minimo): bool\n    {\n        return $this->saldo($produto) < $minimo;\n    }\n")
open(p,'w').write(s)
p='CHANGELOG.md'; s=open(p).read()
s=s.replace("- TRE-199 | FISCAL | ICMS passa a respeitar a alíquota de cada UF\n","- TRE-199 | FISCAL | ICMS passa a respeitar a alíquota de cada UF\n- TRE-200 | ESTOQUE | Alerta de estoque mínimo\n",1)
open(p,'w').write(s)
PY
}

# A (TRE-201) limpa
f_tre201() {
  python3 - <<'PY'
p='class/Pedido.class.php'; s=open(p).read()
s=s.replace("    // ------------------------------------------------------------------\n    // Taxa de serviço",
"    public function aplicarCupom(string $codigo): float\n    {\n        $cupons = ['BEMVINDO10' => 10.0, 'FIDELIDADE5' => 5.0];\n        return $this->aplicarDesconto($cupons[$codigo] ?? 0.0);\n    }\n\n    // ------------------------------------------------------------------\n    // Taxa de serviço",1)
open(p,'w').write(s)
PY
}

# B (TRE-202) limpa, mas vai ganhar uma conversa de review aberta
f_tre202() {
  cat > class/RelatorioEstoque.class.php <<'EOF'
<?php

class RelatorioEstoque
{
    public function __construct(private Estoque $estoque) {}

    public function produtosAbaixoDoMinimo(array $minimos): array
    {
        $lista = [];
        foreach ($minimos as $produto => $minimo) {
            if ($this->estoque->abaixoDoMinimo($produto, $minimo)) {
                $lista[] = $produto;
            }
        }
        return $lista;
    }
}
EOF
}

# D (TRE-204) limpa, traz SCRIPT DE BANCO
f_tre204() {
  cat > migrations/2026-09-24_TRE-204_add_ncm_produto.sql <<'EOF'
-- TRE-204: adiciona NCM no cadastro de produto (obrigatório para a NFC-e)
-- NÃO roda sozinho no deploy: precisa ser executado à mão em produção.
ALTER TABLE produto ADD COLUMN ncm VARCHAR(8) NULL AFTER descricao;
UPDATE produto SET ncm = '21069090' WHERE ncm IS NULL AND categoria = 'BEBIDA';
EOF
  cat > class/Produto.class.php <<'EOF'
<?php

class Produto
{
    public function __construct(
        public string $descricao,
        public ?string $ncm = null,
    ) {}

    public function temNcmValido(): bool
    {
        return $this->ncm !== null && strlen($this->ncm) === 8;
    }
}
EOF
}

# E (TRE-205) rascunho
f_tre205() {
  cat > class/Comanda.class.php <<'EOF'
<?php

// WIP: comanda eletrônica — ainda em desenvolvimento
class Comanda
{
}
EOF
}

# ---------------------------------------------------------------- linha do tempo
PR_F=$(nova_pr feature/TRE-206 develop develop "RETAGUARDA | FISCAL | TRE-206 Alíquota reduzida para Simples Nacional" "Card: TRE-206 (fictício)" f_tre206)

PR_150=$(nova_pr hotfix/TRE-150 master master "RETAGUARDA | HOTFIX | TRE-150 Valor sem casas decimais no cupom" "Hotfix direto em produção (sexta)." f_tre150)
mergear "$PR_150"

PR_199=$(nova_pr feature/TRE-199 develop develop "RETAGUARDA | FISCAL | TRE-199 ICMS por UF" "Card: TRE-199 (fictício)" f_tre199)
mergear "$PR_199"

PR_C=$(nova_pr feature/TRE-203 develop develop "RETAGUARDA | PEDIDO | TRE-203 Taxa de serviço configurável" "Card: TRE-203 (fictício)" f_tre203)

PR_200=$(nova_pr feature/TRE-200 develop develop "RETAGUARDA | ESTOQUE | TRE-200 Alerta de estoque mínimo" "Card: TRE-200 (fictício)" f_tre200)
mergear "$PR_200"

PR_A=$(nova_pr feature/TRE-201 develop develop "RETAGUARDA | PEDIDO | TRE-201 Desconto por cupom" "Card: TRE-201 (fictício)" f_tre201)
PR_B=$(nova_pr feature/TRE-202 develop develop "RETAGUARDA | ESTOQUE | TRE-202 Relatório de estoque mínimo" "Card: TRE-202 (fictício)" f_tre202)
PR_D=$(nova_pr feature/TRE-204 develop develop "RETAGUARDA | PRODUTO | TRE-204 NCM no cadastro de produto" "Card: TRE-204 (fictício). Traz migration em migrations/." f_tre204)
PR_E=$(nova_pr feature/TRE-205 develop develop "RETAGUARDA | COMANDA | TRE-205 Comanda eletrônica (WIP)" "Rascunho." f_tre205 --draft)

# conversa de review aberta na B (vai deixar o botão de merge cinza)
SHA_B=$(gh api repos/$R/pulls/$PR_B --jq .head.sha)
gh api repos/$R/pulls/$PR_B/reviews --input - >/dev/null <<EOF
{"commit_id":"$SHA_B","event":"COMMENT","body":"Revisão do Pedro (simulada).",
 "comments":[{"path":"class/RelatorioEstoque.class.php","line":11,
 "body":"Se o produto não existir no estoque, o saldo vem 0 e ele entra na lista. É esse o comportamento esperado?"}]}
EOF

git switch -q master

# ---------------------------------------------------------------- ruleset (igual ao sistema real, com 0 aprovações)
gh api repos/$R/rulesets --input - >/dev/null <<'EOF'
{
  "name": "protecao-branches-principais",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["refs/heads/master","refs/heads/homolog","refs/heads/develop"], "exclude": []}},
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "dismiss_stale_reviews_on_push": true,
      "require_code_owner_review": false,
      "require_last_push_approval": false,
      "required_review_thread_resolution": true}}
  ]
}
EOF

echo "REPO=https://github.com/$R"
echo "PRs: F=$PR_F hotfix=$PR_150 199=$PR_199 C=$PR_C 200=$PR_200 A=$PR_A B=$PR_B D=$PR_D E=$PR_E"
