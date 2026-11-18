-- 1. Criação do Banco de Dados
CREATE DATABASE DW_Atacado;
GO

USE DW_Atacado;
GO

-- 2. Criação das Tabelas (com tipos flexíveis na camada bruta/staging para aceitar as sujeiras)
CREATE TABLE dim_fornecedores (
    id_fornecedor VARCHAR(10) PRIMARY KEY,
    nome_fornecedor VARCHAR(100),
    lead_time_combinado_dias INT,
    uf CHAR(2)
);

CREATE TABLE dim_produtos (
    id_sku VARCHAR(15) PRIMARY KEY,
    nome_produto VARCHAR(100),
    categoria VARCHAR(50),
    curva_abc_esperada CHAR(1),
    id_fornecedor VARCHAR(10),
    custo_unitario DECIMAL(10,2),
    preco_tabela DECIMAL(10,2),
    estoque_minimo INT
);

CREATE TABLE fato_vendas (
    id_pedido VARCHAR(15),
    data_pedido DATE,
    id_sku VARCHAR(15),
    canal_venda VARCHAR(30),
    regiao_destino VARCHAR(30),
    qtd_solicitada INT,
    qtd_atendida INT,
    preco_unitario_tabela DECIMAL(10,2),
    desconto_pct DECIMAL(5,2),
    valor_frete VARCHAR(20), -- VARCHAR temporário para aceitar os vazios ('') antes da limpeza
    status_pedido VARCHAR(30)
);

CREATE TABLE fato_estoque_movimentacao (
    id_movimentacao VARCHAR(15),
    data_movimentacao VARCHAR(20), -- VARCHAR temporário para aceitar datas YYYY-MM-DD e DD/MM/YYYY
    id_sku VARCHAR(15),
    tipo_movimento VARCHAR(30),
    quantidade INT,
    dias_atraso_fornecedor INT
);

CREATE TABLE fato_inventario_fisico (
    data_contagem DATE,
    id_sku VARCHAR(15),
    saldo_sistema INT,
    contagem_fisica INT,
    motivo_ajuste VARCHAR(100)
);
GO

-- 3. Importação dos arquivos CSV
BULK INSERT dim_fornecedores
FROM 'C:\Users\conta\OneDrive\Documentos\ProjetoVarejista_ds\01_geracao_dados\dim_fornecedores.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '\n', CODEPAGE = '65001');

BULK INSERT dim_produtos
FROM 'C:\Users\conta\OneDrive\Documentos\ProjetoVarejista_ds\01_geracao_dados\dim_produtos.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '\n', CODEPAGE = '65001');

BULK INSERT fato_vendas
FROM 'C:\Users\conta\OneDrive\Documentos\ProjetoVarejista_ds\01_geracao_dados\fato_vendas.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '\n', CODEPAGE = '65001');

BULK INSERT fato_estoque_movimentacao
FROM 'C:\Users\conta\OneDrive\Documentos\ProjetoVarejista_ds\01_geracao_dados\fato_estoque_movimentacao.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '\n', CODEPAGE = '65001');

BULK INSERT fato_inventario_fisico
FROM 'C:\Users\conta\OneDrive\Documentos\ProjetoVarejista_ds\01_geracao_dados\fato_inventario_fisico.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '\n', CODEPAGE = '65001');
GO

-- 4. Teste rápido para confirmar se os dados entraram
SELECT 'Fornecedores' AS Tabela, COUNT(*) AS Total_Linhas FROM dim_fornecedores
UNION ALL
SELECT 'Produtos', COUNT(*) FROM dim_produtos
UNION ALL
SELECT 'Vendas', COUNT(*) FROM fato_vendas
UNION ALL
SELECT 'Movimentacoes', COUNT(*) FROM fato_estoque_movimentacao
UNION ALL
SELECT 'Inventario', COUNT(*) FROM fato_inventario_fisico;