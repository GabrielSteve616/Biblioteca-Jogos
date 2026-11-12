# Textos para as versões no GitHub

Cada seção abaixo pode ser usada como descrição da release correspondente. Os textos estão em primeira pessoa, começando pela versão mais recente.

## v0.13.3 — Atualizei o catálogo

Atualizei a planilha e o ZIP com 279 jogos, incluindo cinco títulos novos e descrições revisadas. Mantive o reconhecimento dos jogos já importados para preservar minha biblioteca.

## v0.13.2 — Backup e ícone atualizado

Revisei o backup para escolher a pasta e o nome do arquivo JSON ao exportar. Ajustei a geração para usar menos memória e preservei a biblioteca se o backup estiver incompleto.

Também atualizei a arte do ícone e adaptei o enquadramento para celulares Android, incluindo Samsung.

## v0.13.1 — Novo ícone

Atualizei o ícone do aplicativo usando a imagem de catálogo gamer azul que criei.

## v0.13.0 — Biblioteca organizada e importação em segundo plano

Agora posso escolher quais jogos da pasta jogos quero importar ou trazer todos de uma vez. Também fiz a importação continuar em segundo plano para poder usar a biblioteca enquanto as capas são preparadas.

- Adicionei as opções Importar selecionados e Importar todos.
- Mostro quais jogos já foram identificados na biblioteca para evitar repetição.
- Coloquei o progresso na biblioteca e em uma notificação do Android, quando permitida.
- Salvo o andamento para retomar ao abrir o aplicativo se a tarefa for interrompida.
- Passei a usar SQLite no Android, migrando os dados existentes sem apagar o arquivo anterior.
- Salvo o backup JSON com capas em Downloads e permito restaurar a biblioteca.
- Acrescentei cinco gêneros mais comuns e filtros de jogos platinados ou fechados.
- Organizo por console, gênero ou alfabeto e arrasto capas e lombadas para definir a ordem.
- Salvo a visualização escolhida entre grade, estante e capa frontal.
- Extraio do ZIP somente as capas dos jogos selecionados.
- Mantive a escolha manual de plataformas e o funcionamento offline.

## v0.12.0 — Importação de jogos com escolha de plataformas

Adicionei a importação da planilha Excel junto com o ZIP das capas, sem precisar separar as imagens em pastas por plataforma.

- Fiz a leitura dos nomes, descrições, gêneros, anos, classificações e números de jogadores.
- Vinculei as capas pelo nome da imagem ou do jogo e adicionei uma revisão antes de salvar.
- Deixei as plataformas em branco para escolher manualmente, por jogo ou em lote.
- Permiti marcar várias plataformas no mesmo cadastro e criar jogos sem plataforma definida.
- Adicionei a alteração de plataformas ao segurar a capa ou a lombada na biblioteca.
- Deixei a pasta jogos pronta e incluí os arquivos atuais no APK como opção de carregamento.
- Testei o catálogo de 254 jogos e suas 254 capas, preservando a coleção existente.

O aplicativo continua 100% offline e mantém as cases 3D, os adesivos e os backups.

## v0.11.0 — Corrigi as bordas da case

Corrigi o problema que fazia as bordas parecerem abertas quando eu olhava a case pelos lados, por cima ou por baixo. As partes internas estavam aparecendo por cima das paredes externas mesmo com a tampa fechada.

- Ajustei o desenho das faces para manter a case fechada como no modelo GLB.
- Mantive a abertura pelo toque e o CD removível.
- Conferi as laterais, o topo, a base e a visão diagonal.
- Mantive o modelo original e o funcionamento 100% offline.

## v0.10.0 — Atualizei o modelo da case

Nessa atualização, coloquei no aplicativo a nova versão da case 3D que fiz. Ajustei o encaixe das capas e das peças para acompanhar as mudanças no modelo.

- Atualizei a case usada no Steam, Android, PS2, PS3 e PS4.
- Fiz o encaixe considerar o tamanho real das peças do arquivo GLB.
- Mantive a abertura da tampa e a retirada, o giro e a devolução do CD pelo toque.
- Conferi as prévias e os 25 testes automatizados passaram.

O aplicativo continua 100% offline, sem login, com os dados e as imagens salvos localmente.

**Instalador:** `Biblioteca.apk`.

## v0.9.0 — Mesma case para Android e Steam

Coloquei no Android a mesma case com CD que já estava usando no Steam. Substituí o cartucho antigo, mantendo os detalhes cyberpunk na capa do Android.

- Passei a usar o modelo GLB também nos jogos Android.
- Padronizei o campo da imagem da mídia como Disco.
- Mantive as imagens, os cadastros e os backups existentes.

## v0.8.0 — Meu modelo 3D dentro do aplicativo

Integrei a case que fiz em GLB para usar nos jogos de Steam, PS2, PS3 e PS4. O modelo tem a base, a tampa, o CD e o suporte separados, permitindo movimentar cada parte.

- Apliquei as capas, a contracapa, a lombada e a arte do CD cadastradas no aplicativo.
- Ajustei as cores e as proporções de cada plataforma.
- Melhorei o acabamento interno e a dobradiça.
- Corrigi as emendas que apareciam entre os triângulos das texturas.
- Mantive tudo funcionando offline.

## v0.7.0 — Melhorias na case e nova estante

Melhorei a junção entre a base e a tampa para tirar o vão que deixava a case com aparência aberta. Também ajustei a contracapa e adicionei uma visualização parecida com uma estante de livros.

- Corrigi as laterais, o apoio da lombada e o eixo de abertura.
- Melhorei o alinhamento da contracapa ao girar o modelo.
- Adicionei prateleiras com lombadas clicáveis e rolagem para ver a coleção.
- Mantive o cadastro manual e a importação de imagens locais.

## v0.6.0 — Cases com formato mais próximo das reais

Ajustei os modelos para ficarem mais parecidos com capinhas de verdade, com proporções diferentes para cada plataforma e bordas arredondadas.

- Arredondei os cantos das cases de PS3, PS4, PS5 e Steam.
- Ajustei a largura, a altura e a espessura dos formatos de CD e DVD.
- Melhorei a lombada, com o título na vertical e a faixa da plataforma alinhada à frente.
- Ajustei as molduras, o encaixe da capa e as dobradiças.

## v0.5.0 — Biblioteca com menos texto e mais ícones

Troquei o nome exibido para Biblioteca e deixei a interface mais direta, usando mais ícones e menos texto nas ações.

- Simplifiquei a busca, os filtros, a ordenação e os contadores.
- Deixei os campos opcionais do cadastro recolhidos em Detalhes.
- Mantive as descrições dos ícones ao segurar e os recursos de acessibilidade.
- Passei a usar o nome `Biblioteca.apk` no instalador.

## v0.4.0 — Interação pelo toque e adesivos na capa

Mudei a interação do 3D para abrir a case e movimentar a mídia diretamente pelo toque e pelo arraste. Também separei o cadastro da capa dos controles de progresso.

- Tirei as opções de progresso do formulário de capas.
- Coloquei controles circulares no canto para Zerado, Platina, 100% e Favorito.
- Fiz os estados aparecerem como adesivos nos cantos das capas.
- Melhorei o interior das cases e a composição das contracapas, inspirada nas embalagens antigas.
- Mantive a posição do 3D ao mudar os adesivos e preservei o progresso ao editar o cadastro.

## v0.3.0 — Visual cyberpunk

Dei ao aplicativo um visual cyberpunk mais discreto, com fundo escuro e detalhes em ciano, magenta e âmbar.

- Adicionei uma grade no fundo e iluminação suave.
- Ajustei os painéis, as molduras das capas e os botões.
- Mantive o contraste e a leitura, sem efeitos piscando na tela.

## v0.2.0 — Organização das capas em pastas

Adicionei a opção de escolher uma pasta de capas na primeira abertura, sem precisar criar conta ou fazer login.

- Coloquei a opção de criar as pastas ps1, ps2, ps3, ps4, ps5, Steam e android.
- Fiz a leitura das subpastas reconhecer a plataforma pelo nome da pasta.
- Evitei que imagens de origem já cadastradas fossem importadas novamente.
- Adicionei PS2, PS5 e Android ao cadastro, aos filtros e aos backups.
- Nessa versão, criei a case com cartucho cyberpunk para Android, que depois foi substituída pela case com CD na versão 0.9.0.

Mantive a compatibilidade com os cadastros e os backups anteriores.
