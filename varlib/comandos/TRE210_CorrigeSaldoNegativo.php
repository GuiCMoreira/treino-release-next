<?php
// TRE-210 (emergencial): zera saldos negativos gerados pela transferência entre lojas.
// NÃO roda sozinho no deploy. Uso: php TRE210_CorrigeSaldoNegativo.php --dry-run | --apply
$apply = in_array('--apply', $argv, true);
$sql = "UPDATE pds11_estoque SET saldo = 0 WHERE saldo < 0";
echo $apply ? "Aplicando: $sql\n" : "Dry-run: $sql\n";
