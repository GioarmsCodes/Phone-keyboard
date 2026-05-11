#!/usr/bin/env bash
# setup.sh — installer multi-distro per Phone Remote.
# Supporta: Arch/Manjaro/EndeavourOS, Debian/Ubuntu/Mint/Pop!_OS,
#           Fedora/RHEL/CentOS/Rocky/Alma, openSUSE, Alpine, Void.
# Idempotente: rieseguibile senza danni.

set -e
cd "$(dirname "$0")"

# ─── Colori ─────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_INFO=$'\033[36m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_INFO=""; C_OFF=""
fi
info() { echo "${C_INFO}── $*${C_OFF}"; }
ok()   { echo "${C_OK}✓ $*${C_OFF}"; }
warn() { echo "${C_WARN}⚠ $*${C_OFF}" >&2; }
err()  { echo "${C_ERR}✗ $*${C_OFF}" >&2; }

# ─── Pre-check ──────────────────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
  err "Non eseguire come root. Usa il tuo utente, sudo verrà chiamato dove serve."
  exit 1
fi

if ! command -v sudo &>/dev/null; then
  err "sudo non trovato. Installa sudo o esegui i comandi manualmente (vedi README)."
  exit 1
fi

# ─── Detect distro ──────────────────────────────────────────────────
if [ ! -f /etc/os-release ]; then
  err "/etc/os-release non trovato. Distro non riconosciuta."
  exit 1
fi
. /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"
info "Distro rilevata: ${PRETTY_NAME:-$DISTRO_ID}"

family() {
  case "$DISTRO_ID $DISTRO_LIKE" in
    *arch*|*manjaro*|*endeavouros*)         echo "arch" ;;
    *debian*|*ubuntu*|*linuxmint*|*pop*)    echo "debian" ;;
    *fedora*|*rhel*|*centos*|*rocky*|*alma*) echo "rhel" ;;
    *opensuse*|*suse*|*sles*)               echo "suse" ;;
    *alpine*)                                echo "alpine" ;;
    *void*)                                  echo "void" ;;
    *)                                       echo "unknown" ;;
  esac
}
FAMILY=$(family)

# ─── Install pacchetti ──────────────────────────────────────────────
info "Pacchetti (ydotool, nodejs, npm)"
case "$FAMILY" in
  arch)
    sudo pacman -S --needed --noconfirm ydotool nodejs npm
    ;;
  debian)
    sudo apt-get update
    sudo apt-get install -y ydotool nodejs npm
    ;;
  rhel)
    sudo dnf install -y ydotool nodejs npm || sudo yum install -y ydotool nodejs npm
    ;;
  suse)
    sudo zypper --non-interactive install ydotool nodejs npm
    ;;
  alpine)
    sudo apk add --no-cache ydotool nodejs npm
    ;;
  void)
    sudo xbps-install -Sy ydotool nodejs npm
    ;;
  unknown)
    warn "Distro non riconosciuta. Installa manualmente: ydotool nodejs npm"
    warn "Poi rilancia: ./setup.sh"
    read -rp "Continuo presumendo che siano installati? [y/N] " a
    [ "$a" = "y" ] || exit 1
    ;;
esac

# Verifica versione node
if command -v node &>/dev/null; then
  NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
  if [ "$NODE_MAJOR" -lt 16 ]; then
    warn "Node.js $NODE_MAJOR è troppo vecchio. Aggiorna a Node ≥ 16 (vedi nodesource.com o nvm)."
  fi
else
  err "node non installato. Aborting."
  exit 1
fi

# ─── Gruppi input/video ─────────────────────────────────────────────
info "Gruppi 'input' e 'video'"
NEED_RELOG=0
for grp in input video; do
  if ! getent group "$grp" >/dev/null; then
    sudo groupadd "$grp" || true
  fi
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx "$grp"; then
    sudo usermod -aG "$grp" "$USER"
    NEED_RELOG=1
  fi
done

# ─── /dev/uinput udev rule ──────────────────────────────────────────
info "Regola udev per /dev/uinput"
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' \
  | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo modprobe uinput || warn "modprobe uinput fallito (può essere normale: riprova dopo reboot)"

# ─── Daemon ydotoold ────────────────────────────────────────────────
YDOTOOLD_BIN=$(command -v ydotoold || echo "/usr/bin/ydotoold")
if [ ! -x "$YDOTOOLD_BIN" ]; then
  # Fedora a volte lo mette in /usr/libexec
  for p in /usr/libexec/ydotoold /usr/local/bin/ydotoold; do
    [ -x "$p" ] && YDOTOOLD_BIN=$p && break
  done
fi

if command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
  info "Systemd user service per ydotoold"
  mkdir -p ~/.config/systemd/user
  cat > ~/.config/systemd/user/ydotoold.service <<EOF
[Unit]
Description=ydotool daemon
After=default.target

[Service]
Type=simple
ExecStart=${YDOTOOLD_BIN} --socket-path=%t/.ydotool_socket --socket-own=%U:%G
Restart=on-failure

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now ydotoold || warn "ydotoold non parte. Probabilmente serve relog (gruppi)."
else
  warn "Systemd user non disponibile. Avvia ydotoold a mano nel tuo init di sessione:"
  warn "  ${YDOTOOLD_BIN} --socket-path=\$XDG_RUNTIME_DIR/.ydotool_socket --socket-own=\$(id -u):\$(id -g) &"
fi

# ─── YDOTOOL_SOCKET nell'ambiente ───────────────────────────────────
info "Variabile YDOTOOL_SOCKET nelle rc shell"
LINE='export YDOTOOL_SOCKET="$XDG_RUNTIME_DIR/.ydotool_socket"'
for rc in ~/.bashrc ~/.zshrc ~/.profile; do
  [ -f "$rc" ] && ! grep -q "YDOTOOL_SOCKET" "$rc" && echo "$LINE" >> "$rc"
done
export YDOTOOL_SOCKET="$XDG_RUNTIME_DIR/.ydotool_socket"

# ─── npm install ────────────────────────────────────────────────────
info "npm install"
npm install --silent

# ─── Firewall ───────────────────────────────────────────────────────
info "Firewall (porta 8080/tcp)"
OPENED=0
if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
  sudo firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1 && \
  sudo firewall-cmd --reload >/dev/null 2>&1 && \
  ok "firewalld: 8080/tcp aperta" && OPENED=1
fi
if [ $OPENED -eq 0 ] && command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  sudo ufw allow 8080/tcp >/dev/null 2>&1 && ok "ufw: 8080/tcp aperta" && OPENED=1
fi
if [ $OPENED -eq 0 ]; then
  warn "Nessun firewall attivo o riconosciuto: nulla da aprire. Se hai un firewall, apri 8080/tcp."
fi

# ─── Riepilogo ──────────────────────────────────────────────────────
IP=$(ip -4 addr show 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {sub("/.*","",$2); print $2; exit}')

echo
ok "Tutto pronto."
echo
if [ $NEED_RELOG -eq 1 ]; then
  warn "Prima volta? → LOGOUT + LOGIN (gruppi 'input' e 'video' appena aggiunti)."
  echo
fi
echo "  Avvio:    npm start"
echo "  Telefono: http://${IP:-<IP-PC>}:8080"
