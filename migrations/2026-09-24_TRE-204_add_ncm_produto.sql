-- TRE-204: adiciona NCM no cadastro de produto (obrigatório para a NFC-e)
-- NÃO roda sozinho no deploy: precisa ser executado à mão em produção.
ALTER TABLE produto ADD COLUMN ncm VARCHAR(8) NULL AFTER descricao;
UPDATE produto SET ncm = '21069090' WHERE ncm IS NULL AND categoria = 'BEBIDA';
