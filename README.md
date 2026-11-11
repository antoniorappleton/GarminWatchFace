# Tático Navy

Mostrador monocromático de 176 × 176 px para o Garmin Instinct 3 Solar 45 mm.
O ecrã é 1-bit; fontes, marcas e ícones são recursos pixelizados gerados
por `tools/gen_assets.py`.

## Estilos

- **Navy** — analógico, tema claro, escuro ou automático, ponteiros espada,
  triângulo nas 12h, horas 12/24 nas 3, 6 e 9 e azimute em graus nas restantes
  posições. O tema automático troca às 06:00 e às 18:00 (hora
  local) e pode ser claro de dia e escuro de noite, ou o inverso.
- **Surf** — analógico sempre escuro, com ondas, nascer/pôr do sol, vento e
  fase da lua.
- **Zulu** — digital, tema claro, escuro ou automático, com campos de altitude
  e pressão, DTG em UTC e janela de azimute.

Todos os estilos permitem escolher os dados da janela superior. Também é
possível ocultar o DTG, as coordenadas e a assinatura. O formato das
coordenadas pode ser graus/minutos inteiros (`N38 43`) ou minutos decimais
(`N3843.5`). As unidades de temperatura, altitude, pressão e velocidade são
configuráveis.

O mostrador não inicia o GPS. As coordenadas usam, por ordem: a atividade em
curso, o último ponto GPS do sistema (permissão de posicionamento), a última
posição guardada pelo mostrador e, por fim, o local da meteorologia vinda do
telemóvel (aproximado). Só sem nenhuma destas fontes aparecem marcadores.
Os mostradores analógicos não têm ponteiro dos segundos.

## Recursos gráficos

Para regenerar as fontes:

```powershell
python tools\gen_assets.py
```

O gerador requer Pillow e NumPy. A fonte DejaVu Sans Condensed Bold incluída em
`tools` é usada apenas para produzir os glifos bitmap.

## Compilação

Abra o projeto no VS Code com a extensão Monkey C e escolha
`instinct3solar45mm`. `test.jungle` compila a variante de demonstração com
valores fixos da folha de produção; `monkey.jungle` compila a aplicação normal.
Para abrir qualquer variante de referência no simulador:

```powershell
.\tools\run_design_simulator.ps1 -DeveloperKey "C:\caminho\para\developer_key" -Variant NavyLight
.\tools\run_design_simulator.ps1 -DeveloperKey "C:\caminho\para\developer_key" -Variant NavyDark
.\tools\run_design_simulator.ps1 -DeveloperKey "C:\caminho\para\developer_key" -Variant Surf
```

As três builds usam os dados fixos da folha; Navy claro mostra o cenário da
manhã (10:08Z), e Navy escuro e Surf mostram o cenário da tarde (16:33Z).
Zulu também está disponível nos dois temas:

```powershell
.\tools\run_design_simulator.ps1 -DeveloperKey "C:\caminho\para\developer_key" -Variant ZuluLight
.\tools\run_design_simulator.ps1 -DeveloperKey "C:\caminho\para\developer_key" -Variant ZuluDark
```

As variantes de demonstração usam um ID Connect IQ de teste separado. O ID de
produção em `manifest.xml` mantém-se inalterado para não afetar a aplicação
publicada.

Não inclua a chave privada de programador no repositório.
