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
