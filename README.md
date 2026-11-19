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

App de Mac da **Impera Services** para trabalhar em várias tarefas em rodízio, com timer por tarefa.

## Como funciona

- **Rodadas com timer:** a tarefa do topo da fila é a atual. Cada rodada tem 10 minutos por padrão (dá pra mudar por tarefa).
- **Você decide quando trocar:** quando o tempo acaba, o alarme toca, aparece uma notificação e o timer para em 00:00. Aí é com você: **Próxima tarefa** ou **+5 min**.
- **Fazer agora:** o botão ▶ de qualquer tarefa da fila pula direto pra ela.
- **Editar durante a execução:** título, duração da rodada, tempo restante e anotações, tudo com o timer rodando.
- **Anotações com horário:** cada tarefa tem um diário de anotações. Ao trocar de tarefa, o app pergunta "onde você parou?".
- **Aviso de 1 minuto** antes do fim da rodada.
- **Concluir e arquivar:** concluídas vão pro **Histórico** com o tempo total gasto (todas as rodadas somadas); arquivadas ficam guardadas pra depois.
- **Barra de menus:** o tempo restante fica sempre visível lá em cima. Fechar a janela não para o timer.
- **Atualização automática:** em Configurações (⚙ ou ⌘,), **Buscar atualização** baixa e instala a versão nova do GitHub.
- **Salva sozinho** em `~/Library/Application Support/Multitarefa/`.

### Atalhos

| Atalho | Ação |
|---|---|
| ⌘ ↩ | Iniciar ou pausar |
| ⌘ → | Próxima tarefa |
| ⌘ D | Concluir a tarefa atual |
| ⌘ E | Editar a tarefa atual |
| ⌘ , | Configurações |

## Instalar

1. Clique no botão **Baixar para macOS** no topo desta página (ou [baixe aqui](https://github.com/Tamiozzo22/Multitarefa/releases/download/latest/Multitarefa.dmg)).
2. Abra o `Multitarefa.dmg` e, na janela que aparecer, arraste o **Multitarefa** para o atalho **Aplicativos**. Depois pode ejetar o disco.
3. Na primeira vez, o macOS bloqueia porque o app não é de um desenvolvedor registrado na Apple. Vá em **Ajustes do Sistema → Privacidade e Segurança**, desça até o fim e clique em **Abrir Mesmo Assim**. Só precisa fazer isso uma vez.
4. Permita as notificações quando o app pedir.

## Como o app é compilado

Toda vez que o código muda na branch `main`, o GitHub Actions compila o app num Mac da nuvem (`scripts/build-app.sh`) e publica o DMG em **Releases → latest**. Dá pra acompanhar na aba **Actions**.

A duração padrão das rodadas fica em `defaultDuration`, em `Sources/Multitarefa/TaskStore.swift`. A versão do app é o conteúdo do arquivo `VERSION` mais o número do build.
