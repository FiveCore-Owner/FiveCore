'use strict';

let _locale     = {};
let currentMode = 'local';
let isOpen      = false;

function t(key, ...args) {
    let str = _locale[key] ?? key;
    if (args.length > 0) { let i=0; str=str.replace(/%[sd]/g, ()=>String(args[i++]??'')); }
    return str;
}
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => el.placeholder = t(el.dataset.i18nPlaceholder));
    // Mode-Tabs aktualisieren
    document.querySelectorAll('.mode-btn').forEach(btn => {
        if (btn.dataset.i18n) btn.textContent = t(btn.dataset.i18n);
    });
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

function addMessage(data) {
    const log = document.getElementById('chat-log');
    const div = document.createElement('div');
    div.className = `chat-msg ${data.type || 'local'}`;
    const sender = data.sender
        ? `<span class="sender">${escHtml(data.sender)}:</span> `
        : '';
    div.innerHTML = sender + escHtml(data.msg || data.message || '');
    log.appendChild(div);
    if (log.children.length > 200) log.removeChild(log.firstChild);
    log.scrollTop = log.scrollHeight;
}

function openChat(mode) {
    isOpen      = true;
    currentMode = mode || 'local';
    const row   = document.getElementById('chat-input-row');
    row.style.display = 'flex';
    const input = document.getElementById('chat-input');
    input.value = '';
    input.focus();
    setMode(currentMode);
}

function closeChat() {
    isOpen = false;
    document.getElementById('chat-input-row').style.display = 'none';
    post('closeChat', {});
}

function setMode(mode) {
    currentMode = mode;
    document.querySelectorAll('.mode-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.mode === mode);
    });
}

document.querySelectorAll('.mode-btn').forEach(b => {
    b.addEventListener('click', () => setMode(b.dataset.mode));
});

document.getElementById('chat-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') {
        const msg = e.target.value.trim();
        if (msg) post('sendMessage', { message: msg, mode: currentMode });
        e.target.value = '';
        closeChat();
    }
    if (e.key === 'Escape') closeChat();
});

window.addEventListener('message', e => {
    const data = e.data;
    if (!data || !data.type) return;
    if (data.type === 'setLang') {
        if (data.locale) { _locale = data.locale; applyI18n(); }
        return;
    }
    if (data.type === 'open')    openChat(data.mode);
    if (data.type === 'close')   closeChat();
    if (data.type === 'message') addMessage(data.data);
    if (data.type === 'init' && data.locale) { _locale = data.locale; applyI18n(); }
});
