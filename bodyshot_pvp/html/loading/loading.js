'use strict';
// Ladebildschirm: Daten kommen vom Server (window.nuiHandoverData), Fortschritt vom Spiel.
// Alles Fremde wird nur als Text eingesetzt.

const $ = (id) => document.getElementById(id);
const data = window.nuiHandoverData || {};

function svgIcon(name) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + ((window.ICONS && window.ICONS[name]) || '') + '</svg>';
}
function setIcon(node, name) { node.innerHTML = svgIcon(name); }
document.querySelectorAll('.ic[data-icon]').forEach((i) => setIcon(i, i.dataset.icon));

function openUrl(url) {
    if (!url) return;
    try { if (window.invokeNative) { window.invokeNative('openUrl', url); return; } } catch (e) { /* weiter */ }
    window.open(url, '_blank');
}

// ------------------------------------------------------------------ Texte
$('logo-name').textContent = data.serverName || 'BODYSHOT';
if (data.serverTag) $('logo-tag').textContent = data.serverTag; else $('logo-tag').classList.add('off');
$('subtitle').textContent = data.subtitle || '';
$('welcome').textContent = data.welcome || '';
if (data.discord) { $('btn-discord').classList.remove('off'); $('btn-discord').addEventListener('click', () => openUrl(data.discord)); }
if (data.store) { $('btn-store').classList.remove('off'); $('btn-store').addEventListener('click', () => openUrl(data.store)); }

// Eigenes Logo / eigenes Bild rechts (falls vorhanden)
// Logo: eigenes img/logo.png, sonst die BODYSHOT-Wortmarke, sonst Text
const logoImg = $('logo-img');
const logoSrcs = ['../img/logo.png', '../img/brand/logo-wordmark.png'];
logoImg.onload = () => { logoImg.classList.remove('off'); $('logo-text').classList.add('off'); };
logoImg.onerror = () => { logoSrcs.shift(); if (logoSrcs.length) logoImg.src = logoSrcs[0]; };
logoImg.src = logoSrcs[0];
// Rechts: eigenes Bild (img/character.png) oder das BS-Abzeichen mit Fadenkreuz-Ring
const charImg = $('character');
charImg.onload = () => { charImg.classList.remove('off'); $('badge').classList.add('off'); };
charImg.src = 'img/character.png';
$('badge-img').onerror = () => $('badge').classList.add('off');

// Tipps wechseln alle 6 Sekunden
const tips = Array.isArray(data.tips) && data.tips.length ? data.tips : ['Mit F1 wählst du dein Team, mit F2 öffnest du das Hauptmenü.'];
let tipIndex = Math.floor(Math.random() * tips.length);
const tipText = $('tip-text');
tipText.textContent = tips[tipIndex];
setInterval(() => {
    tipText.classList.add('swap');
    setTimeout(() => { tipIndex = (tipIndex + 1) % tips.length; tipText.textContent = tips[tipIndex]; tipText.classList.remove('swap'); }, 400);
}, 6000);

// ------------------------------------------------------------------ Bokeh-Lichter
(() => {
    const box = $('orbs');
    const n = 16;
    for (let i = 0; i < n; i++) {
        const o = document.createElement('i');
        o.className = 'orb';
        const size = 2 + Math.random() * 14;
        o.style.width = o.style.height = size + 'rem';
        o.style.left = (Math.random() * 100) + '%';
        o.style.top = (35 + Math.random() * 70) + '%';
        o.style.setProperty('--b', (size > 10 ? 18 : size > 6 ? 9 : 3) + 'px');
        o.style.setProperty('--d', (14 + Math.random() * 16) + 's');
        o.style.setProperty('--delay', (-Math.random() * 20) + 's');
        o.style.setProperty('--mx', ((Math.random() - 0.5) * 160) + 'px');
        o.style.setProperty('--my', (-80 - Math.random() * 220) + 'px');
        o.style.setProperty('--o', (0.25 + Math.random() * 0.5).toFixed(2));
        o.style.setProperty('--s0', (0.6 + Math.random() * 0.3).toFixed(2));
        o.style.setProperty('--s1', (1 + Math.random() * 0.4).toFixed(2));
        box.append(o);
    }
})();

// ------------------------------------------------------------------ Karte im Hintergrund
(() => {
    const d = window.GW_MAP;
    const canvas = $('map');
    if (!d || !canvas.getContext) return;
    const layers = {};
    Object.keys(d.l).forEach((k) => {
        const bin = atob(d.l[k]);
        const buf = new Int16Array(bin.length / 2);
        for (let i = 0; i < buf.length; i++) {
            let v = bin.charCodeAt(i * 2) | (bin.charCodeAt(i * 2 + 1) << 8);
            if (v > 32767) v -= 65536;
            buf[i] = v;
        }
        const lines = [];
        let i = 0;
        while (i < buf.length) {
            const n = buf[i];
            let x = buf[i + 1], y = buf[i + 2];
            i += 3;
            const pts = new Float32Array(n * 2);
            pts[0] = x; pts[1] = y;
            for (let j = 1; j < n; j++) { x += buf[i]; y += buf[i + 1]; i += 2; pts[j * 2] = x; pts[j * 2 + 1] = y; }
            lines.push(pts);
        }
        layers[k] = lines;
    });
    const style = [['dt', 'rgba(110,128,146,0.28)', 1], ['bk', 'rgba(70,120,165,0.45)', 1], ['st', 'rgba(105,160,210,0.6)', 1.1], ['mj', 'rgba(150,200,240,0.75)', 1.5], ['fw', 'rgba(14,165,255,0.9)', 2]];
    const zones = Array.isArray(data.zones) ? data.zones : [];
    const hoods = Array.isArray(data.hoods) ? data.hoods : [];
    const dpr = window.devicePixelRatio || 1;
    let base = null, W = 0, H = 0;
    // Statisches Bild der ganzen Insel einmal zeichnen, dann nur verschieben/zoomen
    const renderBase = () => {
        W = canvas.width = Math.round(window.innerWidth * dpr);
        H = canvas.height = Math.round(window.innerHeight * dpr);
        const scale = 2.2;                                   // Grundbild größer als der Bildschirm
        base = document.createElement('canvas');
        base.width = Math.round(W * scale);
        base.height = Math.round(H * scale);
        const ctx = base.getContext('2d');
        const [x0, y0, x1, y1] = d.b;
        const mpp = Math.max((x1 - x0) / (base.width * 0.55), (y1 - y0) / base.height) * 1.02;
        const cx = (x0 + x1) / 2 + 300, cy = (y0 + y1) / 2 - 900;
        const P = (x, y) => [base.width * 0.62 + (x - cx) / mpp, base.height / 2 - (y - cy) / mpp];
        ctx.fillStyle = '#05090d';
        ctx.fillRect(0, 0, base.width, base.height);
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
        const draw = (lines, color, width) => {
            ctx.strokeStyle = color;
            ctx.lineWidth = width;
            ctx.beginPath();
            for (const p of lines) {
                let [sx, sy] = P(p[0], p[1]);
                ctx.moveTo(sx, sy);
                for (let j = 2; j < p.length; j += 2) { [sx, sy] = P(p[j], p[j + 1]); ctx.lineTo(sx, sy); }
            }
            ctx.stroke();
        };
        ctx.save();
        ctx.filter = 'blur(10px)';
        style.forEach(([k]) => draw(layers[k] || [], 'rgba(14,110,180,0.25)', 14 * dpr));
        ctx.restore();
        style.forEach(([k, c, w]) => draw(layers[k] || [], c, w * dpr));
        zones.forEach((z) => {
            const [sx, sy] = P(z.x, z.y);
            const r = Math.max(6 * dpr, (z.r || 80) / mpp);
            ctx.fillStyle = z.color ? hexA(z.color, 0.35) : 'rgba(139,154,171,0.2)';
            ctx.strokeStyle = z.color || '#8b9aab';
            ctx.lineWidth = 2 * dpr;
            ctx.beginPath(); ctx.arc(sx, sy, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
        });
        hoods.forEach((h) => {
            const [sx, sy] = P(h.x, h.y);
            ctx.save(); ctx.translate(sx, sy); ctx.rotate(Math.PI / 4);
            ctx.fillStyle = h.color || '#fff';
            const s = 5 * dpr;
            ctx.fillRect(-s, -s, s * 2, s * 2);
            ctx.restore();
        });
    };
    function hexA(hex, a) {
        const m = /^#?([0-9a-f]{6})$/i.exec(String(hex));
        if (!m) return `rgba(139,154,171,${a})`;
        const n = parseInt(m[1], 16);
        return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
    }
    renderBase();
    window.addEventListener('resize', renderBase);
    const ctx = canvas.getContext('2d');
    const start = performance.now();
    const frame = (now) => {
        const t = (now - start) / 1000;
        // langsamer Kameraflug: Zoom pendelt, Mitte wandert über die Insel
        const zoom = 1.25 + 0.18 * Math.sin(t / 23);
        const cx = base.width * (0.55 + 0.12 * Math.sin(t / 31));
        const cy = base.height * (0.55 + 0.14 * Math.cos(t / 27));
        const sw = W / zoom * 1.0, sh = H / zoom * 1.0;
        ctx.fillStyle = '#05090d';
        ctx.fillRect(0, 0, W, H);
        ctx.drawImage(base, cx - sw / 2, cy - sh / 2, sw, sh, 0, 0, W, H);
        requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
})();

// ------------------------------------------------------------------ Fortschritt
const STAGES = {
    startInitFunctionOrder: 'Starte Spiel …',
    initFunctionInvoking: 'Lade Spieldaten …',
    startDataFileEntries: 'Lade Dateien …',
    performMapLoadFunction: 'Lade Los Santos …',
    onDataFileEntry: 'Lade Ressourcen …',
};
let target = 0.02, shown = 0;
const bar = $('bar'), pct = $('percent'), status = $('status');
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.eventName === 'loadProgress' && typeof m.loadFraction === 'number') {
        target = Math.max(target, Math.min(1, m.loadFraction));
    } else if (STAGES[m.eventName]) {
        status.textContent = STAGES[m.eventName];
    } else if (m.eventName === 'onLogLine' && m.message) {
        status.textContent = String(m.message).replace(/\.+$/, '') + ' …';
    }
});
// auch ohne Meldungen langsam weiter (nie bis 100 %)
setInterval(() => { if (target < 0.9) target = Math.min(0.9, target + 0.004); }, 400);
(function tick() {
    shown += (target - shown) * 0.06;
    const p = Math.max(0, Math.min(100, shown * 100));
    bar.style.width = p.toFixed(2) + '%';
    pct.textContent = Math.floor(p) + '%';
    requestAnimationFrame(tick);
})();

// ------------------------------------------------------------------ Musik
(() => {
    const music = data.music || {};
    const tracks = Array.isArray(music.tracks) ? music.tracks.filter((t) => t && t.file) : [];
    if (!tracks.length) return;
    const audio = $('audio');
    const player = $('player');
    player.classList.remove('off');
    let index = Math.floor(Math.random() * tracks.length);
    const vol = $('vol');
    const setVol = (v) => {
        audio.volume = Math.max(0, Math.min(1, v));
        vol.value = audio.volume;
        vol.style.setProperty('--p', (audio.volume * 100) + '%');
        setIcon($('mute').firstElementChild, audio.volume === 0 ? 'volume-x' : 'volume-2');
    };
    let lastVol = typeof music.volume === 'number' ? music.volume : 0.25;
    setVol(lastVol);
    const load = (i) => {
        index = (i + tracks.length) % tracks.length;
        const t = tracks[index];
        $('track-title').textContent = t.title || t.file;
        $('track-artist').textContent = t.artist || '';
        audio.src = 'music/' + encodeURIComponent(t.file);
        const p = audio.play();
        if (p && p.catch) p.catch(() => setPlaying(false));
    };
    const setPlaying = (on) => {
        player.classList.toggle('playing', on);
        setIcon($('play').firstElementChild, on ? 'pause' : 'play');
    };
    audio.addEventListener('play', () => setPlaying(true));
    audio.addEventListener('pause', () => setPlaying(false));
    audio.addEventListener('ended', () => load(index + 1));
    audio.addEventListener('error', () => { if (tracks.length > 1) setTimeout(() => load(index + 1), 500); });
    $('play').addEventListener('click', () => { if (audio.paused) audio.play(); else audio.pause(); });
    $('next').addEventListener('click', () => load(index + 1));
    $('prev').addEventListener('click', () => load(index - 1));
    vol.addEventListener('input', () => { setVol(Number(vol.value)); if (audio.volume > 0) lastVol = audio.volume; });
    $('mute').addEventListener('click', () => setVol(audio.volume > 0 ? 0 : (lastVol || 0.25)));
    load(index);
})();
