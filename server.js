// server.js — Phone Remote v3 (Linux/Wayland, ydotool, PWA, media keys)

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { WebSocketServer } = require('ws');

const PORT = 8080;

const KEYCODES = {
  Escape: 1, Backspace: 14, Tab: 15, Enter: 28, Space: 57, Delete: 111,
  ArrowUp: 103, ArrowDown: 108, ArrowLeft: 105, ArrowRight: 106,
  Home: 102, End: 107, PageUp: 104, PageDown: 109, Insert: 110,
  Control: 29, Shift: 42, Alt: 56, Meta: 125,
  A:30,B:48,C:46,D:32,E:18,F:33,G:34,H:35,I:23,J:36,K:37,L:38,
  M:50,N:49,O:24,P:25,Q:16,R:19,S:31,T:20,U:22,V:47,W:17,X:45,Y:21,Z:44,
  F1:59,F2:60,F3:61,F4:62,F5:63,F6:64,F7:65,F8:66,F9:67,F10:68,F11:87,F12:88,
  // Media / system keys (XF86)
  Mute: 113, VolumeDown: 114, VolumeUp: 115,
  PlayPause: 164, NextTrack: 163, PrevTrack: 165, Stop: 166,
  BrightnessDown: 224, BrightnessUp: 225,
};

function ydo(args) {
  return new Promise((resolve) => {
    execFile('ydotool', args, (err, _o, stderr) => {
      if (err) console.error('ydotool:', stderr || err.message);
      resolve();
    });
  });
}

const BTN = { left: 0, right: 1, middle: 2 };
const click = (action, button) => '0x' + (action | (BTN[button] ?? 0)).toString(16);

// ─── Static file routes ─────────────────────────────────────────────
const STATIC = {
  '/': { file: 'client.html', mime: 'text/html; charset=utf-8' },
  '/index.html': { file: 'client.html', mime: 'text/html; charset=utf-8' },
  '/manifest.webmanifest': { file: 'manifest.webmanifest', mime: 'application/manifest+json' },
  '/sw.js': { file: 'sw.js', mime: 'text/javascript' },
  '/icon-192.png': { file: 'icon-192.png', mime: 'image/png' },
  '/icon-512.png': { file: 'icon-512.png', mime: 'image/png' },
  '/icon-512-maskable.png': { file: 'icon-512-maskable.png', mime: 'image/png' },
  '/apple-touch-icon.png': { file: 'apple-touch-icon.png', mime: 'image/png' },
};

const server = http.createServer((req, res) => {
  const route = STATIC[req.url];
  if (!route) { res.writeHead(404); return res.end(); }
  fs.readFile(path.join(__dirname, route.file), (err, data) => {
    if (err) { res.writeHead(500); return res.end('Error: ' + route.file); }
    res.writeHead(200, { 'Content-Type': route.mime, 'Cache-Control': 'no-cache' });
    res.end(data);
  });
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log('Phone connected');
  ws.on('message', async (raw) => {
    try {
      const m = JSON.parse(raw.toString());
      switch (m.type) {
        case 'move':      await ydo(['mousemove', '--', String(m.dx|0), String(m.dy|0)]); break;
        case 'click':     await ydo(['click', click(0xC0, m.button)]); break;
        case 'mousedown': await ydo(['click', click(0x80, m.button)]); break;
        case 'mouseup':   await ydo(['click', click(0x40, m.button)]); break;
        case 'scroll':    await ydo(['mousemove', '--wheel', '--', '0', String(-(m.dy|0))]); break;
        case 'type':      await ydo(['type', '--', m.text]); break;
        case 'key': {
          const c = KEYCODES[m.key];
          if (!c) break;
          const mods = (m.mods || []).map(x => KEYCODES[x]).filter(Boolean);
          const seq = [
            ...mods.map(x => `${x}:1`),
            `${c}:1`, `${c}:0`,
            ...mods.slice().reverse().map(x => `${x}:0`),
          ];
          await ydo(['key', ...seq]);
          break;
        }
      }
    } catch (e) { console.error(e); }
  });
  ws.on('close', () => console.log('Phone disconnected'));
});

execFile('ydotool', ['--help'], (err) => { if (err) console.warn('⚠  ydotool not in PATH'); });
execFile('pgrep', ['-x', 'ydotoold'], (_e, out) => {
  if (!out || !out.trim()) console.warn('⚠  ydotoold not running');
});

server.listen(PORT, () => console.log(`Server on http://0.0.0.0:${PORT}`));
