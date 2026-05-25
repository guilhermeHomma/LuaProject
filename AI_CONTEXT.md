# AI Context Guide

Este arquivo existe para acelerar novas implementacoes feitas por IA ou por devs voltando ao projeto. Antes de mexer em uma mecanica, leia este resumo e depois abra os arquivos citados.

## Objetivo do Projeto

`mobize` e um jogo em LOVE/Lua top-down com salas geradas, combate contra zumbis, lojas, cartas, drops, particulas, iluminacao e menus pixel art. O codigo deve continuar facil de manter e com bom desempenho, principalmente em floors grandes.

## Regras de Manutencao

- Prefira alterar a mecanica no modulo dono dela em vez de espalhar regras por arquivos grandes.
- Coloque configuracoes em `scripts/config/` quando forem valores de gameplay, dificuldade, chances, templates ou toggles.
- Evite hardcode em managers quando o valor provavelmente sera ajustado depois.
- Preserve efeitos pixel art sem blur: fontes e sprites devem usar `nearest`, posicoes visuais normalmente devem ser inteiras.
- Nao crie sistemas paralelos se ja existir manager, objeto ou particula equivalente.
- Mantenha novas mecanicas parametrizaveis quando envolver quantidade, chance, duracao, cor, escala, distancia ou dificuldade.
- Evite refactors grandes junto com ajustes visuais pequenos.

## Regras de Performance

- Em updates por frame, evite varrer mapas ou listas grandes quando puder usar estado cacheado.
- Para objetos fora da tela, use culling ou cheque de distancia antes de desenhar/atualizar efeitos caros.
- Particulas devem ter limite claro de quantidade, tempo de vida curto quando possivel e remocao simples.
- Evite criar fontes, imagens, shaders, quads ou sons dentro de `update`/`draw`; carregue uma vez.
- Prefira tabelas persistentes/cacheadas para dados de sala, chao, grama, caminhos, variantes e luzes.
- Em floors grandes, cuidado com pathfinding, geracao de salas e loops por tile. Execute isso em carregamento/geracao, nao continuamente.

## Entrada Principal

- `main.lua`: estados do jogo, canvas, shader final de apresentacao/CRT, menus, transicoes e callbacks LOVE.
- `conf.lua`: flags globais experimentais, configuracao inicial da janela e toggles como CRT/camera shake.
- `scripts/config/gameConfig.lua`: dimensoes base, escala, viewport, camera bounds e configuracao global do level ativo.
- `scripts/config/levels.lua`: escolhe/carrega o level padrao.
- `scripts/levels/default.lua`: level principal; deve ficar leve e delegar configuracao de salas para `scripts/config/defaultRoomConfig.lua`.

## Geracao de Salas e Floors

- `scripts/managers/floorManager.lua`: grafo de salas, start room, salas especiais, distancia do start, conexoes, minimap e troca de sala.
- `scripts/config/defaultRoomConfig.lua`: configuracao editavel de salas, quantidades, probabilidades, salas de armas/cards/baus, dificuldade por distancia, paths e variantes.
- `scripts/rooms/roomTemplates.lua`: desenhos/templates das salas.
- `scripts/rooms/roomBuilder.lua`: transforma template em tilemap/objetos.
- `scripts/tilemaps/defaultSystem.lua`: carrega tilemap da sala atual, cria objetos de tiles, chao, caminhos, lojas, baus, vegetacao, luzes e pathfinding.

Ao adicionar nova sala especial, prefira configurar em `defaultRoomConfig.lua` e implementar a instanciacao no fluxo ja existente de `floorManager.lua`/`defaultSystem.lua`.

## Tilemap, Objetos e Render

- `scripts/objects/tileset.lua`: quads do tileset.
- `scripts/objects/tile.lua`: tile visual/colisao/render padrao.
- `scripts/objects/tree.lua`, `container.lua`, `chest.lua`, `store.lua`, `door.lua`, `floorPath.lua`: objetos principais vindos do tilemap.
- `scripts/managers/gameManager.lua`: orquestra update/draw, listas de entidades, draw queues, luzes, sombras, HUD, minimap, room transitions e spawn de inimigos/drops.
- `scripts/config/lightConfig.lua`: configuracao de sombras, luz geral e brilho minimo por contexto.

Ordem visual importa muito. Antes de mudar render, confira as filas em `gameManager.lua`: ground, trails/footsteps, ground queue, shadows, light sprites, draw queue, player/HUD.

## Player, Armas e Balas

- `scripts/player/player.lua`: movimento, colisao, animacao, dano, vida, maos, desenho e sangue do player.
- `scripts/player/gun.lua`: estado geral das armas do player.
- `scripts/player/weapons/*.lua`: comportamento de cada arma.
- `scripts/player/weapons/shared.lua`: helpers compartilhados entre armas.
- `scripts/player/bullets/particleBullet.lua` e `lineBullet.lua`: projeteis do player.
- `scripts/bullet.lua`: base/compatibilidade de bullets.
- `scripts/camera.lua`: camera, follow, zoom de dano e shake. Shake deve respeitar `GAME_FLAGS.cameraShake`.

Ao mexer em colisao do player, teste quinas e paredes lisas. O player nao pode entrar no tile, e deve deslizar sem parecer teleporte.

## Inimigos e Waves

- `scripts/enemies/enemy.lua`: base de inimigo.
- `scripts/enemies/zombie.lua`, `babyZombie.lua`, `bigZombie.lua`, `noHead.lua`, `scarecrow.lua`: inimigos especificos.
- `scripts/config/encounterWaves.lua`: templates editaveis de waves, inimigos, pesos/chances e dificuldade minima.
- `scripts/managers/waves.lua`: UI/estado de waves.
- `scripts/managers/gameManager.lua`: selecao, spawn e controle de waves por sala.

Start room e especial: deve ter apenas o scarecrow quando configurado assim, sem waves extras de zumbi.

## Drops, Pontos, Lojas e Cartas

- `scripts/drops/drop.lua`: base de drops.
- `scripts/drops/coin.lua`, `life.lua`, `bullets.lua`, `card.lua`: drops especificos.
- `scripts/drops/dropTemplates.lua`: configuracao de drops.
- `scripts/managers/pointsManager.lua`: moedas/HUD/animacao de ganho e perda.
- `scripts/objects/store.lua`: lojas de armas, ammo e cards.
- `scripts/objects/chest.lua`: baus comuns/cards e luz/beam.
- `scripts/cards/cardDefinitions.lua`: definicoes das cartas, raridade, texto e efeito aplicado.
- `scripts/managers/cardChoice.lua`: tela de escolha de cartas, animacao, hover e aplicacao da carta.

Cartas sao mecanica central. Novas regras de carta devem ficar claras e isoladas em `cardDefinitions.lua` ou em modulo proprio dentro de `scripts/cards/`.

## Particulas e Efeitos

- `scripts/particles/`: particulas de sangue, bullets, caixas, folhas, passos, estrelas, etc.
- `scripts/effects/damageNumber.lua`: numeros que sobem ao pegar itens/cartas/moedas.
- `scripts/effects/rgbShiftDraw.lua`, `damageStretch.lua`, `gunStarDraw.lua`: efeitos visuais reutilizaveis.
- `scripts/shaders/`: shaders de luz, distorcao HUD, CRT, paletas, outlines e efeitos.

Ao criar nova particula, exponha quantidade, duracao, escala e cores. Evite alpha quando o estilo pedir aparicao/desaparicao por timing.

## Menus, Settings e HUD

- `scripts/managers/menu/baseMenu.lua`: base visual dos menus, hover arco-iris zumbi, titulo e input.
- `scripts/managers/menu/settingsMenu.lua`: settings de resolucao, fullscreen, CRT, camera shake e volumes.
- `scripts/managers/settings.lua`: aplica settings em audio, janela, CRT e camera shake.
- `scripts/managers/menu/mainMenu.lua`, `pauseMenu.lua`, `confirmMenu.lua`, `gameoverMenu.lua`, `logoIntro.lua`: menus especificos.
- `scripts/managers/gameIntro.lua`: intro level/texto/camera inicial.

Para novas opcoes de menu, coloque a aplicacao real em `settings.lua` e apenas a UI em `settingsMenu.lua`.

## Checklist Antes de Finalizar

- Rodar um boot rapido com `.\love-win\lovec.exe .` e verificar se nao aparece traceback.
- Conferir se a mudanca nao cria objetos/recursos novos dentro de `draw` ou `update` sem necessidade.
- Conferir se valores ajustaveis ficaram em config ou constantes bem nomeadas.
- Conferir se estados de sala persistem ao sair/voltar quando a mecanica deve ser persistente.
- Conferir se visual pixel art nao ficou borrado por escala/fonte/posicao.
- Em mudancas de sala/floor, testar start room, sala especial e salas distantes.
