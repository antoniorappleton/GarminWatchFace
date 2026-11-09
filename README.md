# Tático Navy

Variante experimental do Tático Claro, de inspiração militar, para o Garmin Instinct 3 Solar.

- Numeração que muda com o período do dia (manhã 12, 1–11; tarde 12, 13–23): eixos cardeais grandes, restantes pequenos
- Ponteiros tipo espada com faixa interior ("lume") e contorno
- Data e hora militar (DTG): DDHHMM + letra do fuso (Z = UTC), MÊS AA
- Subjanela: temperatura e probabilidade de precipitação
- Pulsação no mostrador e assinatura da marca por baixo do 12 (`_brand`; usar ™ enquanto a marca não estiver registada)
- Variante escura: `_dark = true` no início de `TaticoNavyView.mc`

Estado: **EM DESENVOLVIMENTO** — v1 testada no simulador; v3 (DTG, meteorologia, assinatura, sem bateria) ainda por compilar.

Tem um ID de aplicação próprio: pode ser instalado ao lado do Tático Claro para comparar.

## Correr no simulador

1. Abre esta pasta no VS Code (File → Open Folder).
2. Abre `source/TaticoNavyView.mc` e carrega em Ctrl+F5.
3. Escolhe o dispositivo `instinct3solar45mm`.

## Regras

- Nunca fazer commit da chave de programador (`*.der`).
- Desenhar sempre o ecrã inteiro em `onUpdate`.
