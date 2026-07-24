# NeuroMine Lab

Laboratório visual experimental em Godot para, futuramente, evoluir pequenas redes neurais capazes de jogar Campo Minado.

## Estado atual

Esta etapa contém um Campo Minado 6×6 com 6 minas, geração determinística por seed, primeira jogada segura, abertura em cascata, bandeiras, vitória/derrota e diagnósticos internos. Um agente aleatório já pode jogar partidas completas como baseline, tanto no modo visual temporizado quanto em lotes rápidos de 1, 10, 100 ou 1.000 partidas.

O sistema de observação v1 transforma cada casa candidata em um vetor fixo de **72 entradas**: oito características visíveis para cada uma das oito direções locais (64) e oito características globais (8). A ordem local é NW, N, NE, W, E, SW, S e SE. Bandeiras não contam como casas cobertas; o valor de pista restante usa 0,5 como neutro para casas não reveladas; `flags_used_ratio` é a única característica que pode exceder 1, com limite em 2.

## Controles

- Clique esquerdo: revelar casa.
- Clique direito: colocar ou remover bandeira.
- **Mesmo campo** reinicia preservando a seed; **Novo campo** gera outra seed.
- Uma seed numérica pode ser carregada pelo painel lateral.
- **Assistir agente** inicia a execução visual; a partida pode ser pausada, avançada uma jogada por vez, reiniciada e acelerada de 0,25× a 10×.
- Os botões de lote executam partidas headless e acumulam vitórias, progresso, jogadas, interrupções e desempenho.
- O **Inspetor de Observação** permite navegar pelas candidatas, mostrar índices absolutos, inspecionar os 72 valores e copiar o vetor. Durante uma partida visual ele acompanha a célula escolhida pelo agente antes da revelação.

Requer **Godot 4.7**. A cena principal é `scenes/main.tscn`.

O modelo em `scripts/core/` é independente de Nodes e renderização. `scripts/agents/` contém o contrato comum e o agente aleatório; `scripts/observation/` enumera candidatas e codifica apenas cópias sanitizadas do estado visível; `scripts/simulation/` executa partidas e agrega resultados sem depender da interface. `scripts/ui/` adapta esses dados à cena, enquanto `scripts/debug/` valida tudo em modo headless.

Minas ocultas, pistas ocultas e a seed do campo não são expostas ao codificador ou aos agentes. O agente aleatório não aprende nem usa heurísticas: ele serve como referência para medir o desempenho das futuras redes neurais. Ainda não existem rede neural, pesos, treinamento ou evolução genética.
