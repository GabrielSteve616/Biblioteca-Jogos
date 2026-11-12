# Biblioteca — Jogos Android

Aplicativo Flutter/Dart seguindo a abordagem do Walken (pasta wlak), com armazenamento offline e visualizador tridimensional em Flutter Canvas, incluindo o modelo GLB fornecido para Steam, Android, PS2, PS3 e PS4. Não depende de Godot, Blender, WebView, servidor ou conta.

## Instalar e usar

O arquivo Biblioteca.apk, na raiz deste projeto, é o instalador Android. Copie para o celular, abra e autorize a instalação por essa origem quando o Android solicitar. A biblioteca começa vazia e oferece escolher uma pasta de capas na primeira abertura. Você pode pular essa etapa e usar o app imediatamente, sem conta ou login.

1. Toque em Novo jogo.
2. Preencha o título, selecione uma ou mais plataformas e escolha suas imagens.
3. Salve e toque na capa para abrir o visualizador.
4. Arraste com um dedo para girar; use dois dedos para zoom.
5. Abra a caixa e retire o disco. Toque na mídia para retirá-la, arraste para girá-la e toque novamente para guardá-la.
6. Use os controles circulares no canto para Zerado, Platina, 100% e Favorito. Os estados aparecem como adesivos nos cantos da capa. O formulário de capas não contém opções de progresso.

O menu superior também oferece Importar Excel + ZIP, com revisão em lote e seleção manual das plataformas. A opção Carregar pasta jogos usa os arquivos incluídos no APK.

O menu superior permite configurar a pasta de capas, localizar fotos novas nela e importar várias capas ou as imagens diretamente contidas em uma pasta, exportar backup e restaurar backup. A importação em lote apresenta um formulário para cada imagem; voltar interrompe o restante do lote.

## Funcionalidades

- PS1, PS2, PS3, PS4, PS5, Steam e Android; estojos gerados por geometria compartilhada, com formato quadrado para PS1 e identificação por plataforma.
- Android e Steam com a case GLB fornecida e CD com arte personalizável, retirada, devolução e giro independente. Android conserva detalhes cyberpunk na capa.
- Caixa com espessura, capa frontal, contracapa, lombada gerada, dobradiça e disco com furo central.
- Frente, verso, lombada, restauração da câmera, abertura/fechamento e retirada/devolução do disco.
- Modo Steam com arte ampliável ou caixa virtual.
- Cadastro, edição, duplicação, exclusão e reorganização manual.
- Pesquisa, cinco gêneros mais comuns, filtros de plataforma e progresso, e ordenação por título, console, gênero, data ou posição manual.
- Grade, capa frontal e estante: a visualização escolhida é lembrada; segure e arraste uma capa ou lombada para organizar. O menu de cada jogo altera suas plataformas.
- Contracapa composta localmente a partir da capa e dos dados cadastrados, sem consultar ou inventar informações.
- Persistência SQLite transacional no Android; dados JSON de versões anteriores são migrados mantendo o arquivo original.
- Imagens copiadas para armazenamento privado; limite de 1536 pixels no maior lado e miniaturas com 240 pixels de largura.
- Backup JSON único com imagens embutidas em base64, restaurável em outra instalação.

## Estrutura

| Caminho | Responsabilidade |
| --- | --- |
| lib/main.dart | Inicialização e tema Material 3 escuro |
| lib/models/game.dart | Modelo e validação do cadastro |
| lib/services/collection_store.dart | Persistência, miniaturas, importação e backups |
| lib/screens/library_screen.dart | Pesquisa, filtros, organização e importação em lote |
| lib/screens/game_editor.dart | Formulário e seleção de imagens |
| lib/screens/game_detail.dart | Detalhes, progresso e gerenciamento |
| lib/widgets/cover.dart | Capas, cores de plataformas e indicadores |
| lib/widgets/game_box_3d.dart | Geometria, projeção em perspectiva, texturas e animações |
| android/app/src/main/kotlin/br/com/acervo/acervo/MainActivity.kt | Ponte nativa para arquivos e pastas Android |
| test/widget_test.dart | Testes de armazenamento, restauração, interface e controles 3D |
| test/visual_test.dart | Capturas opcionais para inspeção visual |
| docs/*.png | Capturas da interface em testes, com coleção fictícia |

As telas são widgets Flutter. O visualizador monta uma árvore Column → GestureDetector → CustomPaint, acompanhada dos controles. O desenho usa vértices tridimensionais, projeção em perspectiva e faces com texturas subdivididas. A dobradiça transforma a tampa; o disco possui transformações próprias. Animações usam AnimationController; recursos de imagem e controladores são liberados ao sair.

## Dados e permissões

No Android, os cadastros ficam no banco SQLite privado biblioteca.db e as imagens em media/. O arquivo collection.json das versões anteriores é migrado e preservado. Os caminhos de mídia são relativos, permitindo restaurar em outro aparelho.

A ponte Kotlin usa o Storage Access Framework: ACTION_OPEN_DOCUMENT, ACTION_OPEN_DOCUMENT_TREE e ACTION_CREATE_DOCUMENT. O usuário escolhe os arquivos ou a pasta no seletor do Android. Não são solicitadas permissões amplas de armazenamento. O trabalho de leitura e cópia nativo é feito fora da thread da interface.

Para exportar o backup JSON, escolha a pasta e o nome no seletor do Android. O arquivo inclui imagens, jogos, plataformas, progresso e preferências; sua geração usa processamento em partes para limitar o uso de memória. Desinstalar o aplicativo remove sua coleção privada; o arquivo exportado permite recuperá-la. Restaurar substitui a coleção atual, após confirmação. Backups inválidos ou incompletos não substituem os dados ativos.

## Compilar e testar

Ferramentas utilizadas: Flutter 3.47.9 / Dart 3.13.7, JDK 17 e Android SDK em C:\Walkman-tools. As versões exatas dos pacotes ficam em pubspec.lock.

Na pasta do projeto, execute .\build-apk.ps1. O script resolve dependências, executa análise e testes e gera Biblioteca.apk.

Comandos individuais com C:\Walkman-tools\flutter\bin\flutter.bat:

- analyze
- test
- build apk --release

As capturas opcionais são geradas com flutter test --dart-define=CAPTURE=true. Esse teste visual usa fontes locais do ambiente Windows de desenvolvimento.

O APK desta versão usa assinatura de desenvolvimento, como o projeto Walken. Para distribuição pública, configure uma chave permanente em android/app/build.gradle.kts.

## Limites desta primeira versão

- Visualizador leve com desenho por polígonos e ordenação de profundidade. Transparência real dos estojos PS1 e materiais fotorrealistas ainda não foram implementados.
- A estante organiza capas com prateleiras; não é um ambiente 3D navegável.
- A busca da pasta de capas percorre subpastas em até oito níveis e reconhece a plataforma pelos nomes ps1, ps2, ps3, ps4, ps5, Steam e android.
- A geração de contracapa resume visualmente textos muito longos; o cadastro preserva o texto completo.
- Backups com muitas imagens podem ficar grandes; a restauração ainda carrega o JSON em memória. Não há coleta automática de imagens sem referências.
- O APK foi compilado e os testes Flutter foram executados no computador. O fluxo nativo de arquivos e o desempenho dos gestos ainda precisam de validação em celular: não havia aparelho conectado ou emulador disponível.

Para novas plataformas, acrescente o identificador em Game.platforms, a cor em platformColor e as dimensões/identificação no visualizador. Modelos e texturas continuam compartilhados entre todos os jogos.

## Configuração inicial de pastas — versão 0.2.0

Na primeira abertura o aplicativo pergunta onde estão as capas. A opção Criar pastas por plataforma começa desativada. Se ativada, a pasta escolhida recebe ps1, ps2, ps3, ps4, ps5, Steam e android. Pastas existentes são reutilizadas sem alterar seus arquivos. Se o usuário preferir, pode entrar imediatamente e escolher uma pasta depois, pelo menu.

A autorização de acesso à pasta é persistida no Android. A busca percorre subpastas (até oito níveis) e preenche a plataforma pelo nome de pasta mais próximo. Por exemplo, capas em android já recebem Android. Para fotos sem pasta reconhecida, o formulário permite escolher a plataforma.

Cada imagem é apresentada no formulário antes de salvar. Fotos já cadastradas a partir dessa pasta não são oferecidas novamente, usando o identificador de origem. A busca de novas fotos é manual no menu; não há sincronização ou login.

As preferências de primeira abertura ficam em preferences.json. A URI e a autorização da pasta ficam nas preferências nativas do Android. Essas autorizações são específicas da instalação; ao reinstalar, escolha a pasta novamente. Os backups da coleção continuam contendo as imagens próprias do app, independentemente da pasta externa.

Arquivos novos:
- lib/screens/folder_setup.dart: escolha opcional e organização de pastas.
- lib/screens/startup_gate.dart: exibe a configuração uma vez e depois abre direto na biblioteca.
- test/folder_setup_test.dart: primeira abertura, pular, cancelar, persistência, compatibilidade e ponte de arquivos.

Nas versões anteriores à 0.9, Android reutilizava o campo de imagem do disco como arte de um cartucho. Desde a versão 0.9, Android usa a case GLB com CD, preservando as imagens e o formato dos backups antigos.

## Visual — versão 0.3.0

Tema compartilhado em lib/theme/cyber_theme.dart: fundo escuro com grade estática, acentos ciano/magenta/âmbar, painéis contornados e botões com cantos recortados. O fundo usa CustomPainter isolado em RepaintBoundary e não possui animações contínuas. As capas e os dados da coleção permanecem locais; a mudança visual é compatível com as instalações anteriores.

## Embalagens interativas — versão 0.4.0

O visualizador não tem botões de abrir, retirar ou girar. Interaja com as peças:
- Toque na caixa para abrir ou na tampa aberta para fechar.
- Puxe horizontalmente a borda direita da tampa para controlar a abertura.
- Toque no disco/cartucho para retirá-lo; também é possível puxá-lo para fora.
- Arraste a mídia retirada para girar frente e verso; toque nela para recolocar.
- Arraste a caixa fora da borda de abertura para girar; use pinça para zoom.
- Dois toques no fundo restauram a posição e guardam as peças.
- As ações também estão disponíveis pela semântica de acessibilidade.

O modelo tem bandeja rebaixada, aro de encaixe, suporte central, dobradiças, travas, moldura e encarte sob presilhas. A projeção enquadra a abertura progressivamente, oculta faces traseiras e aplica iluminação e reflexos discretos. O verso do disco usa faixas de reflexão; a frente usa arte personalizada ou rótulo gerado.

A contracapa automática tem composição de embalagem antiga: título e descrição sobre a arte, faixa de detalhes recortados da capa (identificados como arte, não como capturas de jogo), bloco técnico em papel claro e identificador decorativo da coleção. Não são inventadas certificações, screenshots ou dados técnicos. Uma contracapa importada é preservada.

Os adesivos são desenhados também na textura frontal do modelo, acompanhando sua rotação. Ativar um estado não altera os demais nem reinicia a posição da caixa. Favoritos usam um selo próprio. Os estados existentes são preservados ao editar uma capa.

Arquivos adicionais: lib/widgets/package_art.dart, lib/widgets/progress_stickers.dart e test/interaction_test.dart.

## Interface por ícones — versão 0.5.0

O nome exibido no Android, na tela inicial e no seletor de backup passou a ser Biblioteca. O identificador interno Android foi preservado para atualizar a instalação existente sem apagar a coleção.

A interface prioriza ícones: adicionar, importar, filtrar, ordenar, alternar estante/grade, salvar e gerenciar. Contadores exibem ícone e número. Slogans e instruções longas foram removidos; gestos do 3D são indicados por ícones. Segure um ícone para ver sua descrição. Tooltips e rótulos de acessibilidade são preservados.

A configuração inicial resume a pasta e a organização por plataforma. No formulário, os campos opcionais ficam recolhidos em Detalhes. Dados dos jogos e confirmações de exclusão/restauração continuam explícitos.

O instalador desta versão é Biblioteca.apk.

## Embalagens e lombada — versão 0.6.0

As caixas PS3, PS4 e Steam usam perímetros curvos extrudados, tampas curvas, chanfros e papel recortado no mesmo contorno. O arredondamento pertence à geometria, não a uma máscara da interface. O estojo PS5 segue o mesmo formato compacto com faixa branca; PS2 usa formato DVD mais alto; PS1 segue o formato jewel case com tira de bandeja escura. Android conserva o cartucho e sua identidade cyberpunk.

As proporções foram separadas em lib/models/case_profile.dart:
- PS1: referência comum de estojo CD simples, 142 × 125 × 10,5 mm.
- PS2: referência DVD simples, 135 × 190 × 14 mm.
- PS3: referência compacta de 135 × 171 × 15 mm.
- PS4 e PS5: referência de 134 × 170 × 14 mm.
- Steam: embalagem virtual com proporções de DVD e cantos arredondados. Não existe uma embalagem física única da plataforma.

As medidas são referências de formatos comuns, não a promessa de reproduzir todas as edições e moldes regionais. Fontes de dimensões:
- [Vinpower Digital — materiais de embalagem](https://www.vinpowerdigital.com/products/case-package-material)
- [Workup — comparação de estojos e formatos de jogos](https://www.fukuro.in/page/834)

A lombada é uma folha impressa dedicada, estendida pela espessura completa da caixa fechada. O título é girado em uma única linha, sem quebrar letras como um parágrafo. A faixa da plataforma fica alinhada à altura da faixa frontal. As fotos de origem e os dados da coleção não são modificados.

Novos arquivos: lib/models/case_profile.dart, lib/widgets/spine_art.dart e test/case_profile_test.dart. Capturas de modelo e lombada por plataforma ficam em docs/.

## Versão 0.7.0

A caixa possui paredes laterais até a tampa, apoio sólido na lombada e abertura pelo eixo da dobradiça. A impressão usa planos subdivididos com recorte arredondado para preservar linhas retas na frente e no verso. Ao terminar um giro perto da frente ou da contracapa, o visualizador alinha a leitura se a inclinação for pequena.

Na versão 0.7, o 3D usava apenas geometria procedural em Dart/Flutter Canvas (`lib/widgets/game_box_3d.dart`), com texturas locais PNG. A versão 0.8 passou a usar o GLB fornecido nas plataformas indicadas abaixo. Os formatos são aproximações dos estojos comuns, não digitalizações de produtos.

O aplicativo funciona 100% offline, sem permissão de internet no APK de distribuição. Os dados dos jogos são preenchidos pelo usuário, e as imagens são importadas dos arquivos e pastas locais.

## Modelo do proprietário — versão 0.8.0

Steam, PS2, PS3 e PS4 agora carregam a geometria real de `modelos/case.glb` diretamente dos assets offline do APK. O arquivo original foi preservado (SHA-256: 19BCF656024807BF156B76145F397807D781A151CC7CDE0B16E3B3D94FF78E2A). As quatro peças exportadas são `Cubo` (base), `Cubo.001` (tampa), `Círculo` (CD) e `Círculo.001` (suporte central), totalizando 944 triângulos. Não foi adicionada dependência de motor, WebView ou servidor.

`lib/models/case_mesh.dart` lê o GLB 2.0 local, respeitando offsets, stride, transformações de nós e índices, conforme a [especificação Khronos glTF](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html). O leitor é voltado a este asset sem compressão, sem skins e sem animações exportadas; não é um importador genérico de qualquer modelo.

`lib/widgets/game_box_3d.dart` adapta os eixos, proporções e cores por plataforma. Base e tampa usam os vértices do GLB; a tampa gira na dobradiça e a malha do CD se desloca e gira independentemente. O disco foi reposicionado para o interior, com diâmetro e furo central ajustados. Superfícies internas, acabamento da dobradiça e superfícies contínuas de impressão completam a malha: capa/contracapa/lombada e rótulo vêm do cadastro local. A impressão do CD é desenhada em lote para eliminar emendas entre triângulos.

Na versão 0.8, PS1, PS5 e Android mantinham seus modelos procedurais anteriores; desde a 0.9, Android também usa a case GLB com CD. A estante, adesivos e dados existentes continuam funcionando. O identificador e a assinatura do app foram mantidos para permitir atualização.

Validação: 25 testes automatizados, incluindo leitura do GLB real, transformações, buffers com offsets, rejeição de contêiner truncado, seleção da geometria correta nas sete plataformas e abertura/retirada/giro/devolução/fechamento pelo toque. Capturas visuais estão em `docs/modelo-*.png`, `docs/caixa-aberta.png` e `docs/disco.png`. Não foi possível testar em aparelho físico sem dispositivo conectado.

## Versão 0.9.0

Android passa a usar a mesma case GLB com CD de Steam, com proporções de estojo DVD virtual (135 × 190 × 14 mm) e identidade de cor própria. O modelo de cartucho foi substituído. O campo de imagem da mídia agora se chama Disco em todas as plataformas; imagens e backups antigos continuam válidos, e a arte anteriormente usada no cartucho é aplicada ao CD. Steam continua usando o mesmo GLB. O app permanece 100% offline.

## Case revisada — versão 0.10.0

Atualizado o asset `modelos/case.glb` com a revisão do proprietário, de 68.612 bytes e 1.236 triângulos, mantendo base, tampa, CD e suporte independentes. SHA-256 da revisão: 98A0B54823D27C06106CE8B91E3B5C0298963360968354FA964B0D27C572ECD6. O arquivo fornecido não foi alterado.

O encaixe agora calcula os limites reais da case e das peças, em vez de usar as medidas fixas da primeira exportação. A normalização mantém as proporções de cada plataforma e o alinhamento das superfícies de impressão, da dobradiça, do CD e do suporte com a malha revisada. Os nomes e eixos das quatro peças continuam seguindo o modelo fornecido. Aplicado a Steam, Android, PS2, PS3 e PS4.

## Bordas fechadas — versão 0.11.0

Corrigida a sobreposição das superfícies internas nas paredes externas durante o giro da case GLB. Com a tampa fechada, os painéis internos, o CD e o suporte deixam de participar do desenho; as faces sólidas da malha usam sua orientação externa para eliminar a aparência de fendas. Ao abrir, o interior e a mídia voltam a ser desenhados. O GLB original não foi alterado.

A conferência visual cobre as laterais direita/esquerda, topo, base e diagonal. Testes verificam a ausência de bordas abertas nas duas metades do GLB e a cor da parede externa nas regiões em que o interior escuro aparecia.

## Importação Excel + ZIP — versão 0.12.0

A pasta `jogos/` contém `Catalogo_de_254_jogos.xlsx` e `Imagens_dos_jogos_renomeadas.zip`. Os originais são somente lidos. Não é preciso editar a planilha, descompactar o ZIP ou organizar subpastas por plataforma.

1. Abra o menu ⋮ e escolha **Importar Excel + ZIP**.
2. Use **Carregar pasta jogos** para os arquivos atuais deste projeto. Também é possível escolher Excel e ZIP pelo seletor do Android, ou escolher uma pasta no celular que contenha uma planilha e um ZIP.
3. Confira a lista de jogos e capas. Toque na plataforma de uma linha para marcar uma ou várias opções. Todas começam em **Sem plataforma definida**, independentemente dos nomes das pastas ou de qualquer plataforma mencionada na planilha.
4. Marque os jogos pelas caixas de seleção ou selecione todos os visíveis; use **Atribuir plataforma aos selecionados**. Essa ação substitui a seleção anterior pelo conjunto escolhido, inclusive um conjunto vazio. A busca permite aplicar a organização apenas aos resultados visíveis.
5. Toque na capa para corrigir o vínculo usando as imagens do ZIP ou uma imagem local. O menu da linha permite conferir os dados e remover um jogo do lote.
6. Marque as caixas dos jogos desejados e toque em **Importar selecionados**, ou toque em **Importar todos** para importar todos os jogos ainda disponíveis no catálogo. Jogos sem plataforma ficam na categoria **Sem plataforma definida**. Sair da revisão sem iniciar a importação não cadastra o lote.
7. Na biblioteca, segure a capa ou a lombada para alterar as plataformas. A tela Editar também permite isso.

O mesmo jogo aparece em cada coleção selecionada e permanece um único cadastro, com imagens, dados e progresso compartilhados. A biblioteca geral conta esse jogo uma vez. O visualizador permite escolher a case das plataformas atribuídas. PS5 foi preservado junto às seis opções solicitadas para manter a funcionalidade existente. Backups e cadastros antigos continuam sendo lidos; backups novos incluem as plataformas adicionais.

Leitura local de `.xlsx`: encontra o cabeçalho mesmo depois de um título/resumo e lê células esparsas, textos compartilhados, textos diretos e resultados de fórmulas já salvos pelo Excel. Importa nome, descrição, gênero, ano, classificação e jogadores; não calcula fórmulas nem abre links da planilha. O formato antigo `.xls` não é suportado por este importador.

A vinculação prioriza a coluna de imagem, quando disponível, e depois o nome do jogo, ignorando diferenças de caixa, acentos e pontuação. Vínculos ambíguos ficam sem capa para decisão manual. Nenhum título repetido é fundido automaticamente. A importação acrescenta os jogos após a revisão e não substitui a coleção atual. Os dados são gravados em lote depois de preparar as imagens.

As imagens ZIP são extraídas para nomes internos, sem usar os caminhos do arquivo como destino. A leitura roda em isolate e limita quantidade e tamanho dos arquivos. As capas usam a mesma normalização e as miniaturas já existentes no projeto. Dependências: [archive](https://pub.dev/packages/archive) e [xml](https://pub.dev/packages/xml), com versões fixadas em `pubspec.lock`. O app continua sem permissão de internet.

**Atualizar os arquivos:** a pasta `jogos/` é incluída no APK durante a compilação. Trocar os arquivos no computador não altera um APK já instalado. Nesse caso, gere outro APK ou transfira os arquivos para o celular e use o seletor. Se houver mais de uma planilha ou mais de um ZIP, selecione manualmente o par desejado.

Validação dos arquivos fornecidos: 254 linhas, 254 capas vinculadas, todos os seis campos preenchidos e nenhuma plataforma automática. O relatório está em `docs/import-validation.json`. Foi testada também a conversão das 254 imagens para o armazenamento da biblioteca e o salvamento único do lote preservando jogos existentes. Capturas da revisão: `docs/importacao-revisao.png`, `docs/importacao-plataformas.png` e `docs/importacao-lote.png`.

## Seleção e segundo plano — versão 0.13.0

Na revisão, marque apenas os jogos desejados e use **Importar selecionados**. Use **Importar todos** para os jogos disponíveis no catálogo inteiro, inclusive os que estiverem fora do filtro de busca. A caixa superior seleciona apenas os jogos visíveis. Jogos já identificados na biblioteca são sinalizados e ficam fora de novas importações. As plataformas continuam sendo escolhidas manualmente, individualmente ou em lote.

Ao iniciar a importação, a tela retorna para a biblioteca, onde o progresso permanece visível. O Android executa um serviço em primeiro plano para manter o processamento quando o app vai para segundo plano. Há uma notificação de progresso; no Android 13 ou superior, ela aparece na área de notificações se a permissão for concedida. A negação da permissão não impede o serviço.

O andamento é salvo em armazenamento privado após cada jogo. Se o Android encerrar o processo ou o mecanismo do aplicativo, a tarefa interrompida é retomada ao abrir a Biblioteca novamente. Caso uma imagem falhe, a biblioteca mostra as opções de retomar ou cancelar. Não há comunicação de rede. As permissões adicionadas são as do serviço de importação, prevenção temporária de suspensão e notificações. Referência: [serviços em primeiro plano no Android](https://developer.android.com/develop/background-work/services/fgs) e [permissão de notificação](https://developer.android.com/develop/ui/compose/notifications/notification-permission).

O lote só é adicionado à coleção quando todas as capas escolhidas tiverem sido preparadas; os jogos já existentes são preservados. Ao retomar depois de um salvamento concluído, os identificadores impedem que os mesmos jogos sejam adicionados duas vezes. O app identifica os itens da mesma planilha por um identificador estável. Cadastros de planilhas anteriores também são reconhecidos quando os dados importados continuam correspondendo; se esses dados foram alterados, confira a revisão antes de importar novamente.
