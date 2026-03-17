'use strict';

// ─── i18n ─────────────────────────────────────────────────────────────────────

let _locale = {};
function t(key, ...args) {
    let str = _locale[key] ?? key;
    if (args.length > 0) { let i=0; str=str.replace(/%[sd]/g, ()=>String(args[i++]??'')); }
    return str;
}
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
}

// ─── Fallback-Locale (EN) ─────────────────────────────────────────────────────
// Loading Screen startet bevor der Server die Sprache setzt,
// daher inline EN-Fallback für die wichtigsten Strings.

const FALLBACK = {
    loading_step_1:    "Connecting to server...",
    loading_step_2:    "Loading account...",
    loading_step_3:    "Loading character list...",
    loading_step_4:    "Character selected...",
    loading_step_5:    "Loading world...",
    loading_step_6:    "Welcome to FiveCore!",
    loading_tip_1:     "Press F2 to open your phone.",
    loading_tip_2:     "Use /me for roleplay actions.",
    loading_tip_3:     "Press T to chat. /ooc for out-of-character.",
    loading_tip_4:     "Your character saves every 5 minutes.",
    loading_tip_5:     "Type /help for all commands.",
    loading_tip_6:     "Phone numbers use format 555-XXXX.",
    loading_tip_7:     "Hunger and thirst decrease over time!",
    loading_server:    "SERVER",
    loading_account:   "ACCOUNT",
    loading_character: "CHARACTER",
    loading_spawn:     "SPAWN",
    loading_world:     "WORLD",
    loading_ready:     "READY",
    loading_tip_label: "TIP",
    loading_subtitle:  "ROLEPLAY",
};
_locale = FALLBACK;
applyI18n();

// ─── Partikel ─────────────────────────────────────────────────────────────────

function spawnParticle() {
    const p = document.createElement('div');
    p.className = 'particle';
    const size = Math.random() * 4 + 2;
    p.style.width  = size + 'px';
    p.style.height = size + 'px';
    p.style.left   = Math.random() * 100 + 'vw';
    p.style.bottom = '-' + size + 'px';
    const dur = Math.random() * 8 + 6;
    p.style.animationDuration = dur + 's';
    p.style.animationDelay    = (Math.random() * 2) + 's';
    document.getElementById('particles').appendChild(p);
    setTimeout(() => p.remove(), (dur + 3) * 1000);
}
setInterval(spawnParticle, 600);
for (let i = 0; i < 5; i++) spawnParticle();

// ─── Tips ─────────────────────────────────────────────────────────────────────

const TIP_KEYS = [
    'loading_tip_1','loading_tip_2','loading_tip_3','loading_tip_4',
    'loading_tip_5','loading_tip_6','loading_tip_7',
];
let tipIdx = Math.floor(Math.random() * TIP_KEYS.length);

function updateTip() {
    const el = document.getElementById('tip-text');
    el.style.transition = 'opacity 0.4s';
    el.style.opacity = '0';
    setTimeout(() => {
        el.textContent = t(TIP_KEYS[tipIdx]);
        el.style.opacity = '1';
    }, 400);
}

document.getElementById('tip-text').textContent = t(TIP_KEYS[tipIdx]);
setInterval(() => {
    tipIdx = (tipIdx + 1) % TIP_KEYS.length;
    updateTip();
}, 7000);

// ─── Steps ────────────────────────────────────────────────────────────────────

let currentStep = 0;

const STEP_TEXT_KEYS = {
    1: 'loading_step_1', 2: 'loading_step_2', 3: 'loading_step_3',
    4: 'loading_step_4', 5: 'loading_step_5', 6: 'loading_step_6',
};
const STEP_PCT = { 1: 8, 2: 25, 3: 50, 4: 72, 5: 90, 6: 100 };

function setStep(step) {
    if (step <= currentStep) return;
    currentStep = step;
    document.getElementById('progress-bar').style.width = (STEP_PCT[step] || 0) + '%';
    document.getElementById('status-text').textContent  = t(STEP_TEXT_KEYS[step] || 'loading_step_1');

    for (let i = 1; i <= 6; i++) {
        const el = document.getElementById('step-' + i);
        if (!el) continue;
        el.classList.remove('done','active');
        if (i < step)  el.classList.add('done');
        if (i === step) el.classList.add('active');
    }
}

setTimeout(() => setStep(1), 200);

// ─── NUI / FiveM Events ───────────────────────────────────────────────────────

window.addEventListener('message', e => {
    const data = e.data;
    if (!data) return;

    // Sprache gesetzt → Locale updaten
    if (data.type === 'setLang' && data.locale) {
        _locale = data.locale;
        applyI18n();
        updateTip();
        // Aktuellen Step-Text neu setzen
        if (currentStep > 0) {
            document.getElementById('status-text').textContent = t(STEP_TEXT_KEYS[currentStep] || 'loading_step_1');
        }
        return;
    }

    if (data.eventName === 'loadProgress') {
        document.getElementById('progress-bar').style.width =
            Math.floor((data.loadFraction || 0) * 100) + '%';
    }
    if (data.eventName === 'startConnect') setStep(1);

    // Step-Event
    if (data.type === 'loading:updateStep' || data.eventName === 'loading:updateStep') {
        const step = data.step || (data.data && data.data.step);
        const text = data.text || (data.data && data.data.text);
        if (step) setStep(step);
        if (text) document.getElementById('status-text').textContent = text;
    }
});
