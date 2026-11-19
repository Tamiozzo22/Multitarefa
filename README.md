<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Ícone do Multitarefa">
</p>

<h1 align="center">Multitarefa</h1>

<p align="center">
  <a href="https://github.com/Tamiozzo22/Multitarefa/releases/download/latest/Multitarefa.dmg">
    <img src="Resources/download-button.svg" width="420" alt="Baixar para Mac">
  </a>
</p>

<p align="center">macOS 14 ou mais novo · Liquid Glass no macOS 26+ · Apple Silicon e Intel</p>

Aplicativo para macOS da **Impera Services** que organiza o trabalho em várias tarefas por meio de rodadas cronometradas.

## Funcionalidades

- **Rodadas cronometradas:** a tarefa no topo da fila é a tarefa atual. Cada rodada dura 10 minutos por padrão, e a duração pode ser alterada individualmente.
- **Troca manual:** ao fim do tempo, o alarme toca, uma notificação é exibida e o cronômetro para em 00:00. A troca de tarefa ocorre somente quando você a solicita.
- **Alarme persistente:** se nenhuma ação for realizada no aplicativo em até 5 segundos após o alarme, ele toca novamente, até que você interaja com o aplicativo.
- **Registro de onde parou:** antes de trocar de tarefa, o aplicativo solicita uma anotação sobre o ponto em que você parou.
- **Iniciar agora:** o botão ▶ de qualquer tarefa da fila permite passar diretamente para ela.
- **Edição durante a execução:** título, duração da rodada, tempo restante, tags e anotações podem ser alterados com o cronômetro em andamento.
- **Anotações com data e hora:** cada tarefa possui um histórico próprio de anotações.
- **Aviso de 1 minuto** antes do fim de cada rodada.
- **Concluídas e arquivadas:** as tarefas concluídas vão para o **Histórico**, com o tempo total dedicado a cada uma; as arquivadas ficam guardadas para uso posterior.
- **Tags:** crie tags com cores, classifique as tarefas e encontre-as rapidamente pela tela de Tags, com busca por título ou anotação.
- **Lixeira:** as tarefas excluídas permanecem na Lixeira por 5 dias e podem ser recuperadas nesse período. Depois disso, são excluídas definitivamente.
- **Barra de menus:** o tempo restante permanece visível na barra de menus. Fechar a janela não interrompe o cronômetro.
- **Atualização automática:** em Configurações (⚙ ou ⌘,), o botão **Buscar atualização** baixa e instala a versão mais recente publicada no GitHub.
- **Salvamento automático** em `~/Library/Application Support/Multitarefa/`.

### Atalhos de teclado

| Atalho | Ação |
|---|---|
| ⌘ ↩ | Iniciar ou pausar |
| ⌘ → | Próxima tarefa |
| ⌘ D | Concluir a tarefa atual |
| ⌘ E | Editar a tarefa atual |
| ⌘ . | Silenciar o alarme |
| ⌘ , | Configurações |

## Instalação

1. Clique no botão **Baixar para Mac** no topo desta página (ou [faça o download aqui](https://github.com/Tamiozzo22/Multitarefa/releases/download/latest/Multitarefa.dmg)).
2. Abra o arquivo `Multitarefa.dmg` e, na janela exibida, arraste o **Multitarefa** para o atalho **Aplicativos**. Em seguida, ejete o disco.
3. Na primeira execução, o macOS bloqueia o aplicativo por não ser de um desenvolvedor registrado na Apple. Acesse **Ajustes do Sistema → Privacidade e Segurança**, role até o final e clique em **Abrir Mesmo Assim**. Esse procedimento é necessário apenas uma vez.
4. Autorize as notificações quando solicitado.

## Compilação

Sempre que o código é alterado na branch `main`, o GitHub Actions compila o aplicativo em um Mac na nuvem (`scripts/build-app.sh`) e publica o DMG em **Releases → latest**. O andamento pode ser acompanhado na aba **Actions**.

A duração padrão das rodadas é definida em `defaultDuration`, no arquivo `Sources/Multitarefa/TaskStore.swift`. A versão do aplicativo é composta pelo conteúdo do arquivo `VERSION` seguido do número da compilação.
