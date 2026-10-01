# Alice Zero — próximas atualizações

Planejamento de 30/09/2026, baseado no GDD atualizado e em leitura do código atual. Não houve playtest nesta análise. As tarefas abaixo são propostas de produção; os conceitos não definidos no GDD estão identificados como sugestões.

## Direção e capacidade

Prioridade: entregar Floresta 1–3 como uma experiência completa, com escolhas de build, três chefes, artefatos e progressão clara. Depois, completar Caverna, Cidade e pós-jogo, nessa ordem.

Oito semanas são uma sequência sugerida, não uma promessa de prazo. Premissa: uma pessoa dividindo programação e arte, com dedicação regular. Reservar cerca de 25% de cada semana para integração, correções e playtest. Se a disponibilidade for parcial, tratar cada semana como um sprint que pode durar duas semanas. Chefes, especialmente a Cobra, podem exigir um sprint extra.

Os seis andares atuais continuam sendo a base do projeto. O marco da Floresta é um recorte de qualidade, não uma tarefa de remover a Caverna.

## Estado encontrado

| Área | Evidência atual | Próximo trabalho |
| --- | --- | --- |
| Campanha | Seis floors configurados; Floresta 1–3 e Caverna 4–6 | Fechar a conclusão por chefe antes de ampliar para nove |
| Cartas | Atributos, ricochete, fragmentação, projéteis na morte e cartas malignas | Balancear decisões e comunicar efeitos; não reimplementar o sistema |
| Armas | Múltiplas armas, lojas e pools por tema | Dar função clara a cada arma e conferir o revólver inicial do GDD |
| Encontros | Pools por andar, ondas e implementação de aranhas e inimigos voadores | Conferir participação real nos encontros e variar composições |
| Elevadores | Transição de andar e tela de agradecimento ao terminar os andares disponíveis | Integrar artefato e estados de conclusão; a tela atual não é o final narrativo |
| Arte | Temas Floresta e Caverna configurados | Reforçar arquitetura artificial e produzir arenas/chefes |

No fluxo de elevador inspecionado, não aparece uma exigência de artefato. Não foi identificado um sistema completo de chefes nos módulos revisados. Conferir isso no inventário inicial antes de implementar.

## Semana 1 — fechar decisões e medir a base

### Mecânicas e design
- [ ] Fazer 5 runs de diagnóstico: registrar tempo por sala/andar, causa da morte, arma escolhida, cartas escolhidas, moedas recebidas e gastas.
- [ ] Inventariar o que está jogável, o que é experimental e o que falta; conferir chefe/artefato, cartas malignas e inimigo voador versus o morcego do GDD.
- [ ] Definir o percurso obrigatório: entrada → exploração → arena → artefato → elevador. Salas opcionais não devem exigir limpeza total do andar.
- [ ] Fixar provisoriamente Slime no floor 1 e Cobra no floor 2; aprovar um conceito simples para o chefe do floor 3.
- [ ] Definir regras do artefato: pertence ao andar, não é moeda nem upgrade, libera o elevador e não pode ser perdido por posição inacessível.
- [ ] Documentar se upgrades acompanham Alice ou a arma ao trocar; fazer a interface refletir a regra real.

### Arte e áudio
- [ ] Criar uma folha de referência: escala dos sprites, paleta, contorno, cores dos perigos e arquitetura branca da Estrutura.
- [ ] Esboçar Slime em quatro tamanhos, Cobra e três arenas, ainda sem animação final.
- [ ] Esboçar artefato, encaixe do elevador, ícone de chefe e comporta fechada.

**Concluído quando:** há uma lista de lacunas confirmadas e um desenho do primeiro andar completo, com estimativas revisadas. Metas iniciais de teste, não exigências do GDD: salas comuns em 20–45 s e chefe em 45–90 s; ajustar após observar runs reais.

## Semana 2 — ciclo chefe → artefato → elevador

### Mecânicas
- [ ] Integrar arena de chefe à geração existente, com caminho sempre acessível e espaço reservado.
- [ ] Criar estados de encontro: não iniciado, em combate, derrotado, artefato coletado e elevador liberado.
- [ ] Usar um inimigo provisório para validar trancamento da arena, vitória, recompensa e saída.
- [ ] Garantir um único artefato por chefe e impedir duplicação ao sair e voltar à sala.
- [ ] Bloquear o elevador sem artefato e indicar visualmente o requisito; validar também no ponto de entrada da transição.
- [ ] Reiniciar esses estados na morte/nova run e preservar o necessário ao revisitar salas.

### Arte e áudio
- [ ] Produzir artefato com idle/brilho, coleta e encaixe no elevador.
- [ ] Produzir estados bloqueado/liberado do elevador e sinalização da arena.
- [ ] Adicionar sons de arena fechando, vitória, coleta e ativação.

**Concluído quando:** o jogador termina um andar pelo novo ciclo, não consegue pular o requisito e não fica preso após vencer. Verificar diferentes gerações, morte e revisita.

## Semana 3 — Slime gigante completo

### Mecânicas
- [ ] Implementar as três divisões do GDD: 1 → 2 → 4 → 8, com divisão individual e limite de população.
- [ ] Definir vida por tamanho e impedir divisão duplicada quando vários projéteis acertarem no mesmo instante.
- [ ] Projetar movimentação/ataque legível e intervalo seguro na divisão; não causar dano inevitável ao nascer sobre Alice.
- [ ] Entregar o artefato somente depois de eliminar todos os descendentes.
- [ ] Testar revólver inicial, arma de área, ricochete e fragmentação, inclusive custo de partículas/projéteis.

### Arte e áudio
- [ ] Finalizar quatro tamanhos com idle/movimento, preparação de ataque, dano, divisão e morte; reutilizar quadros quando funcionar.
- [ ] Finalizar arena 1 e efeitos de salto/impacto, se esses ataques forem escolhidos.
- [ ] Criar som distinto de divisão e transição musical de chefe.

**Concluído quando:** a divisão é compreensível sem explicação, a recompensa aparece uma vez e todas as armas do pool inicial conseguem vencer com execução adequada.

## Semana 4 — escolhas de build e economia

### Mecânicas
- [ ] Catalogar cartas existentes por função: dano direto, ricochete/área e mobilidade/sobrevivência. Usar essas funções para analisar escolhas, sem impor classes fixas.
- [ ] Revisar limites de acúmulo e interações de fragmentação; impedir cadeias infinitas e ganhos desproporcionais.
- [ ] Ajustar moedas e preços com os registros da semana 1; garantir oportunidades de compra sem tornar todas as compras automáticas.
- [ ] Revisar a oferta barata com risco versus cara/confiável descrita no GDD; indicar o risco antes de gastar.
- [ ] Ajustar penalidades malignas para manter a run jogável; confirmar limites de dano, velocidade e vida.
- [ ] Mostrar efeitos ativos e consequência da troca de arma. Adicionar carta nova apenas se faltar uma função identificada.

### Arte e áudio
- [ ] Revisar ícones das cartas e consistência visual das raridades.
- [ ] Diferenciar oferta arriscada e segura por símbolo, texto e aparência, sem depender apenas de cor.
- [ ] Refinar indicação de arma no chão, comparação e feedback de compra.

**Concluído quando:** jogadores entendem compra, risco e troca; pelo menos três combinações existentes oferecem maneiras perceptivelmente diferentes de jogar.

## Semana 5 — Cobra segmentada

### Mecânicas
- [ ] Prototipar trajetória e seguimento de segmentos antes de finalizar sprites.
- [ ] Implementar vida por segmento e divisão ao destruir o corpo antes da cabeça.
- [ ] Decidir e documentar cabeça/controle dos fragmentos, destino do corpo quando a cabeça morre e limite de cobras independentes.
- [ ] Impedir dano múltiplo injusto por sobreposição de segmentos; testar armas que acertam vários segmentos.
- [ ] Construir arena que permita prever passagem e reposicionar Alice.
- [ ] Integrar vitória apenas após o encontro inteiro terminar, usando o mesmo fluxo de artefato.

### Arte e áudio
- [ ] Produzir cabeça, corpo, cauda e leitura de direção/curva.
- [ ] Produzir estados de dano, ruptura e nova cabeça, se exigida pela regra escolhida.
- [ ] Finalizar arena 2, aviso de investida/passagem e som de ruptura.

**Concluído quando:** destruir segmentos realmente muda a luta, fragmentos permanecem legíveis e a Cobra não prende Alice sem possibilidade de reação. Se o protótipo atrasar, ampliar o sprint antes de iniciar outro chefe.

## Semana 6 — identidade da Floresta e terceiro chefe

### Mecânicas
- [ ] Implementar o conceito aprovado para o floor 3 com uma mecânica central e uma mudança de fase.
- [ ] Sugestão fora do GDD: Guardião de Raízes que marca faixas do chão, bloqueia caminhos temporariamente e abre janelas de ataque. Validar o conceito antes de produzir arte final.
- [ ] Diferenciar encontros: floor 1 ensina perseguição/tiro; floor 2 combina mobilidade e enxames; floor 3 exige controle de espaço.
- [ ] Reaproveitar aranhas e voadores existentes conforme seu comportamento real; evitar adicionar inimigos que só alterem vida/dano.
- [ ] Ajustar obstáculos e quantidade de ondas para não estender salas além do ritmo desejado.

### Arte e áudio
- [ ] Finalizar chefe 3: movimento/idle, aviso, ataque, mudança de fase, dano e morte.
- [ ] Produzir arena 3 e perigos com contraste suficiente contra chão e vegetação.
- [ ] Adicionar poucos elementos arquitetônicos que mostrem natureza confinada dentro da Estrutura.

**Concluído quando:** Floresta 1–3 tem três conclusões próprias e aumento perceptível de complexidade. Reduzir decoração antes de cortar legibilidade ou testes do chefe.

## Semana 7 — apresentação e preparação narrativa

### Mecânicas
- [ ] Inserir comportas fechadas como antecipação visual, sem implementar rotas externas ainda.
- [ ] Apresentar de forma breve que cada tentativa é uma nova Alice; reaproveitar introdução e transições existentes.
- [ ] Revisar minimapa, objetivo atual, feedback de dano e informações essenciais da build.
- [ ] Diferenciar conclusão da demonstração de vitória da campanha; não desbloquear o primeiro final ao acabar o conteúdo provisório.
- [ ] Documentar futuro save de campanha: versão do formato, Construtor derrotado, comportas liberadas e identidade da Alice Zero. Não confundir com estado temporário da run.

### Arte e áudio
- [ ] Finalizar comporta fechada com escala monumental e contraste com Alice.
- [ ] Revisar Alice/revólver inicial, contraste de inimigos e avisos de ataques.
- [ ] Aproveitar camadas existentes de elevador/ambiência para reforçar motores, metal e natureza confinada.
- [ ] Padronizar sinais visuais/sonoros de chefe, artefato e subida.

**Concluído quando:** um jogador novo entende como avançar e reconhece a Estrutura como um ambiente artificial, sem depender de exposição longa.

## Semana 8 — playtest e entrega da Floresta

### Mecânicas e validação
- [ ] Fazer sessões com 3–5 pessoas que não conhecem os sistemas; observar antes de explicar.
- [ ] Registrar mortes, duração, escolhas ignoradas, moedas sobrando e pontos de desorientação.
- [ ] Corrigir bloqueios de geração, artefatos inacessíveis, falhas de transição, recompensas duplicadas e combinações dominantes.
- [ ] Testar início/fim de run, revisita de salas, compras, troca de armas e passagem para a Caverna existente.
- [ ] Medir desempenho nos oito slimes e em builds de muitos projéteis; ajustar limites usando a máquina-alvo.
- [ ] Fechar build de teste com mudanças conhecidas e backlog ordenado para a próxima etapa.

### Arte e áudio
- [ ] Corrigir perigos pouco visíveis, animações sem antecipação e efeitos que escondem tiros.
- [ ] Revisar volume de dano, armas, chefes e ambiente em conjunto.
- [ ] Capturar imagens e vídeo curto da versão efetivamente jogável.

**Concluído quando:** Floresta 1–3 pode ser percorrida com seus três chefes sem bloqueios conhecidos, escolhas são compreendidas e os problemas restantes estão registrados. Não declarar balanceamento concluído só pelo número de testes.

## Marcos seguintes — estimar depois da Floresta

1. **Caverna 4–6 completa:** aproveitar cenário já existente; produzir três chefes, uma ameaça própria de controle de espaço e encontros distintos. Finalizar arenas e maquinário enterrado. Validar a campanha de seis andares.
2. **Cidade 7–9:** definir linguagem visual, tileset, formações/projéteis e unidades artificiais; completar chefes e arenas. Resolver antes da produção se o Construtor é o chefe do floor 9 ou um encontro adicional na Sala de Comando, pois o GDD não fecha essa relação com precisão.
3. **Primeiro final e persistência:** implementar Construtor, Sala de Comando, abertura das comportas e save permanente. Testar reinício do aplicativo e ausência do Construtor nas runs futuras. Não adicionar grind de atributos permanentes sem uma decisão de design: isso não é requisito do GDD.
4. **Pós-jogo inicial:** definir encontro com Alice Zero e comportamento ao chegar sem a arma especial; desenvolver rota da Caverna, arma que atravessa o campo e final de substituição. Salvar a nova ocupante do topo.
5. **Exterior e final Contorno:** criar regras de HUD oculto/hitkill com restauração ao sair, linguagem de contornos, inimigos próprios, rota da Cidade, Boss Contorno e dissolução de Alice. Implementar também o atalho da Floresta, com destinos válidos e regras claras ao retornar ao interior.

Comportas pós-vitória: respeitar os floors 2/3, 5/6 e 8/9 definidos no GDD. Os detalhes de sorteio e garantia das rotas precisam de especificação antes da implementação.

## Dependências e cortes de escopo

- Sistema de arena/artefato vem antes dos três chefes; protótipo de cada chefe vem antes da animação final.
- Economia depende de observar runs; não balancear apenas por comparação de números.
- Primeiro final persistente vem antes das rotas pós-vitória.
- Se faltar tempo, adiar novas armas, cartas extras, decoração e cenas longas. Preservar conclusão de andar, leitura de ataques e correção de bloqueios.
- Não assumir que Cidade, nove chefes e três finais cabem nestas oito semanas.

## Pontos do projeto para futuras tarefas

- Geração/progressão: `scripts/config/defaultRoomConfig.lua`, `scripts/managers/floorManager.lua`, `scripts/managers/roomFlowManager.lua`.
- Encontros: `scripts/managers/roomEncounterManager.lua`, `scripts/config/floorEncounterConfig.lua`, `scripts/config/encounterWaves.lua`.
- Subida de andar: `scripts/objects/elevator.lua`, `scripts/managers/gameManager.lua`.
- Cartas/economia: `scripts/cards/cardDefinitions.lua`, `scripts/managers/cardChoice.lua`, `scripts/objects/store.lua`, `scripts/drops/dropTemplates.lua`.
- Armas: `scripts/player/gun.lua`, `scripts/player/weapons/`.
- Apresentação: `scripts/config/visualThemes.lua`, `scripts/ui/`, `scripts/managers/floorIntroManager.lua`.

Referência de design: `C:/Users/guilh/Downloads/Alice_Zero_GDD_atualizado.pdf`, especialmente páginas 4–8 e 18 para o primeiro marco, e 9–15 para a expansão posterior.
