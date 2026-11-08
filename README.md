# Control Center para Omarchy

Um Centro de Controle no estilo Windows 11 para a barra do Omarchy. Os ícones de status do lado direito (rede, bluetooth, som, energia, monitor, clima, VPN e dispositivos) viram **uma pílula só**. Ao clicar nela, abre um painel com:

- **Blocos rápidos**: Ethernet/Wi-Fi, Bluetooth, VPN, Luz noturna, Não perturbe, Manter ativo e Teclado (este último fica oculto por padrão). Clicar no bloco liga/desliga; a seta **›** abre os detalhes.
- **Sliders** de brilho (do monitor onde o painel abriu) e de volume, com **›** para os painéis completos de tela e de áudio.
- **Now Playing** (MPRIS), que aparece só quando há mídia tocando.
- **Dispositivos**: Galaxy Buds, ar-condicionado Midea e fita de LED DoHome, com status e chave liga/desliga.
- **Rodapé** com CPU/RAM, ✎ (modo de edição), ⚙ (menu de setup) e ⏻ (menu do sistema).

Os detalhes **não são reimplementados**: o plugin embute os painéis reais, tanto os do Omarchy (rede, bluetooth, áudio, tela, energia, clima) quanto os dos plugins integrados. Esses painéis ficam ancorados na pílula, e o shell faz a transição entre eles como faz entre quaisquer dois painéis da mesma seção.

## Instalação

```bash
# 1. O plugin precisa morar exatamente aqui:
git clone <este-repo> ~/.config/omarchy/plugins/danluan.control-center

# 2. Integra na barra, nos atalhos e no DoHome (idempotente, com backup):
~/.config/omarchy/plugins/danluan.control-center/install.sh
```

O `install.sh`:

1. Verifica se os plugins integrados têm os ganchos necessários (veja abaixo).
2. Desativa o plugin `danluan.dohome-strip`, cujo daemon BLE passa a rodar no serviço deste plugin.
3. Põe a pílula na barra (antes do elsewhen/notificações/relógio), copia os perfis do NetExtender para a entrada `vpn` e tira da barra os widgets que o Centro de Controle absorve. Use `./install.sh --keep-widgets` para manter os widgets antigos.
4. Redireciona os atalhos **Super+Ctrl+A/B/D/N/P** (áudio, bluetooth, tela, rede, energia) em `~/.config/hypr/bindings.lua`, valida com `hyprctl configerrors` e reverte se houver erro.
5. Reinicia o shell. Isso é necessário, porque o hot-reload não registra os handlers de IPC de novo.

Para desfazer: `./uninstall.sh` devolve os widgets à barra, restaura os atalhos e reativa o DoHome.

## Atualizar depois de editar

Ao salvar arquivos em `~/.config/omarchy/plugins/`, o shell recarrega o plugin sozinho. Se você mudar algo de IPC (`Service.qml`), rode `omarchy restart shell`.

## Comandos

```bash
omarchy-shell danluan.control-center toggle          # abre/fecha no monitor em foco
omarchy-shell danluan.control-center show network    # abre direto um painel
omarchy-shell danluan.control-center flip audio      # abre ou fecha (usado nos atalhos)
# alvos: network bluetooth audio display power weather vpn buds midea strip
```

Na pílula: clique esquerdo abre o painel, clique direito abre o áudio, botão do meio silencia e a rolagem ajusta o volume.

## Configuração

O modo de edição (✎) grava na entrada do widget em `~/.config/omarchy/shell.json`:

```json
{
  "id": "danluan.control-center",
  "tiles": ["network", "bluetooth", "vpn", "nightlight", "dnd", "awake", "keyboard"],
  "hiddenTiles": ["keyboard"],
  "hiddenDevices": [],
  "vpn": { "server": "…", "username": "…", "domain": "…", "profiles": [] }
}
```

Os textos seguem o idioma do Omarchy (Setup > Language). Há catálogos em `i18n/` para `en` e `pt-BR`.

## Dependências (plugins integrados)

Um plugin do Omarchy só consegue acessar o **próprio** serviço. Por isso, cada painel embutido aceita receber do hospedeiro o que precisa. As mudanças são opcionais e não alteram o funcionamento quando o plugin roda sozinho:

| Plugin | Gancho |
|---|---|
| `local.galaxy-buds` | `property var anchorItem` (usado no `KeyboardPanel`) |
| `local.midea-ecomaster` | `property var anchorItem` (já existia) |
| `danluan.netextender` | `property var anchorItem` e `property var settingsWriter` |
| `danluan.dohome-strip` | `property var stripService` |

Plugins ausentes deixam o card correspondente vazio, sem quebrar o painel.

## Arquitetura

- `Panel.qml` é o widget da barra: a pílula, o painel e os `Loader`s invisíveis com os painéis embutidos.
- `Service.qml` existe uma única vez no shell. Ele roteia o IPC para o monitor em foco, hospeda o serviço da fita DoHome e lê/alterna luz noturna, não perturbe e manter ativo via `omarchy-shell nightlight|notifications|idle`, porque widgets não recebem esses serviços do Omarchy.
- `components/` tem os componentes visuais: bloco, slider, linha de dispositivo, card de mídia e botão redondo.
- `scripts/integrate` aplica e remove a integração no `shell.json`.
