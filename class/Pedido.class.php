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

    public function calcularTaxaServico(float $percentual = 10.0): float
    {
        return round($this->subtotal() * $percentual / 100, 2);
    }

    // ------------------------------------------------------------------
    // Formatação
    // ------------------------------------------------------------------

    public static function formatarValor(float $valor): string
    {
        return 'R$ ' . $valor;
    }
}
