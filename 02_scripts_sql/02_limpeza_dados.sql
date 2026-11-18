USE DW_Atacado;
GO

/* ==========================================================================
   PARTE 1: DIAGNÓSTICO DE QUALIDADE DE DADOS (AUDITORIA)
   Execute este bloco primeiro para visualizar as falhas antes de corrigir
   ========================================================================== */

-- 1.1 Identificar categorias despadronizadas (espaços extras e caixa alta/baixa)
SELECT 
    categoria AS Categoria_Original,
    COUNT(*) AS Qtd_SKUs
FROM dim_produtos
GROUP BY categoria
ORDER BY categoria;

-- 1.2 Identificar os 15 pedidos duplicados na tabela de vendas
SELECT 
    id_pedido,
    COUNT(*) AS Qtd_Ocorrencias
FROM fato_vendas
GROUP BY id_pedido
HAVING COUNT(*) > 1;

-- 1.3 Identificar registros com valor de frete vazio ou nulo
SELECT 
    COUNT(*) AS Total_Fretes_Vazios
FROM fato_vendas
WHERE valor_frete IS NULL OR LTRIM(RTRIM(valor_frete)) = '';

-- 1.4 Identificar datas fora do padrão ISO (formato brasileiro DD/MM/YYYY)
SELECT 
    id_movimentacao,
    data_movimentacao,
    tipo_movimento
FROM fato_estoque_movimentacao
WHERE data_movimentacao LIKE '%/%';
GO

/* ==========================================================================
   PARTE 2: TRATAMENTO E CRIAÇÃO DAS TABELAS LIMPAS (CAMADA TRUSTED)
   ========================================================================== */

-- 2.1 Limpeza da Dimensão Produtos (Padronização de texto com TRIM e Primeira Maiúscula)
IF OBJECT_ID('dim_produtos_limpa', 'U') IS NOT NULL DROP TABLE dim_produtos_limpa;

SELECT 
    id_sku,
    LTRIM(RTRIM(nome_produto)) AS nome_produto,
    -- Padroniza para Primeira letra maiúscula e o restante minúsculo (ex: 'Alimentos')
    UPPER(LEFT(LTRIM(RTRIM(categoria)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(categoria)), 2, LEN(LTRIM(RTRIM(categoria))))) AS categoria,
    curva_abc_esperada,
    id_fornecedor,
    custo_unitario,
    preco_tabela,
    estoque_minimo
INTO dim_produtos_limpa
FROM dim_produtos;

-- 2.2 Limpeza da Fato Vendas (Remoção de duplicatas via ROW_NUMBER + Tratamento de frete nulo + Tipagem)
IF OBJECT_ID('fato_vendas_limpa', 'U') IS NOT NULL DROP TABLE fato_vendas_limpa;

WITH Vendas_Deduplicadas AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY id_pedido ORDER BY data_pedido) AS num_linha
    FROM fato_vendas
)
SELECT 
    id_pedido,
    data_pedido,
    id_sku,
    canal_venda,
    regiao_destino,
    qtd_solicitada,
    qtd_atendida,
    preco_unitario_tabela,
    desconto_pct,
    -- Converte frete vazio para 0.00 (ou poderia ser substituído pela média da região) e tipa como DECIMAL
    CASE 
        WHEN valor_frete IS NULL OR LTRIM(RTRIM(valor_frete)) = '' THEN 0.00
        ELSE CAST(valor_frete AS DECIMAL(10,2))
    END AS valor_frete,
    status_pedido
INTO fato_vendas_limpa
FROM Vendas_Deduplicadas
WHERE num_linha = 1; -- Mantém apenas a primeira ocorrência de cada pedido

-- 2.3 Limpeza da Fato Movimentação de Estoque (Padronização de datas mistas para DATE)
IF OBJECT_ID('fato_estoque_movimentacao_limpa', 'U') IS NOT NULL DROP TABLE fato_estoque_movimentacao_limpa;

SELECT 
    id_movimentacao,
    -- Estilo 103 converte DD/MM/YYYY; Estilo 23 converte YYYY-MM-DD
    CASE 
        WHEN data_movimentacao LIKE '%/%' THEN TRY_CONVERT(DATE, data_movimentacao, 103)
        ELSE TRY_CONVERT(DATE, data_movimentacao, 23)
    END AS data_movimentacao,
    id_sku,
    tipo_movimento,
    quantidade,
    dias_atraso_fornecedor
INTO fato_estoque_movimentacao_limpa
FROM fato_estoque_movimentacao;
GO

/* ==========================================================================
   PARTE 3: VALIDAÇÃO PÓS-LIMPEZA
   ========================================================================== */
SELECT 'Produtos Limpos (Categorias únicas)' AS Check_Item, COUNT(DISTINCT categoria) AS Resultado FROM dim_produtos_limpa
UNION ALL
SELECT 'Vendas Limpas (Total sem 15 duplicatas)', COUNT(*) FROM fato_vendas_limpa
UNION ALL
SELECT 'Movimentações com Data Inválida (Deve ser 0)', COUNT(*) FROM fato_estoque_movimentacao_limpa WHERE data_movimentacao IS NULL;