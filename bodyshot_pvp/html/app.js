'use strict';

// Alles, was vom Spiel oder von Spielern kommt, wird nur als Text eingesetzt (nie als HTML).
const $ = (id) => document.getElementById(id);
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'bodyshot_pvp';
const SVGNS = 'http://www.w3.org/2000/svg';

function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

const state = {
    config: { serverName: 'BODYSHOT', serverTag: 'GANGWAR', keys: {}, discord: '', chat: { fadeSeconds: 10, maxLength: 150 }, maxHealth: 100, maxArmour: 100 },
    settings: { hitmarker: true, hitSound: true, killSound: true, damageNumbers: true, damageDirection: true, killfeed: true, killfeedSeconds: 6, clock: true, volume: 0.5, hudScale: 1, chatFade: true },
    screen: null,
    account: null,
    mode: 'login',
    team: null,
    uid: null,
    serverId: 0,
    hp: 0,
    streak: 0,
    menu: null,
    page: 'ffa',
    teams: null,
    garage: null,
    admin: null,
    adminTab: 'players',
    adminSel: null,
    war: null,
    lastWarPhase: null,
    timers: {},
    bannerQueue: [],
    bannerBusy: false,
};

// ------------------------------------------------------------------ Helfer
function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = String(text);
    return e;
}
function txt(s) { return document.createTextNode(String(s)); }
function svgEl(tag, attrs, text) {
    const e = document.createElementNS(SVGNS, tag);
    Object.keys(attrs || {}).forEach((k) => e.setAttribute(k, attrs[k]));
    if (text !== undefined && text !== null) e.textContent = String(text);
    return e;
}
// Icons sind feste Zeichenketten aus icons.js (Lucide), keine Spielerdaten
function svgIcon(name) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + ((window.ICONS && window.ICONS[name]) || '') + '</svg>';
}
function icon(name, cls) {
    const i = el('i', 'ic' + (cls ? ' ' + cls : ''));
    i.innerHTML = svgIcon(name);
    return i;
}
function fillIcons(root) {
    (root || document).querySelectorAll('.ic[data-icon]').forEach((i) => { i.innerHTML = svgIcon(i.dataset.icon); });
}
function btn(label, cls, onClick, disabled, iconName) {
    const b = el('button', 'btn ' + (cls || ''));
    b.type = 'button';
    if (iconName) b.append(icon(iconName));
    if (label) b.append(txt(label));
    if (disabled) b.disabled = true;
    if (onClick) b.addEventListener('click', (e) => { e.stopPropagation(); click(); onClick(e); });
    return b;
}
function iconBtn(name, cls, onClick, title) {
    const b = el('button', 'iconbtn ' + (cls || ''));
    b.type = 'button';
    b.append(icon(name));
    if (title) b.title = title;
    if (onClick) b.addEventListener('click', (e) => { e.stopPropagation(); click(); onClick(e); });
    return b;
}
// Gefährliche Aktion: erster Klick fragt nach, zweiter führt aus
function confirmBtn(label, question, cls, onConfirm, iconName) {
    const b = btn(label, cls, null, false, iconName);
    let armed = null;
    b.addEventListener('click', () => {
        click();
        if (armed) { clearTimeout(armed); armed = null; onConfirm(); return; }
        b.lastChild.textContent = question;
        b.classList.add('armed');
        armed = setTimeout(() => { armed = null; b.lastChild.textContent = label; b.classList.remove('armed'); }, 4000);
    });
    return b;
}
function stagger(container) {
    Array.from(container.children).forEach((c, i) => c.style.setProperty('--i', Math.min(i, 24)));
    container.classList.add('stagger');
    return container;
}
function nb(s) { return String(s === undefined || s === null ? '' : s).replace(/ (Mk II)\b/g, ' $1'); }
function num(n) { return Math.round(Number(n) || 0).toLocaleString('de-DE'); }
function money(n) { return '$' + num(n); }
function dec(n) { return (Number(n) || 0).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 }); }
function pct(v, max) { return Math.max(0, Math.min(100, ((Number(v) || 0) / (max || 1)) * 100)); }
function clock(sec) {
    sec = Math.max(0, Math.round(sec || 0));
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
}
function kd(s) { return s && s.deaths > 0 ? s.kills / s.deaths : ((s && s.kills) || 0); }
function plural(n, one, many) { return n === 1 ? one : many; }
function restartAnim(node, cls) { node.classList.remove(cls); void node.offsetWidth; node.classList.add(cls); }
function every(name, ms, fn) { clearInterval(state.timers[name]); state.timers[name] = fn ? setInterval(fn, ms) : null; }
function later(name, ms, fn) { clearTimeout(state.timers[name]); state.timers[name] = setTimeout(fn, ms); }
function action(name, extra) { post('action', Object.assign({ action: name }, extra || {})); }
function initials(name) { return String(name || '?').replace(/[^A-Za-z0-9]/g, '').slice(0, 2).toUpperCase() || '?'; }
function openUrl(url) {
    if (!url) return;
    try { if (window.invokeNative) { window.invokeNative('openUrl', url); return; } } catch (e) { /* weiter */ }
    window.open(url, '_blank');
}

// ------------------------------------------------------------------ Farben
function hexRgb(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(String(hex || '').trim());
    if (!m) return null;
    const n = parseInt(m[1], 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function inkFor(color) {
    const rgb = hexRgb(color);
    if (!rgb) return '#ffffff';
    const c = rgb.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2] > 0.36 ? '#0a1118' : '#ffffff';
}
function rgba(color, a) { const c = hexRgb(color) || [14, 165, 255]; return `rgba(${c[0]},${c[1]},${c[2]},${a})`; }
function darker(color, f) { const c = hexRgb(color) || [14, 165, 255]; const k = f; return `rgb(${Math.round(c[0] * k + 10 * (1 - k))},${Math.round(c[1] * k + 17 * (1 - k))},${Math.round(c[2] * k + 24 * (1 - k))})`; }
function paint(node, color, prefix) {
    const p = prefix || 'c';
    const c = hexRgb(color) ? color : '#0ea5ff';
    node.style.setProperty(`--${p}`, c);
    node.style.setProperty(`--${p}-ink`, inkFor(c));
    node.style.setProperty(`--${p}-a22`, rgba(c, 0.22));
    node.style.setProperty(`--${p}-a26`, rgba(c, 0.26));
    node.style.setProperty(`--${p}-a55`, rgba(c, 0.55));
    node.style.setProperty(`--${p}-a70`, rgba(c, 0.7));
    node.style.setProperty(`--${p}-dark`, darker(c, 0.4));
    return node;
}
function setTheme(color) { paint(document.documentElement, color, 'team'); }

// ------------------------------------------------------------------ Logo + Embleme
// Reihenfolge: eigenes Logo (img/logo.png) -> BODYSHOT-Wortmarke (img/brand) -> Text
const BRAND = { wordmark: 'img/brand/logo-wordmark.png', mark: 'img/brand/logo-anim.webp', badge: 'img/brand/logo-badge.png' };
function logo() {
    const l = el('div', 'logo');
    l.append(el('span', 'logo-name', state.config.serverName || 'GANGWAR'));
    if (state.config.serverTag) l.append(el('span', 'logo-tag', state.config.serverTag));
    const tryImg = (srcs) => {
        if (!srcs.length) return;
        const img = new Image();
        img.className = 'logo-img';
        img.onload = () => { l.textContent = ''; l.append(img); };
        img.onerror = () => tryImg(srcs.slice(1));
        img.src = srcs[0];
    };
    tryImg(['img/logo.png', BRAND.wordmark]);
    return l;
}
// Fadenkreuz-Ring aus dem Discord-Logo: Ring + 4 Striche (langsam), Komet (schnell), BS-Abzeichen in der Mitte
function reticle(sizeRem, src) {
    const r = el('div', 'reticle');
    if (sizeRem) r.style.setProperty('--rs', sizeRem + 'rem');
    r.append(el('i', 'glowdisc'));
    const s = svgEl('svg', { viewBox: '0 0 512 512' });
    const defs = svgEl('defs');
    const gid = 'rg' + (emblemSeq++);
    const g = svgEl('linearGradient', { id: gid, x1: '0', y1: '0', x2: '1', y2: '0' });
    g.append(svgEl('stop', { offset: '0', 'stop-color': '#19b2ff', 'stop-opacity': '0' }), svgEl('stop', { offset: '1', 'stop-color': '#c9ecff', 'stop-opacity': '1' }));
    defs.append(g);
    s.append(defs);
    const ring = svgEl('g', { class: 'ring' });
    ring.append(svgEl('circle', { cx: 256, cy: 256, r: 226, fill: 'none', stroke: '#19b2ff', 'stroke-opacity': '0.45', 'stroke-width': 4 }));
    ring.append(svgEl('circle', { cx: 256, cy: 256, r: 210, fill: 'none', stroke: '#19b2ff', 'stroke-opacity': '0.2', 'stroke-width': 2, 'stroke-dasharray': '2 9.1' }));
    [['256', '16', '256', '46'], ['256', '466', '256', '496'], ['16', '256', '46', '256'], ['466', '256', '496', '256']].forEach(([x1, y1, x2, y2]) => {
        ring.append(svgEl('line', { x1, y1, x2, y2, stroke: '#4cc3ff', 'stroke-width': 7, 'stroke-linecap': 'round' }));
    });
    const comet = svgEl('g', { class: 'comet' });
    comet.style.transformOrigin = '256px 256px';
    comet.append(svgEl('path', { d: 'M 256 30 A 226 226 0 0 1 415.8 96.2', fill: 'none', stroke: `url(#${gid})`, 'stroke-width': 6, 'stroke-linecap': 'round' }));
    comet.append(svgEl('circle', { cx: 415.8, cy: 96.2, r: 7, fill: '#e6f6ff' }));
    s.append(ring, comet);
    r.append(s);
    if (src === false) return r;                      // nur der Ring (z. B. Duell-Countdown)
    const img = new Image();
    img.src = src || BRAND.mark;
    img.onerror = () => { img.remove(); r.append(el('span', 'logo-name', state.config.serverName || 'BS')); };
    r.append(img);
    return r;
}

function hashStr(s) { let h = 0; for (const ch of String(s)) h = (h * 31 + ch.charCodeAt(0)) >>> 0; return h; }
const SHAPES = {
    hex: 'M50 3 L93 27 L93 73 L50 97 L7 73 L7 27 Z',
    shield: 'M50 3 L91 15 L91 50 C91 75 72 89 50 97 C28 89 9 75 9 50 L9 15 Z',
    diamond: 'M50 2 L97 50 L50 98 L3 50 Z',
    crest: 'M50 3 L88 12 L94 46 L78 82 L50 97 L22 82 L6 46 L12 12 Z',
};
let emblemSeq = 0;
function svgEmblem(t) {
    const c = hexRgb(t.color) ? t.color : '#8c8c8c';
    const keys = Object.keys(SHAPES);
    const shape = SHAPES[keys[hashStr(t.tag || t.name || '?') % keys.length]];
    const id = 'emg' + (emblemSeq++);
    const s = svgEl('svg', { viewBox: '0 0 100 100' });
    const defs = svgEl('defs');
    const g = svgEl('linearGradient', { id, x1: '0', y1: '0', x2: '0', y2: '1' });
    g.append(svgEl('stop', { offset: '0', 'stop-color': c }), svgEl('stop', { offset: '1', 'stop-color': darker(c, 0.45) }));
    defs.append(g);
    s.append(defs);
    s.append(svgEl('path', { d: shape, fill: `url(#${id})` }));
    s.append(svgEl('path', { d: shape, fill: '#0b1219', stroke: c, 'stroke-width': '2.2', transform: 'translate(50 50) scale(0.82) translate(-50 -50)' }));
    s.append(svgEl('path', { d: 'M30 70 L50 78 L70 70', fill: 'none', stroke: c, 'stroke-width': '2.4', 'stroke-linecap': 'round', opacity: '0.8' }));
    s.append(svgEl('path', { d: 'M38 26 L50 21 L62 26', fill: 'none', stroke: c, 'stroke-width': '2.4', 'stroke-linecap': 'round', opacity: '0.6' }));
    const tag = String(t.tag || '?').slice(0, 4);
    s.append(svgEl('text', {
        x: '50', y: '58', 'text-anchor': 'middle', fill: '#fff',
        'font-family': 'Russo One', 'font-size': tag.length > 3 ? '19' : '23', 'letter-spacing': '0.5',
    }, tag));
    return s;
}
function emblem(t, small) {
    const wrap = el('div', 'emblem' + (small ? ' small' : ''));
    wrap.append(svgEmblem(t));
    const file = t.kind === 'private' ? 'p' + t.id : t.id;
    if (file !== undefined && file !== null) {
        const img = new Image();
        img.onload = () => { wrap.textContent = ''; wrap.append(img); };
        img.src = `img/teams/${file}.png`;
    }
    return wrap;
}

// ------------------------------------------------------------------ Straßenkarte (aus mapdata.js)
const ROADS = (() => {
    const d = window.GW_MAP;
    if (!d) return null;
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
            let x = buf[i + 1];
            let y = buf[i + 2];
            i += 3;
            const pts = new Float32Array(n * 2);
            pts[0] = x; pts[1] = y;
            let x0 = x, x1 = x, y0 = y, y1 = y;
            for (let j = 1; j < n; j++) {
                x += buf[i]; y += buf[i + 1]; i += 2;
                pts[j * 2] = x; pts[j * 2 + 1] = y;
                if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
            }
            lines.push({ pts, x0, x1, y0, y1 });
        }
        layers[k] = lines;
    });
    return { bounds: d.b, layers };
})();
const ROAD_STYLE = [
    ['dt', 'rgba(110,128,146,0.35)', 1],
    ['bk', 'rgba(70,120,165,0.55)', 1],
    ['st', 'rgba(105,160,210,0.7)', 1.1],
    ['mj', 'rgba(150,200,240,0.85)', 1.6],
    ['fw', 'rgba(14,165,255,0.95)', 2],
];
// view = { cx, cy, mpp } (Weltmitte, Meter pro Pixel)
function drawRoads(ctx, w, h, view, glow) {
    ctx.fillStyle = '#060b10';
    ctx.fillRect(0, 0, w, h);
    if (!ROADS) return;
    const halfW = (w / 2) * view.mpp, halfH = (h / 2) * view.mpp;
    const vx0 = view.cx - halfW, vx1 = view.cx + halfW, vy0 = view.cy - halfH, vy1 = view.cy + halfH;
    const pass = (key, style, width) => {
        const lines = ROADS.layers[key];
        if (!lines) return;
        ctx.strokeStyle = style;
        ctx.lineWidth = width;
        ctx.beginPath();
        for (const L of lines) {
            if (L.x1 < vx0 || L.x0 > vx1 || L.y1 < vy0 || L.y0 > vy1) continue;
            const p = L.pts;
            ctx.moveTo(w / 2 + (p[0] - view.cx) / view.mpp, h / 2 - (p[1] - view.cy) / view.mpp);
            for (let j = 2; j < p.length; j += 2) ctx.lineTo(w / 2 + (p[j] - view.cx) / view.mpp, h / 2 - (p[j + 1] - view.cy) / view.mpp);
        }
        ctx.stroke();
    };
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    if (glow) {
        ctx.save();
        ctx.filter = 'blur(6px)';
        ROAD_STYLE.forEach(([k]) => pass(k, 'rgba(14,110,180,0.22)', Math.max(4, 60 / view.mpp)));
        ctx.restore();
    }
    ROAD_STYLE.forEach(([k, s, wd]) => pass(k, s, wd));
}
function canvasFor(box) {
    const c = el('canvas');
    box.append(c);
    const fit = () => {
        const r = box.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        c.width = Math.max(10, Math.round(r.width * dpr));
        c.height = Math.max(10, Math.round(r.height * dpr));
        return dpr;
    };
    return { c, fit };
}

// ------------------------------------------------------------------ Sound
let audio;
function tone(freq, duration, type, volume, delay) {
    try {
        audio = audio || new (window.AudioContext || window.webkitAudioContext)();
        if (audio.state === 'suspended') audio.resume();
        const t = audio.currentTime + (delay || 0);
        const osc = audio.createOscillator();
        const gain = audio.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, t);
        gain.gain.setValueAtTime(0.0001, t);
        gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, volume * state.settings.volume), t + 0.005);
        gain.gain.exponentialRampToValueAtTime(0.0001, t + duration);
        osc.connect(gain).connect(audio.destination);
        osc.start(t);
        osc.stop(t + duration + 0.02);
    } catch (e) { /* kein Audio */ }
}
// Treffer- und Kill-Sounds zur Auswahl (Einstellungen)
const HIT_SOUNDS = {
    classic() { tone(2100, 0.05, 'triangle', 0.5); },
    click() { tone(3200, 0.02, 'square', 0.25); },
    ding() { tone(1800, 0.09, 'sine', 0.45); tone(2700, 0.07, 'sine', 0.25, 0.01); },
    pop() { tone(620, 0.05, 'sine', 0.6); tone(900, 0.03, 'sine', 0.3, 0.02); },
    bass() { tone(160, 0.09, 'sawtooth', 0.45); },
};
const KILL_SOUNDS = {
    classic() { tone(880, 0.1, 'sine', 0.6); tone(1320, 0.18, 'sine', 0.6, 0.07); },
    ding() { tone(1568, 0.12, 'sine', 0.6); tone(2093, 0.3, 'sine', 0.5, 0.1); },
    headshot() { tone(1200, 0.06, 'square', 0.3); tone(1600, 0.06, 'square', 0.3, 0.06); tone(2400, 0.16, 'square', 0.3, 0.12); },
    coin() { tone(988, 0.08, 'square', 0.3); tone(1319, 0.3, 'square', 0.3, 0.08); },
    bass() { tone(110, 0.28, 'sawtooth', 0.5); tone(220, 0.2, 'sine', 0.4, 0.05); },
    none() {},
};
const sounds = {
    hit() { (HIT_SOUNDS[state.settings.hitSoundType] || HIT_SOUNDS.classic)(); },
    armour() { if ((state.settings.hitSoundType || 'classic') === 'classic') tone(1500, 0.05, 'triangle', 0.4); else sounds.hit(); },
    kill() { (KILL_SOUNDS[state.settings.killSoundType] || KILL_SOUNDS.classic)(); },
    alert() { tone(520, 0.12, 'square', 0.25); tone(520, 0.12, 'square', 0.25, 0.18); },
    level() { tone(660, 0.12, 'sine', 0.5); tone(880, 0.12, 'sine', 0.5, 0.1); tone(1320, 0.3, 'sine', 0.5, 0.2); },
    click() { tone(1800, 0.025, 'sine', 0.12); },
};
function click() { sounds.click(); }

// ================================================================== HUD
const HM_COLORS = { white: '#ffffff', red: '#ff4d61', blue: '#19b2ff', yellow: '#ffd400', green: '#34e39a', pink: '#ff4fa3' };
function applySettings() {
    const s = state.settings;
    document.documentElement.style.setProperty('--hud-scale', String(Math.max(0.7, Math.min(1.3, Number(s.hudScale) || 1))));
    const hm = $('hitmarker');
    if (hm) {
        hm.classList.remove('st-x', 'st-cross', 'st-dot', 'st-circle');
        hm.classList.add('st-' + (s.hitmarkerStyle || 'x'));
        hm.style.setProperty('--hm', HM_COLORS[s.hitmarkerColor] || '#ffffff');
    }
    if (typeof setLanguage === 'function' && window.I18N && window.I18N.lang !== (s.lang || 'de')) setLanguage(s.lang || 'de');
    $('clock').classList.toggle('off', !s.clock);
    $('killfeed').classList.toggle('off', !s.killfeed);
    document.querySelectorAll('.msg').forEach((m) => { if (!s.chatFade) m.classList.remove('faded'); });
}

function setStat(id, value) {
    const box = $(id);
    const b = box.querySelector('b');
    if (b.textContent !== value) {
        const changed = b.textContent !== '' && b.textContent !== '0' && b.textContent !== '0,00';
        b.textContent = value;
        if (changed) restartAnim(box, 'bump');
    }
}

function setAccount(acc) {
    if (!acc) return;
    const prevXp = state.account ? state.account.xp : null;
    state.account = acc;
    const s = acc.stats || {};
    setStat('st-kills', num(s.kills));
    setStat('st-deaths', num(s.deaths));
    setStat('st-kd', dec(kd(s)));
    $('hud-lvl').textContent = acc.level;
    $('hud-lvl2').textContent = acc.level;
    $('hud-id').textContent = acc.id;
    $('hud-money').textContent = money(acc.money);
    const max = acc.level >= acc.maxLevel;
    const fill = $('hud-xp');
    fill.style.width = (max ? 100 : Math.round((acc.progress || 0) * 100)) + '%';
    $('hud-xp-text').textContent = max ? 'Max' : `${num((acc.progress || 0) * acc.xpPerLevel)} / ${num(acc.xpPerLevel)} XP`;
    if (prevXp !== null && acc.xp > prevXp) restartAnim(fill, 'gain');
    const onme = $('onme-hud');
    if (onme) { onme.classList.toggle('off', !(acc.bounty > 0)); $('onme-amt').textContent = money(acc.bounty || 0); }
    if (state.screen === 'menu' && state.menu) { state.menu.account = acc; renderSideMe(); renderPips(); }
}

const MODE_TEXT = { ffa: 'FFA', gangwar: 'Gangwar', lobby: 'Hood', select: 'Teamwahl', login: 'Login', duel: '1v1-Duell' };
function setMode(d) {
    state.mode = d.mode;
    if (typeof d.serverId === 'number') state.serverId = d.serverId;
    if (d.uid !== undefined && d.uid !== null) state.uid = d.uid;
    if (d.team) { state.team = d.team; setTheme(d.team.color); }
    const place = $('hud-place');
    place.textContent = '';                      // Team-Kürzel steht nicht mehr im HUD
    if (d.mode === 'lobby') {
        place.append(el('span', null, d.hood || d.place || 'Hood'));
        if (state.config.hoodCombat) place.append(el('span', 'danger', 'Kampfzone'));
        else { const safe = el('span', 'safe'); safe.append(icon('shield-check'), txt('Safezone')); place.append(safe); }
    } else if (d.mode === 'ffa' || d.mode === 'gangwar' || d.mode === 'duel') {
        const s = el('span', 'danger', MODE_TEXT[d.mode]);
        place.append(s, el('span', null, d.place || ''));
    }
    if (d.mode !== 'gangwar') setWar(false);
    if (d.mode !== 'duel' && typeof setDuel === 'function') setDuel(null);
    if (d.mode === 'lobby') { if (!state.config.hoodCombat) $('lowhp').classList.remove('on'); $('zonewarn').classList.add('off'); }
    $('hud').classList.remove('off');
    while (chatPending.length) fadeLater(chatPending.shift());
}

// Spielzeit-Bonus + Online
function setHudData(d) {
    if (!d) return;
    if (typeof d.online === 'number') $('hud-online').textContent = d.online;
    const pt = $('playtime');
    if (!d.reward) { pt.classList.add('off'); every('playtime', 0, null); return; }
    pt.classList.remove('off');
    $('pt-money').textContent = '+' + money(d.reward.money);
    const until = Date.now() + d.reward.seconds * 1000;
    const total = d.reward.total || 3600;
    const tick = () => {
        const left = Math.max(0, Math.round((until - Date.now()) / 1000));
        $('pt-left').textContent = clock(left);
        $('pt-fill').style.width = (100 - pct(left, total)) + '%';
        pt.classList.toggle('ready', left <= 0);
    };
    tick();
    every('playtime', 1000, tick);
}

// Uhr oben links
const DAYS = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
function tickClock() {
    const n = new Date();
    $('clock-time').textContent = `${String(n.getHours()).padStart(2, '0')}:${String(n.getMinutes()).padStart(2, '0')}`;
    $('clock-date').textContent = `${DAYS[n.getDay()]}, ${String(n.getDate()).padStart(2, '0')}.${String(n.getMonth() + 1).padStart(2, '0')}.${n.getFullYear()}`;
}
tickClock();
setInterval(tickClock, 5000);

function setVitals(d) {
    if (d.maxHp) state.config.maxHealth = d.maxHp;
    state.hp = d.hp || 0;
    const low = state.hp > 0 && state.hp <= state.config.maxHealth * 0.3 && state.mode !== 'lobby';
    $('lowhp').classList.toggle('on', low);
}

function setAmmo(a) {
    const box = $('ammo');
    if (!a || !a.show) { box.classList.add('off'); return; }
    box.classList.remove('off');
    $('ammo-name').textContent = nb(a.name);
    $('ammo-clip').textContent = a.clip;
    $('ammo-reserve').textContent = a.reserve < 0 ? '/ ∞' : '/ ' + num(a.reserve);
    $('ammo-fill').style.width = pct(a.clip, a.maxClip || a.clip || 1) + '%';
    box.classList.toggle('low', a.maxClip > 0 && a.clip <= Math.ceil(a.maxClip * 0.25));
    box.classList.toggle('reload', !!a.reloading);
}

function showHitmarker(kill) {
    if (!state.settings.hitmarker) return;
    const hm = $('hitmarker');
    hm.classList.toggle('kill', !!kill);
    restartAnim(hm, 'show');
}
function showDamageNumber(dmg, armour, kill) {
    if (!state.settings.damageNumbers || !dmg) return;
    const n = el('div', 'dmg' + (armour ? ' armour' : '') + (kill ? ' kill' : ''), '-' + dmg);
    n.style.left = (2.4 + Math.random() * 1.6) + 'rem';
    n.style.top = (-1 + Math.random() * 2) + 'rem';
    $('dmgnums').append(n);
    setTimeout(() => n.remove(), 760);
}
function showDirection(angle, armour) {
    if (!state.settings.damageDirection || typeof angle !== 'number') return;
    const d = el('div', 'dir' + (armour ? ' armour' : ''));
    d.style.transform = 'rotate(' + (-angle) + 'deg)';
    $('dirs').append(d);
    setTimeout(() => d.remove(), 1150);
}
function flash(armour) {
    const v = $('vignette');
    v.classList.toggle('armour', !!armour);
    v.classList.add('flash');
    requestAnimationFrame(() => requestAnimationFrame(() => v.classList.remove('flash')));
}

// Killfeed
function causeText(cause) {
    if (cause === 'suicide') return 'hat neu gestartet';
    if (cause === 'fall') return 'ist abgestürzt';
    return 'ist gestorben';
}
function addKillfeed(e) {
    if (!state.settings.killfeed) return;
    const feed = $('killfeed');
    const row = el('div', 'kf');
    const name = (text, color) => { const s = el('span', null, text); if (hexRgb(color)) s.style.color = color; return s; };
    if (e.killer) {
        const w = el('span', 'w');
        w.append(icon('crosshair'), txt(nb(e.weapon || 'Kill')));
        row.append(name(e.killer, e.killerColor), w, name(e.victim, e.victimColor));
        if (e.killerId === state.serverId) row.classList.add('own');
    } else {
        row.append(name(e.victim, e.victimColor), el('span', 'x', causeText(e.cause)));
    }
    if (e.victimId === state.serverId) row.classList.add('me');
    feed.prepend(row);
    while (feed.children.length > 6) feed.lastChild.remove();
    const life = (state.settings.killfeedSeconds || 6) * 1000;
    setTimeout(() => row.classList.add('out'), life);
    setTimeout(() => row.remove(), life + 460);
}

// Ansagen (nacheinander)
function nextBanner() {
    if (state.bannerBusy || state.bannerQueue.length === 0) return;
    state.bannerBusy = true;
    const b = $('banner');
    b.textContent = state.bannerQueue.shift();
    b.classList.remove('off');
    restartAnim(b, 'show');
    setTimeout(() => { b.classList.add('off'); b.classList.remove('show'); state.bannerBusy = false; nextBanner(); }, 3500);
}
function announce(text) {
    if (!text) return;
    state.bannerQueue.push(String(text));
    if (state.bannerQueue.length > 4) state.bannerQueue.shift();
    nextBanner();
}

// Toasts
const TOAST_ICON = { success: 'circle-check', error: 'circle-x', war: 'swords', level: 'zap', info: 'info' };
function toast(kind, text) {
    if (!text) return;
    kind = TOAST_ICON[kind] ? kind : 'info';
    const t = el('div', 'toast ' + kind);
    t.append(icon(TOAST_ICON[kind]), el('span', null, text));
    const life = kind === 'war' ? 9000 : 5000;
    const bar = el('i', 'life');
    bar.style.animationDuration = life + 'ms';
    t.append(bar);
    $('toasts').append(t);
    if (kind === 'war') sounds.alert();
    if (kind === 'level') { sounds.level(); const m = /Level (\d+)/.exec(text); levelUp(m ? m[1] : null); }
    setTimeout(() => t.classList.add('out'), life);
    setTimeout(() => t.remove(), life + 360);
    while ($('toasts').children.length > 5) $('toasts').firstChild.remove();
}
function levelUp(level) {
    const box = $('levelup');
    $('levelup-num').textContent = level || (state.account ? state.account.level + 1 : '');
    box.classList.add('off');
    void box.offsetWidth;
    box.classList.remove('off');
    later('levelup', 2900, () => box.classList.add('off'));
}

function killPop(d) {
    showHitmarker(true);
    state.streak = d.streak || 0;
    $('killpop-name').textContent = d.victim || '';
    const parts = [];
    if (d.money) parts.push('+' + money(d.money));
    if (state.streak >= 3) parts.push(state.streak + 'er Serie');
    $('killpop-extra').textContent = parts.join('   ');
    restartAnim($('killpop'), 'show');
    if (state.settings.killSound) sounds.kill();
}

// Tod
function mini(kind, label, value, max) {
    const box = el('div', 'mini ' + kind);
    const head = el('span');
    head.append(txt(label), el('b', null, Math.round(value || 0)));
    const bar = el('div', 'bar');
    const fill = el('i');
    fill.style.width = pct(value, max) + '%';
    bar.append(fill);
    box.append(head, bar);
    return box;
}
// Profilbild des Killers: Discord-Bild oder Charakter-Foto, sonst Initialen
function deathPhoto(url) {
    const box = $('death-photo');
    if (!box || !url) return;
    const img = new Image();
    img.onload = () => { box.textContent = ''; box.append(img); box.classList.add('has-img'); };
    img.src = url;
}
function deathProfile(k) {
    const box = $('death-profile');
    box.textContent = '';
    const photo = el('div', 'death-photo', initials(k.name));
    photo.id = 'death-photo';
    if (k.team && k.team.color) paint(photo, k.team.color);
    const who = el('div', 'death-who');
    const nm = el('div', 'death-name');
    nm.append(el('span', null, k.name));
    if (k.id !== undefined && k.id !== null) nm.append(el('span', 'idbadge', 'ID ' + k.id));
    if (k.premium) { const pb = el('span', 'badge gold'); pb.append(icon('gem')); nm.append(pb); }
    if (k.rank) nm.append(paint(el('span', 'rank-tag', k.rank.label), k.rank.color));
    const line = el('div', 'death-team');
    if (k.team) line.append(paint(el('span', 'chip', k.team.tag), k.team.color), txt(k.team.name));
    else line.append(txt('Ohne Team'));
    if (k.booster) { const b = el('span', 'booster-badge'); b.append(icon('gem'), txt('Server Booster')); line.append(b); }
    who.append(nm, line);
    box.append(photo, who, medal(k.level || 1));
    applyBanner(box, k.booster, k.banner, k.accent);
    box.classList.remove('off');
    if (k.avatar) deathPhoto(k.avatar);
}
// Discord-Banner der Server-Booster (oder ihre Profilfarbe, wenn sie kein Banner haben)
function applyBanner(box, booster, banner, accent) {
    box.classList.toggle('boosted', !!booster);
    box.style.removeProperty('--banner');
    box.style.removeProperty('--accent');
    if (!booster) return;
    if (accent && hexRgb(accent)) box.style.setProperty('--accent', accent);
    if (banner) {
        const img = new Image();
        img.onload = () => box.style.setProperty('--banner', `url("${banner}")`);
        img.src = banner;
    }
}
function deathStats(k) {
    const box = $('death-stats');
    box.textContent = '';
    const s = { kills: k.kills, deaths: k.deaths };
    [['Level', num(k.level || 1)], ['K/D', dec(kd(s))], ['Kills', num(k.kills)], ['Tode', num(k.deaths)], ['Serie', num(k.streak)], ['Beste Serie', num(k.best)]]
        .forEach(([label, v]) => { const t = el('div', 'ds'); t.append(el('b', null, v), el('span', null, label)); box.append(t); });
    box.classList.remove('off');
}
function showDeath(d) {
    const box = $('death');
    every('death', 0, null);
    if (!d.show) { box.classList.add('off'); return; }
    state.streak = 0;
    $('lowhp').classList.remove('on');
    const killer = $('death-killer');
    const sub = $('death-sub');
    const vitals = $('death-vitals');
    killer.textContent = ''; sub.textContent = ''; vitals.textContent = '';
    $('death-profile').classList.add('off');
    $('death-stats').classList.add('off');
    if (d.killer) {
        $('death-title').textContent = 'Eliminiert';
        killer.append(el('span', 'by', 'von'), el('span', null, d.killer.name));
        if (d.killer.id !== undefined && d.killer.id !== null) killer.append(el('span', 'id', '#' + d.killer.id));
        if (d.killer.level !== undefined) {
            killer.classList.add('off');              // Name steht schon auf der Profilkarte
            deathProfile(d.killer);
            deathStats(d.killer);
        } else killer.classList.remove('off');
        if (d.weapon) sub.textContent = 'mit ' + nb(d.weapon);
        vitals.append(mini('hp', 'Leben übrig', d.killer.hp, state.config.maxHealth), mini('ar', 'Weste übrig', d.killer.armour, state.config.maxArmour));
        vitals.classList.remove('off');
    } else {
        killer.classList.remove('off');
        $('death-title').textContent = d.cause === 'suicide' ? 'Neustart' : 'Gestorben';
        sub.textContent = d.cause === 'suicide' ? 'Du hast /kill benutzt.' : d.cause === 'fall' ? 'Du bist abgestürzt.' : 'Kein Gegner beteiligt.';
        vitals.classList.add('off');
    }
    box.classList.toggle('duel', !!d.duel);
    if (d.duel) {
        if (d.killer) $('death-title').textContent = 'Runde verloren';
        sub.textContent = (d.weapon ? 'mit ' + nb(d.weapon) + ' – ' : '') + 'gleich geht die nächste Runde los';
        box.classList.remove('off');
        restartAnim($('death-title'), 'death-title');
        return;
    }
    let left = Math.max(0, Math.round(d.seconds || 3));
    const total = Math.max(1, left);
    const ring = $('death-ring');
    $('death-sec').textContent = left;
    ring.style.animationDuration = total + 's';
    ring.classList.remove('run');
    void ring.getBoundingClientRect();
    ring.classList.add('run');
    every('death', 1000, () => {
        left = Math.max(0, left - 1);
        $('death-sec').textContent = left;
        if (left <= 0) every('death', 0, null);
    });
    box.classList.remove('off');
    restartAnim($('death-title'), 'death-title');
}

// Gangwar
const PHASE = { prepare: 'Vorbereitung', fight: 'Kampf', ended: 'Ende' };
function setWar(w) {
    every('war', 0, null);
    const box = $('war');
    if (!w) { box.classList.add('off'); state.war = null; state.lastWarPhase = null; return; }
    const prev = state.war;
    state.war = w;
    box.classList.remove('off');
    box.classList.toggle('prepare', w.phase === 'prepare');
    const att = w.attacker || { tag: '?', points: 0, players: 0, color: '#f23d4f' };
    const def = w.defender || null;
    const a = box.querySelector('.war-side.att');
    const b = box.querySelector('.war-side.def');
    paint(a, att.color, 'side');
    paint(b, def ? def.color : '#42505e', 'side');
    $('war-att-tag').textContent = att.tag;
    $('war-def-tag').textContent = def ? def.tag : 'Frei';
    const setPts = (id, v) => { const n = $(id); if (n.textContent !== String(v)) { n.textContent = v; restartAnim(n, 'bump'); } };
    setPts('war-att-pts', att.points || 0);
    setPts('war-def-pts', def ? def.points || 0 : 0);
    $('war-phase').textContent = PHASE[w.phase] || w.phase;
    $('war-zone').textContent = w.zoneName || '';
    $('war-count').textContent = `${att.players || 0} gegen ${def ? def.players || 0 : 0}`;
    let left = w.remaining || 0;
    $('war-time').textContent = clock(left);
    every('war', 1000, () => { left = Math.max(0, left - 1); $('war-time').textContent = clock(left); });
    // Versus-Einblendung: beim ersten Mal und wenn der Kampf beginnt
    const firstTime = !prev || prev.id !== w.id;
    if ((firstTime && w.phase !== 'ended') || (state.lastWarPhase === 'prepare' && w.phase === 'fight')) versus(att, def, w.zoneName);
    state.lastWarPhase = w.phase;
}
function versus(att, def, zone) {
    const v = $('versus');
    paint(v.querySelector('.vs-band.left'), att.color);
    paint(v.querySelector('.vs-band.right'), def ? def.color : '#42505e');
    v.querySelector('.vs-band.left').style.setProperty('--ink', inkFor(att.color));
    v.querySelector('.vs-band.right').style.setProperty('--ink', inkFor(def ? def.color : '#42505e'));
    $('vs-left').textContent = att.name || att.tag;
    $('vs-right').textContent = def ? (def.name || def.tag) : 'Frei';
    $('vs-zone').textContent = zone || '';
    v.classList.add('off');
    void v.offsetWidth;
    v.classList.remove('off');
    sounds.alert();
    later('versus', 2900, () => v.classList.add('off'));
}
function showWarEnd(r) { if (r && r.text) announce(r.text); }

// Team beigetreten: Wipe in der Teamfarbe
function takeover(t) {
    if (!t) return;
    const box = $('takeover');
    paint(box, t.color);
    box.style.setProperty('--ink', inkFor(t.color));
    const e = $('to-emblem');
    e.textContent = '';
    e.append(emblem(t));
    $('to-name').textContent = t.name;
    $('to-hood').textContent = t.hood || '';
    box.classList.add('off');
    void box.offsetWidth;
    box.classList.remove('off');
    later('takeover', 2000, () => box.classList.add('off'));
}

function showPrompt(d) {
    const p = $('prompt');
    if (!d.show) { p.classList.add('off'); return; }
    $('prompt-key').textContent = d.key || 'E';
    $('prompt-text').textContent = d.text || '';
    if (p.classList.contains('off')) { p.classList.remove('off'); restartAnim(p, 'prompt'); }
}

// ================================================================== Chat
const CHAT_COLORS = { 0: '#ffffff', 1: '#f23d4f', 2: '#22d37b', 3: '#ffc341', 4: '#2f80ff', 5: '#5ad1ff', 6: '#b07cff', 7: '#e9f1f8', 8: '#b4232f', 9: '#ff7ab8' };
const chat = { open: false, channel: 'all', history: [], hIndex: -1, suggestions: [], sel: 0 };

// "^1rot ^7weiß" -> farbige Spans (nur Text, kein HTML)
function colorText(parent, text, base) {
    const parts = String(text).split(/(\^[0-9])/);
    let color = base || null;
    parts.forEach((p) => {
        const m = /^\^([0-9])$/.exec(p);
        if (m) { color = CHAT_COLORS[m[1]]; return; }
        if (!p) return;
        const s = el('span', null, p);
        if (color) s.style.color = color;
        parent.append(s);
    });
}

function addChat(msg) {
    if (!msg) return;
    const log = $('chat-log');
    const row = el('div', 'msg');
    if (msg.kind === 'system') {
        row.append(el('span', 'sys', '[System]'), txt(' : '));
        colorText(row, msg.text);
    } else if (msg.kind === 'plain') {
        colorText(row, msg.text);
    } else if (msg.kind === 'player') {
        if (msg.channel === 'team') row.append(el('span', 'chan', '(Team)'));
        if (msg.rank && msg.rank.label) {
            const r = el('span', 'rank-tag', msg.rank.label);
            paint(r, msg.rank.color);
            row.append(r);
        }
        if (msg.tag) {
            const t = el('span', 'tag', msg.tag);
            paint(t, msg.color);
            row.append(t);
        }
        const who = el('span', 'who', msg.name);
        if (hexRgb(msg.color)) who.style.color = msg.color;
        row.append(who);
        if (msg.uid !== undefined && msg.uid !== null) row.append(el('span', 'id', '#' + msg.uid));
        row.append(txt(': '));
        row.append(el('span', null, msg.text));
    } else {
        if (msg.name) {
            const who = el('span', 'who', msg.name);
            if (hexRgb(msg.color)) who.style.color = msg.color;
            row.append(who, txt(': '));
        }
        colorText(row, msg.text);
    }
    log.append(row);
    while (log.children.length > 60) log.firstChild.remove();
    log.scrollTop = log.scrollHeight;
    // Solange das HUD noch versteckt ist (Login, Teamwahl), läuft die Zeit erst ab, wenn man es sieht
    if ($('hud').classList.contains('off')) chatPending.push(row); else fadeLater(row);
}
const chatPending = [];
function fadeLater(row) {
    if (state.settings.chatFade) setTimeout(() => row.classList.add('faded'), (state.config.chat.fadeSeconds || 10) * 1000);
}

function setChannel(ch) {
    chat.channel = ch === 'team' ? 'team' : 'all';
    const b = $('chat-channel');
    b.textContent = chat.channel === 'team' ? 'Team' : 'Alle';
    b.classList.toggle('team', chat.channel === 'team');
}
function openChat(channel) {
    chat.open = true;
    setChannel(channel || chat.channel);
    $('chat').classList.add('open');
    $('chat-box').classList.remove('off');
    $('chat-hint').classList.remove('off');
    const input = $('chat-text');
    input.maxLength = state.config.chat.maxLength || 150;
    input.value = '';
    chat.hIndex = -1;
    setTimeout(() => input.focus(), 10);
    renderSuggest();
    const log = $('chat-log');
    log.scrollTop = log.scrollHeight;
}
function closeChat() {
    chat.open = false;
    $('chat').classList.remove('open');
    $('chat-box').classList.add('off');
    $('chat-hint').classList.add('off');
    $('chat-suggest').classList.add('off');
    $('chat-text').blur();
}
function sendChat() {
    const text = $('chat-text').value.trim();
    if (text) {
        chat.history.unshift(text);
        if (chat.history.length > 30) chat.history.pop();
    }
    closeChat();
    post('chatSend', { text, channel: chat.channel });
}
function matches() {
    const v = $('chat-text').value;
    if (!v.startsWith('/')) return [];
    const word = v.split(' ')[0].toLowerCase();
    return chat.suggestions.filter((s) => s.name.toLowerCase().startsWith(word)).slice(0, 6);
}
function renderSuggest() {
    const box = $('chat-suggest');
    const list = matches();
    box.textContent = '';
    if (!chat.open || list.length === 0) { box.classList.add('off'); return; }
    chat.sel = Math.min(chat.sel, list.length - 1);
    list.forEach((s, i) => {
        const r = el('div', 'sug' + (i === chat.sel ? ' sel' : ''));
        r.append(el('b', null, s.name));
        (s.params || []).forEach((p) => r.append(el('span', 'param', '[' + p.name + ']')));
        if (s.help) r.append(el('span', null, s.help));
        box.append(r);
    });
    box.classList.remove('off');
}
$('chat-text').addEventListener('input', () => { chat.sel = 0; renderSuggest(); });
$('chat-text').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); sendChat(); }
    else if (e.key === 'Escape') { e.preventDefault(); closeChat(); post('chatClose', { channel: chat.channel }); }
    else if (e.key === 'Tab') {
        e.preventDefault();
        const list = matches();
        const v = $('chat-text').value;
        if (list.length && !v.includes(' ')) { $('chat-text').value = list[chat.sel].name + ' '; renderSuggest(); }
        else setChannel(chat.channel === 'team' ? 'all' : 'team');
    } else if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        const list = matches();
        e.preventDefault();
        if (list.length) {
            chat.sel = (chat.sel + (e.key === 'ArrowUp' ? -1 : 1) + list.length) % list.length;
            renderSuggest();
        } else if (chat.history.length) {
            chat.hIndex = Math.max(-1, Math.min(chat.history.length - 1, chat.hIndex + (e.key === 'ArrowUp' ? 1 : -1)));
            $('chat-text').value = chat.hIndex >= 0 ? chat.history[chat.hIndex] : '';
        }
    }
});
$('chat-channel').addEventListener('click', () => { setChannel(chat.channel === 'team' ? 'all' : 'team'); $('chat-text').focus(); });

// ================================================================== Bildschirme
const SCREENS = ['login', 'teams', 'menu', 'garage', 'admin', 'wardrobe', 'help'];
function showScreen(name) {
    SCREENS.forEach((s) => {
        const node = $('scr-' + s);
        if (s === name) {
            node.classList.remove('off', 'leaving');
        } else if (!node.classList.contains('off')) {
            node.classList.add('off');
        }
    });
    state.screen = name;
    document.body.classList.add('screen-open');
    if (chat.open) closeChat();
}
function hideScreen(name) {
    const node = $('scr-' + name);
    if (!node || node.classList.contains('off')) return;
    node.classList.add('leaving');
    setTimeout(() => { node.classList.add('off'); node.classList.remove('leaving'); }, 220);
    if (state.screen === name) { state.screen = null; document.body.classList.remove('screen-open'); }
    if (name === 'menu') { stopMapAnim(); const op = $('opener'); if (op && !op.classList.contains('off') && !window.openerBusy && typeof closeOpener === 'function') closeOpener(); }
}
function hideAll() { SCREENS.forEach(hideScreen); state.screen = null; document.body.classList.remove('screen-open'); }

function panelHead(title, extra, closable, screen) {
    const head = el('div', 'panel-head');
    head.append(logo(), el('div', 'head-sep'), el('span', 'panel-title', title));
    const grow = el('div', 'grow');
    head.append(grow);
    (extra || []).forEach((n) => head.append(n));
    if (closable) head.append(iconBtn('x', 'close', () => post('closeScreen', { screen }), 'Schließen'));
    return head;
}

// ---------------------------------------------------------- Modus-Auswahl (Login)
function xpBlock(a) {
    const max = a.level >= a.maxLevel;
    const wrap = el('div', 'pc-xp');
    const bar = el('div', 'bar');
    const fill = el('i');
    bar.append(fill);
    requestAnimationFrame(() => requestAnimationFrame(() => { fill.style.width = (max ? 100 : Math.round((a.progress || 0) * 100)) + '%'; }));
    const lab = el('div', 'bar-label');
    lab.append(el('span', null, max ? 'Maximales Level' : `${num((a.progress || 0) * a.xpPerLevel)} / ${num(a.xpPerLevel)} XP`), el('span', null, money(a.money)));
    wrap.append(bar, lab);
    return wrap;
}
function medal(level) {
    const m = el('div', 'medal', level);
    m.append(el('span', null, 'LVL'));
    return m;
}
function showLogin(d) {
    state.login = d;
    const scr = $('scr-login');
    scr.textContent = '';
    const wrap = el('div', 'login-wrap');
    const hero = el('div', 'login-hero');
    hero.append(reticle(21));
    wrap.append(hero);
    const panel = el('div', 'panel login');
    panel.append(panelHead('Modus-Auswahl', [], false));
    const body = el('div', 'login-body');

    const known = !!(d.registered && d.account);
    let nameInput = null;
    let refInput = null;
    if (known) {
        const a = d.account;
        const card = el('div', 'player-card');
        const mid = el('div');
        const nm = el('div', 'pc-name');
        nm.append(txt(a.name), el('span', 'idbadge', 'ID ' + a.id));
        mid.append(nm, xpBlock(a));
        card.append(el('div', 'avatar', initials(a.name)), mid, medal(a.level));
        body.append(card);
    } else {
        const card = el('div', 'player-card');
        const mid = el('div', 'form');
        mid.append(el('div', 'card-title', 'Neu hier? Wähl deinen Namen'));
        const f = el('label', 'field');
        nameInput = el('input', 'input');
        nameInput.maxLength = d.nameMax || 16;
        nameInput.value = d.suggestedName || '';
        nameInput.placeholder = 'Spielername';
        f.append(nameInput, el('span', 'field-label', `${d.nameMin || 3} bis ${d.nameMax || 16} Zeichen: Buchstaben ohne Umlaute, Zahlen und _`));
        mid.append(f);
        // Einladungs-Code = User-ID von dem, der einen eingeladen hat
        const rf = el('label', 'field');
        refInput = el('input', 'input');
        refInput.maxLength = 8;
        refInput.inputMode = 'numeric';
        refInput.placeholder = 'Einladungs-Code (optional)';
        rf.append(refInput, el('span', 'field-label', 'User-ID von dem, der dich eingeladen hat'));
        mid.append(rf);
        card.style.gridTemplateColumns = 'auto 1fr';
        card.append(el('div', 'avatar', '?'), mid);
        body.append(card);
        setTimeout(() => nameInput.focus(), 80);
    }

    body.append(el('div', 'section-label', 'Modi'));
    const err = el('div', 'login-error', d.noLicense ? 'Keine Rockstar-Lizenz gefunden. Starte FiveM neu und verbinde dich noch einmal.' : '');
    err.id = 'login-error';
    const go = () => {
        err.textContent = '';
        if (known) { post('login'); return; }
        const name = nameInput.value.trim();
        const min = d.nameMin || 3, max = d.nameMax || 16;
        if (!new RegExp(`^[A-Za-z0-9_]{${min},${max}}$`).test(name)) {
            err.textContent = `Der Name braucht ${min} bis ${max} Zeichen: Buchstaben ohne Umlaute, Zahlen und _.`;
            return;
        }
        post('register', { name, ref: refInput ? refInput.value.replace(/\D/g, '') : '' });
    };
    const modes = el('div', 'grid');
    (d.modes || [{ key: 'bodyshot', name: 'Bodyshot', online: 0 }]).forEach((m) => {
        const row = el('div', 'mode-row');
        const ic = el('div', 'mode-icon');
        ic.append(icon('crosshair'));
        const t = el('div');
        t.append(el('div', 'mode-name', `${m.name} Gangwar`), el('div', 'mode-desc', 'Nur Langwaffen, 14 bis 17 Treffer bis zum Kill, Gangs und Gebiete'));
        const on = el('span', 'badge green');
        on.append(el('i', 'dot'), txt(`${m.online || 0} online`));
        row.append(ic, t, on, btn(known ? 'Betreten' : 'Account erstellen', 'primary', go, false, 'log-in'));
        modes.append(row);
    });
    body.append(stagger(modes));
    if (d.notice && d.notice.title) {
        const n = el('div', 'notice');
        const t = el('div');
        t.append(el('b', null, d.notice.title), el('p', null, d.notice.text));
        n.append(icon('video'), t);
        body.append(n);
    }
    body.append(err);
    panel.append(body);
    wrap.append(panel);
    scr.append(wrap);
    if (nameInput) nameInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
    showScreen('login');
}

// ---------------------------------------------------------- Teams (F1)
function seg(options, value, onChange) {
    const s = el('div', 'seg');
    const pill = el('i', 'seg-pill');
    s.append(pill);
    const buttons = options.map(([key, label]) => {
        const b = el('button', key === value ? 'on' : '', label);
        b.type = 'button';
        b.addEventListener('click', () => {
            click();
            buttons.forEach((x) => x.classList.toggle('on', x === b));
            move(b);
            onChange(key);
        });
        s.append(b);
        return b;
    });
    const move = (b) => { pill.style.left = b.offsetLeft + 'px'; pill.style.width = b.offsetWidth + 'px'; };
    requestAnimationFrame(() => { const on = buttons.find((b) => b.classList.contains('on')) || buttons[0]; pill.style.transition = 'none'; move(on); requestAnimationFrame(() => { pill.style.transition = ''; }); });
    return s;
}
function teamCard(t, kind, d) {
    const key = kind + ':' + t.id;
    const card = el('div', 'team-card');
    paint(card, t.color);
    const current = d.current === key;
    if (current) card.classList.add('current');
    const top = el('div', 'tc-top');
    const left = el('div');
    const label = el('div', 'tc-label');
    if (current) label.append(icon('circle-check'), txt('Dein Team'));
    else label.textContent = kind === 'private' ? 'Privates Team' : 'Team';
    left.append(label, el('div', 'tc-name', t.name));
    const max = t.max || 0;
    const count = el('span', 'badge green');
    count.append(el('i', 'dot'), txt(max > 0 ? `${t.online || 0}/${max}` : `${t.online || 0}`));
    top.append(left, count);
    const em = el('div', 'tc-emblem');
    em.append(emblem({ id: t.id, kind, tag: t.tag, color: t.color, name: t.name }));
    const meta = el('div', 'tc-meta');
    const hood = el('span'); hood.append(icon('house'), txt(t.hood || 'Hood'));
    const zones = el('span'); zones.append(icon('flag'), txt(`${t.zones || 0} ${plural(t.zones || 0, 'Gebiet', 'Gebiete')}`));
    meta.append(hood, zones);
    if (kind === 'private') { const m = el('span'); m.append(icon('users'), txt(`${t.members || 0}`)); meta.append(m); }
    let b;
    if (kind === 'private' && !t.member) {
        b = btn('Nur Mitglieder', 'block', null, true, 'lock');
    } else if (t.full) {
        b = btn('Voll', 'block', null, true);
    } else {
        b = btn(current && state.mode === 'lobby' ? 'Bleiben' : 'Betreten', 'primary block', () => {
            post('selectTeam', { kind, id: t.id });
            document.querySelectorAll('#scr-teams .btn.primary').forEach((x) => { x.disabled = true; });
            setTimeout(() => document.querySelectorAll('#scr-teams .btn.primary').forEach((x) => { x.disabled = false; }), 1500);
        }, false, 'log-in');
    }
    card.append(top, em, meta, b);
    return card;
}
// Eigenes Team direkt hier in F1 gründen (auch gleich nach dem Login)
function createTeamCard(d) {
    const card = el('div', 'team-card create form-card');
    card.append(icon('plus'), el('div', 'tc-name', 'Eigenes Team'));
    const short = (d.createPrice || 0) - (d.money || 0);
    card.append(el('div', 'muted', `Kostet ${money(d.createPrice)}. Bis zu ${d.maxMembers || 15} Mitglieder, eigene Hood und Farbe.`));
    const name = el('input', 'input'); name.maxLength = 20; name.placeholder = 'Teamname, z. B. Grove Kings';
    const tag = el('input', 'input'); tag.maxLength = 4; tag.placeholder = 'Kürzel, z. B. GK';
    let color = (d.colors || [])[0] || '#2f80ff';
    const sws = el('div', 'swatches');
    (d.colors || []).forEach((c, i) => {
        const s = el('button', 'sw' + (i === 0 ? ' sel' : ''));
        s.type = 'button';
        paint(s, c);
        s.addEventListener('click', () => { click(); color = c; sws.querySelectorAll('.sw').forEach((x) => x.classList.remove('sel')); s.classList.add('sel'); });
        sws.append(s);
    });
    const go = btn(short > 0 ? 'Dir fehlen ' + money(short) : 'Gründen für ' + money(d.createPrice), short > 0 ? 'block' : 'primary block', () => {
        post('createTeam', { name: name.value.trim(), tag: tag.value.trim(), color });
        go.disabled = true;
        setTimeout(() => { go.disabled = false; }, 1500);
    }, short > 0, short > 0 ? null : 'plus');
    card.append(name, tag, sws, go);
    return card;
}
function renderTeamsGrid() {
    const st = state.teams;
    const grid = $('teams-grid');
    if (!grid || !st) return;
    grid.textContent = '';
    const q = (st.q || '').toLowerCase();
    const hit = (t) => !q || String(t.name).toLowerCase().includes(q) || String(t.tag).toLowerCase().includes(q);
    if (st.tab === 'private') {
        if (st.data.canCreate && !q) grid.append(createTeamCard(st.data));
        (st.data.private || []).filter(hit).forEach((t) => grid.append(teamCard(t, 'private', st.data)));
        if (!grid.children.length) grid.append(el('div', 'empty', q ? 'Kein Team gefunden.' : 'Noch keine privaten Teams.'));
    } else {
        (st.data.gangs || []).filter(hit).forEach((t) => grid.append(teamCard(t, 'gang', st.data)));
        if (!grid.children.length) grid.append(el('div', 'empty', 'Kein Team gefunden.'));
    }
    grid.classList.remove('stagger');
    void grid.offsetWidth;
    stagger(grid);
}
function showTeams(d, closable) {
    const prevTab = state.teams && state.teams.tab;
    state.teams = { data: d, closable: !!closable, tab: prevTab || ((d.current || '').startsWith('private:') ? 'private' : 'public'), q: '' };
    const scr = $('scr-teams');
    scr.textContent = '';
    const panel = el('div', 'panel teams');
    const search = el('label', 'search');
    const si = el('input', 'input');
    si.placeholder = 'Team suchen';
    si.addEventListener('input', () => { state.teams.q = si.value; renderTeamsGrid(); });
    search.append(icon('search'), si);
    const tabs = seg([['public', 'Öffentlich'], ['private', 'Privat']], state.teams.tab, (k) => { state.teams.tab = k; renderTeamsGrid(); });
    panel.append(panelHead('Teams', [search, tabs], closable, 'teams'));
    const grid = el('div', 'teams-grid');
    grid.id = 'teams-grid';
    panel.append(grid);
    scr.append(panel);
    showScreen('teams');
    renderTeamsGrid();
}

// ================================================================== Hauptmenü (F2)
const NAV = [
    ['Kämpfen', [['ffa', 'Free for all', 'crosshair'], ['gangwar', 'Gangwar', 'flag'], ['duels', '1v1-Duelle', 'swords']]],
    ['Belohnungen', [['daily', 'Täglich', 'calendar'], ['wheel', 'Glücksrad', 'disc-3'], ['cases', 'Cases & Skins', 'package'], ['bp', 'Battlepass', 'ticket'], ['shop', 'Waffenshop', 'shopping-cart']]],
    ['Server', [['referral', 'Einladen', 'user-plus'], ['bounty', 'Kopfgeld', 'target'], ['top', 'Rangliste', 'trophy'], ['players', 'Spieler', 'users'], ['rules', 'Regelwerk', 'scroll-text']]],
    ['Du', [['inventory', 'Inventar', 'box'], ['emotes', 'Emotes & Tänze', 'sparkles'], ['team', 'Team', 'shield'], ['profile', 'Profil', 'circle-user'], ['settings', 'Einstellungen', 'settings'], ['discord', 'Discord', 'discord']]],
];
const PAGE_TITLES = {
    ffa: ['Free for all', 'Jeder gegen jeden. Wähl eine Arena.'],
    gangwar: ['Gangwar', 'Greif Gebiete an und verteidige, was deinem Team gehört.'],
    top: ['Rangliste', 'Die zehn Spieler mit den meisten Kills.'],
    rules: ['Regelwerk', 'Wer sich nicht daran hält, fliegt.'],
    players: ['Spieler', 'Wer gerade online ist.'],
    team: ['Team', 'Dein Team und dein privates Team.'],
    shop: ['Waffenshop', 'Einmal kaufen, für immer im Loadout.'],
    inventory: ['Inventar', 'Alles, was dir gehört. Deine Waffen hast du immer dabei.'],
    wheel: ['Glücksrad', 'Einmal am Tag drehen – Geld, XP, Cases, Waffen oder Premium.'],
    referral: ['Einladen', 'Lade Freunde ein: Sie geben bei der Registrierung deine User-ID ein.'],
    emotes: ['Emotes & Tänze', 'Klick drauf oder schreib /e <name>. Bewegen bricht ab. Taste K öffnet diese Seite.'],
    bp: ['Battlepass', 'XP gibt es für Kills und Gangwars.'],
    settings: ['Einstellungen', 'Gilt nur für dich und bleibt gespeichert.'],
    profile: ['Profil', 'Deine Werte auf diesem Server.'],
    daily: ['Täglich', 'Jeden Tag drei Missionen und ein Bonus fürs Einloggen.'],
    cases: ['Cases & Skins', 'Echte GTA-Lackierungen für deine Waffen. Einmal gezogen, für immer deins.'],
    duels: ['1v1-Duelle', 'Fordere jemanden heraus. Best of 3, eigene Arena, gleiche Waffe.'],
    bounty: ['Kopfgeld', 'Setz Geld auf einen Kopf. Wer ihn im FFA oder Gangwar erwischt, kassiert.'],
};
const RENDER = {};
let mapAnim = null;
function stopMapAnim() { if (mapAnim) { cancelAnimationFrame(mapAnim); mapAnim = null; } }

// Profilbild: Discord-Bild, sonst Initialen
function avatarFor(a) {
    const av = el('div', 'avatar', initials(a.name));
    const url = a.discord && a.discord.avatar;
    if (url) {
        const img = new Image();
        img.onload = () => { av.textContent = ''; av.classList.add('img'); av.append(img); };
        img.src = url;
    }
    return av;
}
function renderSideMe() {
    const box = $('side-me');
    const a = state.menu && state.menu.account;
    if (!box || !a) return;
    box.textContent = '';
    const t = el('div');
    const meta = el('span', 'me-meta');
    meta.append(el('span', null, 'ID ' + a.id), el('span', null, 'LVL ' + a.level), el('span', 'me-money', money(a.money)));
    t.append(el('b', null, a.name), meta);
    box.append(avatarFor(a), t);
}
function moveNavPill(animate) {
    const nav = $('nav');
    const pill = $('nav-pill');
    const on = nav && nav.querySelector('button.on');
    if (!on || !pill) return;
    if (!animate) pill.style.transition = 'none';
    pill.style.top = on.offsetTop + 'px';
    pill.style.height = on.offsetHeight + 'px';
    if (!animate) requestAnimationFrame(() => { pill.style.transition = ''; });
}
function buildMenu() {
    const scr = $('scr-menu');
    scr.textContent = '';
    const panel = el('div', 'panel menu');
    const side = el('aside', 'side');
    const brand = el('div', 'side-brand');
    brand.append(reticle(10.5));
    side.append(brand);
    const nav = el('nav', 'nav');
    nav.id = 'nav';
    const pill = el('i', 'nav-pill');
    pill.id = 'nav-pill';
    nav.append(pill);
    NAV.forEach(([group, items]) => {
        nav.append(el('div', 'nav-group', group));
        items.forEach(([key, label, ic]) => {
            const b = el('button');
            b.type = 'button';
            b.dataset.page = key;
            b.append(icon(ic), txt(label));
            const pip = el('span', 'pip off');
            pip.dataset.pip = key;
            b.append(pip);
            b.addEventListener('click', () => {
                click();
                if (key === 'discord') { openUrl(state.menu && state.menu.discord || state.config.discord); return; }
                openPage(key);
            });
            if (key === 'discord' && !(state.config.discord)) b.classList.add('off');
            nav.append(b);
        });
    });
    const me = el('div', 'side-me');
    me.id = 'side-me';
    side.append(nav, me);
    const main = el('section', 'main');
    const head = el('div', 'main-head');
    const titles = el('div', 'grow');
    const t1 = el('div', 'main-title');
    t1.id = 'main-title';
    const t2 = el('div', 'main-sub');
    t2.id = 'main-sub';
    titles.append(t1, t2);
    const where = el('div', 'where');
    where.id = 'menu-where';
    head.append(titles, where, iconBtn('x', 'close', () => post('closeScreen', { screen: 'menu' }), 'Schließen'));
    const body = el('div', 'main-body');
    body.id = 'main-body';
    main.append(head, body);
    panel.append(side, main);
    scr.append(panel);
}
function renderWhere() {
    const w = $('menu-where');
    const d = state.menu;
    if (!w || !d) return;
    w.textContent = '';
    w.className = 'where';
    if (d.mode === 'lobby' && !state.config.hoodCombat) {
        w.classList.add('safe');
        w.append(icon('shield-check'), el('b', null, d.lobby ? d.lobby.name : 'Hood'), txt('Safezone'));
    } else if (d.mode === 'lobby') {
        w.classList.add('fight');
        w.append(icon('house'), el('b', null, d.lobby ? d.lobby.name : 'Hood'), txt('Kampfzone'));
    } else {
        w.classList.add('fight');
        w.append(icon(d.mode === 'ffa' ? 'crosshair' : 'swords'), el('b', null, MODE_TEXT[d.mode] || d.mode));
    }
}
// Rote/goldene Punkte in der Navigation: etwas abzuholen, ungeöffnete Cases, Herausforderung
function renderPips() {
    const a = (state.menu && state.menu.account) || state.account || {};
    const d = state.menu || {};
    const set = (key, n, cls) => {
        const p = document.querySelector(`#nav .pip[data-pip="${key}"]`);
        if (!p) return;
        p.className = 'pip' + (cls ? ' ' + cls : '') + (n > 0 ? '' : ' off');
        p.textContent = n > 9 ? '9+' : String(n);
    };
    set('daily', a.daily || 0);
    set('cases', a.cases || 0, 'gold');
    set('duels', d.duels && d.duels.incoming ? 1 : 0);
    set('bounty', a.bounty > 0 ? 1 : 0);
}
function openPage(page) {
    if (!RENDER[page]) return;
    const same = state.page === page;
    state.page = page;
    renderMenu(!same);
}
function renderMenu(fresh) {
    const d = state.menu;
    if (!d) return;
    if (d.account) setAccount(d.account);
    if (d.team && d.team.current) setTheme(d.team.current.color);
    document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('on', b.dataset.page === state.page));
    moveNavPill(true);
    const [title, sub] = PAGE_TITLES[state.page] || ['', ''];
    $('main-title').textContent = title;
    $('main-sub').textContent = sub;
    renderWhere();
    renderSideMe();
    renderPips();
    stopMapAnim();
    const body = $('main-body');
    const scroll = fresh ? 0 : body.scrollTop;
    body.textContent = '';
    const page = el('div', fresh ? 'page' : '');
    RENDER[state.page](d, page);
    body.append(page);
    body.scrollTop = scroll;
}

// Zeiten im Menü laufen live weiter
const live = [];
let refreshQueued = false;
function liveClock(node, seconds, format) {
    const until = Date.now() + Math.max(0, seconds || 0) * 1000;
    let done = false;
    const update = () => {
        const left = Math.max(0, Math.ceil((until - Date.now()) / 1000));
        node.textContent = format(clock(left));
        if (left <= 0 && !done) {
            done = true;
            if (!refreshQueued) { refreshQueued = true; setTimeout(() => { refreshQueued = false; if (state.screen === 'menu') post('refresh'); }, 1500); }
        }
    };
    update();
    live.push(update);
}
setInterval(() => { if (state.screen === 'menu') live.forEach((f) => f()); }, 1000);

// ---------------------------------------------------------- Free for all
function arenaArt(box, a) {
    const img = new Image();
    let usedImg = false;
    img.onload = () => { usedImg = true; box.textContent = ''; box.append(img); };
    img.src = `img/ffa/${a.key}.jpg`;
    requestAnimationFrame(() => {
        if (usedImg) return;
        const { c, fit } = canvasFor(box);
        const dpr = fit();
        const ctx = c.getContext('2d');
        const w = c.width, h = c.height;
        const center = { x: a.x || 0, y: a.y || 0, r: a.radius || 60 };
        const mpp = Math.max(2.4, center.r / (0.2 * h / dpr)) / dpr;
        drawRoads(ctx, w, h, { cx: center.x, cy: center.y, mpp }, true);
        const r = center.r / mpp;
        const g = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, r);
        g.addColorStop(0, 'rgba(242,61,79,0.05)');
        g.addColorStop(1, 'rgba(242,61,79,0.32)');
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(w / 2, h / 2, r, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = 'rgba(255,90,105,0.95)';
        ctx.lineWidth = 2 * dpr;
        ctx.setLineDash([6 * dpr, 4 * dpr]);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = '#fff';
        ctx.beginPath(); ctx.arc(w / 2, h / 2, 3 * dpr, 0, Math.PI * 2); ctx.fill();
    });
}
RENDER.ffa = (d, page) => {
    const tools = el('div', 'page-tools');
    const inside = (d.arenas || []).find((a) => a.inside);
    if (d.mode === 'duel') tools.append(confirmBtn('Duell aufgeben', 'Wirklich aufgeben?', 'ghost', () => action('duelLeave'), 'flag'));
    else if (d.mode !== 'lobby') tools.append(btn('Zurück zur Hood', 'ghost', () => action('toLobby'), false, 'house'));
    tools.append(el('span', 'muted', d.mode === 'gangwar' ? 'Aus dem Gangwar geht es erst zurück zur Hood.' : inside ? `Du bist in ${inside.name}. Wechseln geht direkt.` : 'Kills geben Geld und XP. Jeder Kill heilt dich voll.'));
    page.append(tools);
    const grid = el('div', 'grid c3');
    (d.arenas || []).forEach((a) => {
        const card = el('div', 'card arena hover-lift' + (a.inside ? ' inside' : ''));
        const art = el('div', 'arena-img');
        arenaArt(art, a);
        const full = a.max > 0 && a.players >= a.max && !a.inside;
        const count = el('span', 'badge ' + (full ? 'red' : 'green'));
        count.append(el('i', 'dot'), txt(a.max > 0 ? `${a.players}/${a.max}` : `${a.players}`));
        const bodyRow = el('div', 'arena-body');
        const t = el('div', 'grow');
        t.append(el('div', 'arena-name', a.name), el('div', 'arena-sub', a.players === 0 ? 'Gerade leer' : `${a.players} ${plural(a.players, 'Spieler', 'Spieler')} drin`));
        let b;
        if (a.inside) b = btn('Du bist hier', 'small', null, true);
        else if (full) b = btn('Voll', 'small', null, true);
        else b = btn('Betreten', 'primary small', () => action('joinFFA', { index: a.index }), d.mode === 'gangwar', 'log-in');
        bodyRow.append(t, b);
        card.append(art, count, bodyRow);
        grid.append(card);
    });
    page.append(stagger(grid));
};

// ---------------------------------------------------------- Gangwar
function rulesLine(r) {
    if (!r) return '';
    let s = `${r.pointsPerKill} ${plural(r.pointsPerKill, 'Punkt', 'Punkte')} pro Kill in der Zone, ${r.fightMinutes} Minuten Kampfzeit.`;
    if (r.incomePerZone > 0 && r.incomeMinutes > 0) s += ` Jedes Gebiet zahlt ${money(r.incomePerZone)} alle ${r.incomeMinutes} Minuten an alle im Team.`;
    return s;
}
function zoneRow(z) {
    const row = el('div', 'zone' + (z.war ? ' fighting' : ''));
    paint(row, z.owner ? z.owner.color : '#42505e');
    const info = el('div');
    info.append(el('div', 'zone-name', z.name));
    const line = el('div', 'zone-line');
    if (z.owner) { const chip = paint(el('span', 'chip', z.owner.tag), z.owner.color); line.append(chip, el('span', null, z.owner.name)); }
    else line.append(el('span', null, 'Frei'));
    const act = el('div', 'zone-act');
    if (z.war) {
        const w = z.war;
        const att = w.attacker || { tag: '?', points: 0 };
        const def = w.defender;
        const time = el('span');
        const label = w.phase === 'prepare' ? 'Vorbereitung ' : w.phase === 'fight' ? 'Kampf ' : 'Ende ';
        liveClock(time, w.remaining, (t) => label + t);
        line.append(time);
        act.append(el('span', 'score', `${att.tag} ${att.points} : ${def ? def.points : 0} ${def ? def.tag : 'Frei'}`));
        if (w.inside) act.append(btn('Du kämpfst hier', 'small', null, true));
        else if (w.mySide === 'attacker') act.append(btn('Beitreten', 'primary small', () => action('gwJoin', { zone: z.key }), false, 'swords'));
        else if (w.mySide === 'defender') act.append(btn('Verteidigen', 'danger small', () => action('gwJoin', { zone: z.key }), false, 'shield'));
        else act.append(el('span', 'why', 'Andere Teams kämpfen hier.'));
    } else {
        if (z.cooldown > 0) { const c = el('span'); liveClock(c, z.cooldown, (t) => 'Gesperrt ' + t); line.append(c); }
        else if (z.mine) line.append(el('span', 'badge green', 'Gehört euch'));
        if (z.canAttack) act.append(btn('Angreifen', 'go small', () => action('gwAttack', { zone: z.key }), false, 'swords'));
        else if (!z.mine) {
            act.append(btn('Angreifen', 'small', null, true));
            if (z.reason && z.cooldown <= 0) act.append(el('span', 'why', z.reason));
        }
    }
    info.append(line);
    row.append(el('i', 'zbar'), info, act);
    return row;
}
function zoneMap(box, d) {
    const zones = d.zones || [];
    const pts = zones.map((z) => ({ x: z.x, y: z.y, r: z.radius || 80 }));
    const hoods = (d.hoods || []).slice();
    if (d.lobby) pts.push({ x: d.lobby.x, y: d.lobby.y, r: 60 });
    const { c, fit } = canvasFor(box);
    requestAnimationFrame(() => {
        const dpr = fit();
        const w = c.width, h = c.height;
        if (!pts.length) return;
        const xs = pts.map((p) => p.x), ys = pts.map((p) => p.y);
        const minX = Math.min(...xs) - 400, maxX = Math.max(...xs) + 400, minY = Math.min(...ys) - 400, maxY = Math.max(...ys) + 400;
        const view = { cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, mpp: Math.max((maxX - minX) / w, (maxY - minY) / h) };
        const base = document.createElement('canvas');
        base.width = w; base.height = h;
        drawRoads(base.getContext('2d'), w, h, view, true);
        const P = (x, y) => [w / 2 + (x - view.cx) / view.mpp, h / 2 - (y - view.cy) / view.mpp];
        const ctx = c.getContext('2d');
        const myKey = d.team && d.team.current ? d.team.current.key : null;
        const frame = (now) => {
            ctx.drawImage(base, 0, 0);
            zones.forEach((z) => {
                const [x, y] = P(z.x, z.y);
                const r = Math.max(7 * dpr, (z.radius || 80) / view.mpp);
                const col = z.owner ? z.owner.color : '#8b9aab';
                if (z.war) {
                    const k = (now / 1200) % 1;
                    ctx.strokeStyle = rgba('#f23d4f', 0.8 * (1 - k));
                    ctx.lineWidth = 2 * dpr;
                    ctx.beginPath(); ctx.arc(x, y, r + k * 26 * dpr, 0, Math.PI * 2); ctx.stroke();
                }
                ctx.fillStyle = rgba(col, z.owner ? 0.35 : 0.15);
                ctx.strokeStyle = rgba(col, 0.95);
                ctx.lineWidth = (z.mine ? 3 : 1.6) * dpr;
                ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
            });
            ctx.font = `600 ${13 * dpr}px Rajdhani`;
            ctx.textBaseline = 'middle';
            zones.forEach((z) => {
                const [x, y] = P(z.x, z.y);
                const r = Math.max(7 * dpr, (z.radius || 80) / view.mpp);
                const label = z.name;
                const tw = ctx.measureText(label).width;
                const right = x + r + 6 * dpr + tw < w - 4;
                const tx = right ? x + r + 6 * dpr : x - r - 6 * dpr - tw;
                ctx.fillStyle = 'rgba(5,9,13,0.75)';
                ctx.fillRect(tx - 4 * dpr, y - 9 * dpr, tw + 8 * dpr, 18 * dpr);
                ctx.fillStyle = z.war ? '#ff8794' : '#e9f1f8';
                ctx.fillText(label, tx, y);
            });
            hoods.forEach((hd) => {
                const [x, y] = P(hd.x, hd.y);
                if (x < 0 || y < 0 || x > w || y > h) return;
                const mine = hd.key === myKey;
                ctx.save();
                ctx.translate(x, y);
                ctx.rotate(Math.PI / 4);
                ctx.fillStyle = hd.color || '#fff';
                const s = (mine ? 7 : 4.5) * dpr;
                ctx.fillRect(-s, -s, s * 2, s * 2);
                if (mine) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 2 * dpr; ctx.strokeRect(-s, -s, s * 2, s * 2); }
                ctx.restore();
            });
            if (zones.some((z) => z.war)) mapAnim = requestAnimationFrame(frame);
        };
        stopMapAnim();
        mapAnim = requestAnimationFrame(frame);
    });
}
RENDER.gangwar = (d, page) => {
    page.append(el('div', 'rules-line', rulesLine(d.rules)));
    const wrap = el('div', 'gw');
    const list = el('div');
    (d.zones || []).forEach((z) => list.append(zoneRow(z)));
    if (!(d.zones || []).length) list.append(el('div', 'empty', 'Keine Gebiete eingestellt.'));
    const mapbox = el('div', 'mapbox');
    const cv = el('div');
    cv.style.height = '52rem';
    cv.style.position = 'relative';
    mapbox.append(cv);
    const legend = el('div', 'legend');
    const seen = {};
    (d.zones || []).forEach((z) => {
        if (z.owner && !seen[z.owner.tag]) {
            seen[z.owner.tag] = true;
            const s = el('span'); const i = el('i'); paint(i, z.owner.color); s.append(i, txt(z.owner.tag)); legend.append(s);
        }
    });
    const f = el('span'); const fi = el('i'); paint(fi, '#8b9aab'); f.append(fi, txt('Frei')); legend.append(f);
    const hh = el('span'); hh.append(icon('house'), txt('Hoods')); legend.append(hh);
    mapbox.append(legend);
    wrap.append(stagger(list), mapbox);
    page.append(wrap);
    zoneMap(cv, d);
};

// ---------------------------------------------------------- Rangliste
RENDER.top = (d, page) => {
    const table = el('table', 'table');
    const head = el('tr');
    ['Platz', 'Spieler', 'Kills', 'K/D', 'Level', 'Gangwar-Siege'].forEach((h, i) => head.append(el('th', i >= 2 ? 'num' : null, h)));
    table.append(head);
    (d.top || []).forEach((e, i) => {
        const tr = el('tr', d.account && e.id === d.account.id ? 'me' : '');
        const r = el('td'); r.append(el('span', 'rank' + (i < 3 ? ' p' + (i + 1) : ''), i + 1));
        const who = el('td'); who.append(txt(e.name), el('span', 'uid', '#' + e.id));
        tr.append(r, who, el('td', 'num', num(e.kills)), el('td', 'num', dec(e.kd)), el('td', 'num', e.level), el('td', 'num', num(e.gwWins)));
        table.append(tr);
    });
    page.append(table);
    if (!(d.top || []).length) page.append(el('div', 'empty', 'Noch keine Kills auf dem Server. Platz 1 ist frei.'));
    const s = (d.account && d.account.stats) || {};
    const tiles = el('div', 'tiles');
    [['Kills', num(s.kills)], ['Tode', num(s.deaths)], ['K/D', dec(kd(s))], ['Beste Serie', num(s.best)], ['Gangwars gewonnen', `${num(s.gwWins)}/${num(s.gwPlayed)}`]].forEach(([k, v]) => {
        const t = el('div', 'tile'); t.append(el('span', null, k), el('b', null, v)); tiles.append(t);
    });
    page.append(el('div', 'section-label', 'Deine Werte'), stagger(tiles));
    page.lastChild.previousSibling.style.marginTop = '2.4rem';
};

// ---------------------------------------------------------- Regelwerk
RENDER.rules = (d, page) => {
    const list = el('div', 'rules');
    (d.rulesText || []).forEach((r, i) => { const row = el('div', 'rule'); row.append(el('b', null, '§' + (i + 1)), el('span', null, r)); list.append(row); });
    if (!(d.rulesText || []).length) list.append(el('div', 'empty', 'Kein Regelwerk eingetragen.'));
    page.append(stagger(list));
    page.append(el('div', 'section-label', 'Gangwar'));
    page.lastChild.style.margin = '2.4rem 0 1rem';
    page.append(el('div', 'rules-line', rulesLine(d.rules)));
};

// ---------------------------------------------------------- Spieler
RENDER.players = (d, page) => {
    const table = el('table', 'table');
    const head = el('tr');
    ['ID', 'Spieler', 'Team', 'Ort', 'Level', 'Kills', 'Ping', ''].forEach((h, i) => head.append(el('th', i >= 4 && i < 7 ? 'num' : null, h)));
    table.append(head);
    (d.players || []).forEach((p) => {
        const me = d.account && p.id === d.account.id;
        const tr = el('tr', me ? 'me' : '');
        const team = el('td');
        if (p.tag) { const c = paint(el('span', 'chip', p.tag), p.color); team.append(c, txt(' ' + (p.team || ''))); } else team.append(el('span', 'muted', '–'));
        const who = el('td'); who.append(txt(p.name));
        if (p.bounty > 0) { const f = el('span', 'flag green'); f.append(icon('target')); f.title = money(p.bounty); who.append(f); }
        const acts = el('td', 'acts');
        if (!me) {
            acts.append(iconBtn('swords', 'mini', () => { state.duelForm = Object.assign(state.duelForm || {}, { target: p.id }); openPage('duels'); }, 'Zum Duell fordern'));
            acts.append(iconBtn('target', 'mini', () => { state.bountyForm = Object.assign(state.bountyForm || {}, { target: p.id }); openPage('bounty'); }, 'Kopfgeld setzen'));
        }
        tr.append(el('td', null, '#' + p.id), who, team, el('td', 'muted', p.place || ''), el('td', 'num', p.level), el('td', 'num', num(p.kills)), el('td', 'num', p.ping || 0), acts);
        table.append(tr);
    });
    page.append(el('div', 'rules-line', `${d.online || (d.players || []).length} ${plural(d.online || 0, 'Spieler', 'Spieler')} online`), table);
};

// ---------------------------------------------------------- Team
function privateBox(p) {
    const box = el('div', 'card pad');
    const head = el('div', 'row');
    head.append(emblem({ id: p.id, kind: 'private', tag: p.tag, color: p.color, name: p.name }, true));
    const t = el('div', 'grow');
    t.append(el('div', 'card-title', p.name), el('div', 'muted', `${p.members.length} von ${p.max} Mitgliedern, ${p.zones} ${plural(p.zones, 'Gebiet', 'Gebiete')}, Hood: ${p.hood || '–'}`));
    head.append(t);
    box.append(head);
    const list = el('div', 'members');
    (p.members || []).forEach((m) => {
        const row = el('div', 'member');
        row.append(el('i', 'on' + (m.online ? ' yes' : '')));
        const who = el('span');
        who.append(txt(m.name), el('span', 'uid', '#' + m.id));
        if (m.leader) { const l = el('span', 'lead'); l.append(icon('crown')); who.append(l); }
        row.append(who, el('span', 'muted', 'LVL ' + m.level));
        if (p.leader && !m.leader) row.append(confirmBtn('Entfernen', 'Sicher?', 'ghost small', () => action('team', { action: 'kick', args: { id: m.id } }), 'user-minus'));
        else row.append(el('span'));
        list.append(row);
    });
    box.append(list);
    if (p.leader) {
        const inv = el('div', 'row');
        const input = el('input', 'input');
        input.placeholder = 'User-ID einladen, z. B. 12';
        input.inputMode = 'numeric';
        input.maxLength = 8;
        input.style.flex = '1';
        const send = () => { const id = parseInt(input.value, 10); if (!isNaN(id)) { action('team', { action: 'invite', args: { id } }); input.value = ''; } };
        input.addEventListener('keydown', (e) => { if (e.key === 'Enter') send(); });
        inv.append(input, btn('Einladen', 'primary', send, false, 'user-plus'));
        box.append(inv);
    }
    const foot = el('div', 'row');
    foot.style.marginTop = '1.4rem';
    if (p.leader) foot.append(confirmBtn('Team auflösen', 'Wirklich auflösen?', 'ghost', () => action('team', { action: 'disband' }), 'trash'));
    else foot.append(confirmBtn('Team verlassen', 'Wirklich verlassen?', 'ghost', () => action('team', { action: 'leave' }), 'log-out'));
    box.append(foot);
    return box;
}
function createBox(t, d) {
    const box = el('div', 'card pad form');
    let color = (t.colors || [])[0] || '#0ea5ff';
    box.append(el('div', 'card-title', 'Eigenes Team gründen'), el('div', 'muted', `Eigener Name, Kürzel und Farbe. Bis zu ${t.maxMembers || 15} Mitglieder lädst du per User-ID ein. Dein Team bekommt eine eigene Hood.`));
    const name = el('input', 'input'); name.maxLength = 20; name.placeholder = 'Teamname, z. B. Grove Kings';
    const tag = el('input', 'input'); tag.maxLength = 4; tag.placeholder = 'Kürzel, z. B. GK';
    const f1 = el('label', 'field'); f1.append(el('span', 'field-label', 'Teamname'), name);
    const f2 = el('label', 'field'); f2.append(el('span', 'field-label', 'Kürzel (2 bis 4 Zeichen)'), tag);
    const prev = el('div', 'preview-team');
    const prevEm = el('div');
    const prevName = el('div', 'card-title', 'Dein Team');
    prev.append(prevEm, prevName);
    const update = () => {
        prevEm.textContent = '';
        prevEm.append(emblem({ tag: tag.value.trim().toUpperCase() || 'TAG', color, name: name.value }, true));
        prevName.textContent = name.value.trim() || 'Dein Team';
    };
    name.addEventListener('input', update);
    tag.addEventListener('input', update);
    const sws = el('div', 'swatches');
    (t.colors || []).forEach((c, i) => {
        const s = el('button', 'sw' + (i === 0 ? ' sel' : ''));
        s.type = 'button';
        paint(s, c);
        s.addEventListener('click', () => { click(); color = c; sws.querySelectorAll('.sw').forEach((x) => x.classList.remove('sel')); s.classList.add('sel'); update(); });
        sws.append(s);
    });
    const f3 = el('div', 'field'); f3.append(el('span', 'field-label', 'Farbe (bestimmt auch die Outfits)'), sws);
    const short = (t.createPrice || 0) - d.account.money;
    let label = 'Gründen für ' + money(t.createPrice);
    if (d.mode !== 'lobby') label = 'Gründen geht nur an der Hood';
    else if (short > 0) label = 'Dir fehlen ' + money(short);
    box.append(f1, f2, f3, prev, btn(label, 'primary', () => action('team', { action: 'create', args: { name: name.value.trim(), tag: tag.value.trim(), color } }), d.mode !== 'lobby' || short > 0, 'plus'));
    update();
    return box;
}
RENDER.team = (d, page) => {
    const t = d.team || {};
    const wrap = el('div', 'team-page');
    const left = el('div', 'grid');
    const cur = el('div', 'card cur-team');
    if (t.current) {
        paint(cur, t.current.color);
        cur.append(emblem({ id: t.current.id, kind: t.current.kind, tag: t.current.tag, color: t.current.color, name: t.current.name }));
        const info = el('div');
        info.append(el('div', 'tc-label', 'Du spielst für'), el('div', 'tc-name', t.current.name));
        info.append(el('div', 'muted', d.mode === 'lobby' ? 'Wechseln kannst du jederzeit an deiner Hood.' : 'Wechseln geht nur an deiner Hood.'));
        const r = el('div', 'row'); r.style.marginTop = '1.2rem';
        r.append(btn('Team wechseln', 'ghost', () => action('changeTeam'), d.mode !== 'lobby', 'refresh-cw'));
        info.append(r);
        cur.append(info);
    } else cur.append(el('div', 'card-title', 'Kein Team'));
    left.append(cur);
    if (t.invite) {
        const inv = el('div', 'card pad');
        paint(inv, t.invite.color);
        inv.style.borderColor = 'var(--c-a55)';
        const r1 = el('div', 'row');
        r1.append(emblem({ tag: t.invite.tag, color: t.invite.color }, true));
        const tt = el('div'); tt.append(el('div', 'tc-label', 'Einladung von ' + t.invite.from), el('div', 'card-title', t.invite.team));
        r1.append(tt);
        const r2 = el('div', 'row'); r2.style.marginTop = '1.2rem';
        r2.append(btn('Annehmen', 'go', () => action('team', { action: 'accept' }), false, 'check'), btn('Ablehnen', 'ghost', () => action('team', { action: 'decline' }), false, 'x'));
        inv.append(r1, r2);
        left.append(inv);
    }
    const right = el('div');
    if (t.private) right.append(privateBox(t.private));
    else if (t.enabled) right.append(createBox(t, d));
    else { const off = el('div', 'card pad'); off.append(el('div', 'card-title', 'Private Teams'), el('div', 'muted', 'Private Teams sind auf diesem Server ausgeschaltet.')); right.append(off); }
    wrap.append(left, right);
    page.append(wrap);
};

// ---------------------------------------------------------- Waffenshop
function weaponImage(box, name) {
    const fb = typeof silhouette === 'function' ? silhouette(weaponShape(name), null) : icon('crosshair', 'fallback');
    box.append(fb);
    const img = new Image();
    img.onload = () => { fb.remove(); box.prepend(img); };
    img.src = `https://docs-backend.fivem.net/weapons/${name}.png`;
}
RENDER.shop = (d, page) => {
    const tools = el('div', 'page-tools');
    const bal = el('span', 'balance'); bal.append(icon('wallet'), txt(money(d.account.money)));
    tools.append(bal, el('span', 'muted', 'Weniger Treffer bis zum Kill heißt mehr Schaden. Mk-II-Waffen sind am stärksten.'));
    page.append(tools);
    const grid = el('div', 'grid c4');
    (d.shop || []).forEach((w) => {
        const card = el('div', 'card gun hover-lift' + (w.owned ? ' owned' : '') + (w.mk2 ? ' mk2' : ''));
        const img = el('div', 'gun-img');
        weaponImage(img, w.name);
        if (w.mk2) img.append(el('span', 'badge gold', 'Mk II'));
        if (w.owned) { const b = el('span', 'badge green right'); b.append(icon('check'), txt(w.price > 0 ? 'Im Besitz' : 'Startwaffe')); img.append(b); }
        else img.append(el('span', 'badge blue right', money(w.price)));
        const body = el('div', 'gun-body');
        body.append(el('div', 'gun-name', nb(w.label)));
        const st = el('div', 'gun-stats');
        const s1 = el('div'); s1.append(el('span', null, 'Treffer bis Kill'), el('b', null, w.shots));
        const s2 = el('div'); s2.append(el('span', null, 'Schaden'), el('b', null, w.damage));
        st.append(s1, s2);
        const foot = el('div', 'gun-foot');
        if (w.owned) foot.append(btn('Gehört dir', 'block', null, true, 'check'));
        else {
            const short = w.price - d.account.money;
            foot.append(btn(short > 0 ? 'Dir fehlen ' + money(short) : 'Kaufen', (short > 0 ? '' : 'primary') + ' block', () => action('buy', { weapon: w.name }), short > 0, short > 0 ? null : 'shopping-cart'));
        }
        body.append(st, foot);
        card.append(img, body);
        grid.append(card);
    });
    page.append(stagger(grid));
};

// ---------------------------------------------------------- Inventar
RENDER.inventory = (d, page) => {
    const a = d.account || {};
    const armed = d.mode === 'ffa' || d.mode === 'gangwar' || (d.mode === 'lobby' && state.config.hoodCombat);
    const skins = (d.cases && d.cases.skins) || [];
    const tools = el('div', 'page-tools');
    const bal = el('span', 'balance'); bal.append(icon('wallet'), txt(money(a.money)));
    tools.append(bal, el('span', 'muted', armed ? 'Klick auf eine Waffe, um sie direkt in die Hand zu nehmen.' : 'Deine Waffen bekommst du, sobald du wieder kämpfst.'));
    if (d.wardrobe && d.mode === 'lobby') tools.append(el('div', 'grow'), btn('Kleiderschrank öffnen', 'ghost', () => action('wardrobe'), false, 'user'));
    page.append(tools);

    // Weste & Medkit
    page.append(el('div', 'section-label', 'Weste & Medkit'));
    const items = el('div', 'grid c2 items');
    (d.items || []).forEach((it) => {
        const card = el('div', 'card pad item-card ' + it.kind);
        const head = el('div', 'row');
        const ic = el('div', 'item-ic'); ic.append(icon(it.kind === 'vest' ? 'shield' : 'heart-pulse'));
        const t = el('div', 'grow');
        const name = el('div', 'card-title'); name.append(txt(it.label + ' '), el('span', 'badge ' + (it.unlimited || it.count > 0 ? 'blue' : 'red'), it.unlimited ? 'Gratis · unbegrenzt' : `${it.count} / ${it.max}`));
        t.append(name, el('div', 'muted', (it.kind === 'vest' ? 'Volle Weste in 3,5 s' : 'Volles Leben in 3,5 s') + ' · Taste ' + it.key));
        head.append(ic, t);
        card.append(head);
        items.append(card);
        if (it.unlimited) return;
        const row = el('div', 'row');
        row.style.marginTop = '1.2rem';
        const left = (it.max || 10) - it.count;
        row.append(
            btn('Kaufen ×1 · ' + money(it.price), 'primary small', () => action('itemBuy', { kind: it.kind, amount: 1 }), left <= 0 || a.money < it.price, 'shopping-cart'),
            btn('Kaufen ×5 · ' + money(it.price * Math.min(5, Math.max(1, left))), 'ghost small', () => action('itemBuy', { kind: it.kind, amount: 5 }), left <= 0 || a.money < it.price * Math.min(5, Math.max(1, left)), 'shopping-cart'),
        );
        card.append(row);
    });
    page.append(stagger(items));

    // Waffen
    const owned = (d.shop || []).filter((w) => w.owned);
    const wl = el('div', 'section-label', `Waffen (${owned.length} von ${(d.shop || []).length})`);
    wl.style.marginTop = '2.4rem';
    page.append(wl);
    const attAllowed = d.attachments && d.attachments.allowed;
    const guns = el('div', 'grid c4');
    owned.forEach((w) => {
        const card = el('div', 'card gun inv hover-lift owned' + (w.mk2 ? ' mk2' : ''));
        const img = el('div', 'gun-img');
        weaponImage(img, w.name);
        if (w.mk2) img.append(el('span', 'badge gold', 'Mk II'));
        const skin = skins.find((s) => s.equipped && s.weapon === w.name);
        if (skin) { const b = rarityBadge(skin); img.append(b); }
        const body = el('div', 'gun-body');
        body.append(el('div', 'gun-name', nb(w.label)));
        const st = el('div', 'gun-stats');
        const s1 = el('div'); s1.append(el('span', null, 'Treffer bis Kill'), el('b', null, w.shots));
        const s2 = el('div'); s2.append(el('span', null, 'Skin'), el('b', null, skin ? skin.name : 'Standard'));
        st.append(s1, s2);
        const foot = el('div', 'gun-foot row');
        foot.append(btn('In die Hand', 'primary', () => action('holdWeapon', { weapon: w.name }), !armed, 'crosshair'));
        const eq = ((a.attachments || {})[w.name]) || {};
        const n = Object.keys(eq).length;
        foot.append(attAllowed
            ? btn(n > 0 ? `Aufsätze (${n})` : 'Aufsätze', 'gold', () => openAttachments(w, d), false, 'wrench')
            : btn('Aufsätze (Premium)', '', null, true, 'lock'));
        body.append(st, foot);
        card.append(img, body);
        guns.append(card);
    });
    if (!owned.length) guns.append(el('div', 'empty', 'Noch keine Waffen.'));
    page.append(stagger(guns));

    // Cases
    const cases = ((d.cases && d.cases.cases) || []).filter((c) => c.owned > 0);
    const caseLabel = el('div', 'section-label', 'Cases');
    caseLabel.style.marginTop = '2.4rem';
    page.append(caseLabel);
    const cl = el('div', 'inv-list');
    cases.forEach((c) => {
        const row = el('div', 'inv-row');
        if (typeof miniCase === 'function') row.append(miniCase(c.color, 3.2));
        row.append(el('b', 'grow', c.name), el('span', 'badge gold', c.owned + 'x'), btn('Öffnen', 'gold small', () => action('caseOpen', { case: c.key }), false, 'package'));
        cl.append(row);
    });
    if (!cases.length) cl.append(el('div', 'empty', 'Keine ungeöffneten Cases.'));
    page.append(cl);

    // Skins + Autos
    const vehicles = ((d.garage && d.garage.vehicles) || []).filter((v) => v.unlocked);
    const tiles = el('div', 'tiles');
    [['Geld', money(a.money)], ['Skins', `${skins.length} von ${(d.cases && d.cases.total) || 0}`], ['Autos frei', `${vehicles.length} von ${((d.garage && d.garage.vehicles) || []).length}`],
        ['Level', a.level || 1], ['Premium', a.premium ? 'Ja' : 'Nein']].forEach(([k, v]) => {
        const t = el('div', 'tile'); t.append(el('span', null, k), el('b', null, v)); tiles.append(t);
    });
    page.append(stagger(tiles));
    if (vehicles.length) {
        const vl = el('div', 'section-label', 'Autos in deiner Hood-Garage');
        vl.style.marginTop = '2.4rem';
        page.append(vl);
        const cars = el('div', 'inv-list');
        vehicles.forEach((v) => { const row = el('div', 'inv-row'); row.append(icon('car-front'), el('b', 'grow', v.label), el('span', 'badge blue', 'LVL ' + v.level)); cars.append(row); });
        page.append(cars);
    }
};
// ---------------------------------------------------------- Glücksrad
const WHEEL_ICON = { money: 'banknote', xp: 'zap', case: 'package', weapon: 'crosshair', premium: 'gem' };
function drawWheel(cv, prizes) {
    const ctx = cv.getContext('2d');
    const n = Math.max(1, prizes.length);
    const size = cv.width, r = size / 2, seg = (Math.PI * 2) / n;
    ctx.clearRect(0, 0, size, size);
    prizes.forEach((p, i) => {
        const a0 = -Math.PI / 2 + i * seg, a1 = a0 + seg;
        const col = p.color || '#19b2ff';
        const g = ctx.createRadialGradient(r, r, r * 0.15, r, r, r);
        g.addColorStop(0, rgba(col, 0.35));
        g.addColorStop(1, i % 2 ? darker(col, 0.25) : col);
        ctx.beginPath(); ctx.moveTo(r, r); ctx.arc(r, r, r - 8, a0, a1); ctx.closePath();
        ctx.fillStyle = g; ctx.fill();
        ctx.strokeStyle = 'rgba(5,9,13,0.85)'; ctx.lineWidth = 5; ctx.stroke();
        ctx.save();
        ctx.translate(r, r);
        ctx.rotate(a0 + seg / 2);
        ctx.textAlign = 'right'; ctx.textBaseline = 'middle';
        ctx.fillStyle = inkFor(col);
        ctx.font = `700 ${Math.round(size * 0.036)}px Rajdhani`;
        ctx.fillText(String(p.label), r - 34, 0);
        ctx.restore();
    });
    ctx.beginPath(); ctx.arc(r, r, r - 6, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(255,255,255,0.85)'; ctx.lineWidth = 8; ctx.stroke();
}
RENDER.wheel = (d, page) => {
    const w = d.wheel || { prizes: [] };
    const wrap = el('div', 'wheel-page');
    const stage = el('div', 'wheel-stage');
    const cv = document.createElement('canvas');
    cv.className = 'wheel-canvas';
    cv.id = 'wheel-canvas';
    cv.width = 900; cv.height = 900;
    drawWheel(cv, w.prizes || []);
    cv.style.transform = `rotate(${state.wheelRot || 0}deg)`;
    const hub = el('div', 'wheel-hub');
    hub.append(icon('gift'));
    stage.append(cv, el('i', 'wheel-pointer'), hub);
    const side = el('div', 'wheel-side');
    side.append(el('div', 'card-title', 'Tägliches Glücksrad'), el('div', 'muted', 'Einmal alle 24 Stunden gratis. Der Gewinn wird sofort gutgeschrieben.'));
    let b;
    if (!w.enabled) b = btn('Ausgeschaltet', 'block', null, true, 'lock');
    else if (state.wheelBusy) b = btn('Dreht …', 'block', null, true, 'disc-3');
    else if (w.left > 0) {
        b = btn(null, 'block', null, true, 'clock');
        const s = el('span');
        b.append(s);
        liveClock(s, w.left, (t) => 'Nächster Dreh in ' + t);
    } else {
        b = btn('Drehen!', 'gold block big', () => {
            state.wheelBusy = true;
            b.disabled = true;
            action('wheelSpin');
            later('wheelUnlock', 9000, () => { state.wheelBusy = false; });
        }, false, 'disc-3');
    }
    side.append(b);
    if (w.last) side.append(el('div', 'muted', 'Letzter Gewinn: ' + w.last));
    const list = el('div', 'wheel-list');
    (w.prizes || []).forEach((p) => {
        const row = el('div', 'wheel-prize');
        const dot = el('i'); dot.style.background = p.color || '#19b2ff';
        row.append(dot, icon(WHEEL_ICON[p.kind] || 'gift'), el('span', null, p.label));
        list.append(row);
    });
    side.append(list);
    wrap.append(stage, side);
    page.append(wrap);
};
function spinWheel(res) {
    const prizes = (state.menu && state.menu.wheel && state.menu.wheel.prizes) || [];
    const n = Math.max(1, prizes.length);
    const seg = 360 / n;
    const cur = state.wheelRot || 0;
    const jitter = (Math.random() - 0.5) * seg * 0.6;
    const target = cur - (cur % 360) + 360 * 7 + (360 - (res.index - 0.5) * seg) + jitter;
    state.wheelRot = target;
    state.wheelBusy = true;
    const cv = $('wheel-canvas');
    if (cv) {
        cv.style.transition = 'transform 6s cubic-bezier(0.12, 0.8, 0.12, 1)';
        requestAnimationFrame(() => { cv.style.transform = `rotate(${target}deg)`; });
    }
    later('wheelDone', 6300, () => {
        state.wheelBusy = false;
        if (state.menu && res.view) state.menu.wheel = res.view;
        sounds.kill && sounds.kill();
        if (state.screen === 'menu' && state.page === 'wheel') renderMenu(false);
    });
}

// ---------------------------------------------------------- Weste & Medkit (Balken unten + Anzeige)
let itemBarAnim = null;
function showItemBar(d) {
    const bar = $('itembar');
    cancelAnimationFrame(itemBarAnim);
    if (!d.show) { bar.classList.add('off'); return; }
    $('itembar-label').textContent = d.label || '';
    bar.classList.toggle('medkit', d.kind === 'medkit');
    bar.classList.remove('off');
    const start = performance.now();
    const dur = Math.max(0.5, Number(d.seconds) || 3.5) * 1000;
    const step = (now) => {
        const p = Math.min(1, (now - start) / dur);
        $('itembar-fill').style.width = (p * 100).toFixed(1) + '%';
        $('itembar-pct').textContent = Math.floor(p * 100) + '%';
        if (p < 1) itemBarAnim = requestAnimationFrame(step);
    };
    itemBarAnim = requestAnimationFrame(step);
}
function showItemCounts(d) {
    const box = $('itemcounts');
    if (!d.show) { box.classList.add('off'); return; }
    box.textContent = '';
    const chip = (ic, n, key, label) => {
        const c = el('div', 'ic-chip' + (n !== 0 ? '' : ' empty'));
        c.append(el('kbd', null, key), icon(ic));
        if (n >= 0) c.append(el('b', null, n + 'x'));
        c.append(el('span', null, label));
        return c;
    };
    box.append(chip('shield', d.vest || 0, d.vestKey || 'G', 'Weste'), chip('heart-pulse', d.medkit || 0, d.medkitKey || 'H', 'Medkit'));
    box.classList.remove('off');
}

// ---------------------------------------------------------- Hilfe (F11): alle Tasten und Befehle
function showHelp(d) {
    const scr = $('scr-help');
    scr.textContent = '';
    const panel = el('div', 'panel help');
    const search = el('label', 'search');
    const si = el('input', 'input');
    si.placeholder = 'Befehl suchen';
    search.append(icon('search'), si);
    panel.append(panelHead('Befehle & Tasten', [search], true, 'help'));
    const body = el('div', 'help-body');
    const render = () => {
        body.textContent = '';
        const q = si.value.trim().toLowerCase();
        (d.sections || []).forEach((sec) => {
            const rows = (sec.items || []).filter((it) => !q || (it.cmd + ' ' + it.text).toLowerCase().includes(q));
            if (!rows.length) return;
            const box = el('div', 'help-sec');
            const h = el('div', 'section-label', sec.title);
            if (sec.rank) h.append(paint(el('span', 'rank-tag', sec.rank.label), sec.rank.color));
            box.append(h);
            rows.forEach((it) => {
                const row = el('div', 'help-row');
                row.append(el(it.key ? 'kbd' : 'code', null, it.cmd), el('span', null, it.text));
                box.append(row);
            });
            body.append(box);
        });
        if (!body.children.length) body.append(el('div', 'empty', 'Nichts gefunden.'));
    };
    si.addEventListener('input', render);
    render();
    panel.append(body);
    scr.append(panel);
    showScreen('help');
    setTimeout(() => si.focus(), 60);
}

// ---------------------------------------------------------- Kleiderschrank
function wardrobeCall(name, data) {
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) })
        .then((r) => r.json()).catch(() => ({}));
}
function showWardrobe(slots) {
    const scr = $('scr-wardrobe');
    scr.textContent = '';
    const panel = el('div', 'panel wardrobe');
    panel.append(panelHead('Kleiderschrank', [], true, 'wardrobe'));
    panel.append(el('div', 'muted wd-note', 'Das Oberteil bleibt in deiner Gangfarbe, damit jeder sieht, zu wem du gehörst.'));
    const list = el('div', 'wd-list');
    const render = (rows) => {
        list.textContent = '';
        rows.forEach((s) => {
            const row = el('div', 'wd-row' + (s.gang ? ' gang' : ''));
            row.append(el('b', null, s.label));
            const line = (value, field) => {
                const l = el('div', 'wd-line');
                l.append(iconBtn('chevron-left', 'mini', () => wardrobeCall('wardrobeChange', { slot: s.key, field, dir: -1 }).then((r) => r.slots && render(r.slots))),
                    el('span', null, value),
                    iconBtn('chevron-right', 'mini', () => wardrobeCall('wardrobeChange', { slot: s.key, field, dir: 1 }).then((r) => r.slots && render(r.slots))));
                return l;
            };
            row.append(line(s.value, 'd'));
            if (!s.gang && s.texture && s.texture !== '–') row.append(line(s.texture, 't'));
            list.append(row);
        });
    };
    render(slots);
    panel.append(list);
    const foot = el('div', 'row wd-foot');
    foot.append(
        iconBtn('rotate-ccw', 'mini', () => wardrobeCall('wardrobeRotate', { dir: -1 }), 'Drehen'),
        iconBtn('refresh-cw', 'mini', () => wardrobeCall('wardrobeRotate', { dir: 1 }), 'Drehen'),
        el('div', 'grow'),
        btn('Abbrechen', 'ghost', () => post('wardrobeCancel'), false, 'x'),
        btn('Speichern', 'primary', () => post('wardrobeSave'), false, 'check'),
    );
    panel.append(foot);
    scr.append(panel);
    showScreen('wardrobe');
}

// ---------------------------------------------------------- Emotes
RENDER.emotes = (d, page) => {
    const tools = el('div', 'page-tools');
    tools.append(btn('Emote stoppen', 'ghost', () => action('emote', { name: 'stop' }), false, 'x'));
    tools.append(el('span', 'muted', d.emotesAllowed ? 'Klick spielt das Emote ab. Laufen, springen oder zielen bricht ab.' : 'Emotes gehen nur an deiner Hood.'));
    page.append(tools);
    const groups = {};
    (d.emotes || []).forEach((e) => { (groups[e.group] = groups[e.group] || []).push(e); });
    Object.keys(groups).forEach((g, gi) => {
        const label = el('div', 'section-label', g);
        if (gi > 0) label.style.marginTop = '2.2rem';
        page.append(label);
        const grid = el('div', 'emote-grid');
        groups[g].forEach((e) => {
            const b = el('button', 'emote');
            b.type = 'button';
            b.append(icon(g === 'Tänze' ? 'sparkles' : 'hand-coins'), el('b', null, e.label), el('span', null, '/e ' + e.name));
            b.disabled = !d.emotesAllowed;
            b.addEventListener('click', () => { click(); action('emote', { name: e.name }); });
            grid.append(b);
        });
        page.append(stagger(grid));
    });
};

// Aufsätze einer Waffe (welche passen, sagt das Spiel selbst)
function openAttachments(w, d) {
    fetch(`https://${RES}/weaponComponents`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ weapon: w.name }) })
        .then((r) => r.json()).catch(() => ({ list: [] }))
        .then((res) => {
            const list = (res && res.list) || [];
            const acc = d.account || {};
            acc.attachments = acc.attachments || {};
            const eq = acc.attachments[w.name] = acc.attachments[w.name] || {};
            const old = $('att-modal');
            if (old) old.remove();
            const ov = el('div', 'att-modal');
            ov.id = 'att-modal';
            const box = el('div', 'att-box panel');
            const head = el('div', 'row');
            head.append(el('div', 'card-title grow', nb(w.label) + ' – Aufsätze'), iconBtn('x', 'close', () => { ov.remove(); renderMenu(false); }, 'Schließen'));
            box.append(head);
            const slots = {};
            list.forEach((c) => { (slots[c.slot] = slots[c.slot] || { label: c.slotLabel, opts: [] }).opts.push(c); });
            if (!list.length) box.append(el('div', 'empty', 'Diese Waffe hat keine Aufsätze.'));
            Object.keys(slots).forEach((key) => {
                const s = slots[key];
                box.append(el('div', 'section-label', s.label));
                const row = el('div', 'att-row');
                const paintRow = () => {
                    row.textContent = '';
                    const none = btn('Keine', !eq[key] ? 'primary small' : 'ghost small', () => { delete eq[key]; action('attachSet', { weapon: w.name, slot: key, component: '' }); paintRow(); });
                    row.append(none);
                    s.opts.forEach((o) => {
                        row.append(btn(o.label, eq[key] === o.component ? 'primary small' : 'ghost small', () => {
                            eq[key] = o.component;
                            action('attachSet', { weapon: w.name, slot: key, component: o.component });
                            paintRow();
                        }));
                    });
                };
                paintRow();
                box.append(row);
            });
            const done = btn('Fertig', 'primary', () => { ov.remove(); renderMenu(false); }, false, 'check');
            done.style.marginTop = '1.6rem';
            box.append(done);
            ov.append(box);
            ov.addEventListener('click', (e) => { if (e.target === ov) { ov.remove(); renderMenu(false); } });
            $('scr-menu').append(ov);
        });
}

// ---------------------------------------------------------- Einladen (Ref-Code)
RENDER.referral = (d, page) => {
    const r = d.referral || {};
    const top = el('div', 'grid c2');
    const codeBox = el('div', 'card pad ref-code');
    codeBox.append(el('div', 'section-label', 'Dein Einladungs-Code'), el('div', 'ref-big', '#' + r.code));
    codeBox.append(el('div', 'muted', 'Lade Freunde ein: Sie geben bei der Registrierung deine User-ID ein.'));
    const copy = btn('Code kopieren', 'ghost small', () => {
        try { const ta = el('textarea'); ta.value = String(r.code); document.body.append(ta); ta.select(); document.execCommand('copy'); ta.remove(); copy.lastChild.textContent = 'Kopiert!'; } catch (e) { /* egal */ }
    }, false, 'hash');
    codeBox.append(copy);
    const rew = el('div', 'card pad');
    rew.append(el('div', 'section-label', 'Belohnungen'));
    const kv = el('div', 'kv');
    kv.append(el('span', null, 'Für dich'), el('b', null, `${r.inviterReward || '–'} (nach ${r.minutes || 60} Min Spielzeit des Neuen)`));
    kv.append(el('span', null, 'Für den Neuen'), el('b', null, r.newReward || '–'));
    rew.append(kv);
    top.append(codeBox, rew);
    page.append(top);
    const tiles = el('div', 'tiles');
    [['Eingeladen', num(r.count)], ['Wartet noch', num(r.pending)], ['Verdient', money(r.earned)]].forEach(([k, v]) => {
        const t = el('div', 'tile'); t.append(el('span', null, k), el('b', null, v)); tiles.append(t);
    });
    tiles.style.gridTemplateColumns = 'repeat(3, 1fr)';
    page.append(stagger(tiles));
    const ml = el('div', 'section-label', 'Meilensteine');
    ml.style.marginTop = '2.4rem';
    page.append(ml);
    const list = el('div', 'inv-list');
    (r.milestones || []).forEach((m) => {
        const row = el('div', 'inv-row' + (m.reached ? ' reached' : ''));
        row.append(icon(m.reached ? 'circle-check' : 'lock'), el('b', 'grow', `${m.count} Einladungen`), el('span', null, m.text), el('span', 'badge ' + (m.reached ? 'green' : ''), m.reached ? 'Erreicht' : `${r.count}/${m.count}`));
        list.append(row);
    });
    page.append(list);
    if (r.by) page.append(el('div', 'rules-line', `Du wurdest von ${r.by.name} #${r.by.id} eingeladen.`));
};

function rarityBadge(s) {
    const b = el('span', 'badge right');
    b.style.background = s.rarityColor || '';
    b.style.color = inkFor(s.rarityColor || '#19b2ff');
    b.append(icon('sparkles'), txt(s.rarityName || s.rarity || 'Skin'));
    return b;
}

// ---------------------------------------------------------- Battlepass
function rewardBox(r, track, tier, premium) {
    const box = el('div', 'reward ' + track);
    const what = el('span', 'what');
    if (r && r.kind === 'case' && typeof miniCase === 'function') what.append(miniCase(r.color, 2.6));
    what.append(txt(r ? nb(r.label) : 'Nichts'));
    box.append(el('span', 'kind', track === 'premium' ? 'Premium' : 'Gratis'), what);
    if (!r) return box;
    const claimed = track === 'premium' ? tier.premiumClaimed : tier.freeClaimed;
    const state_ = el('span', 'state');
    if (claimed) { box.classList.add('got'); state_.append(icon('circle-check'), txt('Abgeholt')); box.append(state_); }
    else if (!tier.reached) { state_.append(icon('lock'), txt('Ab Level ' + tier.level)); box.append(state_); }
    else if (track === 'premium' && !premium) { state_.append(icon('lock'), txt('Nur mit Premium')); box.append(state_); }
    else box.append(btn('Abholen', (track === 'premium' ? 'gold' : 'go') + ' small block', () => action('claim', { track, level: tier.level }), false, 'gift'));
    return box;
}
RENDER.bp = (d, page) => {
    const bp = d.battlepass;
    const max = bp.level >= bp.maxLevel;
    const head = el('div', 'bp-head');
    const hl = el('div');
    hl.append(el('div', 'section-label', bp.name));
    const lv = el('div', 'bp-level'); lv.append(txt('Level'), el('b', null, bp.level), el('span', 'muted', 'von ' + bp.maxLevel)); hl.append(lv);
    const bar = el('div', 'bar'); const fill = el('i'); bar.append(fill);
    requestAnimationFrame(() => requestAnimationFrame(() => { fill.style.width = (max ? 100 : Math.round(bp.progress * 100)) + '%'; }));
    fill.style.background = 'linear-gradient(90deg, #e09a12, #ffc341)';
    fill.style.boxShadow = '0 0 1rem rgba(255,195,65,.6)';
    hl.append(bar, el('div', 'bar-label', max ? 'Maximales Level erreicht.' : `Noch ${num((1 - bp.progress) * bp.xpPerLevel)} XP bis Level ${bp.level + 1}`));
    const prem = el('div');
    const pb = el('span', 'badge ' + (bp.premium ? 'gold' : ''));
    pb.append(icon(bp.premium ? 'gem' : 'lock'), txt(bp.premium ? 'Premium aktiv' : 'Kein Premium'));
    prem.append(pb);
    head.append(hl, prem);
    page.append(head);
    const road = el('div', 'road');
    let target = null;
    (bp.tiers || []).forEach((t) => {
        const col = el('div', 'tier' + (t.reached ? ' reached' : '') + (t.level === bp.level ? ' current' : ''));
        const th = el('div', 'tier-head'); th.append(el('span', null, 'Level ' + t.level)); if (t.reached) th.append(icon('check'));
        col.append(th, rewardBox(t.free, 'free', t, bp.premium), rewardBox(t.premium, 'premium', t, bp.premium));
        road.append(col);
        const open = t.reached && ((t.free && !t.freeClaimed) || (bp.premium && t.premium && !t.premiumClaimed));
        if (!target && open) target = col;
    });
    if (!target) target = road.querySelector('.tier.current');
    page.append(road);
    const previous = state.bpScroll;
    requestAnimationFrame(() => {
        road.style.scrollBehavior = 'auto';
        if (previous !== undefined && previous !== null) road.scrollLeft = previous;
        else if (target) road.scrollLeft = Math.max(0, target.offsetLeft - road.offsetLeft - 20);
        requestAnimationFrame(() => { road.style.scrollBehavior = ''; });
    });
    road.addEventListener('wheel', (e) => { if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) { road.scrollLeft += e.deltaY; e.preventDefault(); } }, { passive: false });
    road.addEventListener('scroll', () => { state.bpScroll = road.scrollLeft; });
};

// ---------------------------------------------------------- Einstellungen
const SETTINGS = [
    ['hitmarker', 'Trefferanzeige', 'Kreuz in der Mitte bei jedem Treffer', 'crosshair'],
    ['hitSound', 'Treffer-Sound', 'Kurzer Ton bei jedem Treffer', 'volume-2'],
    ['killSound', 'Kill-Sound', 'Ton bei jedem Kill', 'skull'],
    ['damageNumbers', 'Schadenszahlen', 'Zeigt den Schaden pro Treffer', 'hash'],
    ['damageDirection', 'Trefferrichtung', 'Zeigt, aus welcher Richtung du getroffen wirst', 'locate-fixed'],
    ['killfeed', 'Killfeed', 'Wer wen erwischt hat, oben rechts', 'activity'],
    ['clock', 'Uhr', 'Datum und Uhrzeit oben links', 'clock'],
    ['chatFade', 'Chat ausblenden', 'Alte Nachrichten verschwinden nach ein paar Sekunden', 'message-square'],
];
function saveSettings() { post('settings', { settings: state.settings }); applySettings(); }
RENDER.settings = (d, page) => {
    const grid = el('div', 'settings');
    SETTINGS.forEach(([key, label, help, ic]) => {
        const row = el('div', 'set-row');
        const t = el('div'); t.append(el('b', null, label), el('span', null, help));
        const tg = el('i', 'toggle' + (state.settings[key] ? ' on' : ''));
        row.append(icon(ic), t, tg);
        row.addEventListener('click', () => { click(); state.settings[key] = !state.settings[key]; tg.classList.toggle('on', state.settings[key]); saveSettings(); });
        grid.append(row);
    });
    const slider = (key, label, help, ic, min, max, step, fmt) => {
        const row = el('div', 'set-row range');
        const t = el('div'); t.append(el('b', null, label), el('span', null, help));
        const wrap = el('div', 'row');
        const r = el('input'); r.type = 'range'; r.min = min; r.max = max; r.step = step; r.value = state.settings[key];
        const v = el('b', null, fmt(state.settings[key]));
        const upd = () => { r.style.setProperty('--p', ((r.value - min) / (max - min) * 100) + '%'); v.textContent = fmt(Number(r.value)); };
        r.addEventListener('input', () => { state.settings[key] = Number(r.value); upd(); applySettings(); });
        r.addEventListener('change', () => { saveSettings(); if (key === 'volume') sounds.hit(); });
        r.style.flex = '1';
        wrap.append(r, v);
        upd();
        row.append(icon(ic), t, wrap);
        return row;
    };
    grid.append(slider('volume', 'Lautstärke', 'Treffer- und Kill-Sounds', 'volume-2', 0, 1, 0.05, (x) => Math.round(x * 100) + '%'));
    grid.append(slider('hudScale', 'HUD-Größe', 'Statistik, Chat und Munition', 'sliders-horizontal', 0.8, 1.2, 0.05, (x) => Math.round(x * 100) + '%'));
    // Auswahl-Zeilen: Sprache, Trefferanzeige, Sounds
    const choice = (key, label, help, ic, options, preview) => {
        const row = el('div', 'set-row choice');
        const t = el('div'); t.append(el('b', null, label), el('span', null, help));
        const wrap = el('div', 'row');
        wrap.append(seg(options, state.settings[key] || options[0][0], (k) => {
            state.settings[key] = k;
            saveSettings();
            if (preview) preview(k);
            if (key === 'lang') renderMenu(false);
        }));
        row.append(icon(ic), t, wrap);
        return row;
    };
    grid.append(choice('lang', 'Sprache', 'Deutsch oder Englisch', 'message-square', [['de', 'Deutsch'], ['en', 'English']]));
    grid.append(choice('hitmarkerStyle', 'Trefferanzeige', 'Stil der Trefferanzeige', 'crosshair',
        [['x', 'X'], ['cross', 'Kreuz'], ['dot', 'Punkt'], ['circle', 'Kreis']], () => showHitmarker(false)));
    grid.append(choice('hitmarkerColor', 'Trefferanzeige', 'Farbe der Trefferanzeige', 'circle-dot',
        [['white', 'Weiß'], ['red', 'Rot'], ['blue', 'Blau'], ['yellow', 'Gelb'], ['green', 'Grün'], ['pink', 'Pink']], () => showHitmarker(false)));
    grid.append(choice('hitSoundType', 'Treffer-Sound', 'Welcher Ton beim Treffer', 'volume-2',
        [['classic', 'Klassisch'], ['click', 'Klick'], ['ding', 'Ding'], ['pop', 'Pop'], ['bass', 'Bass']], () => sounds.hit()));
    grid.append(choice('killSoundType', 'Kill-Sound', 'Welcher Ton beim Kill', 'skull',
        [['classic', 'Klassisch'], ['ding', 'Ding'], ['headshot', 'Headshot'], ['coin', 'Münze'], ['bass', 'Bass'], ['none', 'Aus']], () => sounds.kill()));
    page.append(stagger(grid));
};

// ---------------------------------------------------------- Profil
function since(ts) {
    if (!ts) return '–';
    const dd = new Date(ts * 1000);
    return `${String(dd.getDate()).padStart(2, '0')}.${String(dd.getMonth() + 1).padStart(2, '0')}.${dd.getFullYear()}`;
}
RENDER.profile = (d, page) => {
    const a = d.account;
    const s = a.stats || {};
    const head = el('div', 'profile-head');
    const mid = el('div');
    const nm = el('div', 'profile-name'); nm.append(txt(a.name), el('span', 'idbadge', 'ID ' + a.id));
    if (a.staffRank) nm.append(paint(el('span', 'rank-tag big', a.staffRank.label), a.staffRank.color));
    if (a.booster) { const b = el('span', 'booster-badge'); b.append(icon('gem'), txt('Server Booster')); nm.append(b); }
    applyBanner(head, a.booster, a.discord && a.discord.banner, a.discord && a.discord.accent);
    if (a.premium) { const pb = el('span', 'badge gold'); pb.append(icon('gem'), txt('Premium'), el('span', 'pdays', a.premiumText || '')); nm.append(pb); }
    // Discord-Profil (Name + Bild), wenn Discord beim Starten von FiveM offen war
    const dc = el('div', 'discord-line' + (a.discord ? '' : ' off'));
    dc.append(icon('discord'), txt(a.discord ? (a.discord.name || a.discord.username || 'Discord') + (a.discord.username && a.discord.name && a.discord.username !== a.discord.name ? '  @' + a.discord.username : '') : 'Discord nicht verknüpft – Discord beim Start von FiveM offen haben'));
    mid.append(nm, dc, xpBlock(a));
    head.append(avatarFor(a), mid, medal(a.level));
    page.append(head);
    const tiles = el('div', 'tiles');
    [['Kills', num(s.kills)], ['Tode', num(s.deaths)], ['K/D', dec(kd(s))], ['Beste Serie', num(s.best)], ['Gangwars', `${num(s.gwWins)}/${num(s.gwPlayed)}`],
        ['Geld', money(a.money)], ['Spielzeit', `${Math.floor((a.playMinutes || 0) / 60)} Std ${(a.playMinutes || 0) % 60} Min`], ['Dabei seit', since(a.created)],
        ['Waffen', `${(a.weapons || []).length}`], ['Team', d.team && d.team.current ? d.team.current.tag : '–'],
        ['Duelle', `${num(s.duelWins)} : ${num(s.duelLosses)}`], ['Kopfgelder', num(s.bounties)], ['Kopfgeld kassiert', money(s.bountyEarned)],
        ['Cases geöffnet', num(s.casesOpened)], ['Skins', `${a.skins || 0}`]].forEach(([k, v]) => {
        const t = el('div', 'tile'); t.append(el('span', null, k), el('b', null, v)); tiles.append(t);
    });
    page.append(stagger(tiles));
};

// ================================================================== Garage
function vehicleImage(box, model) {
    const fb = icon('car-front', 'fallback');
    box.append(fb);
    const img = new Image();
    img.onload = () => { fb.remove(); box.prepend(img); };
    img.src = `https://docs-backend.fivem.net/vehicles/${String(model).toLowerCase()}.webp`;
}
function showGarage(d) {
    state.garage = d;
    const scr = $('scr-garage');
    scr.textContent = '';
    const panel = el('div', 'panel garage');
    const lvl = el('span', 'badge gold');
    lvl.append(icon('award'), txt('Dein Level ' + (d.level || 1)));
    panel.append(panelHead('Garage', [lvl], true, 'garage'));
    const grid = el('div', 'garage-grid');
    (d.vehicles || []).forEach((v) => {
        const card = el('div', 'card car hover-lift' + (v.unlocked ? '' : ' locked'));
        const img = el('div', 'car-img');
        vehicleImage(img, v.model);
        img.append(el('span', 'badge ' + (v.unlocked ? 'blue' : ''), 'LVL ' + v.level));
        const body = el('div', 'car-body');
        body.append(el('div', 'car-name', v.label));
        if (v.unlocked) body.append(btn('Ausparken', 'primary block', () => post('garageSpawn', { model: v.model }), false, 'car'));
        else body.append(btn('Ab Level ' + v.level, 'block', null, true, 'lock'));
        card.append(img, body);
        grid.append(card);
    });
    if (!(d.vehicles || []).length) grid.append(el('div', 'empty', 'In der Garage stehen keine Autos.'));
    panel.append(stagger(grid));
    scr.append(panel);
    showScreen('garage');
}

// ================================================================== Admin (F6)
const ADMIN_TABS = [['players', 'Spieler'], ['zones', 'Gebiete'], ['server', 'Server'], ['bans', 'Banns']];
function adminAction(a, args) { post('adminAction', { action: a, args: args || {} }); }
// Darf mein Rang diese Aktion? (der Server prüft das trotzdem noch einmal)
function adminCan(a) { const me = state.admin && state.admin.me; return !!(me && me.can && me.can[a]); }
function untilText(ts) {
    if (!ts) return 'Für immer';
    const d = new Date(ts * 1000);
    return `bis ${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}. ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function inputRow(placeholder, buttonLabel, cls, onSend, iconName, numeric) {
    const r = el('div', 'row');
    const i = el('input', 'input');
    i.placeholder = placeholder;
    if (numeric) i.inputMode = 'numeric';
    i.style.flex = '1';
    const go = () => { onSend(i.value.trim()); i.value = ''; };
    i.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
    r.append(i, btn(buttonLabel, cls, go, false, iconName));
    return r;
}
function adminPlayerSide(p) {
    const side = el('div', 'admin-side');
    if (!p) { side.append(el('div', 'empty', 'Spieler links anklicken, um ihn zu verwalten.')); return side; }
    const can = adminCan;
    const me = (state.admin && state.admin.me) || { level: 0 };
    const head = el('div', 'row');
    head.append(el('div', 'avatar', initials(p.name)));
    const t = el('div');
    const nm = el('div', 'card-title'); nm.append(txt(p.name + ' '));
    if (p.rank) nm.append(paint(el('span', 'rank-tag', p.rank.label), p.rank.color));
    t.append(nm, el('div', 'muted', `User #${p.id}   Spieler-ID ${p.sid}`));
    head.append(t);
    side.append(head);
    const kv = el('div', 'kv');
    [['Team', p.team || 'Frei'], ['Ort', p.place || '–'], ['Level', p.level], ['Geld', money(p.money)], ['Kills / Tode', `${num(p.kills)} / ${num(p.deaths)}`], ['Ping', (p.ping || 0) + ' ms'], ['Premium', p.premium ? (p.premiumText || 'Ja') : 'Nein'], ['Stumm', p.muted > 0 ? `noch ${p.muted} min` : 'Nein']]
        .forEach(([k, v]) => kv.append(el('span', null, k), el('b', null, v)));
    side.append(kv);
    // gleich- oder höherrangige Teammitglieder kann man nicht bestrafen (außer als Owner)
    const higher = p.rank && p.rank.level >= me.level && me.level < 6 && !(state.account && state.account.id === p.id);
    const section = (label, nodes) => {
        nodes = nodes.filter(Boolean);
        if (!nodes.length) return;
        if (label) side.append(el('div', 'section-label', label));
        const box = el('div', 'admin-actions');
        nodes.forEach((n) => box.append(n));
        side.append(box);
    };
    section('Aktionen', [
        can('heal') && btn('Heilen', 'ghost', () => adminAction('heal', { sid: p.sid }), p.dead, 'heart'),
        can('hood') && btn('Zur Hood', 'ghost', () => adminAction('hood', { sid: p.sid }), higher, 'house'),
        can('mute') && btn(p.muted > 0 ? 'Stumm aufheben' : 'Stumm 30 min', 'ghost', () => adminAction('mute', { uid: p.id, minutes: p.muted > 0 ? 0 : 30 }), higher, 'mic-off'),
        can('endDuel') && btn('Duell beenden', 'ghost', () => adminAction('endDuel', { sid: p.sid }), !p.duel, 'swords'),
        can('tpTo') && btn('Zu ihm', 'ghost', () => adminAction('tpTo', { sid: p.sid }), false, 'map-pin'),
        can('bring') && btn('Zu mir holen', 'ghost', () => adminAction('bring', { sid: p.sid }), higher, 'locate-fixed'),
    ]);
    // Geben: nur Admin und Owner
    if (can('money') || can('xp') || can('premium')) {
        side.append(el('div', 'section-label', 'Geben (nur Admin)'));
        if (can('money')) side.append(inputRow('Betrag, z. B. 5000 oder -500', 'Geld', 'ghost', (v) => { const n = parseInt(v, 10); if (!isNaN(n)) adminAction('money', { uid: p.id, amount: n }); }, 'banknote', true));
        if (can('xp')) side.append(inputRow('XP, z. B. 1000', 'XP', 'ghost', (v) => { const n = parseInt(v, 10); if (!isNaN(n)) adminAction('xp', { uid: p.id, amount: n }); }, 'zap', true));
        if (can('premium')) side.append(inputRow(`Premium-Tage (jetzt: ${p.premiumText || 'aus'}) – 0 = für immer, -1 = weg`, 'Premium', 'ghost', (v) => { const n = parseInt(v, 10); if (!isNaN(n)) adminAction('premium', { uid: p.id, days: n, on: n >= 0 }); }, 'gem', true));
    }
    section('', [
        ...(can('case') ? (state.admin && state.admin.cases || []).map((c) => btn(c.name + ' geben', 'ghost', () => adminAction('case', { uid: p.id, case: c.key, amount: 1 }), false, 'package')) : []),
        can('clearBounty') && btn('Kopfgeld löschen', 'ghost', () => adminAction('clearBounty', { uid: p.id }), !(p.bounty > 0), 'target'),
    ]);
    if (can('kick') || can('ban')) {
        side.append(el('div', 'section-label', 'Strafen'));
        const reason = el('input', 'input'); reason.placeholder = 'Grund';
        side.append(reason);
        let hours = null;
        if (can('ban')) { hours = el('input', 'input'); hours.placeholder = 'Stunden (0 = für immer)'; hours.inputMode = 'numeric'; side.append(hours); }
        const pen = el('div', 'row');
        if (can('kick')) pen.append(confirmBtn('Kicken', 'Wirklich kicken?', 'ghost', () => adminAction('kick', { sid: p.sid, reason: reason.value }), 'door-open'));
        if (can('ban')) pen.append(confirmBtn('Bannen', 'Wirklich bannen?', 'danger', () => adminAction('ban', { uid: p.id, hours: parseFloat(hours.value) || 0, reason: reason.value }), 'ban'));
        if (higher) pen.querySelectorAll('button').forEach((b) => { b.disabled = true; });
        side.append(pen);
    }
    // Rang vergeben (ab Teamverwaltung, nur unter dem eigenen Rang)
    if (can('setRank')) {
        side.append(el('div', 'section-label', 'Team-Rang'));
        const r = el('div', 'row');
        const sel = el('select', 'input');
        const none = el('option', null, 'Kein Rang'); none.value = ''; sel.append(none);
        ((state.admin.me && state.admin.me.ranks) || []).forEach((rk) => {
            if (me.level >= 6 || rk.level < me.level) {
                const o = el('option', null, rk.label); o.value = rk.key;
                if (p.savedRank === rk.key) o.selected = true;
                sel.append(o);
            }
        });
        sel.style.flex = '1';
        r.append(sel, btn('Setzen', 'primary small', () => adminAction('setRank', { uid: p.id, rank: sel.value }), higher, 'shield'));
        side.append(r);
        if (p.rank && !p.savedRank) side.append(el('div', 'muted', 'Rang kommt aus der server.cfg oder einer Discord-Rolle.'));
    }
    if (can('troll')) {
        side.append(el('div', 'section-label', 'Troll'));
        const tr = el('div', 'admin-actions troll');
        (state.admin && state.admin.trolls || []).forEach(([kind, label]) => tr.append(btn(label, 'ghost', () => adminAction('troll', { sid: p.sid, kind }), p.dead || higher, 'sparkles')));
        side.append(tr);
    }
    return side;
}function renderAdmin() {
    const d = state.admin;
    const body = $('admin-body');
    if (!d || !body) return;
    body.textContent = '';
    const list = el('div', 'admin-list');
    let side = null;
    if (state.adminTab === 'players') {
        const table = el('table', 'table');
        const h = el('tr');
        ['ID', 'Spieler', 'Team', 'Ort', 'LVL', 'Geld', 'Ping'].forEach((x, i) => h.append(el('th', i >= 4 ? 'num' : null, x)));
        table.append(h);
        (d.players || []).forEach((p) => {
            const tr = el('tr', 'click' + (state.adminSel === p.id ? ' sel' : ''));
            const who = el('td'); who.append(txt(p.name));
            if (p.rank) { who.append(txt(' ')); who.append(paint(el('span', 'rank-tag', p.rank.label), p.rank.color)); }
            if (p.premium) { const f = el('span', 'flag gold'); f.append(icon('gem')); who.append(f); }
            if (p.muted > 0) { const f = el('span', 'flag red'); f.append(icon('mic-off')); who.append(f); }
            const team = el('td');
            if (p.tag) team.append(paint(el('span', 'chip', p.tag), p.color)); else team.append(el('span', 'muted', '–'));
            tr.append(el('td', null, '#' + p.id), who, team, el('td', 'muted', p.place || ''), el('td', 'num', p.level), el('td', 'num', money(p.money)), el('td', 'num', p.ping || 0));
            tr.addEventListener('click', () => { click(); state.adminSel = p.id; renderAdmin(); });
            table.append(tr);
        });
        list.append(table);
        if (!(d.players || []).length) list.append(el('div', 'empty', 'Niemand online.'));
        side = adminPlayerSide((d.players || []).find((p) => p.id === state.adminSel));
    } else if (state.adminTab === 'zones') {
        (d.zones || []).forEach((z) => {
            const row = el('div', 'zone');
            paint(row, z.ownerColor || '#42505e');
            const info = el('div');
            info.append(el('div', 'zone-name', z.name), el('div', 'zone-line', z.war ? 'Gangwar läuft' : 'Gehört ' + z.ownerName));
            const act = el('div', 'row');
            const sel = el('select', 'input');
            (d.teams || []).forEach((t) => {
                const o = el('option', null, t.key ? `[${t.tag}] ${t.name}` : 'Frei (niemand)');
                o.value = t.key;
                if (t.key === z.owner) o.selected = true;
                sel.append(o);
            });
            act.append(sel, btn('Setzen', 'primary small', () => adminAction('zone', { key: z.key, owner: sel.value }), false, 'flag'));
            if (z.war) act.append(confirmBtn('Beenden', 'Sicher?', 'danger small', () => adminAction('endwar', { key: z.key }), 'x'));
            row.append(el('i', 'zbar'), info, act);
            list.append(row);
        });
    } else if (state.adminTab === 'server') {
        if (d.db) {
            const dbb = el('div', 'card pad');
            dbb.style.marginBottom = '1.6rem';
            const line = el('div', 'dbline');
            line.append(icon(d.db.mode === 'mysql' ? 'circle-check' : 'info'), el('b', null, d.db.mode === 'mysql' ? 'MySQL' : 'Resource-KVP'), txt(d.db.status || ''));
            if (d.db.pending > 0) line.append(el('span', 'badge gold', d.db.pending + ' ausstehend'));
            dbb.append(el('div', 'card-title', 'Speicher'), line);
            list.append(dbb);
        }
        if (adminCan('announce')) {
            const box = el('div', 'card pad form');
            box.append(el('div', 'card-title', 'Ankündigung'));
            const ta = el('textarea', 'input'); ta.placeholder = 'Text für alle Spieler (Banner + Chat)'; ta.maxLength = 150;
            box.append(ta, btn('Senden', 'primary', () => { if (ta.value.trim()) { adminAction('announce', { text: ta.value.trim() }); ta.value = ''; } }, false, 'megaphone'));
            list.append(box);
        }
        if (adminCan('healAll') || adminCan('clearArena')) {
            const box2 = el('div', 'card pad form');
            box2.style.marginTop = '1.6rem';
            box2.append(el('div', 'card-title', 'Schnell'));
            const r = el('div', 'row');
            if (adminCan('healAll')) r.append(btn('Alle heilen', 'ghost', () => adminAction('healAll'), false, 'heart-pulse'));
            if (adminCan('clearArena')) r.append(confirmBtn('Alle FFA-Arenen leeren', 'Wirklich alle?', 'ghost', () => adminAction('clearArena', {}), 'door-open'));
            box2.append(r);
            list.append(box2);
        }
        if (adminCan('clearArena')) {
            const box3 = el('div', 'card pad');
            box3.style.marginTop = '1.6rem';
            box3.append(el('div', 'card-title', 'FFA-Arenen'));
            (d.arenas || []).forEach((a) => {
                const row = el('div', 'member');
                row.style.marginTop = '0.6rem';
                row.append(el('i', 'on' + (a.players > 0 ? ' yes' : '')), el('span', null, a.name), el('span', 'muted', `${a.players}/${a.max}`), btn('Leeren', 'ghost small', () => adminAction('clearArena', { index: a.index }), a.players === 0));
                box3.append(row);
            });
            list.append(box3);
        }
        side = el('div', 'admin-side');
        side.append(el('div', 'card-title', 'Private Teams'));
        const priv = (d.teams || []).filter((t) => t.private);
        if (!priv.length) side.append(el('div', 'muted', 'Keine privaten Teams.'));
        priv.forEach((t) => {
            const row = el('div', 'member');
            row.append(paint(el('span', 'chip', t.tag), t.color), el('span', null, t.name), el('span'));
            if (adminCan('disband')) row.append(confirmBtn('Auflösen', 'Sicher?', 'ghost small', () => adminAction('disband', { id: t.id }), 'trash'));
            side.append(row);
        });
    } else if (state.adminTab === 'bans') {
        const table = el('table', 'table');
        const h = el('tr');
        ['Spieler', 'Grund', 'Von', 'Dauer', ''].forEach((x) => h.append(el('th', null, x)));
        table.append(h);
        (d.bans || []).forEach((b) => {
            const tr = el('tr');
            const who = el('td'); who.append(txt(b.name || '?'), el('span', 'uid', '#' + b.uid));
            const act = el('td'); act.append(confirmBtn('Aufheben', 'Sicher?', 'ghost small', () => adminAction('unban', { license: b.license }), 'check'));
            tr.append(who, el('td', null, b.reason || '–'), el('td', 'muted', b.by || '–'), el('td', 'muted', untilText(b['until'])), act);
            table.append(tr);
        });
        list.append(table);
        if (!(d.bans || []).length) list.append(el('div', 'empty', 'Niemand ist gebannt.'));
    }
    body.append(list);
    if (side) body.append(side); else body.style.gridTemplateColumns = '1fr';
    if (side) body.style.gridTemplateColumns = '';
}
function showAdmin(d, open) {
    state.admin = d;
    if (open || state.screen !== 'admin') {
        const scr = $('scr-admin');
        scr.textContent = '';
        const panel = el('div', 'panel admin');
        // Tabs nur zeigen, wenn der eigene Rang dort etwas darf
        const tabsAllowed = ADMIN_TABS.filter(([k]) => k === 'players' || (k === 'zones' && adminCan('zone'))
            || (k === 'server' && (adminCan('announce') || adminCan('clearArena') || adminCan('disband'))) || (k === 'bans' && adminCan('unban')));
        if (!tabsAllowed.find(([k]) => k === state.adminTab)) state.adminTab = 'players';
        const tabs = seg(tabsAllowed, state.adminTab, (k) => { state.adminTab = k; renderAdmin(); });
        const refresh = iconBtn('refresh-cw', '', () => post('adminRefresh'), 'Neu laden');
        const me = d.me && d.me.rank;
        const myRank = me ? paint(el('span', 'rank-tag big', me.label), me.color) : el('span');
        panel.append(panelHead('Admin', [myRank, tabs, refresh], true, 'admin'));
        const body = el('div', 'admin-body');
        body.id = 'admin-body';
        panel.append(body);
        scr.append(panel);
        showScreen('admin');
    }
    renderAdmin();
}

// ================================================================== Nachrichten vom Spiel
const handlers = {
    init(d) {
        if (d.config) Object.assign(state.config, d.config);
        if (d.settings) Object.assign(state.settings, d.settings);
        applySettings();
    },
    // Bildschirme
    login(d) { showLogin(d.data || {}); },
    loginError(d) { const e = $('login-error'); if (e) e.textContent = d.text || 'Das hat nicht geklappt. Versuch es noch einmal.'; },
    loginOk(d) { setAccount(d.account); },
    teams(d) { showTeams(d.data || {}, d.closable); },
    menu(d) {
        state.menu = d.data;
        if (d.page && RENDER[d.page]) state.page = d.page;
        if (d.open || state.screen !== 'menu') {
            state.bpScroll = null;
            buildMenu();
            showScreen('menu');
            requestAnimationFrame(() => moveNavPill(false));
            renderMenu(true);
        } else {
            renderMenu(false);
        }
    },
    garage(d) { showGarage(d.data || {}); },
    admin(d) { showAdmin(d.data || {}, d.open); },
    adminFlag() {},
    closeScreen(d) { hideScreen(d.screen); },
    closeAll() { hideAll(); },
    joined(d) { takeover(d.team); },

    // HUD
    account(d) { setAccount(d.account); },
    mode(d) { setMode(d); },
    hudData(d) { setHudData(d.data); },
    hudVisible(d) { $('hud').classList.toggle('hidden-pause', !d.show); },
    vitals(d) { setVitals(d); },
    hit(d) {
        showHitmarker(d.kill);
        showDamageNumber(d.dmg, d.armour, d.kill);
        if (!d.kill && state.settings.hitSound) (d.armour ? sounds.armour : sounds.hit)();
    },
    kill(d) { killPop(d); },
    damaged(d) { flash(d.armour); showDirection(d.angle, d.armour); },
    killfeed(d) { if (d.entry) addKillfeed(d.entry); },
    announce(d) { announce(d.text); },
    notify(d) { toast(d.kind, d.text); },
    death(d) { showDeath(d); },
    deathPhoto(d) { deathPhoto(d.url); },
    wheelResult(d) { if (d.data) spinWheel(d.data); },
    itemBar(d) { showItemBar(d); },
    help(d) { showHelp(d.data || {}); },
    itemCounts(d) { showItemCounts(d); },
    wardrobe(d) { showWardrobe(d.slots || []); },
    menuPage(d) { if (d.page) openPage(d.page); },
    war(d) { setWar(d.war); },
    warEnd(d) { showWarEnd(d.result); },
    zone(d) {
        $('zonewarn').classList.toggle('off', !d.show);
        if (d.show) $('zone-sec').textContent = d.seconds;
    },
    protect(d) {
        const p = $('protect');
        every('protect', 0, null);
        if (!d.show) { p.classList.add('off'); return; }
        let left = Math.max(1, Math.round(d.seconds || 3));
        $('protect-sec').textContent = left;
        p.classList.remove('off');
        every('protect', 1000, () => {
            left -= 1;
            if (left <= 0) { every('protect', 0, null); p.classList.add('off'); return; }
            $('protect-sec').textContent = left;
        });
    },
    ammo(d) { setAmmo(d.ammo); },
    prompt(d) { showPrompt(d); },

    // Chat
    chat(d) { addChat(d.msg); },
    chatOpen(d) { openChat(d.channel); },
    chatClose() { closeChat(); },
    chatClear() { $('chat-log').textContent = ''; },
    chatSuggestions(d) { chat.suggestions = Array.isArray(d.list) ? d.list : []; renderSuggest(); },
};

window.addEventListener('message', (event) => {
    const d = event.data;
    if (d && typeof d.type === 'string' && handlers[d.type]) {
        try { handlers[d.type](d); } catch (e) { console.error('[gangwar-ui]', d.type, e); }
    }
});

// Tasten, solange ein Bildschirm offen ist (das Spiel bekommt sie dann nicht)
document.addEventListener('keydown', (e) => {
    if (chat.open) return;
    const typing = e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT');
    if (e.key === 'Escape') {
        if (window.openerBusy) { e.preventDefault(); return; }                         // Case dreht noch
        const op = $('opener');
        if (op && !op.classList.contains('off') && typeof closeOpener === 'function') { e.preventDefault(); closeOpener(); return; }
        if (state.screen) { e.preventDefault(); post('closeScreen', { screen: state.screen }); }
    } else if (e.key === 'F1' || e.key === 'F2' || e.key === 'F6' || e.key === 'F11') {
        e.preventDefault();
        post('key', { key: e.key });
    } else if (state.screen === 'menu' && !typing && (e.key === 'q' || e.key === 'Q' || e.key === 'e' || e.key === 'E')) {
        // Q / E blättern durch die Seiten wie im GTA-Pausenmenü
        const keys = NAV.flatMap(([, items]) => items.map((i) => i[0])).filter((k) => RENDER[k]);
        const i = keys.indexOf(state.page);
        const next = (e.key === 'q' || e.key === 'Q') ? i - 1 : i + 1;
        openPage(keys[(next + keys.length) % keys.length]);
    }
});

fillIcons();
applySettings();
post('nuiReady');
