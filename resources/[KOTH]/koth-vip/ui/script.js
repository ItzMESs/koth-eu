// KOTH VIP menu UI
const RESOURCE = 'koth-vip';
const wrap = document.getElementById('wrap');
const content = document.getElementById('content');

let S = null;          // state from client.lua
let tab = 'overview';
let vehSlot = 'primary';
let vehGroup = null;

const post = (name, body) =>
    fetch(`https://${RESOURCE}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) })
        .then(r => r.json()).catch(() => ({}));

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => Number(n || 0).toLocaleString('en-US');

/* ---------------- render ---------------- */

function render() {
    document.getElementById('who').textContent = `${S.name} · ID ${S.serverId}`;
    const badge = document.getElementById('badge');
    badge.textContent = S.vip ? 'VIP ACTIVE' : 'NO VIP';
    badge.classList.toggle('off', !S.vip);

    document.querySelectorAll('#tabs button').forEach(b => {
        b.classList.toggle('active', b.dataset.tab === tab);
        const needsVip = b.dataset.tab === 'weapon' || b.dataset.tab === 'vehicle';
        let lock = b.querySelector('.lock');
        if (needsVip && !S.vip && !lock) b.insertAdjacentHTML('beforeend', '<i class="fas fa-lock lock"></i>');
        if ((S.vip || !needsVip) && lock) lock.remove();
    });

    ({ overview, weapon, vehicle, settings })[tab]();
}

function perksHtml(locked) {
    return `<div class="perks${locked ? ' locked' : ''}">` + (S.perks || []).map(p => `
        <div class="perk"><i class="fas ${esc(p.icon)}"></i><div><b>${esc(p.title)}</b><span>${esc(p.text)}</span></div></div>`).join('') + '</div>';
}

function overview() {
    const st = S.stats || {};
    const kd = (Number(st.deaths) ? (st.kills / st.deaths) : Number(st.kills || 0)).toFixed(2);
    content.innerHTML = `
        <h2>${S.vip ? 'Welcome back, VIP' : 'VIP benefits'}</h2>
        <div class="sub">${S.vip ? `You earn <b style="color:var(--gold)">x${S.boost}</b> XP and money this match.` : 'Unlock these perks with VIP.'}</div>

        <div class="section">This match</div>
        <div class="stats">
            <div class="stat"><small>KILLS</small><b>${fmt(st.kills)}</b></div>
            <div class="stat"><small>DEATHS</small><b>${fmt(st.deaths)}</b></div>
            <div class="stat"><small>ASSISTS</small><b>${fmt(st.assists)}</b></div>
            <div class="stat"><small>K/D</small><b>${kd}</b></div>
            <div class="stat"><small>EARNED</small><b class="money">$${fmt(st.money)}</b></div>
        </div>

        <div class="section">${S.vip ? 'Your perks' : 'Perks'}</div>
        ${perksHtml(!S.vip)}
        ${S.vip ? '' : `
        <div class="cta"><i class="fas fa-crown"></i><div><b>Get VIP</b><span>Ask a staff member on our Discord to activate VIP on your account.</span></div></div>`}`;
}

function locked(what) {
    content.innerHTML = `
        <div class="empty"><i class="fas fa-lock"></i><b>${what} is <span class="gold">VIP only</span></b>
        <span>Get VIP to unlock free attachments, weapon tints and vehicle paint.</span></div>`;
}

function weapon() {
    if (!S.vip) return locked('Weapon customisation');
    const w = S.weapon;
    if (!w) {
        content.innerHTML = `<div class="empty"><i class="fas fa-hand-paper"></i><b>No weapon in hand</b><span>Take out a weapon and open the menu again.</span></div>`;
        return;
    }
    const comps = w.components || [];
    content.innerHTML = `
        <div class="weapon-head">
            ${w.id ? `<img src="nui://koth-hud/hud/equiped/${esc(w.id)}.png" onerror="this.remove()">` : ''}
            <div><b>${esc(w.label)}</b><span>${comps.length} attachment${comps.length === 1 ? '' : 's'} available · free for VIP</span></div>
        </div>

        <div class="section">Attachments</div>
        ${comps.length ? `<div class="grid">${comps.map(c => `
            <div class="opt${c.on ? ' on' : ''}" data-comp="${esc(c.id)}"><span class="name">${esc(c.label)}</span><span class="toggle"></span></div>`).join('')}</div>`
            : '<div class="sub">This weapon has no attachments.</div>'}

        <div class="section">Weapon tint</div>
        <div class="tints">${(w.tints || []).map((t, i) => `<div class="tint${w.tint === i ? ' on' : ''}" data-tint="${i}">${esc(t)}</div>`).join('')}</div>`;

    content.querySelectorAll('[data-comp]').forEach(el => el.onclick = async () => {
        el.classList.toggle('on');                           // optimistic
        const r = await post('toggleComponent', { id: el.dataset.comp });
        if (r && r.weapon) { S.weapon = r.weapon; render(); }
    });
    content.querySelectorAll('[data-tint]').forEach(el => el.onclick = async () => {
        S.weapon.tint = Number(el.dataset.tint); render();
        const r = await post('setTint', { index: Number(el.dataset.tint) });
        if (r && r.weapon) { S.weapon = r.weapon; render(); }
    });
}

function vehicle() {
    if (!S.vip) return locked('Vehicle paint');
    const v = S.vehicle;
    if (!v) {
        content.innerHTML = `<div class="empty"><i class="fas fa-car"></i><b>You are not in a vehicle</b><span>Get in as the driver and open the menu again.</span></div>`;
        return;
    }
    const groups = v.groups || [];
    if (!vehGroup && groups.length) vehGroup = groups[0].id;
    const g = groups.find(x => x.id === vehGroup) || groups[0];
    const current = vehSlot === 'primary' ? v.primary : v.secondary;

    content.innerHTML = `
        <h2>${esc(v.name)}</h2>
        <div class="sub">Pick a colour group, then a shade. Only the driver can repaint.</div>
        <div class="slot-switch">
            <button data-slot="primary" class="${vehSlot === 'primary' ? 'on' : ''}">Primary</button>
            <button data-slot="secondary" class="${vehSlot === 'secondary' ? 'on' : ''}">Secondary</button>
        </div>
        <div class="groups">${groups.map(x => `<div class="group${x.id === g.id ? ' on' : ''}" data-group="${esc(x.id)}" title="${esc(x.label)}" style="background:${esc(x.swatch)}"></div>`).join('')}</div>
        <div class="colors">${(g ? g.colors : []).map(c => `
            <div class="color${c.index === current ? ' on' : ''}" data-color="${c.index}"><i style="background:${esc(g.swatch)}"></i>${esc(c.label)}</div>`).join('')}</div>`;

    content.querySelectorAll('[data-slot]').forEach(el => el.onclick = () => { vehSlot = el.dataset.slot; render(); });
    content.querySelectorAll('[data-group]').forEach(el => el.onclick = () => { vehGroup = el.dataset.group; render(); });
    content.querySelectorAll('[data-color]').forEach(el => el.onclick = async () => {
        const idx = Number(el.dataset.color);
        if (vehSlot === 'primary') S.vehicle.primary = idx; else S.vehicle.secondary = idx;
        render();
        const r = await post('setVehColor', { slot: vehSlot, index: idx });
        if (r && r.vehicle) { S.vehicle = r.vehicle; render(); }
    });
}

function settings() {
    content.innerHTML = `
        <h2>Settings</h2>
        <div class="sub">Open this menu any time with <span class="kbd">F5</span> or <span class="kbd">/vip</span>. You can change the key in GTA Settings → Key Bindings → FiveM.</div>
        <div class="setting${S.hud ? ' on' : ''}" id="hudToggle"><div>Show HUD<small>Hide the HUD for clean screenshots.</small></div><span class="toggle"></span></div>`;
    document.getElementById('hudToggle').onclick = () => {
        S.hud = !S.hud;
        post('toggleHud', { on: S.hud });
        render();
    };
}

/* ---------------- events ---------------- */

document.querySelectorAll('#tabs button').forEach(b => b.onclick = () => { tab = b.dataset.tab; render(); });

function close() {
    wrap.classList.remove('open');
    post('close');
}
document.getElementById('closebtn').onclick = close;
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && wrap.classList.contains('open')) close(); });

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        S = d.data;
        wrap.classList.add('open');
        render();
    }
});
