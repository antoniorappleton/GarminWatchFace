# Tático Claro

Mostrador personalizável para o Garmin Instinct 3 Solar, inspirado nos exemplos
analógico claro, analógico escuro e digital escuro.

- Escolha entre os estilos analógico e digital e entre os temas claro e escuro.
- Configure os mostradores laterais e os campos de dados de cada estilo
  independentemente.
- Os campos podem mostrar data, bateria, frequência cardíaca, Body Battery,
  altitude, passos, temperatura, probabilidade de precipitação ou carga solar.
- A meteorologia depende dos dados meteorológicos disponíveis no relógio.
  Quando um dado não está disponível, o mostrador apresenta `--`.
- A hora respeita a definição de 12/24 horas do relógio.

As opções encontram-se nas definições do mostrador na aplicação Garmin Connect
IQ depois de instalar/sincronizar a aplicação.

## Correr no simulador

1. Abre esta pasta no VS Code (com a extensão Monkey C e o SDK instalados — ver o guia).
2. Abre `source/TaticoClaroView.mc` e carrega em F5.
3. Escolhe o dispositivo `instinct3solar45mm`.

## Instalar no relógio

1. Paleta de comandos → `Monkey C: Build for Device` → `instinct3solar45mm`.
2. Copia o `.prg` gerado em `bin/` para `GARMIN/APPS` no relógio (USB).

## Publicar na Connect IQ Store

O pacote assinado para carregar no painel de programador é
`bin/taticoclaro.iq`. Foi compilado para os dispositivos Instinct 3 Solar
selecionados no manifesto.

1. Confirma que `monkeyC.developerKeyPath` no VS Code aponta para a chave
   associada a esta aplicação na Connect IQ Store. Mantém essa chave privada
   local e não a partilhes nem a incluas no repositório.
2. Para gerar um pacote atualizado, executa `Monkey C: Export Project` na
   paleta de comandos; o SDK assina o pacote com a chave configurada.
3. Carrega `bin/taticoclaro.iq` em
   [Connect IQ Developer Dashboard](https://apps.garmin.com/en-US/developer/upload).
4. Depois de a versão ser aceite/publicada, instala ou atualiza o mostrador no
   relógio através do Garmin Connect IQ.

Uma chave diferente pode impedir a atualização de uma aplicação já publicada.
Se a chave original foi perdida, confirma com o suporte Garmin como associar a
nova chave antes de submeter a atualização.

## Estrutura

```
manifest.xml                  tipo, dispositivos, idiomas
monkey.jungle                 configuração de compilação
source/TaticoClaroApp.mc      ponto de entrada
source/TaticoClaroView.mc     todo o desenho do mostrador
resources/settings/           predefinições e opções do mostrador
resources/                    nome da app e ícone
```

## Regras

- Nunca fazer commit da chave de programador (`*.der`) — já está no `.gitignore`.
- Desenhar sempre o ecrã inteiro em `onUpdate`.
- Antes de publicar, rever a lista de testes no guia.
