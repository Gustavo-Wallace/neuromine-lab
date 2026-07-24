# NeuroMine Lab

Laboratório visual experimental em Godot 4.7 para neuroevolução de pequenas redes neurais que jogam Campo Minado.

## Estado atual

O projeto contém um Campo Minado 6×6 com 6 minas, geração determinística por seed, primeira jogada segura, abertura em cascata, bandeiras e partidas visuais ou headless. Os baselines aleatório e neural aleatório continuam disponíveis.

O esquema de observação v1 converte cada casa candidata em exatamente **72 entradas** sanitizadas. A rede feedforward usa **72 → 24 → 12 → 1**, ativações TANH/TANH/SIGMOID e **2.065 parâmetros**, com inicialização Xavier, clonagem profunda e snapshots em memória.

A etapa evolutiva implementa uma população real de redes neurais, avaliação padronizada, fitness, elitismo, seleção por torneio, crossover uniforme e mutação gaussiana. Não usa backpropagation, gradientes, NEAT, alteração de topologia, Python ou bibliotecas externas.

## Protocolo evolutivo

Os defaults iniciais são:

- população 48 e elite 4;
- 8 cenários de treino novos e determinísticos por geração;
- 20 cenários fixos de validação durante toda a execução;
- torneio de tamanho 3;
- crossover com probabilidade de 70%, escolhendo cada parâmetro 50/50;
- mutação por parâmetro de 8%, força 0,15 e limite absoluto ±5;
- abertura fixa no centro `(3, 3)` antes da primeira decisão neural.

A identidade completa de um cenário inclui dimensões, minas, seed do campo, posição inicial, raio seguro e versão do gerador, por exemplo:

`6x6:6|seed=123|start=3,3|safe_radius=1|generator=1`

Todas as redes de uma geração enfrentam a mesma suíte de treino. O fitness médio combina progresso quadrático, grande bônus de vitória, eficiência em vitórias e penalidades para ações inválidas, estados inválidos, limite de ações e mina detonada. O campeão global é escolhido na validação por fitness, vitórias, progresso e, por fim, menos ações médias.

Cada indivíduo guarda ID (`G0001-I0037`), geração de nascimento, genoma, métricas de treino/validação, rank, pais, origem, herança do crossover e estatísticas de mutação. O histórico registra campeão, fitness, validação, diversidade, cenários e duração de cada geração.

## Interface

O painel **Evolução Genética** permite executar uma geração ou continuamente, pausar, retomar, parar, reiniciar com confirmação e alterar o tamanho dos blocos de processamento. A avaliação cede frames entre blocos e não renderiza partidas de fitness.

Também é possível:

- assistir ao campeão em cenário de treino, validação ou campo manual;
- usar heatmap, valores, ranking e inspetores durante a reprodução visual;
- comparar, sob a mesma validação fixa, agente aleatório, neural inicial e campeão evoluído;
- consultar fitness, vitórias, progresso, jogadas, diversidade e histórico das gerações.

A reprodução visual é separada da avaliação e não altera fitness ou seleção.

## Estrutura

- `scripts/core/`: modelo determinístico independente de Nodes e renderização;
- `scripts/agents/`: contrato de agente, baseline aleatório e agente neural;
- `scripts/observation/`: candidatas e codificação do estado visível;
- `scripts/neural/`: rede feedforward, camadas, ativações e snapshots;
- `scripts/simulation/`: partidas, resultados e cenários padronizados;
- `scripts/evolution/`: configuração, indivíduos, população, fitness, operadores genéticos e gerenciador;
- `scripts/ui/`: cena, painel evolutivo, heatmap e inspetores;
- `scripts/debug/`: 98 diagnósticos e benchmarks headless.

Minas ocultas, pistas ocultas e a seed do campo não são expostas ao codificador ou aos agentes.

## Execução e validação

Abra `scenes/main.tscn` com **Godot 4.7** ou execute o projeto pela raiz.

Diagnósticos consolidados:

```text
godot --headless --path . --script res://scripts/debug/run_diagnostics.gd
```

Benchmark de três gerações usando os defaults completos:

```text
godot --headless --path . --script res://scripts/debug/run_evolution_benchmark.gd
```
