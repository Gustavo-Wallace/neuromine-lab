# NeuroMine Lab

Laboratório em Godot 4.7 para neuroevolução reproduzível de redes **72 → 24 → 12 → 1** em Campo Minado.

## Presets

O padrão é **Currículo + diversidade**:

- população 96, elite 6 e torneio 4;
- crossover desativado;
- mutação de 2% por parâmetro, intensidade 0,08 e limite ±5;
- 10% de imigrantes por geração;
- no máximo duas cópias idênticas de um genoma;
- quatro cenários fixos e oito rotativos por geração;
- 30 cenários fixos de validação por fase;
- 100 cenários isolados de teste final.

Continuam disponíveis **Calibração sem crossover** e **Configuração original**.

## Currículo

1. **Fundamentos:** 5×5, 3 minas. Após pelo menos 10 gerações, exige 6/30 vitórias e fitness robusto de validação 4.000.
2. **Transição:** 6×6, 4 minas. Após 10 gerações, exige 3/30 vitórias e superar os baselines.
3. **Principal:** 6×6, 6 minas, sem avanço automático.

Ao avançar, os genomas mantêm a arquitetura e são transferidos diretamente: 10% preservados, 70% descendentes mutados do quartil superior e 20% imigrantes. Fitness e métricas da fase anterior são descartados.

O sistema mantém geração global e geração da fase, avanço automático/manual, bloqueio temporário, reinício de fase e início direto em qualquer fase.

## Cenários e fitness robusto

Cada fase possui um pool determinístico de 256 campos. O núcleo de quatro permanece fixo, enquanto oito campos rotativos mudam a cada geração. Todos os indivíduos enfrentam a mesma suíte e os elites são reavaliados.

O fitness por partida continua usando progresso, decisões seguras, vitória, eficiência e penalidades. Para seleção:

```text
fitness robusto = média dos cenários × 0,80
                + média do quartil inferior × 0,20
```

São registrados média, quartil inferior, melhor/pior campo, desvio, núcleo, rotativos, validação e gap de generalização.

## Diversidade

Toda reprodução reserva aproximadamente 10% da população para redes aleatórias. Descendentes que excedem duas cópias idênticas são mutados novamente e, após cinco tentativas, substituídos por imigrantes.

A injeção manual de diversidade preserva elites, substitui 20% dos não elites e reforça 20% dos descendentes restantes com intensidade 0,12. Nenhum ajuste é automático.

## Teste final

O teste final possui 100 campos separados de treino e validação. Só é executado por comando e nunca influencia fitness, seleção, campeão global ou avanço curricular. A interface registra quantas consultas foram feitas.

## Interface e diagnóstico

O painel mostra fase, contagens global/local, critérios, cenários, fitness robusto, diversidade, imigrantes, clones, gap e estagnação. Detalhes avançados permitem assistir a campos fixos, rotativos, validação e teste final.

Também é possível guardar em memória o resumo de uma execução e compará-lo sequencialmente com outro preset usando seed, arquitetura e validação compatíveis.

O projeto mantém **148 diagnósticos** e smokes headless. Minas ocultas são usadas apenas pelo tabuleiro para resolver uma ação; nunca entram nas 72 observações neurais.

```text
godot --headless --path . --script res://scripts/debug/run_diagnostics.gd
godot --headless --path . --script res://scripts/debug/run_curriculum_audit.gd
```
