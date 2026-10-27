# Relatório técnico — Salinha AppImage no KDE Plasma / Wayland

## Resumo

O teste inicial reportou mensagens de GPU/Vulkan e do serviço de rede Chromium. Forçar X11 e desativar a GPU ainda não confirmou a inicialização correta. O próximo passo é capturar o log completo e separar três hipóteses: backend gráfico, processo de rede Chromium e carregamento do site remoto.

## Artefato analisado

- Nome: `Salinha-x86_64.appimage`
- Versão do produto: `1.0.33`
- Arquitetura: ELF 64-bit x86-64 / AppImage
- SHA-256: `3f19a98bcd959ca4d9c5216a2b3f7a961391ddb24159e5f1685cfb88d86c7285`
- Runtime identificado no pacote: Electron `44.5.1`, Chromium `152.0.7977`
- Metadado `package.json`: `license: UNLICENSED`

## Mensagens observadas

```text
'--ozone-platform=wayland' is not compatible with Vulkan.
Consider switching to '--ozone-platform=x11' or disabling Vulkan
```

```text
Persistent cache error: 1
Network service crashed or was terminated, restarting service.
```

## Inspeção estática

1. `resources/app.asar/package.json` identifica o produto `Salinha`, versão `1.0.33`, pacote Electron e licença `UNLICENSED`.
2. `resources/app.asar/main.js` define a janela e usa `win.loadURL(APP_URL)`, onde o padrão é `https://salinha.live`. Portanto, a interface desktop depende do serviço web remoto.
3. No processo principal há `app.commandLine.appendSwitch('ozone-platform-hint', 'auto')` para Linux. A documentação do Electron explica que a seleção explícita de backend por `--ozone-platform` deve chegar na linha de comando antes da inicialização do processo.
4. `salinha.desktop` contém `Exec=AppRun --no-sandbox %U`. Isso desativa o sandbox de Chromium quando o app é aberto pelo atalho de desktop e merece revisão de segurança pelo mantenedor; não há evidência suficiente para dizer que isso causa o erro de rede observado.

## Reprodução já tentada

- Execução direta: exibiu os três erros acima.
- `--ozone-platform=x11`: o usuário interrompeu o processo com Ctrl+C; o resultado não foi confirmado como sucesso.
- `--disable-gpu`: o terminal voltou ao prompt após cerca de 1m34s e o erro de cache da GPU e a falha do serviço de rede ainda foram exibidos.

A mensagem do serviço de rede continuando com `--disable-gpu` é evidência de que o problema não deve ser tratado como exclusivamente gráfico. A mensagem de rede é uma indicação de que o serviço reiniciou, não prova isolada de falha fatal.

## Próximos passos recomendados

1. Reproduzir através de `salinha-kde-compat.sh`, que mantém log completo em `~/.local/state/salinha/` e passa logging do Chromium.
2. Comparar `salinha-network-check.sh` com o log de inicialização para testar DNS/HTTPS até `salinha.live` no mesmo sistema afetado.
3. Registrar `render-process-gone`, `did-fail-load` e eventos de falha de navegação no app, evitando depender apenas de mensagens genéricas do Chromium.
4. Testar versões atuais do AppImage e, se houver diferença no pacote, comparar com o pacote `.deb` oferecido pela página oficial para Linux.
5. Para sessões KDE/Wayland com a incompatibilidade reportada, distribuir um lançador de compatibilidade que force XWayland antes da inicialização; deixar o modo de GPU desativada como fallback diagnóstico, não como padrão.
6. Revisar a necessidade de `--no-sandbox` na entrada `.desktop` e documentar uma exceção somente se tecnicamente necessária.

## Correção local aplicada

O lançador `salinha-kde-compat.sh` foi ajustado como caminho de inicialização corrigido: em Wayland com `DISPLAY` disponível (XWayland), ele envia `--ozone-platform=x11` como argumento do AppImage, antes de iniciar o Electron, registra a sessão e os argumentos no log e informa quando Wayland está ativo sem `DISPLAY`. A GPU continua habilitada por padrão; `SALINHA_DISABLE_GPU=1` permanece como contingência diagnóstica. Foi adicionado `install-menu-launcher.sh` para criar um atalho local que sempre usa esse caminho e não força `--no-sandbox`. Isso trata o conflito gráfico reportado, mas não permite concluir que o erro do serviço de rede foi resolvido.

O instalador do atalho agora procura o AppImage ao lado do script, conforme o README. O lançador também tenta a execução normal primeiro e, se o runtime informar que não consegue montar o AppImage por falta de FUSE, extrai a imagem em uma pasta temporária e inicia o `AppRun` extraído. A pasta temporária é removida ao terminar. Nesta sessão de verificação, a extração funcionou, mas a inicialização do Chromium foi interrompida por `Operation not permitted` na camada de sandbox do executor; isso não confirma o resultado numa sessão Linux fora desse executor.

O teste DNS/HTTPS também não foi conclusivo para a rede do usuário: esta sessão de execução tem rede restrita, e `getent`/`curl` não resolveram `salinha.live`.

O binário AppImage original foi preservado, com SHA-256 `3f19a98bcd959ca4d9c5216a2b3f7a961391ddb24159e5f1685cfb88d86c7285`. Não foi possível reconstruir um AppImage incorporando o lançador: `mksquashfs` e `appimagetool` não estão disponíveis neste ambiente. Assim, para usar a correção, inicie pelo script do kit ou pelo novo atalho local, em vez do atalho embutido original. A causa da mensagem de rede permanece por determinar e requer os dados de execução no sistema afetado.

## Modelo de mensagem para o mantenedor

> No KDE Plasma sobre Wayland, o AppImage x86_64 da Salinha 1.0.33 (Electron 44.5.1 / Chromium 152.0.7977) imprime o aviso de incompatibilidade Wayland/Vulkan, o erro `gpu_persistent_cache` e `Network service crashed or was terminated, restarting service`. Forçar `--ozone-platform=x11` ainda não confirmou a abertura da janela; com `--disable-gpu`, a mensagem do serviço de rede continua. A aplicação usa `loadURL('https://salinha.live')` e tenta selecionar `ozone-platform-hint=auto` dentro do processo principal. Poderiam reproduzir em KDE Plasma/Wayland e incluir logs de backend gráfico, `render-process-gone` e falhas de carregamento da URL? O hash SHA-256 do AppImage testado é `3f19a98bcd959ca4d9c5212a6b3f7a961391ddb24159e5f1685cfb88d86c7285`.
