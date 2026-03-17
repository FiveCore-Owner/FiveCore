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

function setMiniBar(id, valId, value) {
    const bar = document.getElementById(id);
    const val = document.getElementById(valId);
    const v   = Math.max(0, Math.min(100, value));
    if (bar) bar.style.width = v + '%';
    if (val) val.textContent  = Math.round(v);
}

document.getElementById('pause-close-btn').addEventListener('click', () => {
    post('closePause', {});
});

// Close on click outside panel
document.getElementById('pause-overlay').addEventListener('click', () => {
    post('closePause', {});
});

// ESC key
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') post('closePause', {});
});

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'show') {
        if (d.locale) { _locale = d.locale; applyI18n(); }

        document.getElementById('pause').style.display = 'block';
        document.getElementById('pause-server-name').textContent = d.servTitle || 'FiveCore RP';
        document.getElementById('p-time').textContent    = d.time        || '--:--';
        document.getElementById('p-zone').textContent    = d.zone        || '-';
        document.getElementById('p-players').textContent = d.playerCount || '-';

        if (d.coords) {
            document.getElementById('p-coords').textContent =
                `${d.coords.x}, ${d.coords.y}, ${d.coords.z}`;
        }

        setMiniBar('pb-health', 'pv-health', d.health ?? 100);

        const armourRow = document.getElementById('prow-armour');
        if (d.armour > 0) {
            armourRow.style.display = 'flex';
            setMiniBar('pb-armour', 'pv-armour', d.armour);
        } else {
            armourRow.style.display = 'none';
        }
        return;
    }

    if (d.type === 'hide') {
        document.getElementById('pause').style.display = 'none';
        return;
    }

    if (d.type === 'setLang' && d.locale) {
        _locale = d.locale;
        applyI18n();
    }
});
