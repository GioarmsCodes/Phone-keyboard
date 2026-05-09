#!/usr/bin/env bash
# setup.sh — fa tutto: pacchetti, permessi, daemon, npm install, firewall.
# Idempotente: rieseguibile senza danni.
set -e
cd "$(dirname "$0")"

if [ "$EUID" -eq 0 ]; then
  echo "Non eseguire come root. Usa il tuo utente, sudo verrà chiamato dove serve." >&2
  exit 1
fi

if ! command -v pacman &>/dev/null; then
  echo "Questo script è pensato per Arch/Manjaro. Su altre distro vedi il README." >&2
  exit 1
fi

echo "── pacchetti ──"
sudo pacman -S --needed --noconfirm \
  ydotool playerctl wireplumber brightnessctl nodejs npm

echo "── gruppi (input, video) ──"
sudo usermod -aG input,video "$USER"

echo "── udev rule per /dev/uinput ──"
echo 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"' \
  | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
sudo udevadm control --reload-rules
sudo modprobe uinput

echo "── systemd user service per ydotoold ──"
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/ydotoold.service <<'EOF'
[Unit]
Description=ydotool daemon
After=default.target

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path=%t/.ydotool_socket --socket-own=%U:%G
Restart=on-failure

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now ydotoold

echo "── variabile d'ambiente ──"
LINE='export YDOTOOL_SOCKET="$XDG_RUNTIME_DIR/.ydotool_socket"'
for rc in ~/.bashrc ~/.zshrc; do
  [ -f "$rc" ] && ! grep -q "YDOTOOL_SOCKET" "$rc" && echo "$LINE" >> "$rc"
done

echo "── npm install ──"
npm install --silent

echo "── firewall ──"
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1 || true
  sudo firewall-cmd --reload >/dev/null 2>&1 || true
  echo "  porta 8080/tcp aperta su firewalld"
else
  echo "  firewalld non attivo — skip (apri 8080/tcp se hai un altro firewall)"
fi

IP=$(ip -4 addr show | awk '/inet / && $2 !~ /^127\./ {sub("/.*","",$2); print $2; exit}')

cat <<EOF

✓ Tutto pronto.

  Prima volta? → LOGOUT + LOGIN (serve per i gruppi 'input' e 'video').

  Avvio:    npm start
  Telefono: http://${IP:-<IP-PC>}:8080
EOF
