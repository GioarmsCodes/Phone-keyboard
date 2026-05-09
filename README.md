# Phone Remote

Mi sono rotto la spalla qualche giorno fa. Niente di drammatico, ma il braccio destro è fuori uso e usare la tastiera del PC è diventato un esercizio masochistico. Tra una visita ortopedica e l'altra avevo bisogno di qualcosa per ammazzare il tempo, così mi sono messo a scrivere questo: il telefono diventa tastiera + trackpad per il PC, via Wi-Fi.

Apri una pagina web sul telefono, sposti il dito, il cursore si muove. Digiti, e il testo arriva. Niente cloud, niente account, tutto in locale. Linux + Wayland (testato su KDE Plasma, ma dovrebbe andare ovunque ci sia `ydotool`).

## Cosa c'è dentro

- **Trackpad**: muovi il dito, tap = click, doppio-tap-tieni = drag, due dita = scroll o right-click
- **Tastiera**: scrivi sul telefono, arriva sul PC. Funziona anche con accenti e simboli
- **Modificatori**: Ctrl, Shift, Alt, Super (sticky a uso singolo)
- **Tasti media** in una tendina dedicata: play/pause, prev/next, vol±, mute, brightness±
- Auto-reconnect, vibrazione, sensibilità regolabile, lock per evitare input accidentali

## Setup

```bash
./setup.sh
```

Fa tutto da solo: pacchetti, permessi, daemon, dipendenze, firewall. **La prima volta serve logout + login** (per i gruppi `input` e `video`).

## Uso

```bash
npm start
```

## Note

- Lo script di setup è scritto per Arch/Manjaro (`pacman`). Su altre distro installa a mano `ydotool playerctl wireplumber brightnessctl nodejs npm`, il resto del setup è copiabile.
- Server e telefono devono stare sulla stessa Wi-Fi.
- Niente auth: chi è sulla tua rete può connettersi. Su rete domestica non è un problema, su rete pubblica sì.
