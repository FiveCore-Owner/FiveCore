'use strict';

let _locale = {};
function t(key, ...args) {
    let str = _locale[key] ?? key;
    if (args.length > 0) { let i=0; str=str.replace(/%[sd]/g, ()=>String(args[i++]??'')); }
    return str;
}
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
}

const ICONS = ['🏥','🚉','🏙️','🏜️','🌊','📍'];

function post(cb, data) {
    return fetch(`https://${GetParentResourceName()}/${cb}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => {});
}

function escHtml(s) {
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function renderSpawns(spawns) {
    const list = document.getElementById('spawn-list');
    list.innerHTML = '';
    spawns.forEach((s, i) => {
        const btn = document.createElement('button');
        btn.className = 'spawn-btn';
        btn.innerHTML = `<span class="icon">${ICONS[i] || '📍'}</span> ${escHtml(s.label)}`;
        btn.addEventListener('click', () => post('selectSpawn', { index: s.index }));
        list.appendChild(btn);
    });
}

window.addEventListener('message', e => {
    const data = e.data;
    if (!data || !data.type) return;

    if (data.type === 'setLang') {
        if (data.locale) { _locale = data.locale; applyI18n(); }
        return;
    }
    if (data.type === 'open') {
        if (data.locale) { _locale = data.locale; }
        document.getElementById('app').style.display = 'flex';
        applyI18n();
        renderSpawns(data.spawns || []);
    }
    if (data.type === 'close') {
        document.getElementById('app').style.display = 'none';
    }
});
