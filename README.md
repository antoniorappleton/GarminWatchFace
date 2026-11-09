# Tático Navy

Variante experimental do Tático Claro, de inspiração militar, para o Garmin Instinct 3 Solar.

- Numeração das horas que muda com o período do dia: manhã 12, 1–11; tarde 12, 13–23
- Ponteiros tipo espada, pretos, com faixa interior branca ("lume") e contorno branco
- Arco de bateria, pulsação, dia do mês e hora digital na subjanela (como no Tático Claro)

Estado: **EM DESENVOLVIMENTO** — código escrito, ainda não compilado nem testado.

Tem um ID de aplicação próprio: pode ser instalado ao lado do Tático Claro para comparar.

## Correr no simulador

1. Abre esta pasta no VS Code (File → Open Folder).
2. Abre `source/TaticoNavyView.mc` e carrega em Ctrl+F5.
3. Escolhe o dispositivo `instinct3solar45mm`.

## Regras

- Nunca fazer commit da chave de programador (`*.der`).
- Desenhar sempre o ecrã inteiro em `onUpdate`.
