# Salinha Linux Compatibility Kit

Lançador comunitário para o AppImage Linux da Salinha, com ajustes para sessões KDE Plasma/Wayland e diagnóstico básico de conexão.

Este repositório contém somente scripts e documentação. **O AppImage não é distribuído aqui.** Baixe a versão para Linux pelo [site oficial da Salinha](https://salinha.live/) e coloque `Salinha-x86_64.appimage` junto de `salinha-kde-compat.sh`.

## Iniciar

```bash
chmod +x salinha-kde-compat.sh
./salinha-kde-compat.sh
```

No KDE/Wayland, o lançador usa XWayland quando `DISPLAY` está disponível e desativa Vulkan para evitar o conflito relatado nessa versão do pacote. Se o AppImage não conseguir montar por falta de FUSE, o lançador extrai o conteúdo em uma pasta temporária, executa o `AppRun` e remove a pasta ao encerrar.

Para usar outro caminho para o AppImage:

```bash
SALINHA_APPIMAGE="$HOME/Downloads/Salinha-x86_64.appimage" ./salinha-kde-compat.sh
```

Para instalar um atalho de menu somente para o usuário atual:

```bash
./install-menu-launcher.sh
```

## Diagnóstico

```bash
./salinha-network-check.sh
```

O teste verifica DNS e HTTPS para `salinha.live`. Os logs do lançador ficam em `${XDG_STATE_HOME:-$HOME/.local/state}/salinha/` e permanecem na máquina local.

Opções úteis:

- `SALINHA_BACKEND=x11` ou `SALINHA_BACKEND=wayland` escolhe explicitamente o backend gráfico.
- `SALINHA_DISABLE_GPU=1` desativa a GPU como diagnóstico.
- `SALINHA_ENABLE_VULKAN=1` reativa Vulkan.
- `SALINHA_VERBOSE=1` habilita logging detalhado do Chromium.

Leia [RELATORIO-TECNICO.md](RELATORIO-TECNICO.md) para as observações, limitações e resultados de reprodução disponíveis.

## Escopo e marcas

Este é um kit de compatibilidade mantido pela comunidade; não é o aplicativo oficial nem uma versão modificada do AppImage. Não inclui executáveis, bibliotecas, ícones ou código interno da Salinha. Salinha e suas marcas pertencem à Fystec. O aplicativo deve ser obtido pelos canais oficiais e continua sujeito aos [termos de uso](https://salinha.live/termos) e à [política de privacidade](https://salinha.live/privacidade).

## Licença

A licença MIT deste repositório cobre somente os scripts e a documentação do kit. Ela não licencia o aplicativo Salinha, suas marcas ou seus serviços.
