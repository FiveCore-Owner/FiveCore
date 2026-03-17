'use strict';

// ─── i18n ─────────────────────────────────────────────────────────────────────

let _locale = {};
function t(key, ...args) {
    let str = _locale[key] ?? key;
    if (args.length > 0) {
        let i = 0;
        str = str.replace(/%[sd]/g, () => String(args[i++] ?? ''));
    }
    return str;
}
function applyI18n(root) {
    (root || document).querySelectorAll('[data-i18n]').forEach(el => {
        el.textContent = t(el.dataset.i18n);
    });
    (root || document).querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        el.placeholder = t(el.dataset.i18nPlaceholder);
    });
}

// ─── State ────────────────────────────────────────────────────────────────────

let currentGender = 0;
let charList      = [];
let availableLangs = [];
let allLocales     = {};

const appearance = {
    heritage:     { mother: 0, father: 0, resemblance: 0.5, skinTone: 0.5 },
    faceFeatures: new Array(20).fill(0.0),
    headOverlays: {},
    hair:         { style: 0, color: 0, highlight: 0 },
    eyeColor:     0,
};

// ─── NUI Post ─────────────────────────────────────────────────────────────────

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

// ─── Language Selector ───────────────────────────────────────────────────────

const LANG_FLAGS = { en: '🇬🇧', de: '🇩🇪', fr: '🇫🇷', zh: '🇨🇳' };
const LANG_NAMES = { en: 'English', de: 'Deutsch', fr: 'Français', zh: '中文' };

function renderLangSelector() {
    const list = document.getElementById('lang-list');
    list.innerHTML = '';
    availableLangs.forEach(lang => {
        const btn = document.createElement('button');
        btn.className = 'lang-btn';
        btn.innerHTML = `
            <span class="lang-flag">${LANG_FLAGS[lang] || '🌐'}</span>
            <span class="lang-name">${escHtml(LANG_NAMES[lang] || lang.toUpperCase())}</span>
        `;
        btn.addEventListener('click', () => {
            // Locale setzen
            if (allLocales[lang]) {
                _locale = allLocales[lang];
                applyI18n();
            }
            // Server informieren
            post('setLanguage', { lang });
            // Weiter zur Charakter-Auswahl
            showScreen('select');
        });
        list.appendChild(btn);
    });
}

// ─── Screen Navigation ───────────────────────────────────────────────────────

function showScreen(name) {
    ['lang','select','create'].forEach(s => {
        const el = document.getElementById('screen-' + s);
        if (el) el.style.display = (s === name) ? 'flex' : 'none';
    });
}

// ─── Slider Helper ────────────────────────────────────────────────────────────

function bindSlider(id, valId, onchange, decimals) {
    const sl  = document.getElementById(id);
    const val = document.getElementById(valId);
    if (!sl || !val) return;
    const update = () => {
        const v = decimals > 0
            ? (sl.value / 100).toFixed(decimals)
            : sl.value;
        val.textContent = v;
        if (onchange) onchange(parseFloat(v));
    };
    sl.addEventListener('input', () => { update(); sendPreview(); });
    update();
}

// ─── Face Features ────────────────────────────────────────────────────────────

const FF_KEYS = [
    'cc_ff_nose_width','cc_ff_nose_peak_height','cc_ff_nose_peak_length',
    'cc_ff_nose_bone_high','cc_ff_nose_peak_lowering','cc_ff_cheekbone_high',
    'cc_ff_cheekbone_width','cc_ff_cheek_width','cc_ff_eye_opening',
    'cc_ff_lip_thickness','cc_ff_jaw_bone_width','cc_ff_jaw_bone_back_length',
    'cc_ff_chin_bone_lowering','cc_ff_chin_bone_length','cc_ff_chin_bone_width',
    'cc_ff_chin_hole','cc_ff_neck_thickness','cc_ff_eye_spacing',
    'cc_ff_forehead_height','cc_ff_ear_size',
];

function buildFaceFeatures() {
    const container = document.getElementById('face-features-list');
    container.innerHTML = '';
    FF_KEYS.forEach((key, i) => {
        const row = document.createElement('div');
        row.className = 'row-label';
        row.innerHTML = `
            <span>${escHtml(t(key))}</span>
            <input type="range" min="-100" max="100" step="1" value="${Math.round(appearance.faceFeatures[i]*100)}" id="sl-ff-${i}">
            <span id="val-ff-${i}">${Math.round(appearance.faceFeatures[i]*100)}</span>
        `;
        container.appendChild(row);
        const sl = row.querySelector('input');
        sl.addEventListener('input', () => {
            const v = parseInt(sl.value) / 100;
            document.getElementById(`val-ff-${i}`).textContent = sl.value;
            appearance.faceFeatures[i] = v;
            sendPreview();
        });
    });
}

// ─── Overlays ─────────────────────────────────────────────────────────────────

const OVERLAY_DEFS = [
    { id: 0, key: 'cc_ov_blemishes',  max: 23 },
    { id: 1, key: 'cc_ov_facial_hair',max: 28 },
    { id: 2, key: 'cc_ov_eyebrows',   max: 33 },
    { id: 5, key: 'cc_ov_freckles',   max: 11 },
    { id: 6, key: 'cc_ov_aging',      max: 14 },
    { id: 8, key: 'cc_ov_lipstick',   max: 9  },
    { id: 9, key: 'cc_ov_moles',      max: 17 },
    { id: 10,key: 'cc_ov_blush',      max: 6  },
];

function buildOverlays() {
    const container = document.getElementById('overlay-list');
    container.innerHTML = '';
    OVERLAY_DEFS.forEach(ov => {
        const block = document.createElement('div');
        block.style.cssText = 'display:flex;flex-direction:column;gap:4px;';
        block.innerHTML = `
            <div class="section-title" style="margin-top:6px">${escHtml(t(ov.key))}</div>
            <div class="row-label">
                <span>${escHtml(t('cc_ov_style'))}</span>
                <input type="range" min="0" max="${ov.max}" step="1" value="0" id="ov-idx-${ov.id}">
                <span id="ov-idx-val-${ov.id}">0</span>
            </div>
            <div class="row-label">
                <span>${escHtml(t('cc_ov_opacity'))}</span>
                <input type="range" min="0" max="100" step="1" value="0" id="ov-op-${ov.id}">
                <span id="ov-op-val-${ov.id}">0.00</span>
            </div>
        `;
        container.appendChild(block);
        const slIdx = document.getElementById(`ov-idx-${ov.id}`);
        const slOp  = document.getElementById(`ov-op-${ov.id}`);
        const updateOv = () => {
            document.getElementById(`ov-idx-val-${ov.id}`).textContent = slIdx.value;
            document.getElementById(`ov-op-val-${ov.id}`).textContent  = (slOp.value / 100).toFixed(2);
            appearance.headOverlays[ov.id] = { index: parseInt(slIdx.value), opacity: parseFloat(slOp.value) / 100 };
            sendPreview();
        };
        slIdx.addEventListener('input', updateOv);
        slOp.addEventListener('input', updateOv);
    });
}

// ─── Preview ──────────────────────────────────────────────────────────────────

function sendPreview() { post('previewAppearance', { appearance }); }

// ─── Tabs ─────────────────────────────────────────────────────────────────────

document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
    });
});

// ─── Gender ───────────────────────────────────────────────────────────────────

document.querySelectorAll('.gender-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.gender-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentGender = parseInt(btn.dataset.gender);
        post('changeGender', { gender: currentGender });
    });
});

// ─── Camera ──────────────────────────────────────────────────────────────────

document.querySelectorAll('.cam-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.cam-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        post('setCameraPreset', { preset: btn.dataset.cam });
    });
});

// ─── Heritage Sliders ────────────────────────────────────────────────────────

bindSlider('sl-mother',     'val-mother',     v => { appearance.heritage.mother      = v; }, 0);
bindSlider('sl-father',     'val-father',     v => { appearance.heritage.father      = v; }, 0);
bindSlider('sl-resemblance','val-resemblance',v => { appearance.heritage.resemblance = v; }, 2);
bindSlider('sl-skintone',   'val-skintone',   v => { appearance.heritage.skinTone    = v; }, 2);
bindSlider('sl-hair-style',    'val-hair-style',    v => { appearance.hair.style     = v; }, 0);
bindSlider('sl-hair-color',    'val-hair-color',    v => { appearance.hair.color     = v; }, 0);
bindSlider('sl-hair-highlight','val-hair-highlight',v => { appearance.hair.highlight = v; }, 0);
bindSlider('sl-eyecolor',      'val-eyecolor',      v => { appearance.eyeColor       = v; }, 0);

// ─── Randomize ────────────────────────────────────────────────────────────────

document.getElementById('btn-randomize').addEventListener('click', () => {
    const rand  = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
    const randf = (min, max) => parseFloat((Math.random() * (max - min) + min).toFixed(2));

    appearance.heritage = {
        mother: rand(0,44), father: rand(0,44),
        resemblance: randf(0,1), skinTone: randf(0,1),
    };
    ['sl-mother','sl-father'].forEach((id,i) => {
        document.getElementById(id).value = [appearance.heritage.mother, appearance.heritage.father][i];
    });
    document.getElementById('sl-resemblance').value = Math.round(appearance.heritage.resemblance * 100);
    document.getElementById('sl-skintone').value    = Math.round(appearance.heritage.skinTone * 100);

    appearance.faceFeatures = appearance.faceFeatures.map(() => randf(-1,1));
    appearance.faceFeatures.forEach((v,i) => {
        const sl = document.getElementById(`sl-ff-${i}`);
        if (sl) sl.value = Math.round(v * 100);
    });

    appearance.hair = { style: rand(0,73), color: rand(0,63), highlight: rand(0,63) };
    document.getElementById('sl-hair-style').value     = appearance.hair.style;
    document.getElementById('sl-hair-color').value     = appearance.hair.color;
    document.getElementById('sl-hair-highlight').value = appearance.hair.highlight;
    appearance.eyeColor = rand(0,30);
    document.getElementById('sl-eyecolor').value = appearance.eyeColor;

    sendPreview();
});

// ─── Validation ──────────────────────────────────────────────────────────────

function showError(msg) {
    const el = document.getElementById('info-error');
    el.textContent = msg;
    el.style.display = msg ? 'block' : 'none';
}

function validateInfo() {
    const fn  = document.getElementById('inp-firstname').value.trim();
    const ln  = document.getElementById('inp-lastname').value.trim();
    const dob = document.getElementById('inp-dob').value.trim();

    if (!fn || fn.length < 2 || fn.length > 30)    return t('cc_err_firstname');
    if (/[^a-zA-ZäöüÄÖÜßàâéèêëîïôùûüçæœÀÂÉÈÊËÎÏÔÙÛÜÇÆŒ\s\-]/.test(fn))
                                                     return t('cc_err_firstname_chars');
    if (!ln || ln.length < 2 || ln.length > 30)    return t('cc_err_lastname');
    if (/[^a-zA-ZäöüÄÖÜßàâéèêëîïôùûüçæœÀÂÉÈÊËÎÏÔÙÛÜÇÆŒ\s\-]/.test(ln))
                                                     return t('cc_err_lastname_chars');
    if (!dob || !/^\d{2}\/\d{2}\/\d{4}$/.test(dob)) return t('cc_err_dob_format');

    const [dd, mm, yyyy] = dob.split('/').map(Number);
    const date = new Date(yyyy, mm - 1, dd);
    const age  = (Date.now() - date) / (1000 * 60 * 60 * 24 * 365.25);
    if (isNaN(date.getTime()) || age < 18 || age > 100)
        return t('cc_err_dob_age');
    return null;
}

// ─── Create ───────────────────────────────────────────────────────────────────

document.getElementById('btn-create').addEventListener('click', () => {
    const err = validateInfo();
    if (err) {
        document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        document.querySelector('.tab[data-tab="info"]').classList.add('active');
        document.getElementById('tab-info').classList.add('active');
        showError(err);
        return;
    }
    showError(null);
    post('createCharacter', {
        firstname:  document.getElementById('inp-firstname').value.trim(),
        lastname:   document.getElementById('inp-lastname').value.trim(),
        dob:        document.getElementById('inp-dob').value.trim(),
        gender:     currentGender,
        appearance: JSON.parse(JSON.stringify(appearance)),
    });
    document.getElementById('btn-create').disabled    = true;
    document.getElementById('btn-create').textContent = t('cc_creating');
});

// ─── Char List ────────────────────────────────────────────────────────────────

function renderCharList() {
    const container = document.getElementById('char-list');
    container.innerHTML = '';

    if (charList.length === 0) {
        container.innerHTML = `<div style="color:#555;font-size:0.82em;text-align:center;padding:12px 0">${escHtml(t('cc_no_chars'))}</div>`;
        return;
    }
    charList.forEach(char => {
        const card = document.createElement('div');
        card.className = 'char-card';
        const gIcon = char.gender === 0 ? '♂' : '♀';
        card.innerHTML = `
            <div>
                <div class="char-name">${escHtml(char.firstname)} ${escHtml(char.lastname)} <span style="color:#555">${gIcon}</span></div>
                <div class="char-meta">${t('cc_slot', char.slot)} · ${escHtml(char.dob || '?')}</div>
            </div>
            <div class="char-actions">
                <button class="btn-icon primary" data-id="${char.id}" data-action="select">${escHtml(t('cc_play'))}</button>
                <button class="btn-icon danger"  data-id="${char.id}" data-action="delete">✕</button>
            </div>
        `;
        container.appendChild(card);
    });

    container.querySelectorAll('[data-action="select"]').forEach(btn => {
        btn.addEventListener('click', e => {
            e.stopPropagation();
            post('selectCharacter', { charId: parseInt(btn.dataset.id) });
        });
    });
    container.querySelectorAll('[data-action="delete"]').forEach(btn => {
        btn.addEventListener('click', e => {
            e.stopPropagation();
            if (confirm(t('cc_confirm_delete'))) {
                post('deleteCharacter', { charId: parseInt(btn.dataset.id) });
                charList = charList.filter(c => c.id !== parseInt(btn.dataset.id));
                renderCharList();
            }
        });
    });
}

// ─── Navigation ───────────────────────────────────────────────────────────────

document.getElementById('btn-new-char').addEventListener('click', () => {
    showScreen('create');
    buildFaceFeatures();
    buildOverlays();
});

document.getElementById('btn-back').addEventListener('click', () => {
    showScreen('select');
    document.getElementById('btn-create').disabled    = false;
    document.getElementById('btn-create').textContent = t('cc_create');
    showError(null);
});

// ─── NUI Message Handler ─────────────────────────────────────────────────────

window.addEventListener('message', e => {
    const data = e.data;
    if (!data || !data.type) return;

    // Sprache setzen (kommt von core state.lua)
    if (data.type === 'setLang') {
        if (data.locale) {
            _locale = data.locale;
            applyI18n();
            // Charakter-Listen-Buttons neu rendern
            renderCharList();
        }
        return;
    }

    if (data.type === 'open') {
        document.getElementById('app').style.display = 'flex';
        charList      = data.charList  || [];
        availableLangs = data.availableLangs || ['en'];
        allLocales     = data.locales  || {};

        // Falls Sprache bereits gesetzt, Locale laden
        if (data.locale) {
            _locale = data.locale;
            applyI18n();
        }

        // Sprachauswahl zeigen wenn > 1 Sprache verfügbar und noch keine gewählt
        if (availableLangs.length > 1 && !data.langAlreadySet) {
            renderLangSelector();
            showScreen('lang');
        } else {
            showScreen('select');
            renderCharList();
        }
    }

    if (data.type === 'createError') {
        showError(data.error || t('cc_db_error'));
        document.getElementById('btn-create').disabled    = false;
        document.getElementById('btn-create').textContent = t('cc_create');
    }
});
