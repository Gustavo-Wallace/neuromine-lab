# NeuroMine Lab

Laboratório visual experimental em Godot para, futuramente, evoluir pequenas redes neurais capazes de jogar Campo Minado.

## Estado atual

Esta etapa contém um Campo Minado 6×6 com 6 minas, geração determinística por seed, primeira jogada segura, abertura em cascata, bandeiras, vitória/derrota e diagnósticos internos. Um agente aleatório já pode jogar partidas completas como baseline, tanto no modo visual temporizado quanto em lotes rápidos de 1, 10, 100 ou 1.000 partidas.

## Controles

- Clique esquerdo: revelar casa.
- Clique direito: colocar ou remover bandeira.
- **Mesmo campo** reinicia preservando a seed; **Novo campo** gera outra seed.
- Uma seed numérica pode ser carregada pelo painel lateral.
- **Assistir agente** inicia a execução visual; a partida pode ser pausada, avançada uma jogada por vez, reiniciada e acelerada de 0,25× a 10×.
- Os botões de lote executam partidas headless e acumulam vitórias, progresso, jogadas, interrupções e desempenho.

Requer **Godot 4.7**. A cena principal é `scenes/main.tscn`.

O modelo em `scripts/core/` é independente de Nodes e renderização. `scripts/agents/` contém o contrato comum e o agente aleatório; `scripts/simulation/` executa partidas e agrega resultados sem depender da interface. `scripts/ui/` adapta o estado visível à cena, enquanto `scripts/debug/` valida tudo em modo headless.

O agente aleatório não aprende nem usa heurísticas: ele serve como referência para medir o desempenho das futuras redes neurais. Redes neurais e evolução genética continuam reservadas para etapas posteriores.
