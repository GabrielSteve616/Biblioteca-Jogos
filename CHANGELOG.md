## 0.13.3+16

- Catálogo atualizado para 279 jogos e 279 capas, com descrições revisadas.
- Reconhecimento de jogos já importados mesmo quando a descrição mudou, preservando os cadastros existentes.

## 0.13.2+15

- Exportação do backup com escolha de pasta e nome no seletor Android.
- Geração do JSON em partes e limpeza dos arquivos temporários.
- Restauração valida imagens e preserva os dados existentes em caso de erro.
- Nova arte com ícone adaptável para os formatos usados pelos celulares Android.

## 0.13.1+14

- Ícone do aplicativo atualizado com a imagem fornecida.

## 0.13.0+13

- Banco SQLite no Android com migração dos dados anteriores preservados.
- Backup JSON com imagens em Downloads e restauração no aplicativo.
- Cinco filtros de gênero, progresso, ordenação e arrastar capas ou lombadas.
- Visualização de grade, estante ou capa frontal persistente.
- Pré-visualização sem extração em disco; somente capas selecionadas são extraídas do ZIP.

- Seleção individual e importação dos jogos marcados ou de todos os jogos disponíveis.
- Jogos já identificados na biblioteca são sinalizados e não são importados novamente.
- Importação em segundo plano com progresso na biblioteca e notificação Android.
- Registro de progresso para retomar ao reabrir caso o processo seja interrompido.
- Lote salvo atomicamente, com prevenção de duplicatas após uma interrupção.

## 0.12.0+12

- Importação local de Excel .xlsx e ZIP com vinculação automática das capas.
- Revisão antes de salvar, busca, escolha de imagem e seleção de jogos em lote.
- Plataformas sempre vazias no novo importador, com opção de atribuir uma ou várias manualmente.
- Categoria Sem plataforma definida e filtros compatíveis com múltiplas coleções.
- Alteração de plataformas ao segurar a capa/lombada ou pelo editor.
- Visualização da case de cada plataforma atribuída, com um único cadastro e progresso compartilhado.
- Arquivos da pasta jogos disponíveis no APK, além de seletores de arquivos/pasta no celular.
- Compatibilidade com dados, imagens e backups existentes; funcionamento 100% offline.

## 0.11.0+11

- Corrigida a aparência de bordas abertas nas laterais, topo e base da case GLB.
- Superfícies internas deixam de sobrepor as paredes quando a tampa está fechada.
- Orientação das faces sólidas respeitada, com interior e CD disponíveis ao abrir.
- Adicionadas verificações das bordas da malha e capturas de cinco ângulos.

## 0.10.0+10

- Case GLB atualizada com a revisão do proprietário (1.236 triângulos).
- Encaixe das peças calculado pelos limites reais da malha.
- Preservados capas locais, abertura, CD removível e funcionamento offline.

## 0.9.0+9

- Android passa a usar a mesma case GLB com CD utilizada no Steam.
- Removida a geometria antiga de cartucho; campo da mídia padronizado como Disco.
- Imagens e dados antigos preservados.

## 0.8.0+8

- GLB do proprietário integrado a Steam, PS2, PS3 e PS4, com arquivo original preservado.
- Base, tampa, CD e suporte lidos da malha real; movimentos por toque e cores/proporções por plataforma.
- Superfícies contínuas de impressão e lote de rótulo do CD para evitar emendas.
- Acabamento interno e dobradiça; reposicionamento e ajuste do CD para caber no estojo.
- 25 testes automatizados. App continua 100% offline.

## 0.7.0+7

- Laterais com espessura contínua, apoio da lombada e eixo da tampa corrigidos.
- Contracapa com mapeamento plano subdividido e alinhamento de leitura após o giro.
- Estante de lombadas clicáveis com prateleiras contínuas e rolagem.
- Versão 100% offline, com cadastro manual e importação de imagens locais.

# 0.6.0
- Geometria com cantos e bordas curvas em PS3, PS4, PS5 e Steam.
- Proporções e espessuras por formato físico, incluindo CD e DVD.
- Lombada de altura completa, título girado em linha única e faixa alinhada à frente.
- Molduras arredondadas, papel ajustado ao contorno e dobradiças diferenciadas.
- PS5 com faixa branca e PS1 com bandeja escura lateral.
- Câmera inicial mostra a lombada; gestos e adesivos continuam integrados.

# 0.5.0
- Nome exibido alterado para Biblioteca.
- Interface com menos texto e ações por ícones, com tooltips e acessibilidade.
- Busca, filtros, ordenação, contadores e primeira abertura mais compactos.
- Dados opcionais do cadastro recolhidos em Detalhes.
- Instruções do 3D substituídas por indicadores de gestos.
- Instalador Biblioteca.apk; atualização mantém o identificador e os dados existentes.

# 0.4.0
- Progresso removido do formulário de capas; controles circulares no canto do visualizador.
- Adesivos independentes nos cantos das capas da biblioteca e do modelo 3D.
- Caixa e mídia manipuladas diretamente por toque e arraste, sem botões de operação 3D.
- Modelos com bandeja, aro, suporte, molduras, dobradiças, travas e encarte interno.
- Contracapas automáticas com composição inspirada nas embalagens antigas.
- Rótulos de disco, verso reflexivo, culling e enquadramento progressivo.
- Edição preserva progresso; mudanças de estado preservam a pose 3D.

# 0.3.0
- Identidade visual cyberpunk discreta em todas as telas.
- Paleta ciano, magenta e âmbar, fundo com grade e iluminação suave.
- Painéis com bordas coloridas, capas emolduradas e botões com cantos recortados.
- Hierarquia tipográfica e contraste preservados, sem efeitos piscantes.

# 0.2.0
- Configuração opcional de pasta na primeira abertura, sem login.
- Criação opcional de ps1, ps2, ps3, ps4, ps5, Steam e android.
- Acesso persistente à pasta, busca em subpastas e inferência da plataforma.
- Nova busca ignora imagens de origem já cadastradas.
- PS2, PS5 e Android adicionados ao modelo, formulário, filtros e backups.
- Case e cartucho Android com identidade cyberpunk, contatos dourados e giro independente.
- Compatibilidade com cadastros e backups 0.1.0.




