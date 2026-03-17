'use strict';

let _locale  = {};
let myPhone  = '???';
let messages = [];

function t(key, ...args) {
    let str = _locale[key] ?? key;
    if (args.length > 0) { let i=0; str=str.replace(/%[sd]/g, ()=>String(args[i++]??'')); }
    return str;
}
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => el.placeholder = t(el.dataset.i18nPlaceholder));
}

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

function formatTime(dt) {
    if (!dt) return '';
    return new Date(dt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function updateClock() {
    document.getElementById('phone-time').textContent =
        new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}
setInterval(updateClock, 10000);
updateClock();

// ─── Tabs ─────────────────────────────────────────────────────────────────────

document.querySelectorAll('.ptab').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.ptab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.ptab-content').forEach(c => c.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById('ptab-' + btn.dataset.tab).classList.add('active');
        if (btn.dataset.tab === 'outbox') post('getOutbox', {});
    });
});

// ─── Inbox ────────────────────────────────────────────────────────────────────

function renderInbox(msgs) {
    const list = document.getElementById('inbox-list');
    list.innerHTML = '';
    if (!msgs || msgs.length === 0) {
        list.innerHTML = `<div class="empty-msg">${escHtml(t('phone_empty_inbox'))}</div>`;
        return;
    }
    msgs.forEach(m => {
        const item = document.createElement('div');
        item.className = 'msg-item' + (m.is_read === 0 ? ' msg-unread' : '');
        const senderName = m.firstname
            ? `${escHtml(m.firstname)} ${escHtml(m.lastname)} (${escHtml(m.from_phone)})`
            : escHtml(m.from_phone || '???');
        item.innerHTML = `
            <div class="msg-header">
                <span class="msg-from">${senderName}</span>
                <span class="msg-time">${escHtml(formatTime(m.sent_at))}</span>
            </div>
            <div class="msg-text">${escHtml(m.message || '')}</div>
        `;
        item.addEventListener('click', () => {
            document.querySelectorAll('.ptab').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.ptab-content').forEach(c => c.classList.remove('active'));
            document.querySelector('.ptab[data-tab="compose"]').classList.add('active');
            document.getElementById('ptab-compose').classList.add('active');
            document.getElementById('comp-to').value = m.from_phone || '';
            document.getElementById('comp-msg').focus();
        });
        list.appendChild(item);
    });
}

// ─── Outbox ──────────────────────────────────────────────────────────────────

function renderOutbox(msgs) {
    const list = document.getElementById('outbox-list');
    list.innerHTML = '';
    if (!msgs || msgs.length === 0) {
        list.innerHTML = `<div class="empty-msg">${escHtml(t('phone_empty_outbox'))}</div>`;
        return;
    }
    msgs.forEach(m => {
        const item = document.createElement('div');
        item.className = 'msg-item';
        item.innerHTML = `
            <div class="msg-header">
                <span class="msg-from" style="color:#8c8">${escHtml(t('phone_to_prefix'))}${escHtml(m.to_phone || '???')}</span>
                <span class="msg-time">${escHtml(formatTime(m.sent_at))}</span>
            </div>
            <div class="msg-text">${escHtml(m.message || '')}</div>
        `;
        list.appendChild(item);
    });
}

// ─── Compose ──────────────────────────────────────────────────────────────────

document.getElementById('comp-msg').addEventListener('input', function() {
    document.getElementById('comp-counter').textContent = `${this.value.length} / 200`;
});

document.getElementById('btn-send-sms').addEventListener('click', () => {
    const to  = document.getElementById('comp-to').value.trim();
    const msg = document.getElementById('comp-msg').value.trim();
    const err = document.getElementById('comp-error');

    if (!to)       { err.textContent = t('phone_err_no_to');  err.style.display='block'; return; }
    if (!msg)      { err.textContent = t('phone_err_no_msg'); err.style.display='block'; return; }
    if (msg.length > 200) { err.textContent = t('phone_err_too_long'); err.style.display='block'; return; }

    err.style.display = 'none';
    const btn = document.getElementById('btn-send-sms');
    btn.disabled    = true;
    btn.textContent = t('phone_sending');

    post('sendSMS', { to, msg }).then(() => {
        document.getElementById('comp-msg').value = '';
        document.getElementById('comp-counter').textContent = '0 / 200';
        btn.disabled    = false;
        btn.textContent = t('phone_send');
    });
});

document.getElementById('btn-close-phone').addEventListener('click', () => {
    post('closePhone', {});
});

// ─── NUI Messages ─────────────────────────────────────────────────────────────

window.addEventListener('message', e => {
    const data = e.data;
    if (!data || !data.type) return;

    if (data.type === 'setLang') {
        if (data.locale) { _locale = data.locale; applyI18n(); }
        return;
    }
    if (data.type === 'open') {
        if (data.locale) { _locale = data.locale; }
        document.getElementById('phone').style.display = 'flex';
        myPhone  = data.myPhone || '???';
        messages = data.messages || [];
        document.getElementById('my-phone-display').textContent = myPhone;
        applyI18n();

        // Reset to inbox
        document.querySelectorAll('.ptab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.ptab-content').forEach(c => c.classList.remove('active'));
        document.querySelector('.ptab[data-tab="inbox"]').classList.add('active');
        document.getElementById('ptab-inbox').classList.add('active');

        renderInbox(messages);
        updateClock();
    }
    if (data.type === 'close') {
        document.getElementById('phone').style.display = 'none';
    }
    if (data.type === 'outbox') {
        renderOutbox(data.messages || []);
    }
    if (data.type === 'incoming') {
        messages.unshift({
            from_phone: data.data.from,
            message:    data.data.message,
            sent_at:    new Date().toISOString(),
            is_read:    0,
        });
    }
});
