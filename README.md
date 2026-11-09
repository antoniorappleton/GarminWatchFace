# Tático Navy

Variante experimental do Tático Claro, de inspiração militar, para o Garmin Instinct 3 Solar.

- Fundo branco ou preto: escolha no relógio (personalizar mostrador) ou na app Connect IQ, depois de publicado
- Numeração que muda sozinha entre manhã (12, 1–11) e tarde (12, 13–23); eixos cardeais em fonte do sistema, restantes em fonte própria mais pequena
- Ponteiros tipo espada com faixa interior ("lume") e contorno
- DTG: dia em grande + HHMM e letra do fuso (ex.: 09 2017Z; Z = UTC)
- Coordenadas em graus e minutos decimais, sem moldura, em fonte própria de 10 px (última posição conhecida)
- Fundo com curvas de nível discretas (duas montanhas e um vale), pontilhadas em xadrez; só no ecrã de 176 px
- Subjanela: temperatura e probabilidade de precipitação
- Assinatura "appleton" em minúsculas

Recursos gerados por `tools/gen_assets.py` (Pillow + numpy): terreno (`resources/drawables/topo_*.png`)
e fontes (`resources/fonts/small.*` 11 px, `coord.*` 10 px, DejaVu Sans Condensed Bold, 1 bit).
Se mudares posições no mostrador, atualiza as zonas livres no gerador e volta a corrê-lo.

Estado: **EM TESTES** — v5 no relógio; v6 (terreno, coordenadas 10 px, assinatura sem ®) compilada em `bin/taticonavy.iq`, pronta a submeter.

Tem um ID de aplicação próprio: pode ser instalado ao lado do Tático Claro para comparar.

## Correr no simulador

1. Abre esta pasta no VS Code (File → Open Folder).
2. Abre `source/TaticoNavyView.mc` e carrega em Ctrl+F5.
3. Escolhe o dispositivo `instinct3solar45mm`.

## Regras

- Nunca fazer commit da chave de programador (`*.der`).
- Desenhar sempre o ecrã inteiro em `onUpdate`.
