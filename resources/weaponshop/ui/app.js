'use strict';

let _locale     = {};
let _weapons    = [];
let _hasLicense = false;

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

function fmtMoney(n) {
    return '$' + Math.max(0, Math.floor(n)).toLocaleString('en-US');
}

function showStatus(msg, type) {
    const el = document.getElementById('shop-status');
    el.textContent   = msg;
    el.className     = type || '';
    el.style.display = 'block';
    setTimeout(() => { el.style.display = 'none'; }, 4000);
}

// ─── Weapon list render ───────────────────────────────────────────────────────

const CAT_LABELS = {
    handgun: 'Handguns', smg: 'SMG', shotgun: 'Shotguns',
    rifle: 'Rifles', melee: 'Melee',
};

function renderWeapons() {
    const list = document.getElementById('weapon-list');
    list.innerHTML = '';

    const grouped = {};
    for (const w of _weapons) {
        if (!grouped[w.category]) grouped[w.category] = [];
        grouped[w.category].push(w);
    }

    for (const [cat, items] of Object.entries(grouped)) {
        const catDiv = document.createElement('div');
        catDiv.className = 'weapon-cat';
        catDiv.textContent = CAT_LABELS[cat] || cat;
        list.appendChild(catDiv);

        for (const w of items) {
            const row = document.createElement('div');
            row.className = 'weapon-row';
            row.innerHTML = `
                <span class="weapon-name">${w.label}</span>
                <span class="weapon-price">${fmtMoney(w.price)}</span>
                <button class="btn-buy" data-weapon="${w.name}" data-i18n="ws_buy">Buy</button>
            `;
            row.querySelector('.btn-buy').addEventListener('click', () => {
                row.querySelector('.btn-buy').disabled = true;
                post('buyWeapon', { weapon: w.name });
                setTimeout(() => { row.querySelector('.btn-buy').disabled = false; }, 3000);
            });
            list.appendChild(row);
        }
    }
}

// ─── Buttons ──────────────────────────────────────────────────────────────────

document.getElementById('shop-close').addEventListener('click', () => post('closeShop', {}));
document.getElementById('btn-buy-license').addEventListener('click', () => {
    document.getElementById('btn-buy-license').disabled = true;
    post('buyLicense', {});
});
document.getElementById('btn-training').addEventListener('click', () => {
    post('startTraining', {});
});
document.getElementById('btn-exit-training').addEventListener('click', () => {
    // Will be handled by NUI close → client Lua aborts training
    post('exitTraining', {});
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') post('closeShop', {});
});

// ─── Messages ─────────────────────────────────────────────────────────────────

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'open') {
        if (d.locale) { _locale = d.locale; applyI18n(); }
        _weapons    = d.weapons    || [];
        _hasLicense = d.hasLicense || false;

        document.getElementById('license-price-val').textContent = fmtMoney(d.licensePrice || 15000);
        document.getElementById('no-license-section').style.display = _hasLicense ? 'none' : 'flex';
        document.getElementById('weapon-section').style.display     = _hasLicense ? 'block' : 'none';

        if (_hasLicense) renderWeapons();

        document.getElementById('btn-buy-license').disabled = false;
        document.getElementById('shop-status').style.display = 'none';
        document.getElementById('shop').style.display = 'flex';
        return;
    }

    if (d.type === 'close') {
        document.getElementById('shop').style.display = 'none';
        return;
    }

    if (d.type === 'result') {
        const data = d.data || {};
        if (data.ok) {
            if (data.action === 'license') {
                _hasLicense = true;
                document.getElementById('no-license-section').style.display = 'none';
                document.getElementById('weapon-section').style.display = 'block';
                renderWeapons();
                showStatus(t('ws_license_success') || 'License purchased!', 'success');
            } else if (data.action === 'weapon') {
                showStatus((t('ws_bought') || 'Bought:') + ' ' + (data.label || data.weapon), 'success');
            }
        } else {
            const errMap = {
                not_enough_money: t('notify_not_enough_money') || 'Not enough money',
                no_license:       t('ws_no_license')          || 'No license',
                invalid_weapon:   'Invalid weapon',
            };
            showStatus(errMap[data.error] || 'Error', 'error');
            document.getElementById('btn-buy-license').disabled = false;
        }
        return;
    }

    // ── Training ──────────────────────────────────────────────────────────────
    if (d.type === 'trainingStart') {
        document.getElementById('training-hud').style.display = 'flex';
        document.getElementById('training-kills').textContent    = '0';
        document.getElementById('training-required').textContent = d.required || 10;
        document.getElementById('training-bar').style.width = '0%';
        return;
    }

    if (d.type === 'trainingKills') {
        document.getElementById('training-kills').textContent = d.kills || 0;
        const pct = Math.min(100, ((d.kills || 0) / (d.required || 10)) * 100);
        document.getElementById('training-bar').style.width = pct + '%';
        return;
    }

    if (d.type === 'trainingEnd' || d.type === 'trainingFail') {
        document.getElementById('training-hud').style.display = 'none';
        return;
    }

    if (d.type === 'setLang' && d.locale) {
        _locale = d.locale;
        applyI18n();
    }
});
