'use strict';

function setBar(id, valId, value) {
    const bar = document.getElementById(id);
    const val = document.getElementById(valId);
    if (bar) bar.style.width = Math.max(0, Math.min(100, value)) + '%';
    if (val) val.textContent  = Math.round(value);
}

function formatMoney(n) {
    return '$' + Math.floor(n).toLocaleString('de-DE');
}

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'show') {
        document.getElementById('hud').style.display = 'block';
    }
    if (d.type === 'hide') {
        document.getElementById('hud').style.display = 'none';
    }

    if (d.type === 'update') {
        const data = d.data || {};
        setBar('bar-health', 'val-health', data.health ?? 100);
        setBar('bar-hunger', 'val-hunger', data.hunger ?? 100);
        setBar('bar-thirst', 'val-thirst', data.thirst ?? 100);
        setBar('bar-stress', 'val-stress', data.stress ?? 0);
        document.getElementById('hud-cash').textContent = formatMoney(data.cash ?? 0);
        document.getElementById('hud-bank').textContent = 'B ' + formatMoney(data.bank ?? 0);
    }

    if (d.type === 'tick') {
        setBar('bar-health', 'val-health', d.health ?? 100);

        const rowArmour = document.getElementById('row-armour');
        if (d.armour > 0) {
            rowArmour.style.display = 'flex';
            setBar('bar-armour', 'val-armour', d.armour);
        } else {
            rowArmour.style.display = 'none';
        }

        const speedEl = document.getElementById('hud-speed');
        if (d.inVehicle) {
            speedEl.style.display = 'flex';
            document.getElementById('speed-val').textContent = d.speed ?? 0;
        } else {
            speedEl.style.display = 'none';
        }

        if (d.zone)  document.getElementById('hud-zone').textContent = d.zone;
        if (d.time)  document.getElementById('hud-time').textContent = d.time;
    }

    if (d.type === 'updateMoney') {
        document.getElementById('hud-cash').textContent = formatMoney(d.cash ?? 0);
        document.getElementById('hud-bank').textContent = 'B ' + formatMoney(d.bank ?? 0);
    }

    if (d.type === 'updateStatus') {
        setBar('bar-hunger', 'val-hunger', d.hunger ?? 100);
        setBar('bar-thirst', 'val-thirst', d.thirst ?? 100);
        setBar('bar-stress', 'val-stress', d.stress ?? 0);
    }

    if (d.type === 'notify') {
        showNotif(d.text, d.ntype || 'info', d.duration || 4000);
    }
});

function showNotif(text, type, duration) {
    const container = document.getElementById('notif-container');
    const el = document.createElement('div');
    el.className = `notif ${type}`;
    el.textContent = text;
    container.appendChild(el);
    setTimeout(() => {
        el.style.transition = 'opacity 0.3s';
        el.style.opacity = '0';
        setTimeout(() => el.remove(), 350);
    }, duration);
}
