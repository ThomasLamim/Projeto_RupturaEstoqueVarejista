USE DW_Atacado;
GO

/* ==========================================================================
   1. IMPACTO FINANCEIRO DA RUPTURA E TAXA DE ATENDIMENTO (FILL RATE) POR CATEGORIA
   Objetivo: Medir quanto dinheiro a empresa deixou de faturar por falta de produto
   e qual o nível de atendimento real dos pedidos.
   ========================================================================== */
SELECT 
    p.categoria,
    COUNT(DISTINCT v.id_pedido) AS total_pedidos,
    SUM(v.qtd_solicitada) AS unidades_solicitadas,
    SUM(v.qtd_atendida) AS unidades_atendidas,
    SUM(v.qtd_solicitada - v.qtd_atendida) AS unidades_perdidas_ruptura,
    -- Fill Rate (Taxa de atendimento em %): quanto do pedido do cliente foi atendido
    CAST(SUM(v.qtd_atendida) * 100.0 / NULLIF(SUM(v.qtd_solicitada), 0) AS DECIMAL(5,2)) AS fill_rate_pct,
    -- Receita Bruta Realizada (considerando desconto)
    CAST(SUM(v.qtd_atendida * v.preco_unitario_tabela * (1 - v.desconto_pct)) AS DECIMAL(12,2)) AS receita_realizada,
    -- Receita Perdida por Ruptura (vendas canceladas por falta de estoque)
    CAST(SUM((v.qtd_solicitada - v.qtd_atendida) * v.preco_unitario_tabela * (1 - v.desconto_pct)) AS DECIMAL(12,2)) AS receita_perdida_ruptura
FROM fato_vendas_limpa v
INNER JOIN dim_produtos_limpa p ON v.id_sku = p.id_sku
GROUP BY p.categoria
ORDER BY receita_perdida_ruptura DESC;
GO


/* ==========================================================================
   2. RANKING DOS TOP 10 PRODUTOS (SKUs) COM MAIOR PERDA POR RUPTURA
   Objetivo: Identificar se a ruptura está concentrada nos itens de Curva A
   (onde o impacto financeiro é mais crítico).
   ========================================================================== */
SELECT TOP 10
    p.id_sku,
    p.nome_produto,
    p.categoria,
    p.curva_abc_esperada AS curva_abc,
    f.nome_fornecedor,
    COUNT(CASE WHEN v.status_pedido = 'Cancelado_Ruptura' THEN 1 END) AS qtd_pedidos_cancelados,
    SUM(v.qtd_solicitada - v.qtd_atendida) AS unidades_nao_atendidas,
    CAST(SUM((v.qtd_solicitada - v.qtd_atendida) * v.preco_unitario_tabela * (1 - v.desconto_pct)) AS DECIMAL(12,2)) AS receita_perdida
FROM fato_vendas_limpa v
INNER JOIN dim_produtos_limpa p ON v.id_sku = p.id_sku
INNER JOIN dim_fornecedores f ON p.id_fornecedor = f.id_fornecedor
GROUP BY p.id_sku, p.nome_produto, p.categoria, p.curva_abc_esperada, f.nome_fornecedor
HAVING SUM(v.qtd_solicitada - v.qtd_atendida) > 0
ORDER BY receita_perdida DESC;
GO


/* ==========================================================================
   3. AUDITORIA DE FORNECEDORES (SLA E LEAD TIME REAL VS. COMBINADO)
   Objetivo: Descobrir quais fornecedores estão atrasando entregas e provocando
   o desabastecimento no centro de distribuição.
   ========================================================================== */
SELECT 
    f.id_fornecedor,
    f.nome_fornecedor,
    f.uf,
    f.lead_time_combinado_dias,
    COUNT(m.id_movimentacao) AS total_entregas_recebidas,
    CAST(AVG(CAST(m.dias_atraso_fornecedor AS FLOAT)) AS DECIMAL(5,2)) AS media_dias_atraso,
    CAST(f.lead_time_combinado_dias + AVG(CAST(m.dias_atraso_fornecedor AS FLOAT)) AS DECIMAL(5,2)) AS lead_time_real_dias,
    SUM(CASE WHEN m.dias_atraso_fornecedor > 0 THEN 1 ELSE 0 END) AS entregas_com_atraso,
    CAST(SUM(CASE WHEN m.dias_atraso_fornecedor > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(m.id_movimentacao) AS DECIMAL(5,2)) AS pct_entregas_atrasadas
FROM fato_estoque_movimentacao_limpa m
INNER JOIN dim_produtos_limpa p ON m.id_sku = p.id_sku
INNER JOIN dim_fornecedores f ON p.id_fornecedor = f.id_fornecedor
WHERE m.tipo_movimento = 'Entrada_Compra'
GROUP BY f.id_fornecedor, f.nome_fornecedor, f.uf, f.lead_time_combinado_dias
ORDER BY media_dias_atraso DESC;
GO


/* ==========================================================================
   4. AUDITORIA DE INVENTÁRIO FÍSICO (FUROS DE ESTOQUE E PERDAS FINANCEIRAS)
   Objetivo: Comparar o saldo registrado no sistema com a contagem física do
   galpão para quantificar o prejuízo por avarias ou erros operacionais.
   ========================================================================== */
SELECT 
    p.categoria,
    COUNT(i.id_sku) AS total_skus_auditados,
    SUM(CASE WHEN i.contagem_fisica < i.saldo_sistema THEN 1 ELSE 0 END) AS skus_com_divergencia,
    SUM(i.saldo_sistema - i.contagem_fisica) AS unidades_divergentes,
    CAST(SUM((i.saldo_sistema - i.contagem_fisica) * p.custo_unitario) AS DECIMAL(12,2)) AS prejuizo_estoque_custo
FROM fato_inventario_fisico i
INNER JOIN dim_produtos_limpa p ON i.id_sku = p.id_sku
GROUP BY p.categoria
ORDER BY prejuizo_estoque_custo DESC;
GO