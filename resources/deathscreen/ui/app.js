'use strict';

let _locale = {};
function t(key) { return _locale[key] ?? key; }
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        el.textContent = t(el.dataset.i18n);
    });
}

function post(cb, data) {
    return fetch(`https://${GetParentResourceName()}/${cb}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => {});
}

function formatTimer(seconds) {
    const s = Math.max(0, seconds);
    const m = Math.floor(s / 60);
    const r = s % 60;
    return `${m}:${String(r).padStart(2, '0')}`;
}

document.getElementById('btn-ambulance').addEventListener('click', () => {
    post('callAmbulance', {});
});

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'show') {
        if (d.locale) { _locale = d.locale; applyI18n(); }
        document.getElementById('death-timer-val').textContent = formatTimer(d.timer || 300);
        document.getElementById('death').style.display = 'block';
        return;
    }

    if (d.type === 'hide') {
        document.getElementById('death').style.display = 'none';
        return;
    }

    if (d.type === 'tick') {
        document.getElementById('death-timer-val').textContent = formatTimer(d.timer || 0);
        return;
    }

    if (d.type === 'setLang' && d.locale) {
        _locale = d.locale;
        applyI18n();
    }
});
