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
