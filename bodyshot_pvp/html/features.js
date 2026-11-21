'use strict';
// =======================================================================
//  Neu in v4: Tagesmissionen, Cases & Skins, 1v1-Duelle, Kopfgeld
//  (benutzt die Helfer aus app.js: el, btn, icon, money, RENDER, handlers …)
//  Alles von Spielern kommt nur als Text in die Seite, nie als HTML.
// =======================================================================

// ------------------------------------------------------------------ Waffen-Silhouetten (eigene Zeichnung)
// viewBox 0 0 200 64, Mündung rechts. Jede Teilfläche ist ein eigener Pfad.
const SIL = {
    rifle: [
        'M4 30 L42 23 L50 23 L50 36 L42 37 L8 47 L4 45 Z',
        'M48 21 L122 21 L122 33 L48 33 Z',
        'M64 32 L75 32 L71 50 L60 49 Z',
        'M90 32 L102 32 L109 52 L97 56 Z',
        'M120 23 L156 23 L156 31 L120 31 Z',
        'M120 18 L158 18 L158 22 L120 22 Z',
        'M154 25 L196 25 L196 29 L154 29 Z',
        'M110 17 L117 17 L117 22 L110 22 Z',
        'M176 19 L180 19 L180 26 L176 26 Z',
    ],
    carbine: [
        'M4 25 L38 25 L38 23 L54 23 L54 33 L38 33 L38 37 L8 40 L4 36 Z',
        'M52 21 L118 21 L118 32 L52 32 Z',
        'M60 21 L60 15 L100 15 L100 21 Z',
        'M66 31 L77 31 L72 50 L62 48 Z',
        'M88 31 L100 31 L103 52 L91 53 Z',
        'M116 22 L158 22 L158 31 L116 31 Z',
        'M150 22 L150 13 L155 13 L155 22 Z',
        'M156 25 L192 25 L192 28 L156 28 Z',
        'M189 23.5 L197 23.5 L197 29.5 L189 29.5 Z',
    ],
    bullpup: [
        'M6 26 L20 22 L120 22 L120 36 L92 36 L88 40 L60 40 L60 37 L24 38 L8 40 Z',
        'M44 22 L44 14 L98 14 L98 22 Z',
        'M78 35 L89 35 L86 54 L76 53 Z',
        'M36 36 L49 36 L51 55 L38 56 Z',
        'M118 22 L144 22 L144 34 L118 34 Z',
        'M142 26 L194 26 L194 30 L142 30 Z',
    ],
    compact: [
        'M20 17 L56 17 L56 21 L20 21 Z',
        'M30 21 L46 21 L46 31 L32 29 Z',
        'M44 21 L120 21 L120 33 L44 33 Z',
        'M60 32 L71 32 L67 50 L56 49 Z',
        'M84 32 L96 32 L103 51 L91 55 Z',
        'M118 23 L148 23 L148 31 L118 31 Z',
        'M146 25 L178 25 L178 29 L146 29 Z',
        'M162 19 L166 19 L166 26 L162 26 Z',
    ],
    tommy: [
        'M4 31 C20 26 34 24 50 24 L50 36 C36 38 20 42 6 47 Z',
        'M48 23 L122 23 L122 35 L48 35 Z',
        'M62 34 L73 34 L69 52 L58 51 Z',
        'M80 44 A12 12 0 1 0 104 44 A12 12 0 1 0 80 44 Z',
        'M132 34 L142 34 L145 52 L134 52 Z',
        'M120 22 L172 22 L172 34 L120 34 Z',
        'M120 26 L190 26 L190 31 L120 31 Z',
        'M178 20 L182 20 L182 26 L178 26 Z',
    ],
};
const silCache = {};
function silData(shape) {
    shape = SIL[shape] ? shape : 'rifle';
    if (!silCache[shape]) {
        const paths = SIL[shape].map((d) => `<path d="${d}" fill="#000"/>`).join('');
        const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 64">${paths}</svg>`;
        silCache[shape] = `url("data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}")`;
    }
    return silCache[shape];
}
function weaponShape(name) {
    const n = String(name || '').toUpperCase();
    if (n.includes('BULLPUP') || n.includes('ADVANCED')) return 'bullpup';
    if (n.includes('GUSENBERG')) return 'tommy';
    if (n.includes('COMPACT')) return 'compact';
    if (n.includes('CARBINE') || n.includes('MILITARY') || n.includes('TACTICAL')) return 'carbine';
    return 'rifle';
}

// ------------------------------------------------------------------ Skin-Materialien (Farbton oder Muster)
function svgUri(w, h, body) {
    return `url("data:image/svg+xml;charset=utf-8,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`)}")`;
}
function seeded(seed) { let s = seed >>> 0; return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296); }
const PATTERNS = {
    digital() {
        const r = seeded(7), cols = ['#3a454c', '#9aa7ad', '#56636b', '#232b30'];
        let b = '<rect width="48" height="48" fill="#6d7b84"/>';
        for (let i = 0; i < 80; i++) b += `<rect x="${Math.floor(r() * 12) * 4}" y="${Math.floor(r() * 12) * 4}" width="${4 * (1 + Math.floor(r() * 3))}" height="${4 * (1 + Math.floor(r() * 2))}" fill="${cols[i % 4]}"/>`;
        return [svgUri(48, 48, b), '2.4rem'];
    },
    brush() {
        const r = seeded(11), cols = ['#4f5a35', '#7a6a45', '#2e3424', '#a49a72'];
        let b = '<rect width="60" height="60" fill="#5f6b45"/>';
        for (let i = 0; i < 16; i++) {
            const x = r() * 60, y = r() * 60, w = 14 + r() * 22;
            b += `<path d="M${x} ${y} q${w / 2} ${-4 - r() * 6} ${w} ${r() * 6 - 3}" stroke="${cols[i % 4]}" stroke-width="${4 + r() * 5}" stroke-linecap="round" fill="none"/>`;
        }
        return [svgUri(60, 60, b), '3.2rem'];
    },
    woodland() {
        const r = seeded(5), cols = ['#2f3b22', '#6b5a3a', '#1d2216', '#4f6a33'];
        let b = '<rect width="64" height="64" fill="#7d8a4f"/>';
        for (let i = 0; i < 22; i++) b += `<ellipse cx="${r() * 64}" cy="${r() * 64}" rx="${5 + r() * 9}" ry="${3 + r() * 6}" transform="rotate(${r() * 180} 32 32)" fill="${cols[i % 4]}"/>`;
        return [svgUri(64, 64, b), '3.4rem'];
    },
    skull() {
        let b = '<rect width="40" height="40" fill="#15171b"/>';
        [[10, 10], [30, 30]].forEach(([x, y]) => {
            b += `<circle cx="${x}" cy="${y}" r="6" fill="#e9e6df"/><rect x="${x - 3.5}" y="${y + 3}" width="7" height="5" rx="1" fill="#e9e6df"/>`;
            b += `<circle cx="${x - 2.3}" cy="${y}" r="1.6" fill="#15171b"/><circle cx="${x + 2.3}" cy="${y}" r="1.6" fill="#15171b"/>`;
        });
        return [svgUri(40, 40, b), '2.2rem'];
    },
    sessanta() {
        let b = '<rect width="40" height="40" fill="#1f8a4c"/>';
        b += '<path d="M0 40 L40 0 L40 14 L14 40 Z" fill="#f4f1ea"/><path d="M26 40 L40 26 L40 40 Z" fill="#d23a2e"/><path d="M0 26 L26 0 L14 0 L0 14 Z" fill="#d23a2e"/>';
        return [svgUri(40, 40, b), '2.4rem'];
    },
    perseus() {
        let b = '<rect width="32" height="32" fill="#141210"/>';
        b += '<path d="M0 16 L16 4 L32 16 L32 22 L16 10 L0 22 Z" fill="#d8b04a"/><path d="M0 32 L16 20 L32 32 L32 38 L16 26 L0 38 Z" fill="#a8822c"/>';
        return [svgUri(32, 32, b), '1.8rem'];
    },
    leopard() {
        const r = seeded(3);
        let b = '<rect width="56" height="56" fill="#d9a441"/>';
        for (let i = 0; i < 14; i++) {
            const x = r() * 56, y = r() * 56, rx = 3 + r() * 3;
            b += `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${rx * 0.8}" fill="none" stroke="#3b2310" stroke-width="2.4" stroke-dasharray="5 2"/><ellipse cx="${x}" cy="${y}" rx="${rx * 0.5}" ry="${rx * 0.4}" fill="#b37a25"/>`;
        }
        return [svgUri(56, 56, b), '3rem'];
    },
    zebra() {
        let b = '<rect width="48" height="48" fill="#f2f2ef"/>';
        for (let i = -1; i < 7; i++) b += `<path d="M${i * 8} 0 Q${i * 8 + 10} 12 ${i * 8 + 2} 24 T${i * 8 + 6} 48 L${i * 8 + 10} 48 Q${i * 8 + 12} 36 ${i * 8 + 6} 24 T${i * 8 + 4} 0 Z" fill="#141414"/>`;
        return [svgUri(48, 48, b), '2.8rem'];
    },
    geometric() {
        const cols = ['#19c2c9', '#ff8a2a', '#8a4cff', '#f4f6f8', '#1d2733'];
        let b = '<rect width="40" height="40" fill="#1d2733"/>';
        let i = 0;
        for (let y = 0; y < 40; y += 20) for (let x = 0; x < 40; x += 20) {
            b += `<path d="M${x} ${y} L${x + 20} ${y} L${x} ${y + 20} Z" fill="${cols[i++ % 5]}"/><path d="M${x + 20} ${y} L${x + 20} ${y + 20} L${x} ${y + 20} Z" fill="${cols[(i + 2) % 5]}"/>`;
        }
        return [svgUri(40, 40, b), '2.2rem'];
    },
    boom() {
        let b = '<rect width="48" height="48" fill="#ffd21f"/>';
        b += '<path d="M24 4 L29 17 L43 13 L33 24 L44 34 L30 31 L24 44 L19 31 L5 34 L15 24 L5 13 L19 17 Z" fill="#ff3b30"/>';
        b += '<circle cx="24" cy="24" r="6" fill="#ffffff"/><circle cx="6" cy="44" r="3" fill="#1f6bff"/><circle cx="44" cy="4" r="3" fill="#1f6bff"/>';
        return [svgUri(48, 48, b), '3rem'];
    },
    patriot() {
        let b = '<rect width="48" height="48" fill="#f4f4f4"/>';
        for (let y = 0; y < 48; y += 8) b += `<rect y="${y}" width="48" height="4" fill="#c8202f"/>`;
        b += '<rect width="22" height="22" fill="#1f3a8a"/>';
        [[5, 5], [16, 5], [10.5, 11], [5, 17], [16, 17]].forEach(([x, y]) => { b += `<circle cx="${x}" cy="${y}" r="1.8" fill="#fff"/>`; });
        return [svgUri(48, 48, b), '2.8rem'];
    },
    luxe() {
        let b = '';
        for (let i = 0; i < 4; i++) b += `<path d="M${i * 12} 24 c4 -10 8 -10 12 0 s8 10 12 0" fill="none" stroke="rgba(70,40,0,.55)" stroke-width="1.2"/>`;
        b += '<path d="M0 6 L48 6 M0 42 L48 42" stroke="rgba(255,255,255,.35)" stroke-width="1"/>';
        return [svgUri(48, 48, b), '2.2rem', 'linear-gradient(180deg, #fff1b8 0%, #f0c14b 30%, #b9821a 70%, #f6d77a 100%)'];
    },
};
const patternCache = {};
function skinMat(s) {
    if (!s) return 'linear-gradient(180deg, #c3ccd4 0%, #8b96a0 40%, #4b545c 100%)';
    if (s.pattern && PATTERNS[s.pattern]) {
        const [img, size, base] = patternCache[s.pattern] || (patternCache[s.pattern] = PATTERNS[s.pattern]());
        return `${img} 0 0 / ${size} ${size} repeat` + (base ? `, ${base}` : '');
    }
    const c = s.colors || ['#4a535b', '#1a1e22'];
    return `linear-gradient(180deg, ${c[0]} 0%, ${c[0]} 34%, ${c[1]} 100%)`;
}
function silhouette(shape, skin) {
    const d = el('div', 'sil');
    d.style.setProperty('--shape', silData(shape));
    d.style.setProperty('--mat', skinMat(skin));
    return d;
}
function rarityPaint(node, color) {
    const c = hexRgb(color) ? color : '#9fb3c8';
    node.style.setProperty('--r', c);
    [22, 28, 30, 55].forEach((a) => node.style.setProperty(`--r-a${a}`, rgba(c, a / 100)));
    return node;
}
function miniCase(color, sizeRem) {
    const m = el('span', 'mini-case');
    paint(m, color || '#19b2ff');
    if (sizeRem) m.style.setProperty('--ms', sizeRem + 'rem');
    return m;
}
function rewardText(r) {
    if (!r) return '–';
    const parts = [];
    if (r.money > 0) parts.push(money(r.money));
    if (r.xp > 0) parts.push(num(r.xp) + ' XP');
    if (r.caseName) parts.push(r.caseName);
    return parts.join(' + ') || '–';
}
if (typeof TOAST_ICON === 'object') TOAST_ICON.mission = 'circle-check';
function sectionHead(title, extra) {
    const h = el('div', 'streak-head');
    h.append(el('span', 'section-label', title));
    if (extra) { h.append(el('div', 'grow')); (Array.isArray(extra) ? extra : [extra]).forEach((x) => h.append(x)); }
    return h;
}

// ================================================================== Täglich
const MISSION_ICON = { kill: 'crosshair', ffaKill: 'target', gwKill: 'swords', gwPlayed: 'flag', gwWin: 'trophy', streak: 'flame', hit: 'zap',
    duelPlayed: 'swords', duelWin: 'medal', bountyClaim: 'coins', bountyPlace: 'banknote', caseOpen: 'package', minutes: 'clock' };
RENDER.daily = (d, page) => {
    const dv = d.daily || {};
    if (!dv.enabled) { page.append(el('div', 'empty', 'Tagesmissionen sind auf diesem Server ausgeschaltet.')); return; }
    const wrap = el('div', 'daily');
    const left = el('div');
    // Login-Serie
    const lg = dv.login || {};
    const streak = el('b', null, `${lg.streak || 0} ${plural(lg.streak || 0, 'Tag', 'Tage')}`);
    const sh = el('div', 'streak-head');
    sh.append(el('span', 'section-label', 'Login-Serie'), streak, el('div', 'grow'));
    if (lg.claimable) sh.append(btn('Tagesbonus abholen', 'gold', () => action('loginClaim'), false, 'gift'));
    else sh.append(el('span', 'badge green', 'Heute abgeholt'));
    left.append(sh);
    const days = el('div', 'days');
    (lg.days || []).forEach((x) => {
        const c = el('div', 'day ' + (x.state || 'future'));
        const ico = el('div', 'dico');
        if (x.case) ico.append(miniCase(x.caseColor, 4.6)); else ico.append(icon('banknote'));
        c.append(el('span', 'dnum', 'Tag ' + x.day), ico, el('span', 'dval', rewardText(x)));
        days.append(c);
    });
    left.append(stagger(days));
    // Missionen
    const rs = el('span', 'reset');
    const rt = el('span');
    liveClock(rt, dv.resetIn, (t) => 'Neue Missionen in ' + t);
    rs.append(icon('clock'), rt);
    left.append(sectionHead('Missionen von heute', rs));
    const list = el('div', 'missions');
    (dv.list || []).forEach((m) => {
        const row = el('div', 'mission' + (m.claimed ? ' claimed' : m.done ? ' done' : ''));
        const mi = el('div', 'mico');
        mi.append(icon(m.done ? 'circle-check' : (MISSION_ICON[m.stat] || 'target')));
        const mid = el('div');
        mid.append(el('div', 'mtext', m.text));
        const rew = el('div', 'mrew');
        if (m.money > 0) rew.append(el('span', 'm', '+' + money(m.money)));
        if (m.xp > 0) rew.append(el('span', 'x', `+${num(m.xp)} XP`));
        const prog = el('div', 'mprog');
        const bar = el('div', 'bar' + (m.done ? ' green' : ''));
        const fill = el('i');
        bar.append(fill);
        requestAnimationFrame(() => requestAnimationFrame(() => { fill.style.width = pct(m.progress, m.goal) + '%'; }));
        prog.append(bar, el('b', null, `${num(m.progress)} / ${num(m.goal)}`));
        mid.append(rew, prog);
        let b;
        if (m.claimed) b = btn('Abgeholt', 'small', null, true, 'check');
        else if (m.done) b = btn('Abholen', 'go', () => action('missionClaim', { index: m.index }), false, 'gift');
        else b = btn('Läuft', 'small', null, true);
        row.append(mi, mid, b);
        list.append(row);
    });
    left.append(stagger(list));
    // Rechts: Bonus für alle 3
    const right = el('div', 'grid');
    const bc = el('div', 'card bonus-card');
    bc.append(reticle(10), el('div', 'card-title', 'Alle drei geschafft'), el('div', 'muted', 'Bonus obendrauf: ' + rewardText(dv.bonus)));
    const steps = el('div', 'steps');
    const total = (dv.list || []).length || 3;
    for (let i = 0; i < total; i++) steps.append(el('i', i < (dv.claimedCount || 0) ? 'on' : ''));
    bc.append(steps, dv.bonusDone ? el('span', 'badge green', 'Bonus abgeholt') : el('span', 'muted', `${dv.claimedCount || 0} von ${total} abgeholt`));
    right.append(bc);
    const info = el('div', 'card pad');
    info.append(el('div', 'card-title', 'So funktioniert es'), el('p', 'muted', 'Jeden Tag um Mitternacht gibt es drei neue Missionen. Wer jeden Tag einloggt, baut seine Serie aus – Tag 3 und Tag 6 bringen Cases, Tag 7 eine Gold Case. Einen Tag verpasst heißt: wieder bei Tag 1.'));
    info.lastChild.style.marginTop = '0.8rem';
    right.append(info);
    wrap.append(left, right);
    page.append(wrap);
};

// ================================================================== Cases & Skins
function crate(c) {
    const stage = el('div', 'case-stage');
    const fl = el('div', 'crate-float');
    const cr = el('div', 'crate');
    const front = el('div', 'face front');
    const img = new Image();
    img.src = BRAND.mark;
    img.onerror = () => img.remove();
    front.append(img);
    cr.append(el('div', 'face top'), el('div', 'face side'), front);
    fl.append(cr);
    stage.append(fl);
    return stage;
}
function caseCard(c, d) {
    const card = el('div', 'card case-card hover-lift');
    paint(card, c.color);
    const stage = crate(c);
    if (c.owned > 0) { const b = el('span', 'badge gold own'); b.append(icon('package'), txt(`${c.owned}x vorhanden`)); stage.append(b); }
    const body = el('div', 'case-body');
    const head = el('div', 'row');
    head.append(el('div', 'case-name grow', c.name), el('span', 'badge ' + (c.price > 0 ? 'blue' : 'gold'), c.price > 0 ? money(c.price) : 'Nur Belohnung'));
    body.append(head, el('div', 'muted', `${c.count} Skins drin`));
    const odds = el('div', 'odds');
    const legend = el('div', 'odds-legend');
    (c.odds || []).forEach((o) => {
        const seg_ = paint(el('i'), o.color);
        seg_.style.width = o.percent + '%';
        odds.append(seg_);
        const s = el('span'); const dot = paint(el('i'), o.color); s.append(dot, txt(`${o.name} ${String(o.percent).replace('.', ',')} %`)); legend.append(s);
    });
    body.append(odds, legend);
    const prev = el('div', 'case-preview');
    (c.preview || []).slice(0, 5).forEach((s) => { const k = rarityPaint(el('div', 'sk'), s.rarityColor); k.append(silhouette(s.shape, s)); k.title = `${s.weaponLabel} | ${s.name}`; prev.append(k); });
    body.append(prev);
    let b;
    const money_ = (d.account && d.account.money) || 0;
    if (c.owned > 0) b = btn('Öffnen', 'gold block', () => action('caseOpen', { case: c.key }), false, 'package');
    else if (c.price > 0) {
        const short = c.price - money_;
        b = btn(short > 0 ? 'Dir fehlen ' + money(short) : 'Kaufen und öffnen', (short > 0 ? '' : 'primary') + ' block', () => action('caseOpen', { case: c.key }), short > 0, short > 0 ? null : 'package');
    } else b = btn('Gibt es als Belohnung', 'block', null, true, 'lock');
    body.append(b);
    card.append(stage, body);
    return card;
}
function skinCard(s) {
    const card = rarityPaint(el('div', 'skin' + (s.equipped ? ' equipped' : '')), s.rarityColor);
    const art = el('div', 'art');
    art.append(silhouette(s.shape, s));
    if (s.equipped) { const e = el('span', 'badge blue eq'); e.append(icon('check'), txt('Ausgerüstet')); card.append(e); }
    const meta = el('div', 'meta');
    meta.append(el('span', 'wname', nb(s.weaponLabel)), el('span', 'sname', s.name), el('span', 'rar', s.rarityName || s.rarity));
    if (s.equipped) meta.append(btn('Ablegen', 'ghost small block', () => action('skinUnequip', { weapon: s.weapon }), false, 'x'));
    else meta.append(btn('Ausrüsten', 'primary small block', () => action('skinEquip', { id: s.id }), false, 'check'));
    if (!s.ownsWeapon) meta.append(el('span', 'muted', 'Waffe noch nicht gekauft'));
    card.append(art, meta);
    return card;
}
RENDER.cases = (d, page) => {
    const cv = d.cases || { cases: [], skins: [], total: 0 };
    state.casesTab = state.casesTab || 'cases';
    const tools = el('div', 'page-tools');
    tools.append(seg([['cases', 'Cases'], ['skins', `Meine Skins (${(cv.skins || []).length} von ${cv.total || 0})`]], state.casesTab, (k) => { state.casesTab = k; renderMenu(true); }));
    tools.append(el('div', 'grow'));
    const bal = el('span', 'balance'); bal.append(icon('wallet'), txt(money(d.account && d.account.money))); tools.append(bal);
    page.append(tools);
    if (state.casesTab === 'skins') {
        const grid = el('div', 'skins');
        (cv.skins || []).forEach((s) => grid.append(skinCard(s)));
        if (!(cv.skins || []).length) grid.append(el('div', 'empty', 'Noch keine Skins. Öffne eine Case.'));
        page.append(stagger(grid));
        return;
    }
    const grid = el('div', 'cases');
    (cv.cases || []).forEach((c) => grid.append(caseCard(c, d)));
    page.append(stagger(grid));
    page.append(el('div', 'rules-line', 'Doppelt gezogen? Dann gibt es Geld zurück: je seltener, desto mehr. Skins gehören dir für immer und gelten für die Waffe, auf der sie liegen.'));
    page.lastChild.style.marginTop = '1.8rem';
};

// ------------------------------------------------------------------ Case öffnen: Rolle
let opener = null;
window.openerBusy = false;
function remPx() { return window.innerHeight / 108; }
function openCase(data) {
    const box = $('opener');
    box.textContent = '';
    paint(box, data.color || '#19b2ff');
    window.openerBusy = true;
    const title = el('div', 'otitle', data.caseName || 'Case');
    const wrap = el('div', 'reel-wrap');
    const reel = el('div', 'reel');
    (data.reel || []).forEach((s) => {
        const it = rarityPaint(el('div', 'it'), s && s.rarityColor);
        it.append(silhouette(s && s.shape, s), el('span', null, s ? `${nb(s.weaponLabel)} | ${s.name}` : ''));
        reel.append(it);
    });
    wrap.append(reel, el('i', 'reel-mark'));
    box.append(title, wrap);
    box.classList.remove('off');
    const rem = remPx();
    const itemW = 18 * rem;                                    // 17rem + 1rem Abstand
    const center = ((data.win || 1) - 1) * itemW + 8.5 * rem;
    const jitter = (Math.random() - 0.5) * 12 * rem;
    const target = 75 * rem - (center + jitter);
    const start = 75 * rem - 8.5 * rem;                        // erstes Feld unter der Markierung
    const dur = 5800;
    const t0 = performance.now();
    let lastIdx = -1;
    const ease = (t) => 1 - Math.pow(1 - t, 4);
    reel.style.transform = `translateX(${start}px)`;
    const frame = (now) => {
        const t = Math.min(1, (now - t0) / dur);
        const x = start + (target - start) * ease(t);
        reel.style.transform = `translateX(${x}px)`;
        const idx = Math.floor((75 * rem - x) / itemW);
        if (idx !== lastIdx) { lastIdx = idx; tone(1300 + (t * 400), 0.025, 'square', 0.07); }
        if (t < 1) opener = requestAnimationFrame(frame);
        else setTimeout(() => revealSkin(data), 380);
    };
    opener = requestAnimationFrame(frame);
}
function revealSkin(data) {
    const box = $('opener');
    const s = data.skin || {};
    if (state.screen !== 'menu') {                    // Menü wurde zwischendurch geschlossen
        toast('success', `${nb(s.weaponLabel || '')} | ${s.name || ''} (${s.rarityName || s.rarity || ''})` + (data.duplicate ? ` – Duplikat, +${money(data.refund)}` : ''));
        closeOpener();
        return;
    }
    box.textContent = '';
    const r = rarityPaint(el('div', 'reveal'), s.rarityColor);
    const art = el('div', 'rart');
    art.append(el('i', 'rays'), silhouette(s.shape, s));
    r.append(art, el('span', 'rrar', s.rarityName || s.rarity || ''), el('div', 'rname', s.name || ''), el('div', 'rweapon', nb(s.weaponLabel || '')));
    if (data.duplicate) r.append(el('div', 'rdup', `Schon im Besitz – dafür +${money(data.refund)}`));
    const row = el('div', 'row');
    row.style.marginTop = '1.6rem';
    if (!data.duplicate) row.append(btn('Gleich ausrüsten', 'primary', () => { action('skinEquip', { id: s.id }); closeOpener(); }, false, 'check'));
    row.append(btn('Weiter', 'ghost', closeOpener, false, 'arrow-right'));
    r.append(row);
    box.append(r);
    const rare = { common: 0, rare: 1, epic: 2, legendary: 3 }[s.rarity] || 0;
    [0, 1, 2, 3].slice(0, rare + 2).forEach((i) => tone(520 * Math.pow(1.26, i + rare), 0.16, 'sine', 0.45, i * 0.09));
    window.openerBusy = false;
}
function closeOpener() {
    if (opener) cancelAnimationFrame(opener);
    opener = null;
    window.openerBusy = false;
    $('opener').classList.add('off');
    $('opener').textContent = '';
    post('refresh');
}

// ================================================================== 1v1-Duelle
function onlineOthers(d) {
    const me = d.account ? d.account.id : -1;
    return (d.players || []).filter((p) => p.id !== me);
}
function playerPicker(d, form, key, onPick) {
    const box = el('div', 'field');
    const top = el('div', 'row');
    const search = el('label', 'search');
    search.style.flex = '1';
    const si = el('input', 'input');
    si.placeholder = 'Name oder User-ID';
    si.value = form.q || '';
    search.append(icon('search'), si);
    top.append(search);
    box.append(top);
    const list = el('div', 'pick-list');
    const draw = () => {
        list.textContent = '';
        const q = si.value.trim().toLowerCase();
        const rows = onlineOthers(d).filter((p) => !q || String(p.name).toLowerCase().includes(q) || String(p.id) === q);
        rows.forEach((p) => {
            const r = el('div', 'pick' + (form[key] === p.id ? ' sel' : ''));
            const who = el('span');
            who.append(txt(p.name), el('span', 'uid', '#' + p.id));
            const tag = p.tag ? paint(el('span', 'chip', p.tag), p.color) : el('span');
            r.append(tag, who, el('span', 'muted', p.place || ''));
            r.addEventListener('click', () => { click(); form[key] = p.id; form.q = si.value; onPick(); });
            list.append(r);
        });
        if (/^\d+$/.test(q) && !rows.length) {
            const r = el('div', 'pick' + (form[key] === Number(q) ? ' sel' : ''));
            r.append(icon('hash'), el('span', null, 'User-ID ' + q), el('span', 'muted', 'nicht in der Liste'));
            r.addEventListener('click', () => { click(); form[key] = Number(q); form.q = si.value; onPick(); });
            list.append(r);
        }
        if (!list.children.length) list.append(el('div', 'muted', 'Niemand gefunden.'));
    };
    si.addEventListener('input', () => { form.q = si.value; draw(); });
    draw();
    box.append(list);
    return box;
}
function arenaPick(a, selected, onPick) {
    const box = el('div', 'arena-pick' + (selected ? ' sel' : ''));
    box.append(el('span', null, a.name));
    box.addEventListener('click', () => { click(); onPick(); });
    requestAnimationFrame(() => {
        const { c, fit } = canvasFor(box);
        c.style.position = 'absolute';
        const dpr = fit();
        const ctx = c.getContext('2d');
        const w = c.width, h = c.height;
        const mpp = Math.max(0.5, (a.radius * 5) / (w / dpr)) / dpr;
        drawRoads(ctx, w, h, { cx: a.center.x, cy: a.center.y, mpp }, true);
        const P = (x, y) => [w / 2 + (x - a.center.x) / mpp, h / 2 - (y - a.center.y) / mpp];
        ctx.strokeStyle = 'rgba(25,178,255,0.8)';
        ctx.lineWidth = 1.5 * dpr;
        ctx.setLineDash([5 * dpr, 4 * dpr]);
        ctx.beginPath(); ctx.arc(w / 2, h / 2, a.radius / mpp, 0, Math.PI * 2); ctx.stroke();
        ctx.setLineDash([]);
        [[a.a, '#19b2ff'], [a.b, '#ff4d61']].forEach(([p, col]) => {
            const [x, y] = P(p.x, p.y);
            ctx.fillStyle = col; ctx.shadowColor = col; ctx.shadowBlur = 10 * dpr;
            ctx.beginPath(); ctx.arc(x, y, 4.5 * dpr, 0, Math.PI * 2); ctx.fill();
        });
        ctx.shadowBlur = 0;
    });
    return box;
}
RENDER.duels = (d, page) => {
    const dv = d.duels || {};
    if (!dv.enabled) { page.append(el('div', 'empty', '1v1-Duelle sind auf diesem Server ausgeschaltet.')); return; }
    const f = state.duelForm = Object.assign({ target: null, arena: 0, weapon: null, stake: 0, q: '' }, state.duelForm || {});
    if (d.mode === 'duel') {
        const c = el('div', 'invite-card');
        const vi = el('div', 'vsico'); vi.append(icon('swords'));
        const t = el('div'); t.append(el('div', 'card-title', 'Du bist gerade im Duell'), el('div', 'muted', 'Aufgeben zählt als Niederlage, der Einsatz geht an den Gegner.'));
        c.append(vi, t, confirmBtn('Aufgeben', 'Wirklich aufgeben?', 'danger', () => action('duelLeave'), 'flag'));
        page.append(c);
    }
    if (dv.incoming) {
        const inv = dv.incoming;
        const c = el('div', 'invite-card');
        const vi = el('div', 'vsico'); vi.append(icon('swords'));
        const t = el('div');
        const line = el('div', 'muted');
        liveClock(line, inv.seconds, (tm) => `${inv.arena} · ${nb(inv.weapon)}${inv.stake > 0 ? ' · Einsatz ' + money(inv.stake) : ''} · noch ${tm}`);
        t.append(el('div', 'card-title', `${inv.from} fordert dich heraus`), line);
        const r = el('div', 'row');
        r.append(btn('Annehmen', 'go', () => post('duelRespond', { accept: true }), false, 'check'), btn('Ablehnen', 'ghost', () => post('duelRespond', { accept: false }), false, 'x'));
        c.append(vi, t, r);
        page.append(c);
    }
    const wrap = el('div', 'duels');
    const left = el('div', 'card pad duel-form');
    left.append(el('div', 'card-title', 'Herausforderung'));
    const rerender = () => renderMenu(false);
    left.append(el('span', 'section-label', 'Gegner'), playerPicker(d, f, 'target', rerender));
    left.append(el('span', 'section-label', 'Arena'));
    const ap = el('div', 'arena-picks');
    const rnd = el('div', 'arena-pick random' + (!f.arena ? ' sel' : ''));
    rnd.append(icon('sparkles'), el('span', null, 'Zufall'));
    rnd.addEventListener('click', () => { click(); f.arena = 0; rerender(); });
    ap.append(rnd);
    (dv.arenas || []).forEach((a) => ap.append(arenaPick(a, f.arena === a.index, () => { f.arena = a.index; rerender(); })));
    left.append(ap);
    left.append(el('span', 'section-label', 'Waffe (beide spielen damit)'));
    const owned = (d.shop || []).filter((w) => w.owned);
    if (!f.weapon || !owned.find((w) => w.name === f.weapon)) f.weapon = owned.length ? owned[owned.length - 1].name : null;
    const wp = el('div', 'weapon-picks');
    owned.forEach((w) => {
        const b = el('button', w.name === f.weapon ? 'sel' : '', nb(w.label));
        b.type = 'button';
        b.addEventListener('click', () => { click(); f.weapon = w.name; rerender(); });
        wp.append(b);
    });
    left.append(wp);
    left.append(el('span', 'section-label', 'Einsatz (beide zahlen, der Gewinner bekommt alles)'));
    const st = el('div', 'stake');
    const r = el('input');
    r.type = 'range'; r.min = 0; r.max = dv.maxStake || 0; r.step = 500; r.value = Math.min(f.stake || 0, dv.maxStake || 0);
    const v = el('b', null, f.stake > 0 ? money(f.stake) : 'Ohne');
    const upd = () => { f.stake = Number(r.value); r.style.setProperty('--p', pct(r.value, dv.maxStake || 1) + '%'); v.textContent = f.stake > 0 ? money(f.stake) : 'Ohne'; };
    r.addEventListener('input', upd);
    upd();
    st.append(r, v);
    left.append(st);
    const target = (d.players || []).find((p) => p.id === f.target);
    const can = (d.mode === 'lobby' || d.mode === 'ffa') && f.target !== null && f.target !== undefined;
    const label = d.mode === 'gangwar' ? 'Geht nicht im Gangwar' : d.mode === 'duel' ? 'Du bist schon im Duell' : !can ? 'Wähl einen Gegner' : `${target ? target.name : '#' + f.target} herausfordern`;
    left.append(btn(label, 'primary block', () => action('duelChallenge', { id: f.target, arena: f.arena, weapon: f.weapon, stake: f.stake }), !can, 'swords'));
    const right = el('div', 'grid');
    const wl = el('div', 'wl');
    [['Siege', num(dv.wins)], ['Niederlagen', num(dv.losses)]].forEach(([k, val]) => { const t = el('div', 'tile'); t.append(el('span', null, k), el('b', null, val)); wl.append(t); });
    right.append(wl);
    const rules = el('div', 'card pad');
    rules.append(el('div', 'card-title', 'Regeln'));
    const rl = el('div', 'streak-list');
    rl.style.marginTop = '1rem';
    [['Modus', `Best of ${(dv.winRounds || 2) * 2 - 1}`], ['Zeit pro Runde', `${dv.roundSeconds || 90} Sekunden`], ['Zeit um', 'mehr Leben + Weste gewinnt'], ['Zählt für K/D', 'nein']].forEach(([k, val]) => {
        const row = el('div'); row.append(el('span', null, k), el('b', null, val)); rl.append(row);
    });
    rules.append(rl);
    right.append(rules);
    const run = el('div', 'card pad');
    run.append(el('div', 'card-title', 'Läuft gerade'));
    const rr = el('div', 'running');
    rr.style.marginTop = '1rem';
    (dv.running || []).forEach((x) => {
        const row = el('div', 'run-row');
        row.append(el('span', null, x.names[0]), el('span', 'sc', `${x.score[0]} : ${x.score[1]}`), el('span', null, x.names[1]));
        rr.append(row);
    });
    if (!(dv.running || []).length) rr.append(el('div', 'muted', 'Gerade kein Duell.'));
    run.append(rr);
    right.append(run);
    wrap.append(left, right);
    page.append(wrap);
};

// ================================================================== Kopfgeld
RENDER.bounty = (d, page) => {
    const bv = d.bounty || {};
    if (!bv.enabled) { page.append(el('div', 'empty', 'Kopfgeld ist auf diesem Server ausgeschaltet.')); return; }
    const f = state.bountyForm = Object.assign({ target: null, amount: bv.min || 1000, q: '' }, state.bountyForm || {});
    if (bv.onMe > 0) {
        const c = el('div', 'onme');
        const t = el('div', 'grow');
        t.append(el('div', 'card-title', 'Auf dich ist ein Kopfgeld ausgesetzt'), el('div', 'muted', 'Wer dich im FFA oder Gangwar erwischt, kassiert alles. Pass auf dich auf.'));
        c.append(icon('target'), t, el('b', null, money(bv.onMe)));
        page.append(c);
    }
    const wrap = el('div', 'bounty');
    const left = el('div');
    left.append(sectionHead('Meistgesucht'));
    const list = el('div', 'wanted');
    (bv.list || []).forEach((w, i) => {
        const row = el('div', 'want' + (i === 0 ? ' top1' : '') + (w.me ? ' me' : ''));
        const nm = el('div', 'wname');
        if (w.tag) nm.append(paint(el('span', 'chip', w.tag), w.color));
        nm.append(txt(w.name), el('span', 'uid', '#' + w.id));
        const sub = el('div', 'wsub');
        sub.append(el('span', null, w.online ? (w.place || 'online') : 'offline'), el('span', null, `LVL ${w.level}`));
        if (w.auto > 0) sub.append(el('span', null, `davon ${money(w.auto)} durch Killserie`));
        if (w.mine > 0) sub.append(el('span', null, `von dir ${money(w.mine)}`));
        const mid = el('div'); mid.append(nm, sub);
        row.append(el('span', 'rank' + (i < 3 ? ' p' + (i + 1) : ''), i + 1), mid, el('b', 'amt', money(w.amount)));
        if (!w.me) row.append(iconBtn('plus', 'mini', () => { f.target = w.id; renderMenu(false); }, 'Erhöhen'));
        else row.append(el('span'));
        list.append(row);
    });
    if (!(bv.list || []).length) list.append(el('div', 'empty', 'Gerade ist auf niemanden ein Kopfgeld ausgesetzt.'));
    left.append(stagger(list));
    const right = el('div', 'grid');
    const form = el('div', 'card pad form');
    form.append(el('div', 'card-title', 'Kopfgeld setzen'));
    form.append(el('span', 'section-label', 'Auf wen?'), playerPicker(d, f, 'target', () => renderMenu(false)));
    form.append(el('span', 'section-label', 'Betrag'));
    const amt = el('input', 'input');
    amt.inputMode = 'numeric';
    amt.value = f.amount;
    amt.addEventListener('input', () => { f.amount = parseInt(amt.value.replace(/\D/g, ''), 10) || 0; });
    const quick = el('div', 'quick');
    [1000, 5000, 10000, 25000].forEach((n) => {
        const b = el('button', null, '+' + money(n));
        b.type = 'button';
        b.addEventListener('click', () => { click(); f.amount = Math.min(bv.max || n, (f.amount || 0) + n); amt.value = f.amount; });
        quick.append(b);
    });
    form.append(amt, quick, el('span', 'muted', `Mindestens ${money(bv.min)}, höchstens ${money(bv.max)} auf einmal.`));
    const t = (d.players || []).find((p) => p.id === f.target);
    const can = f.target !== null && f.target !== undefined && !(d.account && f.target === d.account.id);
    form.append(btn(can ? `Auf ${t ? t.name : '#' + f.target} setzen` : 'Wähl ein Ziel', 'danger block', () => action('bountyPlace', { id: f.target, amount: f.amount }), !can, 'target'));
    right.append(form);
    if ((bv.streak || []).length) {
        const sc = el('div', 'card pad');
        sc.append(el('div', 'card-title', 'Automatisch bei Killserien'));
        const sl = el('div', 'streak-list');
        sl.style.marginTop = '1rem';
        bv.streak.forEach((x) => { const row = el('div'); row.append(el('span', null, `${x.streak} Kills in Folge`), el('b', null, '+' + money(x.amount))); sl.append(row); });
        sc.append(sl);
        right.append(sc);
    }
    wrap.append(left, right);
    page.append(wrap);
};

// ================================================================== HUD: Duell
const duel = { data: null, timers: [] };
function clearDuelTimers() { duel.timers.forEach(clearTimeout); duel.timers = []; }
function pips(node, n, total) {
    node.textContent = '';
    for (let i = 0; i < total; i++) node.append(el('i', i < n ? 'on' : ''));
}
function setDuel(d) {
    const bar = $('duelbar');
    if (!d) {
        duel.data = null;
        clearDuelTimers();
        every('duel', 0, null);
        bar.classList.add('off');
        $('countdown').classList.add('off');
        return;
    }
    duel.data = d;
    const me = d.me === 2 ? 1 : 0, op = 1 - me;
    const wins = d.winRounds || 2;
    $('db-me').textContent = d.names[me] || 'Du';
    $('db-op').textContent = d.names[op] || 'Gegner';
    pips($('db-me-pips'), d.score[me], wins);
    pips($('db-op-pips'), d.score[op], wins);
    $('db-round').textContent = 'Runde ' + d.round;
    $('db-info').textContent = [d.arena, nb(d.weapon || '')].filter(Boolean).join(' · ');
    bar.classList.remove('off');
    every('duel', 0, null);
    if (d.phase === 'fight') {
        let left = d.remaining || 0;
        $('db-time').textContent = clock(left);
        every('duel', 1000, () => { left = Math.max(0, left - 1); $('db-time').textContent = clock(left); });
    } else if (d.phase === 'countdown') {
        $('db-time').textContent = clock(d.roundSeconds || 90);
    }
}
function countdown(d) {
    clearDuelTimers();
    const box = $('countdown');
    const n = $('cd-num');
    const cd = d.countdown || 3;
    const lead = Math.max(0, (d.startsIn || cd) - cd) * 1000;
    box.textContent = '';
    box.append(reticle(22, false), n);
    const show = (text, fight) => {
        n.textContent = text;
        n.className = fight ? 'fight' : '';
        box.classList.remove('off');
        restartAnim(n, 'pop');
        if (fight) tone(880, 0.25, 'sawtooth', 0.35); else tone(660, 0.12, 'sine', 0.4);
    };
    for (let i = 0; i < cd; i++) duel.timers.push(setTimeout(() => show(String(cd - i)), lead + i * 1000));
    duel.timers.push(setTimeout(() => show('KAMPF', true), lead + cd * 1000));
    duel.timers.push(setTimeout(() => box.classList.add('off'), lead + cd * 1000 + 900));
}
function roundBanner(d) {
    const b = $('roundbanner');
    const mine = d.winner && d.winner === d.me;
    b.className = 'round-banner ' + (d.winner ? (mine ? 'win' : 'loss') : '');
    $('rb-text').textContent = !d.winner ? 'Unentschieden' : mine ? (d.last ? 'Match gewonnen' : 'Runde gewonnen') : (d.last ? 'Match verloren' : 'Runde verloren');
    const me = d.me === 2 ? 1 : 0;
    $('rb-sub').textContent = (d.how === 'time' ? 'Zeit abgelaufen · ' : '') + `${d.score[me]} : ${d.score[1 - me]}`;
    b.classList.remove('off');
    restartAnim(b, 'round-banner');
    later('roundbanner', 2700, () => b.classList.add('off'));
    if (mine) sounds.kill(); else tone(300, 0.3, 'sine', 0.35);
}
handlers.duel = (m) => {
    const d = m.data || {};
    setDuel(d);
    if (d.phase === 'countdown') countdown(d);
    if (d.phase === 'roundEnd') roundBanner(d);
};
handlers.duelEnd = (m) => {
    const d = m.data || {};
    setDuel(null);
    const box = $('duelend');
    const card = box.querySelector('.card-end');
    const res = $('de-res');
    res.textContent = d.draw ? 'UNENTSCHIEDEN' : d.won ? 'SIEG' : 'NIEDERLAGE';
    card.style.setProperty('--resc', d.draw ? '#ffc24a' : d.won ? '#19b2ff' : '#ff4d61');
    card.style.setProperty('--res', d.draw ? 'rgba(255,194,74,.6)' : d.won ? 'rgba(25,178,255,.6)' : 'rgba(255,77,97,.6)');
    $('de-score').textContent = d.score ? `${d.score[0]} : ${d.score[1]}` : '';
    $('de-vs').textContent = (d.reason === 'forfeit' ? (d.won ? 'Gegner hat aufgegeben · ' : 'Aufgegeben · ') : '') + 'gegen ' + (d.opponent || '?');
    $('de-pot').textContent = d.pot > 0 ? '+' + money(d.pot) + (d.xp > 0 ? `  ·  +${num(d.xp)} XP` : '') : '';
    box.classList.remove('off');
    restartAnim(card, 'card-end');
    if (d.won) sounds.level();
    later('duelend', 4800, () => box.classList.add('off'));
};
handlers.duelInvite = (m) => {
    const box = $('invite');
    if (!m.show) { box.classList.add('off'); return; }
    const d = m.data || {};
    $('inv-name').textContent = d.from || '?';
    $('inv-line').textContent = `${d.arena || ''} · ${nb(d.weapon || '')}`;
    $('inv-stake').textContent = d.stake > 0 ? 'Einsatz ' + money(d.stake) + ' (Gewinner bekommt ' + money(d.stake * 2) + ')' : 'Ohne Einsatz';
    if (m.keys) { $('inv-yes').textContent = m.keys.accept || 'Y'; $('inv-no').textContent = m.keys.decline || 'X'; }
    const life = $('inv-life');
    life.style.animationDuration = (d.seconds || 30) + 's';
    box.classList.remove('off');
    restartAnim(life, 'ilife');
    restartAnim(box, 'invite');
    sounds.alert();
    later('invite', (d.seconds || 30) * 1000, () => box.classList.add('off'));
};

// ================================================================== HUD: Kopfgeld, Missionen, Case-Ergebnis
handlers.bountyClaimed = (m) => {
    const d = m.data || {};
    toast('success', `Kopfgeld kassiert: +${money(d.amount)} für ${d.victim || '?'}`);
    const extra = $('killpop-extra');
    if (extra) {
        const b = el('div', 'kp-bounty', 'KOPFGELD +' + money(d.amount));
        extra.append(b);
    }
};
handlers.missionDone = (m) => {
    const d = m.data || {};
    const parts = [];
    if (d.money > 0) parts.push('+' + money(d.money));
    if (d.xp > 0) parts.push(`+${num(d.xp)} XP`);
    toast('mission', `Mission geschafft: ${d.text || ''}${parts.length ? ' (' + parts.join(', ') + ')' : ''} – F2 → Täglich`);
    tone(990, 0.12, 'sine', 0.4); tone(1320, 0.2, 'sine', 0.4, 0.1);
};
handlers.caseResult = (m) => { if (m.data) openCase(m.data); };
