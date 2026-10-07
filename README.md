CUMULUS - by N1ckPA 

Cumulus é uma camada portátil de orquestração de biblioteca de jogos, criada para unificar jogos de diferentes fontes e manter biblioteca, saves e dados persistentes entre lojas, launchers e computadores em um só lugar.

Cumulus é um projeto open source que integra diferentes ferramentas e projetos independentes de código aberto, incluindo Playnite, rclone, Ludusavi e diversos addons para Playnite.
Cada projeto de terceiros permanece independente e sujeito à sua própria licença.

Siga os passos abaixo para configurar o seu Cumulus.

(O Cumulus foi feito para ser portátil. Mantenha a pasta inteira do Cumulus junta e evite mover apenas arquivos individuais para a pasta.)

1. PREPARAR A NUVEM

Para utilizar o Cumulus, será necessário um armazenamento em nuvem. 

Como base do app, usaremos o Google Drive, por suas características de duração de mercado e armazenamento sem custo com limitações.

	Outros métodos podem ser usados também, como OneDrive, Dropbox, etc... 

	Para mais informações, pesquise sobre "Ludusavi ".

1.1 MÉTODO GOOGLE DRIVE

	No Google Drive, crie uma pasta para "Cumulus" no seu local de preferência.

	Instale "Google Drive para computador" e entre na sua conta normalmente.

	Use o Google Drive no modo Streaming. Alterne para esse modo na configuração inicial ou indo em:

		Configurações > Preferências > Pastas do Google Drive > * Transferência de arquivos por streaming
	
	Acesse a unidade criada pelo Google Drive para computador (por exemplo, G:) pelo Explorador de Arquivos do seu computador, localize sua pasta "Cumulus", clique com o botão direito e:
		
		Acesso Off-line > * Disponível Off-line

	O Google Drive não precisa ficar com a janela aberta, mas o aplicativo deve estar em execução em segundo plano sempre que for usar o aplicativo, para que os arquivos da unidade virtual estejam disponíveis.

2. CONFIGURAR O RCLONE

	Usaremos o rclone para conectar as informações locais à nuvem. Essa etapa explica alternativas para o Google Drive.

	Abra a pasta

		Cumulus/Tools/rclone 

	Clique no caminho da pasta duas vezes e digite "CMD" 

	Dentro do prompt de comando, digite:

		rclone config

	Você deve entrar na configuração de um novo remote. 

	Sobre as opções dadas, digite:
		
		n

	Quando dado a opção para escolher um nome, digite:

		cumulus

	Após isso, uma grande lista abrirá com diversos serviços de armazenamento. Apesar de querermos armazenar no Google Drive, como temos acesso às pastas localmente, vamos usar:

		alias

	Localize "alias" e seu número e o insira (geralmente 3).

		Para aqueles que optarem por outros métodos de nuvem, escolha o número do seu método de preferência e siga as instruções do CMD.

	O prompt pedirá então o caminho do seu armazenamento nuvem. Como temos ele de forma local, entre na pasta "Cumulus" da unidade criada pelo Google Drive, onde criou no Google Drive, copie e cole o caminho. (como G:\Meu Drive\Cumulus)

	Rejeite configurações avançadas inserindo:

		n

	Por fim, a configuração estará automaticamente completa, pressione:

		y

	Para confirmar e:

		q

	Para sair do prompt de comando.

	Por último, para checar se essa etapa foi um sucesso, ainda dentro desse mesmo cmd, use o comando:

		rclone lsd cumulus: 
		(ou o nome que deu ao remote)

	Pode aparecer abaixo:

		0 xxxx-xx-xx xx:xx:xx        -1 Playnite
           	0 xxxx-xx-xx xx:xx:xx        -1 Saves
	
	Se aparecer ou não der nenhum erro, vá para a próxima etapa. Se não, garanta que fez a etapa anterior corretamente.
	

3. CONFIGURAR O LUDUSAVI

	Abra o arquivo "ludusavi.exe" em:

		Cumulus/Tools/Ludusavi/ludusavi.exe

	Em "Modo de Backup" e "Modo de Restauração", preencha o campo vazio com o caminho da pasta localizada em:

		SeuPC/Cumulus/Data/Game_Saves

	Após isso, abra a seção "Other", e localize a configuração "nuvem:"

	Em "Rclone", insira o caminho que leva ao seu "rclone.exe", como em: 

		SeuPC/Cumulus/Tools/rclone/rclone.exe

	Escolha no dropdown "Remoto" a opção "Personalizado"

	Em "Nome Remoto", Insira o nome do remote que criou na etapa 2, como:

		cumulus 
		(sem o : no final)

	Em "Pastas", coloque apenas:

		Saves

	Quando Executarmos o CumulusSetup, ela será criada com a sincronização com a nuvem.

	Caso já não esteja, o checkbox "Sincronizar automaticamente" deve estar ativado.

4. CRIAR ATALHO CUMULUS CONFIGURADO

	Abra o arquivo CumulusSetup.ps1 em:

		Cumulus/CumulusSetup.ps1

	Se uma linha aparecer falando sobre execução de scripts e pedindo confirmação, confirme com:
	
		y

	Após isso, deve aparecer duas opções na tela:

		1. Setup Cumulus Launcher
		2. Exit
	
	Garanta que as 3 etapas acima foram concluídas da forma correta.

	Se acredita que sim, insira 1.

	Na pasta Cumulus, deve-se criar um atalho para o Playnite, com configurações próprias do Cumulus para enviar tanto os saves dos seus jogos como sua configuração do Cumulus para uma nova instância, caso seja necessário.

	Sempre abra o aplicativo por esse atalho.

5. ERROS PREVISTOS

	Alguns jogos, principalmente mais antigos, podem não ter compatibilidade com o Ludusavi.

	Nestes casos:
	
		Abra o arquivo "ludusavi.exe" em:

		Cumulus/Tools/Ludusavi/ludusavi.exe
		
		Selecione a aba "Jogos Personalizados", e "Adicionar Jogo"

		Insira o nome do jogo EXATAMENTE como está no Playnite.

		Em caminhos, será necessário selecionar o caminho onde o jogo guarda informações, caso saiba, insira esse caminho, caso não, tente opções como:

			<winDocuments>/<Nome do Jogo>

			<winDocuments>/My Games/<Nome do Jogo>

			<winLocalAppData>/<Nome do Jogo>

			<winAppData>/<Nome do Jogo>

			<winLocalAppDataLow>/<Nome do Jogo>

			<home>/Saved Games/<Nome do Jogo>

		Para testar se acertou o caminho com as informações corretas, vá para a aba "Modo de Backup" e clique no botão "Visualizar"

		Os arquivos essenciais do jogo devem aparecer.

		Se não aparecerem, procure manualmente nas pastas acima (as que antecedem <Nome do Jogo>) pelo nome da distribuidora, empresa responsável ou abreviações. 

		Quando achar o caminho correto, insira no "Caminhos:" da aba "Jogos Personalizados" e refaça o teste acima.

Divirta-se!

O Cumulus é licenciado sob a MIT License. Componentes de terceiros incluídos no projeto estão sujeitos às suas respectivas licenças.

O Cumulus é fornecido “no estado em que se encontra”, sem garantias de qualquer tipo. O autor não se responsabiliza por perda ou corrupção de dados, uso indevido, falhas de serviços de terceiros ou problemas decorrentes de configurações incorretas.

Recomenda-se manter backups adicionais de dados importantes e revisar cuidadosamente as configurações antes de utilizar recursos de sincronização ou restauração.
