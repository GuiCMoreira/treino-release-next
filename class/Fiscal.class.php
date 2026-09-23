<?php

class Fiscal
{
    // Alíquota de ICMS aplicada ao pedido
    public function aliquotaIcms(string $uf): float
    {
        $porUf = ['SP' => 0.18, 'RJ' => 0.20, 'MG' => 0.18, 'RS' => 0.17];
        return $porUf[$uf] ?? 0.18;
    }

    public function calcularIcms(float $valor, string $uf): float
    {
        return round($valor * $this->aliquotaIcms($uf), 2);
    }
}
