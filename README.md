# Tático Navy

Variante experimental do Tático Claro, de inspiração militar, para o Garmin Instinct 3 Solar.

- Fundo branco ou preto: escolha no relógio (personalizar mostrador) ou na app Connect IQ, depois de publicado
- Numeração que muda sozinha entre manhã (12, 1–11) e tarde (12, 13–23); eixos cardeais em fonte do sistema, restantes em fonte própria mais pequena
- Ponteiros tipo espada com faixa interior ("lume") e contorno
- DTG: dia em grande + HHMM e letra do fuso (ex.: 09 2017Z; Z = UTC)
- Coordenadas em graus e minutos decimais, numa caixa de cantos chanfrados (última posição conhecida)
- Subjanela: temperatura e probabilidade de precipitação
- Assinatura "appleton" em minúsculas (`_brand`; usar ™ enquanto a marca não estiver registada)

Fonte própria: `resources/fonts/small.fnt` + `small.png` (DejaVu Sans Condensed Bold, 11 px, 1 bit).

Estado: **EM TESTES** — v4 instalada no relógio; v5 (fonte própria, coordenadas, escolha de fundo) ainda por compilar.

Tem um ID de aplicação próprio: pode ser instalado ao lado do Tático Claro para comparar.

## Correr no simulador

1. Abre esta pasta no VS Code (File → Open Folder).
2. Abre `source/TaticoNavyView.mc` e carrega em Ctrl+F5.
3. Escolhe o dispositivo `instinct3solar45mm`.

## Regras

- Nunca fazer commit da chave de programador (`*.der`).
- Desenhar sempre o ecrã inteiro em `onUpdate`.
