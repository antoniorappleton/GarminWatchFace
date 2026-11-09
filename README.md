# Tático Claro

Mostrador híbrido (analógico + complicações) da Appleton Labs para o Garmin Instinct 3 Solar.

- Ponteiros de horas e minutos com contorno
- Arco de bateria (inferior) com percentagem
- Pulsação (esquerda) e dia do mês (direita)
- Hora digital na subjanela, respeitando a definição 12/24 h do relógio

Estado: **EM DESENVOLVIMENTO** — código escrito, ainda não compilado nem testado.

## Correr no simulador

1. Abre esta pasta no VS Code (com a extensão Monkey C e o SDK instalados — ver o guia).
2. Abre `source/TaticoClaroView.mc` e carrega em F5.
3. Escolhe o dispositivo `instinct3solar45mm`.

## Instalar no relógio

1. Paleta de comandos → `Monkey C: Build for Device` → `instinct3solar45mm`.
2. Copia o `.prg` gerado em `bin/` para `GARMIN/APPS` no relógio (USB).

## Estrutura

```
manifest.xml                  tipo, dispositivos, idiomas
monkey.jungle                 configuração de compilação
source/TaticoClaroApp.mc      ponto de entrada
source/TaticoClaroView.mc     todo o desenho do mostrador
resources/                    nome da app e ícone
```

## Regras

- Nunca fazer commit da chave de programador (`*.der`) — já está no `.gitignore`.
- Desenhar sempre o ecrã inteiro em `onUpdate`.
- Antes de publicar, rever a lista de testes no guia.
