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
        if ($qtd <= 0) return; // TRE-211: cancelamento mandava qtd negativa e duplicava a baixa
        $this->saldos[$produto] = ($this->saldos[$produto] ?? 0) - $qtd;
    }

    public function saldo(string $produto): int
    {
        return $this->saldos[$produto] ?? 0;
    }
}
