<?php

class Fiscal
{
    // Alíquota de ICMS aplicada ao pedido
    public function aliquotaIcms(string $uf): float
    {
        // Simples Nacional: alíquota reduzida para todo o pedido
        return 0.04;
    }

    public function calcularIcms(float $valor, string $uf): float
    {
        return round($valor * $this->aliquotaIcms($uf), 2);
    }
}
