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
