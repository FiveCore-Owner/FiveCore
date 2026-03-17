'use strict';

let _locale   = {};
let _slots    = {};
let dragSlot  = null;

// ─── Item Definitions (icon + label) ──────────────────────────────────────────
const ITEMS = {
    // Weapons
    weapon_pistol:          { icon: '🔫', label: 'Pistol'          },
    weapon_combatpistol:    { icon: '🔫', label: 'Combat Pistol'   },
    weapon_microsmg:        { icon: '🔫', label: 'Micro SMG'       },
    weapon_smg:             { icon: '🔫', label: 'SMG'             },
    weapon_shotgun:         { icon: '🔫', label: 'Shotgun'         },
    weapon_assaultrifle:    { icon: '🔫', label: 'Assault Rifle'   },
    weapon_knife:           { icon: '🗡️', label: 'Knife'           },
    weapon_bat:             { icon: '🏏', label: 'Baseball Bat'    },
    // Food / consumables
    item_water:             { icon: '💧', label: 'Water'           },
    item_sandwich:          { icon: '🥪', label: 'Sandwich'        },
    item_soda:              { icon: '🥤', label: 'Soda'            },
    item_bandage:           { icon: '🩹', label: 'Bandage'         },
    item_medkit:            { icon: '🏥', label: 'Medkit'          },
    item_beer:              { icon: '🍺', label: 'Beer'            },
    // Misc
    item_phone:             { icon: '📱', label: 'Phone'           },
    item_id_card:           { icon: '🪪', label: 'ID Card'         },
    item_weapon_license:    { icon: '📄', label: 'Weapons License' },
    item_cash:              { icon: '💵', label: 'Cash'            },
};

function getItemDef(name) {
    const lname = (name || '').toLowerCase();
    return ITEMS[lname] || { icon: '📦', label: name || 'Item' };
}

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

// ─── Hotbar (always visible) ──────────────────────────────────────────────────

function renderHotbar() {
    for (let i = 1; i <= 5; i++) {
        const slot = document.querySelector(`.hotbar-slot[data-hotbar="${i}"]`);
        if (!slot) continue;
        const item = _slots[String(45 + i)];
        const inner = slot.querySelector('.slot-inner');
        inner.innerHTML = '';
        slot.classList.toggle('has-item', !!item);
        if (item) {
            const def = getItemDef(item.name);
            inner.innerHTML = `
                <span class="slot-icon">${def.icon}</span>
                <span class="slot-label">${def.label}</span>
                ${item.count > 1 ? `<span class="slot-count">x${item.count}</span>` : ''}
            `;
        }
    }
}

// ─── Full Inventory Grid ──────────────────────────────────────────────────────

function buildGrid() {
    const grid = document.getElementById('inv-grid');
    grid.innerHTML = '';
    for (let i = 1; i <= 45; i++) {
        grid.appendChild(createSlotEl(i));
    }

    const hotbarGrid = document.getElementById('inv-hotbar-grid');
    hotbarGrid.innerHTML = '';
    for (let i = 46; i <= 50; i++) {
        const el = createSlotEl(i);
        el.classList.add('hotbar-in-grid');
        hotbarGrid.appendChild(el);
    }
}

function createSlotEl(index) {
    const el   = document.createElement('div');
    el.className = 'inv-slot';
    el.dataset.slot = index;
    el.innerHTML = `<span class="inv-slot-num">${index}</span>`;

    const item = _slots[String(index)];
    if (item) {
        const def = getItemDef(item.name);
        el.classList.add('has-item');
        el.innerHTML += `
            <span style="font-size:1.5em">${def.icon}</span>
            <span style="font-size:0.52em;color:rgba(170,170,170,0.75);max-width:50px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;">${def.label}</span>
            ${item.count > 1 ? `<span class="inv-slot-count">x${item.count}</span>` : ''}
        `;
    }

    // Drag & Drop
    el.draggable = !!item;
    el.addEventListener('dragstart', e => {
        if (!item) { e.preventDefault(); return; }
        dragSlot = index;
        el.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'move';
    });
    el.addEventListener('dragend', () => {
        el.classList.remove('dragging');
        dragSlot = null;
    });
    el.addEventListener('dragover', e => {
        e.preventDefault();
        el.classList.add('drag-over');
    });
    el.addEventListener('dragleave', () => el.classList.remove('drag-over'));
    el.addEventListener('drop', e => {
        e.preventDefault();
        el.classList.remove('drag-over');
        if (dragSlot !== null && dragSlot !== index) {
            post('moveItem', { from: dragSlot, to: index });
        }
    });

    // Right click = use
    el.addEventListener('contextmenu', e => {
        e.preventDefault();
        if (item) post('useItem', { slot: index });
    });

    // Tooltip
    el.addEventListener('mouseenter', ev => {
        if (!item) return;
        const def = getItemDef(item.name);
        const tt  = document.getElementById('inv-tooltip');
        tt.innerHTML = `<div class="tt-name">${def.label}</div><div class="tt-count">x${item.count || 1}</div>`;
        tt.style.display = 'block';
        tt.style.left = (ev.clientX + 12) + 'px';
        tt.style.top  = (ev.clientY - 10) + 'px';
    });
    el.addEventListener('mousemove', ev => {
        const tt = document.getElementById('inv-tooltip');
        tt.style.left = (ev.clientX + 12) + 'px';
        tt.style.top  = (ev.clientY - 10) + 'px';
    });
    el.addEventListener('mouseleave', () => {
        document.getElementById('inv-tooltip').style.display = 'none';
    });

    return el;
}

function renderInventory() {
    buildGrid();
    renderHotbar();
}

// ─── Close ────────────────────────────────────────────────────────────────────

document.getElementById('inv-close').addEventListener('click', () => {
    post('closeInventory', {});
});
document.addEventListener('keydown', e => {
    if (e.key === 'Escape') post('closeInventory', {});
});

// ─── Messages ─────────────────────────────────────────────────────────────────

window.addEventListener('message', e => {
    const d = e.data;
    if (!d || !d.type) return;

    if (d.type === 'inventory') {
        _slots = d.slots || {};
        if (d.locale) { _locale = d.locale; applyI18n(); }
        renderInventory();
        if (d.isOpen) {
            document.getElementById('inv-overlay').style.display = 'flex';
        }
        return;
    }

    if (d.type === 'close') {
        document.getElementById('inv-overlay').style.display = 'none';
        document.getElementById('inv-tooltip').style.display = 'none';
        return;
    }

    if (d.type === 'open') {
        document.getElementById('inv-overlay').style.display = 'flex';
        return;
    }

    if (d.type === 'hotbarShow') {
        document.getElementById('hotbar').style.display = 'flex';
        return;
    }
    if (d.type === 'hotbarHide') {
        document.getElementById('hotbar').style.display = 'none';
        return;
    }

    if (d.type === 'setLang' && d.locale) {
        _locale = d.locale;
        applyI18n();
    }
});

// The inventory overlay opens when data is received and invOpen is true
// The Lua client manages open/close state
const origMessage = window.onmessage;
window.addEventListener('message', e => {
    if (e.data && e.data.type === 'inventory') {
        // Always update slots; only show overlay if explicitly opened
    }
});
