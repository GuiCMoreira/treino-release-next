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

    public function aplicarCupom(string $codigo): float
    {
        $cupons = ['BEMVINDO10' => 10.0, 'FIDELIDADE5' => 5.0];
        return $this->aplicarDesconto($cupons[$codigo] ?? 0.0);
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
