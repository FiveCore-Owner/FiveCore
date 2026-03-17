'use strict';

function setBar(id, valId, value) {
    const bar = document.getElementById(id);
    const val = document.getElementById(valId);
    const v   = Math.max(0, Math.min(100, value));
    if (bar) bar.style.width = v + '%';
    if (val) val.textContent  = Math.round(v);
}

function formatMoney(n) {
    return '$' + Math.max(0, Math.floor(n)).toLocaleString('de-DE');
}

// ─── Wanted stars ────────────────────────────────────────────────────────────
function renderWanted(level) {
    const el = document.getElementById('hud-wanted');
    if (!el) return;
    if (level <= 0) { el.style.display = 'none'; return; }
    el.style.display = 'block';
    const stars = document.getElementById('wanted-stars');
    stars.innerHTML = '&#9733;'.repeat(level) + '<span style="opacity:0.25">&#9733;</span>'.repeat(5 - level);
}

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    // ── Visibility ────────────────────────────────────────────────────────────
    if (d.type === 'show') document.getElementById('hud').style.display = 'block';
    if (d.type === 'hide') document.getElementById('hud').style.display = 'none';

    // ── Server title ──────────────────────────────────────────────────────────
    if (d.type === 'setTitle') {
        const el = document.getElementById('hud-title');
        if (el) el.textContent = d.title || '';
    }

    // ── Initial full update ───────────────────────────────────────────────────
    if (d.type === 'update') {
        const data = d.data || {};
        setBar('bar-health', 'val-health', data.health ?? 100);
        setBar('bar-hunger', 'val-hunger', data.hunger ?? 100);
        setBar('bar-thirst', 'val-thirst', data.thirst ?? 100);
        setBar('bar-stress', 'val-stress', data.stress ?? 0);
        document.getElementById('hud-cash').textContent = formatMoney(data.cash ?? 0);
        document.getElementById('hud-bank').textContent = formatMoney(data.bank ?? 0);
        const jobRow = document.getElementById('hud-job-row');
        const jobEl  = document.getElementById('hud-job');
        if (jobEl && jobRow && data.job) {
            jobEl.textContent = data.job;
            jobRow.style.display = 'flex';
        }
    }

    // ── Per-tick update ───────────────────────────────────────────────────────
    if (d.type === 'tick') {
        setBar('bar-health', 'val-health', d.health ?? 100);

        // Armour: only show row when armour > 0
        const rowArmour = document.getElementById('row-armour');
        if (d.armour > 0) {
            rowArmour.style.display = 'flex';
            setBar('bar-armour', 'val-armour', d.armour);
        } else {
            rowArmour.style.display = 'none';
        }

        // Stress: only show when > 0
        const rowStress = document.getElementById('row-stress');
        if (d.stress > 0) {
            rowStress.style.display = 'flex';
            setBar('bar-stress', 'val-stress', d.stress);
        } else {
            rowStress.style.display = 'none';
        }

        // Vehicle HUD
        const vehicleEl = document.getElementById('hud-vehicle');
        if (d.inVehicle) {
            vehicleEl.style.display = 'flex';
            document.getElementById('speed-val').textContent = d.speed ?? 0;
            document.getElementById('gear-val').textContent  = d.gear  ?? 1;
        } else {
            vehicleEl.style.display = 'none';
        }

        // Location
        if (d.zone)    document.getElementById('hud-zone').textContent    = d.zone;
        if (d.street !== undefined) {
            const streetEl = document.getElementById('hud-street');
            streetEl.textContent = d.street || '';
            streetEl.style.display = d.street ? 'block' : 'none';
        }
        if (d.time)    document.getElementById('hud-time').textContent    = d.time;
        if (d.compass) document.getElementById('hud-compass').textContent = d.compass;

        // Wanted
        renderWanted(d.wanted ?? 0);
    }

    // ── Money update ──────────────────────────────────────────────────────────
    if (d.type === 'updateMoney') {
        document.getElementById('hud-cash').textContent = formatMoney(d.cash ?? 0);
        document.getElementById('hud-bank').textContent = formatMoney(d.bank ?? 0);
    }

    // ── Job update ────────────────────────────────────────────────────────────
    if (d.type === 'updateJob') {
        const row = document.getElementById('hud-job-row');
        const el  = document.getElementById('hud-job');
        if (el && row) {
            el.textContent = d.job || '';
            row.style.display = d.job ? 'flex' : 'none';
        }
    }

    // ── Status update ─────────────────────────────────────────────────────────
    if (d.type === 'updateStatus') {
        setBar('bar-hunger', 'val-hunger', d.hunger ?? 100);
        setBar('bar-thirst', 'val-thirst', d.thirst ?? 100);
        setBar('bar-stress', 'val-stress', d.stress ?? 0);
    }

    // ── Speed-only update (1ms thread) ────────────────────────────────────────
    if (d.type === 'speedOnly') {
        const el = document.getElementById('speed-val');
        if (el) el.textContent = d.speed ?? 0;
        return;
    }

    // ── Notify ────────────────────────────────────────────────────────────────
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
