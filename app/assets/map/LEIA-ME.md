# Contornos do mapa offline

`contornos.json` traz os contornos de países (escala 1:110m) e de estados e
províncias (1:50m) do **Natural Earth 5.1.2** (https://www.naturalearthdata.com),
que é de **domínio público** (autorizado pelo usuário em 2026-11-18; ver o ADR 0026).

Gerado por `tools\fixtures\bin\build_map_data.dart` a partir dos GeoJSON
`ne_110m_admin_0_countries` e `ne_50m_admin_1_states_provinces`: coordenadas em
centésimos de grau (países arredondados a cada 0,1°), cada anel com o primeiro
ponto absoluto e os outros como diferença do anterior.

Nada é baixado em tempo de execução: o arquivo vai dentro do instalador.
