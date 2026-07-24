# NeuroMine Lab

Laboratório visual experimental em Godot para, futuramente, evoluir pequenas redes neurais capazes de jogar Campo Minado.

## Estado atual

Esta etapa contém um Campo Minado 6×6 com 6 minas, geração determinística por seed, primeira jogada segura, abertura em cascata, bandeiras, vitória/derrota e diagnósticos internos. Ainda não há rede neural, treinamento ou algoritmo genético.

## Controles

- Clique esquerdo: revelar casa.
- Clique direito: colocar ou remover bandeira.
- **Mesmo campo** reinicia preservando a seed; **Novo campo** gera outra seed.
- Uma seed numérica pode ser carregada pelo painel lateral.

Requer **Godot 4.7**. A cena principal é `scenes/main.tscn`.

O modelo em `scripts/core/` é independente de Nodes e renderização. `scripts/ui/` adapta esse modelo à interface, enquanto `scripts/debug/` o valida diretamente e pode ser executado em modo headless. IA e evolução genética serão implementadas em etapas futuras.
