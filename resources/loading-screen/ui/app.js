'use strict';

// ─── i18n ──────────────────────────────────────────────────────────────────────
let _loc = {
    loading_subtitle:  'ROLEPLAY',
    loading_step_1:    'Verbinde mit Server...',
    loading_step_2:    'Lade Account...',
    loading_step_3:    'Lade Charaktere...',
    loading_tip_label: 'TIPP',
    loading_server:    'Server',
    loading_account:   'Account',
    loading_character: 'Charaktere',
    loading_tip_1: 'Drücke F2, um dein Telefon zu öffnen.',
    loading_tip_2: 'Nutze /me für Roleplay-Aktionen.',
    loading_tip_3: 'Drücke T zum Schreiben. /ooc für Out-of-Character.',
    loading_tip_4: 'Dein Charakter wird alle 5 Minuten gespeichert.',
    loading_tip_5: 'Tippe /help für alle verfügbaren Befehle.',
    loading_tip_6: 'Telefonnummern haben das Format 555-XXXX.',
    loading_tip_7: 'Hunger und Durst nehmen mit der Zeit ab.',
};

function t(k) { return _loc[k] || k; }
function applyI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
}
applyI18n();

// ─── Tips ─────────────────────────────────────────────────────────────────────
const TIPS = ['loading_tip_1','loading_tip_2','loading_tip_3','loading_tip_4',
              'loading_tip_5','loading_tip_6','loading_tip_7'];
let tipIdx = Math.floor(Math.random() * TIPS.length);
const tipEl = document.getElementById('tip');

function showTip() {
    tipEl.style.opacity = '0';
    setTimeout(() => {
        tipEl.textContent = t(TIPS[tipIdx]);
        tipEl.style.opacity = '1';
    }, 300);
}
showTip();
setInterval(() => { tipIdx = (tipIdx + 1) % TIPS.length; showTip(); }, 8000);

// ─── Progress + Steps ─────────────────────────────────────────────────────────
let curStep = 0;
const pb    = document.getElementById('pb');
const st    = document.getElementById('status');
const STEP_PCT = { 1: 10, 2: 70, 3: 100 };
const STEP_TXT = { 1: 'loading_step_1', 2: 'loading_step_2', 3: 'loading_step_3' };

function setStep(n) {
    if (n <= curStep) return;
    curStep = n;
    if (STEP_PCT[n]) pb.style.width = STEP_PCT[n] + '%';
    if (STEP_TXT[n]) st.textContent  = t(STEP_TXT[n]);

    for (let i = 1; i <= 3; i++) {
        const el = document.getElementById('s' + i);
        if (!el) continue;
        el.classList.remove('active', 'done');
        if (i < n)  el.classList.add('done');
        if (i === n) el.classList.add('active');
    }
}

// start at step 1 immediately
setTimeout(() => setStep(1), 100);

// ─── NUI / FiveM Messages ─────────────────────────────────────────────────────
window.addEventListener('message', e => {
    const d = e.data;
    if (!d) return;

    // FiveM native load progress
    if (d.eventName === 'loadProgress') {
        const pct = Math.floor((d.loadFraction || 0) * 60); // max 60% from native
        if (pct > (parseFloat(pb.style.width) || 0)) pb.style.width = pct + '%';
    }
    if (d.eventName === 'startConnect') setStep(1);

    // Step event forwarded from client/main.lua
    if (d.type === 'updateStep') {
        const s = d.step;
        if (s >= 1 && s <= 3) setStep(s);
    }

    // Branding + tips from server.cfg ConVars
    if (d.type === 'setBranding') {
        const nameEl = document.querySelector('.brand-name');
        const subEl  = document.querySelector('.brand-sub');
        if (nameEl && d.title) nameEl.textContent = d.title.toUpperCase();
        if (subEl  && d.bio)   subEl.textContent  = d.bio.toUpperCase();

        // Show/hide tip row
        const tipRow = document.querySelector('.tip-row');
        if (tipRow) tipRow.style.display = (d.showTips === false) ? 'none' : '';

        // Override tips with custom list from server.cfg
        if (Array.isArray(d.customTips) && d.customTips.length > 0) {
            // Replace TIPS array and reset index
            TIPS.length = 0;
            d.customTips.forEach((t, i) => {
                const key = '__custom_' + i;
                _loc[key] = t;
                TIPS.push(key);
            });
            tipIdx = 0;
            showTip();
        }
    }

    // Language update
    if (d.type === 'setLang' && d.locale) {
        _loc = Object.assign({}, _loc, d.locale);
        applyI18n();
        if (STEP_TXT[curStep]) st.textContent = t(STEP_TXT[curStep]);
        showTip();
    }
});
