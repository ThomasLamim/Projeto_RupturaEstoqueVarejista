import csv
import random
from datetime import datetime, timedelta

random.seed(42)  # Garante que os mesmos dados sejam gerados sempre

# 1. DIM_FORNECEDORES (12 registros)
fornecedores = []
nomes_forn = [
    "Distribuidora Sul", "Alimentos Brasil", "Química Limpa", "Bebidas Serra",
    "Indústria Paulista", "Atacado Nacional", "Grupo Horizonte", "LogiFood",
    "Higiene Total", "Cereais do Vale", "Embalagens Express", "Mega Suprimentos"
]
for i, nome in enumerate(nomes_forn, start=1):
    fornecedores.append({
        "id_fornecedor": f"FORN-{i:02d}",
        "nome_fornecedor": nome,
        "lead_time_combinado_dias": random.choice([3, 5, 7, 10, 14]),
        "uf": random.choice(["SP", "MG", "PR", "SC", "RJ"])
    })

with open("dim_fornecedores.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fornecedores[0].keys(), delimiter=";")
    writer.writeheader()
    writer.writerows(fornecedores)

# 2. DIM_PRODUTOS (80 registros com sujeira proposital em categoria)
categorias_limpas = ["Alimentos", "Bebidas", "Limpeza", "Higiene"]
categorias_sujas = ["Alimentos", "alimentos ", "ALIMENTOS", "Bebidas", "bebidas", "Limpeza", "limpeza ", "Higiene"]

produtos = []
for i in range(1, 81):
    cat_real = random.choice(categorias_limpas)
    # 15% de chance de vir com texto despadronizado
    if random.random() < 0.15:
        cat_exibida = random.choice([c for c in categorias_sujas if c.strip().lower() == cat_real.lower()])
    else:
        cat_exibida = cat_real

    custo = round(random.uniform(5.0, 120.0), 2)
    margem_alvo = random.uniform(1.22, 1.45)
    preco = round(custo * margem_alvo, 2)
    # Primeiros 15 produtos são Curva A (alta demanda)
    curva = "A" if i <= 15 else ("B" if i <= 40 else "C")

    produtos.append({
        "id_sku": f"SKU-{i:04d}",
        "nome_produto": f"Produto {cat_real[:4].upper()} {i:03d}",
        "categoria": cat_exibida,
        "curva_abc_esperada": curva,
        "id_fornecedor": random.choice(fornecedores)["id_fornecedor"],
        "custo_unitario": custo,
        "preco_tabela": preco,
        "estoque_minimo": random.randint(80, 200) if curva == "A" else random.randint(20, 70)
    })

with open("dim_produtos.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=produtos[0].keys(), delimiter=";")
    writer.writeheader()
    writer.writerows(produtos)

# 3. FATO_ESTOQUE_MOVIMENTACAO & 4. FATO_VENDAS (12 meses)
data_inicio = datetime(2025, 11, 1)
estoque_atual = {p["id_sku"]: p["estoque_minimo"] * 2 for p in produtos}

vendas = []
movimentacoes = []
id_pedido = 10000
id_mov = 50000

regioes = ["Sudeste", "Sul", "Centro-Oeste", "Nordeste"]
canais = ["Representante", "Televendas", "Portal B2B"]

for dia in range(365):
    data_atual = data_inicio + timedelta(days=dia)
    data_str_iso = data_atual.strftime("%Y-%m-%d")

    # Simula vendas diárias (12 a 22 pedidos por dia)
    qtd_pedidos_dia = random.randint(12, 22)
    for _ in range(qtd_pedidos_dia):
        # Produtos Curva A têm muito mais chance de serem vendidos
        peso = [5 if p["curva_abc_esperada"] == "A" else (2 if p["curva_abc_esperada"] == "B" else 1) for p in produtos]
        prod = random.choices(produtos, weights=peso, k=1)[0]
        sku = prod["id_sku"]

        qtd_solicitada = random.randint(5, 45) if prod["curva_abc_esperada"] == "A" else random.randint(1, 15)
        regiao = random.choice(regioes)

        # Verifica se há estoque (simula ruptura se estoque = 0)
        if estoque_atual[sku] >= qtd_solicitada:
            qtd_atendida = qtd_solicitada
            status_pedido = "Faturado"
            estoque_atual[sku] -= qtd_atendida

            movimentacoes.append({
                "id_movimentacao": f"MOV-{id_mov}",
                "data_movimentacao": data_str_iso,
                "id_sku": sku,
                "tipo_movimento": "Saida_Venda",
                "quantidade": -qtd_atendida,
                "dias_atraso_fornecedor": 0
            })
            id_mov += 1
        else:
            # Ruptura de estoque! Venda perdida
            qtd_atendida = 0
            status_pedido = "Cancelado_Ruptura"

        # Injeta problema de margem negativa: descontos altos + frete caro no Nordeste/Centro-Oeste
        desconto_pct = random.choice([0.0, 0.03, 0.05, 0.08, 0.15, 0.22])
        frete = round(random.uniform(35.0, 180.0), 2) if regiao in ["Nordeste", "Centro-Oeste"] else round(random.uniform(15.0, 65.0), 2)

        # 2% de chance de frete nulo (erro de sistema)
        if random.random() < 0.02:
            frete = ""

        vendas.append({
            "id_pedido": f"PED-{id_pedido}",
            "data_pedido": data_str_iso,
            "id_sku": sku,
            "canal_venda": random.choice(canais),
            "regiao_destino": regiao,
            "qtd_solicitada": qtd_solicitada,
            "qtd_atendida": qtd_atendida,
            "preco_unitario_tabela": prod["preco_tabela"],
            "desconto_pct": desconto_pct,
            "valor_frete": frete,
            "status_pedido": status_pedido
        })
        id_pedido += 1

    # Reposição de estoque semanal (a cada 7 dias) com atrasos propositais
    if dia % 7 == 0:
        for prod in produtos:
            sku = prod["id_sku"]
            if estoque_atual[sku] < prod["estoque_minimo"]:
                # Fornecedores FORN-02 e FORN-04 atrasam propositalmente, causando ruptura na Curva A
                atraso = random.randint(4, 9) if prod["id_fornecedor"] in ["FORN-02", "FORN-04"] else random.choice([0, 0, 1, 2])
                qtd_compra = prod["estoque_minimo"] * 3
                estoque_atual[sku] += qtd_compra

                # 3% de chance de data no formato brasileiro DD/MM/YYYY (sujeira proposital)
                data_mov = data_atual.strftime("%d/%m/%Y") if random.random() < 0.03 else data_str_iso

                movimentacoes.append({
                    "id_movimentacao": f"MOV-{id_mov}",
                    "data_movimentacao": data_mov,
                    "id_sku": sku,
                    "tipo_movimento": "Entrada_Compra",
                    "quantidade": qtd_compra,
                    "dias_atraso_fornecedor": atraso
                })
                id_mov += 1

# Injeta 15 registros duplicados propositalmente em vendas
duplicados = random.sample(vendas, 15)
vendas.extend(duplicados)

with open("fato_vendas.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=vendas[0].keys(), delimiter=";")
    writer.writeheader()
    writer.writerows(vendas)

with open("fato_estoque_movimentacao.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=movimentacoes[0].keys(), delimiter=";")
    writer.writeheader()
    writer.writerows(movimentacoes)

# 5. FATO_INVENTARIO_FISICO (Auditoria de perdas/divergências no fim do período)
inventario = []
for prod in produtos:
    sku = prod["id_sku"]
    saldo_sistema = estoque_atual[sku]
    # 20% dos produtos apresentam furo de estoque (perda/avaria ou erro de lançamento)
    if random.random() < 0.20:
        diferenca = random.randint(-18, -2)
    else:
        diferenca = 0

    inventario.append({
        "data_contagem": "2026-10-31",
        "id_sku": sku,
        "saldo_sistema": saldo_sistema,
        "contagem_fisica": max(0, saldo_sistema + diferenca),
        "motivo_ajuste": "Avaria/Perda não lançada" if diferenca < 0 else "OK"
    })

with open("fato_inventario_fisico.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=inventario[0].keys(), delimiter=";")
    writer.writeheader()
    writer.writerows(inventario)

print("Arquivos CSV gerados com sucesso! Total de vendas:", len(vendas))