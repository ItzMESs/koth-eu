// KOTH weapon / vehicle shop
// Tabs = classes (infantry, medic, … / Ground, Air), list = items of that class.
// NUI callbacks are unchanged: selectClass, rent, buy, owned, close.

const CLASSES = [
    // Weapon
    { name: 'infantry',   label: 'Infantry',   lvl: 1,  cat: 'weapon' },
    { name: 'medic',      label: 'Medic',      lvl: 7,  cat: 'weapon' },
    { name: 'explosives', label: 'Explosives', lvl: 20, cat: 'weapon' },
    { name: 'support',    label: 'Support',    lvl: 27, cat: 'weapon' },
    { name: 'marksmamb',  label: 'Marksman',   lvl: 50, cat: 'weapon' },
    // Vehicle
    { name: 'Ground', label: 'Ground', lvl: 1,  cat: 'vehicule' },
    { name: 'Air',    label: 'Air',    lvl: 15, cat: 'vehicule' },
];

const SECTIONS = [
    { wrap: 'primary',   label: 'Primary' },
    { wrap: 'secondary', label: 'Secondary' },
    { wrap: 'throwable', label: 'Throwable' },
];

const view  = document.getElementById('view');
const tabs  = document.getElementById('tabs');
const list  = document.getElementById('list');
const toast = document.getElementById('toast');

let state = null;
let toastTimer = null;

const post = (name, body) => $.post(`https://koth-weaponshop/${name}`, JSON.stringify(body || {}));
const num  = (v) => (v === undefined || v === null || v === '' || String(v).toLowerCase() === 'free') ? 0 : Number(v);
const money = (v) => `$ ${Number(v || 0).toLocaleString('en-US')}`;

/* ---------------- open / close ---------------- */

window.addEventListener('message', (e) => {
    const data = e.data || {};
    if (data.type === 'close') return hide();
    if (data.type !== 'weapon' && data.type !== 'vehicule') return;

    const player = (data.player && data.player[0]) || {};
    const classes = CLASSES.filter(c => c.cat === data.type);

    state = {
        type: data.type,
        lvl: Number(player.lvl) || 0,
        money: Number(player.money) || 0,
        items: (data.items || []).filter(i => i.cat === data.type),
        owned: new Set((data.owned || []).map(o => o.id)),
        classes,
        tab: (classes.find(c => Number(player.lvl) >= c.lvl) || classes[0]).name,
        selectedClass: null,     // class actually sent to the client (selectClass)
        taken: new Set(),        // items rented/taken since the class was selected
        confirmBuy: null,
    };

    document.getElementById('shopTitle').textContent = data.type === 'weapon' ? 'Weapon Shop' : 'Vehicle Shop';
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
document.addEventListener('keyup', (e) => { if (e.key === 'Escape' && state) close(); });

/* ---------------- render ---------------- */

function render() {
    document.getElementById('wallet').textContent = money(state.money);
    renderTabs();
    renderList();
}

function renderTabs() {
    tabs.innerHTML = '';
    state.classes.forEach(c => {
        const locked = state.lvl < c.lvl;
        const b = document.createElement('button');
        b.className = 'tab' + (c.name === state.tab ? ' active' : '') + (locked ? ' locked' : '');
        b.innerHTML = locked ? `<i class="fas fa-lock"></i> ${c.label} <small>Lv ${c.lvl}</small>` : c.label;
        if (!locked) b.addEventListener('click', () => { state.tab = c.name; state.confirmBuy = null; renderTabs(); renderList(); });
        tabs.appendChild(b);
    });
}

function renderList() {
    list.innerHTML = '';
    const items = state.items.filter(i => i.class === state.tab);

    if (state.type === 'weapon') {
        SECTIONS.forEach(s => {
            const group = items.filter(i => i.wrap === s.wrap);
            if (!group.length) return;
            const h = document.createElement('div');
            h.className = 'section';
            h.textContent = s.label;
            list.appendChild(h);
            group.forEach(i => list.appendChild(row(i)));
        });
    } else {
        items.forEach(i => list.appendChild(row(i)));
    }

    if (!items.length) list.innerHTML = '<div class="empty">Nothing here yet</div>';
}

function row(item) {
    const locked = state.lvl < Number(item.lvl);
    const owned  = state.owned.has(item.id);
    const taken  = state.taken.has(item.id);

    const el = document.createElement('div');
    el.className = 'row' + (locked ? ' locked' : '');

    const sub = locked
        ? `Unlocked at Level ${item.lvl}`
        : (item.desc || (owned ? 'Owned' : ''));

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
        return el;
    }

    if (taken) {
        price.innerHTML = pill('<i class="fas fa-check"></i>', 'TAKEN', 'done');
        return el;
    }

    if (owned) {
        const p = pillEl('FREE', 'OWNED', 'owned');
        p.addEventListener('click', () => take('owned', item, num(item.buy)));
        price.appendChild(p);
        return el;
    }

    // Buy (with confirm) — only when the item can be bought
    if (item.buy) {
        const confirming = state.confirmBuy === item.id;
        const b = pillEl(confirming ? 'CONFIRM?' : money(item.buy), 'BUY', 'buy' + (confirming ? ' confirm' : ''));
        b.addEventListener('click', (ev) => {
            ev.stopPropagation();
            if (!confirming) { state.confirmBuy = item.id; return renderList(); }
            buy(item);
        });
        price.appendChild(b);
    }

    const rentPrice = num(item.rent);
    const r = pillEl(rentPrice ? money(rentPrice) : 'FREE', 'RENT', 'rent');
    r.addEventListener('click', () => take('rent', item, rentPrice));
    price.appendChild(r);

    return el;
}

function pill(top, bottom, cls) {
    return `<div class="pill ${cls}"><span>${top}</span><small>${bottom}</small></div>`;
}
function pillEl(top, bottom, cls) {
    const d = document.createElement('div');
    d.innerHTML = pill(top, bottom, cls);
    return d.firstElementChild;
}

/* ---------------- actions ---------------- */

function ensureClass() {
    // selecting a class resets the loadout on the client, so only do it
    // when the player actually takes something from a different class
    if (state.selectedClass !== state.tab) {
        state.selectedClass = state.tab;
        state.taken = new Set();
        post('selectClass', { class: state.tab });
    }
}

function take(kind, item, price) {
    if (kind === 'rent' && state.money < price) return notify('Not enough money!', true);
    ensureClass();

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
