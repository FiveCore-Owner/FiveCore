'use strict';

// ─── i18n ─────────────────────────────────────────────────────────────────────
let _locale = {};
function t(key) { return _locale[key] ?? key; }
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        el.textContent = t(el.dataset.i18n);
    });
}

// ─── State ───────────────────────────────────────────────────────────────────
let currentCash = 0;
let currentBank = 0;

function fmtMoney(n) {
    return '$' + Math.max(0, Math.floor(n)).toLocaleString('de-DE');
}

function post(cb, data) {
    return fetch(`https://${GetParentResourceName()}/${cb}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => {});
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────
document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
    });
});

// ─── Quick amount buttons ─────────────────────────────────────────────────────
document.querySelectorAll('.quick-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const val    = btn.dataset.val;
        const tab    = btn.closest('.tab-content').id;
        const isDeposit = tab === 'tab-deposit';
        const inputId   = isDeposit ? 'inp-deposit' : 'inp-withdraw';
        const maxVal    = isDeposit ? currentCash : currentBank;
        const input     = document.getElementById(inputId);
        if (val === 'max') {
            input.value = maxVal;
        } else {
            input.value = parseInt(val);
        }
    });
});

// ─── Close ───────────────────────────────────────────────────────────────────
document.getElementById('btn-close').addEventListener('click', () => {
    post('closeBanking', {});
});

// ─── Feedback ─────────────────────────────────────────────────────────────────
function showFeedback(id, msg, ok) {
    const el = document.getElementById(id);
    el.textContent  = msg;
    el.className    = 'feedback ' + (ok ? 'ok' : 'error');
    el.style.display = 'block';
    setTimeout(() => { el.style.display = 'none'; }, 3500);
}

// ─── Deposit ─────────────────────────────────────────────────────────────────
document.getElementById('btn-deposit').addEventListener('click', () => {
    const amount = parseInt(document.getElementById('inp-deposit').value) || 0;
    if (amount <= 0) {
        showFeedback('dep-feedback', t('bank_err_amount'), false);
        return;
    }
    if (amount > currentCash) {
        showFeedback('dep-feedback', t('bank_err_no_cash'), false);
        return;
    }
    document.getElementById('btn-deposit').disabled = true;
    post('deposit', { amount });
});

// ─── Withdraw ────────────────────────────────────────────────────────────────
document.getElementById('btn-withdraw').addEventListener('click', () => {
    const amount = parseInt(document.getElementById('inp-withdraw').value) || 0;
    if (amount <= 0) {
        showFeedback('wit-feedback', t('bank_err_amount'), false);
        return;
    }
    if (amount > currentBank) {
        showFeedback('wit-feedback', t('bank_err_no_bank'), false);
        return;
    }
    document.getElementById('btn-withdraw').disabled = true;
    post('withdraw', { amount });
});

// ─── History ──────────────────────────────────────────────────────────────────
function renderHistory(history) {
    const container = document.getElementById('history-list');
    container.innerHTML = '';

    if (!history || history.length === 0) {
        container.innerHTML = `<div class="history-empty">${t('bank_no_history')}</div>`;
        return;
    }
    history.forEach(row => {
        const el = document.createElement('div');
        el.className = 'history-row';
        const ts = row.timestamp ? row.timestamp.slice(0,16).replace('T',' ') : '';
        el.innerHTML = `
            <span class="hist-type ${row.action}">${t('bank_' + row.action)}</span>
            <span class="hist-amount">${fmtMoney(row.amount)}</span>
            <span class="hist-time">${ts}</span>
        `;
        container.appendChild(el);
    });
}

// ─── NUI Messages ────────────────────────────────────────────────────────────
window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'close') {
        document.getElementById('app').style.display = 'none';
        return;
    }

    if (d.type === 'setLang' && d.locale) {
        _locale = d.locale;
        applyI18n();
        return;
    }

    if (d.type === 'open') {
        if (d.locale) { _locale = d.locale; applyI18n(); }
        currentCash = d.cash ?? 0;
        currentBank = d.bank ?? 0;
        document.getElementById('bal-cash').textContent = fmtMoney(currentCash);
        document.getElementById('bal-bank').textContent = fmtMoney(currentBank);
        renderHistory(d.history || []);

        // Reset inputs and buttons
        document.getElementById('inp-deposit').value  = '';
        document.getElementById('inp-withdraw').value = '';
        document.getElementById('btn-deposit').disabled  = false;
        document.getElementById('btn-withdraw').disabled = false;
        document.getElementById('dep-feedback').style.display = 'none';
        document.getElementById('wit-feedback').style.display = 'none';

        // Show first tab
        document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        document.querySelector('.tab[data-tab="deposit"]').classList.add('active');
        document.getElementById('tab-deposit').classList.add('active');

        document.getElementById('app').style.display = 'flex';
        return;
    }

    if (d.type === 'result') {
        document.getElementById('btn-deposit').disabled  = false;
        document.getElementById('btn-withdraw').disabled = false;

        if (d.ok) {
            currentCash = d.cash ?? currentCash;
            currentBank = d.bank ?? currentBank;
            document.getElementById('bal-cash').textContent = fmtMoney(currentCash);
            document.getElementById('bal-bank').textContent = fmtMoney(currentBank);
            // Show feedback in the currently active tab
            const activeTab = document.querySelector('.tab-content.active');
            const fbId = activeTab && activeTab.id === 'tab-deposit' ? 'dep-feedback' : 'wit-feedback';
            showFeedback(fbId, d.message || t('bank_success'), true);
            // Clear input
            document.getElementById('inp-deposit').value  = '';
            document.getElementById('inp-withdraw').value = '';
        } else {
            const activeTab = document.querySelector('.tab-content.active');
            const fbId = activeTab && activeTab.id === 'tab-deposit' ? 'dep-feedback' : 'wit-feedback';
            showFeedback(fbId, d.message || t('bank_error'), false);
        }
    }
});

// ESC to close
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') post('closeBanking', {});
});
