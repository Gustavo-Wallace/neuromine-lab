# NeuroMine Lab

Laboratório experimental em Godot 4.7 para neuroevolução de redes neurais que jogam Campo Minado.

## Estado atual

O projeto oferece Campo Minado determinístico, observações sanitizadas com 72 entradas, rede feedforward **72 → 24 → 12 → 1** com 2.065 parâmetros, agentes aleatório e neural, partidas visuais/headless e evolução genética reproduzível.

Não há backpropagation, gradientes, NEAT, reinforcement learning, alteração de topologia ou bandeiras automáticas.

## Presets evolutivos

O preset padrão é **Calibração sem crossover**:

- população 96, elite 8 e torneio 4;
- crossover desativado;
- mutação de 2% por parâmetro, intensidade 0,08 e limite ±5;
- 12 cenários fixos de treino e 30 cenários fixos de validação;
- abertura central fixa antes da primeira decisão neural.

Cada filho copia profundamente um único pai escolhido por torneio e então recebe mutação. O preset anterior — população 48, elite 4, crossover de 70% e mutação de 8% — permanece disponível como **Configuração original**.

Os ambientes disponíveis são:

- **Calibração 5×5 / 3 minas**;
- **Principal 6×6 / 6 minas**.

Trocar ambiente ou reiniciar cria um experimento isolado; históricos e estatísticas não são misturados.

## Fitness calibrado

Por partida:

```text
fitness = progresso × 1500
        + decisões_seguras × 30
        + 10000 em vitória
        + até 1000 de eficiência em vitória
        - penalidades
```

Mina detonada vale −250, ação inválida −500 e término inválido/limite −500. Cascatas contam como uma única decisão segura.

As minas ocultas são consultadas somente pelo tabuleiro para resolver a ação e avaliar seu resultado. Elas nunca entram na observação ou no vetor neural.

## Auditoria e estagnação

Cada geração registra fitness, validação, diversidade, genomas idênticos, distância entre genomas, mutações por filho, amplitude e desvio dos scores, candidatas quase empatadas e primeiras decisões distintas. Scores são considerados praticamente iguais quando diferem menos de `0,0001`.

As saídas são classificadas como saudáveis, pouco diferenciadas, saturadas em zero/um ou inválidas. Após 15 gerações sem melhoria relevante na validação, a interface mostra um alerta de estagnação, mas não interrompe nem modifica parâmetros automaticamente.

O painel compara, na mesma validação fixa:

- baseline aleatório;
- neural não treinado;
- campeão da geração;
- campeão global.

Também permite executar exatamente 20 gerações, pausar, continuar, parar e assistir aos campeões com heatmap e ranking.

## Estrutura

- `scripts/core/`: modelo do jogo;
- `scripts/observation/`: observações visíveis;
- `scripts/neural/`: rede feedforward;
- `scripts/simulation/`: partidas e cenários;
- `scripts/evolution/`: população, fitness, genética, telemetria e estagnação;
- `scripts/ui/`: painel, heatmap e inspetores;
- `scripts/debug/`: 118 diagnósticos, smokes e auditorias headless.

## Validação

```text
godot --headless --path . --script res://scripts/debug/run_diagnostics.gd
godot --headless --path . --script res://scripts/debug/run_calibration_audit.gd
```

A auditoria completa executa 20 gerações em 5×5 e 10 gerações em 6×6 usando o preset calibrado integral.
