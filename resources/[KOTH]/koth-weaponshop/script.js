// KOTH weapon / vehicle shop
// Weapon shop: "Select a class" screen -> "<Class> Class Shop" with
//              Primary / Secondary / Throwable tabs.
// Vehicle shop: Ground / Air tabs.
// NUI callbacks are unchanged: selectClass, rent, buy, owned, close.

const CLASSES = [
    // Weapon
    { name: 'infantry',   label: 'Infantry',   lvl: 1,  cat: 'weapon', thumb: 'INFANTRY.PNG' },
    { name: 'medic',      label: 'Medic',      lvl: 7,  cat: 'weapon', thumb: 'MEDIC.PNG' },
    { name: 'explosives', label: 'Explosives', lvl: 20, cat: 'weapon', thumb: 'EXPLOSIVES.PNG' },
    { name: 'support',    label: 'Support',    lvl: 27, cat: 'weapon', thumb: 'SUPPORT.PNG' },
    { name: 'marksmamb',  label: 'Marksman',   lvl: 50, cat: 'weapon', thumb: 'MARKSMAMB.PNG' },
    // Vehicle
    { name: 'Ground', label: 'Ground', lvl: 1,  cat: 'vehicule' },
    { name: 'Air',    label: 'Air',    lvl: 15, cat: 'vehicule' },
];

const SECTIONS = [
    { name: 'primary',   label: 'Primary' },
    { name: 'secondary', label: 'Secondary' },
    { name: 'throwable', label: 'Throwable' },
];

const TEAM_PREFIX = { redfor: 'R_', blufor: 'B_', independant: 'G_' };

const view    = document.getElementById('view');
const title   = document.getElementById('shopTitle');
const tabs    = document.getElementById('tabs');
const list    = document.getElementById('list');
const classes = document.getElementById('classes');
const toast   = document.getElementById('toast');
const backbtn = document.getElementById('backbtn');

let state = null;
let toastTimer = null;

const post  = (name, body) => $.post(`https://koth-weaponshop/${name}`, JSON.stringify(body || {}));
const num   = (v) => (v === undefined || v === null || v === '' || String(v).toLowerCase() === 'free') ? 0 : Number(v);
const money = (v) => `$${Number(v || 0).toLocaleString('en-US')}`;

/* ---------------- open / close ---------------- */

window.addEventListener('message', (e) => {
    const data = e.data || {};
    if (data.type === 'close') return hide();
    if (data.type !== 'weapon' && data.type !== 'vehicule') return;

    const player = (data.player && data.player[0]) || {};
    const lvl = Number(player.lvl) || 0;
    const cls = CLASSES.filter(c => c.cat === data.type);

    state = {
        type: data.type,
        team: data.team,
        lvl,
        money: Number(player.money) || 0,
        items: (data.items || []).filter(i => i.cat === data.type),
        owned: new Set((data.owned || []).map(o => o.id)),
        classes: cls,
        screen: data.type === 'weapon' ? 'classes' : 'items',
        cls: data.type === 'weapon' ? null : (cls.find(c => lvl >= c.lvl) || cls[0]).name,
        tab: 'primary',
        taken: new Set(),
        confirmBuy: null,
    };

    view.style.display = 'flex';
    render();
});

function hide() {
    view.style.display = 'none';
    state = null;
}

function close() {
    hide();
    post('close', { close: true });
}

document.getElementById('closebtn').addEventListener('click', close);
backbtn.addEventListener('click', () => {
    if (!state) return;
    state.screen = 'classes';
    state.confirmBuy = null;
    render();
});
document.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape' || !state) return;
    if (state.type === 'weapon' && state.screen === 'items') backbtn.click();
    else close();
});

/* ---------------- render ---------------- */

function render() {
    document.getElementById('wallet').textContent = money(state.money);
    view.classList.toggle('picker', state.screen === 'classes');
    backbtn.style.display = (state.type === 'weapon' && state.screen === 'items') ? 'inline-flex' : 'none';

    if (state.screen === 'classes') {
        title.textContent = 'Select a class';
        tabs.innerHTML = '';
        list.innerHTML = '';
        renderClasses();
    } else {
        classes.innerHTML = '';
        if (state.type === 'weapon') {
            const c = state.classes.find(c => c.name === state.cls);
            title.textContent = `${c ? c.label : ''} Class Shop`;
        } else {
            title.textContent = 'Vehicle Shop';
        }
        renderTabs();
        renderList();
    }
}

/* ----- class picker ----- */

function renderClasses() {
    const prefix = TEAM_PREFIX[state.team] || 'R_';
    classes.innerHTML = '';
    state.classes.forEach(c => {
        const locked = state.lvl < c.lvl;
        const card = document.createElement('div');
        card.className = 'class-card' + (locked ? ' locked' : '');
        card.style.backgroundImage = `url('content/class_images/${prefix}${c.thumb}')`;
        card.innerHTML = `
            <div class="class-head">
                <div class="class-name">${c.label}</div>
                <div class="class-sub">${locked ? `Unlock at level ${c.lvl}` : 'Unlocked'}</div>
            </div>
            <div class="class-icon"><i class="${locked ? 'fas fa-lock' : 'far fa-arrow-alt-circle-right'}"></i></div>`;
        if (!locked) card.addEventListener('click', () => selectClass(c.name));
        classes.appendChild(card);
    });
}

function selectClass(name) {
    // same as before: picking a class resets the loadout on the client
    post('selectClass', { class: name });
    state.cls = name;
    state.taken = new Set();
    state.confirmBuy = null;
    state.screen = 'items';
    const first = SECTIONS.find(s => state.items.some(i => i.class === name && i.wrap === s.name));
    state.tab = first ? first.name : 'primary';
    render();
}

/* ----- tabs ----- */

function renderTabs() {
    tabs.innerHTML = '';

    if (state.type === 'weapon') {
        SECTIONS.forEach(s => {
            if (!state.items.some(i => i.class === state.cls && i.wrap === s.name)) return;
            tabs.appendChild(tabButton(s.label, s.name === state.tab, false, () => { state.tab = s.name; }));
        });
    } else {
        state.classes.forEach(c => {
            const locked = state.lvl < c.lvl;
            const label = locked ? `<i class="fas fa-lock"></i> ${c.label} <small>Lv ${c.lvl}</small>` : c.label;
            tabs.appendChild(tabButton(label, c.name === state.cls, locked, () => { state.cls = c.name; }));
        });
    }
}

function tabButton(label, active, locked, onClick) {
    const b = document.createElement('button');
    b.className = 'tab' + (active ? ' active' : '') + (locked ? ' locked' : '');
    b.innerHTML = label;
    if (!locked) b.addEventListener('click', () => { onClick(); state.confirmBuy = null; renderTabs(); renderList(); });
    return b;
}

/* ----- item rows ----- */

function renderList() {
    list.innerHTML = '';
    let items = state.items.filter(i => i.class === state.cls);
    if (state.type === 'weapon') items = items.filter(i => i.wrap === state.tab);

    if (!items.length) {
        list.innerHTML = '<div class="empty">Nothing here yet</div>';
        return;
    }
    items.forEach(i => list.appendChild(row(i)));
}

function row(item) {
    const locked = state.lvl < Number(item.lvl);
    const owned  = state.owned.has(item.id);
    const taken  = state.taken.has(item.id);

    const el = document.createElement('div');
    el.className = 'row' + (locked ? ' locked' : '');
    const sub = locked ? `Unlocked at Level ${item.lvl}` : (item.desc || '');

    el.innerHTML = `
        <div class="thumb" style="background-image:url('content/item_images/${item.thumb}')"></div>
        <div class="info">
            <div class="name">${item.name}</div>
            ${sub ? `<div class="sub">${sub}</div>` : ''}
        </div>
        <div class="price"></div>`;

    const price = el.querySelector('.price');

    if (locked) {
        price.innerHTML = '<i class="fas fa-lock lock"></i>';
    } else if (taken) {
        price.appendChild(button('<i class="fas fa-check"></i> Taken', 'done'));
    } else if (owned) {
        const b = button('Spawn', 'spawn');
        b.addEventListener('click', () => take('owned', item, 0));
        price.appendChild(b);
    } else {
        if (item.buy) {
            const confirming = state.confirmBuy === item.id;
            const b = pill(confirming ? 'Confirm?' : money(item.buy), 'PURCHASE', 'buy' + (confirming ? ' confirm' : ''));
            b.addEventListener('click', () => {
                if (!confirming) { state.confirmBuy = item.id; return renderList(); }
                buy(item);
            });
            price.appendChild(b);
        }
        const rentPrice = num(item.rent);
        const r = pill(rentPrice ? money(rentPrice) : 'Free', 'RENT', 'rent');
        r.addEventListener('click', () => take('rent', item, rentPrice));
        price.appendChild(r);
    }
    return el;
}

function pill(top, bottom, cls) {
    const d = document.createElement('div');
    d.className = `pill ${cls}`;
    d.innerHTML = `<span>${top}</span><small>${bottom}</small>`;
    return d;
}
function button(html, cls) {
    const d = document.createElement('div');
    d.className = `btn ${cls}`;
    d.innerHTML = html;
    return d;
}

/* ---------------- actions ---------------- */

function ensureVehicleClass() {
    // vehicle shop has no class screen; selectClass is harmless for Ground/Air
    if (state.type === 'vehicule' && state.selectedClass !== state.cls) {
        state.selectedClass = state.cls;
        post('selectClass', { class: state.cls });
    }
}

function take(kind, item, price) {
    if (kind === 'rent' && state.money < price) return notify('Not enough money!', true);
    ensureVehicleClass();

    post(kind, { type: item.cat, item: item.id, price: kind === 'rent' ? item.rent : item.buy, class: item.wrap });

    if (kind === 'rent') state.money -= price;
    state.taken.add(item.id);
    state.confirmBuy = null;
    notify(`${item.name} ${state.type === 'vehicule' ? 'is on its way' : 'added to your loadout'}`);
    render();
}

function buy(item) {
    const price = num(item.buy);
    if (state.money < price) { state.confirmBuy = null; renderList(); return notify('Not enough money!', true); }

    post('buy', { id: item.id, price: item.buy });
    state.money -= price;
    state.owned.add(item.id);
    state.confirmBuy = null;
    notify(`You bought ${item.name}`);
    render();
}

function notify(text, error) {
    toast.textContent = text;
    toast.className = 'toast show' + (error ? ' error' : '');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.className = 'toast'; }, 2500);
}
