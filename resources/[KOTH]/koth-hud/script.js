// KOTH HUD — receives the same NUI messages as before (life, player, teams,
// equiped, weapon1-3, reload, kill feed, notifications) plus `heading` for
// the compass.

const qs = (sel) => document.querySelector(sel);
const fmt = (n) => {
    const v = Number(n);
    return isNaN(v) ? (n ?? '') : v.toLocaleString('en-US');
};

let reloadTimer = null;
let unequipTimer = null;
let currentWeapons = { weapon1: null, weapon2: null, weapon3: null, equiped: null };

/* ---------------- Compass ---------------- */

const PX_PER_DEG = 4;
const COMPASS_WIDTH = 560;
const LABELS = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };

(function buildCompass() {
    const tape = qs('#compassTape');
    let html = '';
    // two full turns either side so the tape never runs out
    for (let d = -360; d <= 720; d += 15) {
        const norm = ((d % 360) + 360) % 360;
        const label = LABELS[norm];
        const isMain = norm % 90 === 0;
        html += `<span class="mark${isMain ? ' main' : ''}" style="left:${d * PX_PER_DEG}px">${label || ''}</span>`;
    }
    tape.innerHTML = html;
    setHeading(0);
})();

function setHeading(deg) {
    const h = ((Number(deg) % 360) + 360) % 360;
    qs('#compassTape').style.transform = `translateX(${COMPASS_WIDTH / 2 - h * PX_PER_DEG}px)`;
}

/* ---------------- Slots ---------------- */

function setSlot(id, value) {
    const el = document.getElementById(id);
    // client sends these every 100ms — only touch the DOM on change
    if ((value === 'false' ? null : value) === currentWeapons[id]) return;
    if (value && value !== 'false') {
        currentWeapons[id] = value;
        el.style.display = 'flex';
        el.innerHTML = `<img src="hud/equiped/${value}.png">`;
    } else if (value === 'false') {
        currentWeapons[id] = null;
        el.innerHTML = '';
        el.style.display = 'none';
    }
    updateActiveSlot();
}

function updateActiveSlot() {
    ['weapon1', 'weapon2', 'weapon3'].forEach(id => {
        document.getElementById(id).classList.toggle(
            'active', !!currentWeapons.equiped && currentWeapons[id] === currentWeapons.equiped
        );
    });
}

/* ---------------- XP feed ---------------- */

function pushXpFeed(reason, money, exp) {
    const feed = qs('#xpfeed');
    const row = document.createElement('div');
    row.className = 'row';

    if (money == null || exp == null) {
        row.classList.add('info');
        row.innerHTML = `<span class="reason">${reason}</span>`;
    } else {
        row.innerHTML =
            `<span class="reason">${reason}</span>` +
            (exp && exp != '0' ? `<span class="xp">${fmt(exp)} xp</span>` : '') +
            `<span class="cash">$${fmt(money)}</span>`;
    }

    feed.appendChild(row);
    while (feed.children.length > 6) feed.firstChild.remove();

    setTimeout(() => {
        row.classList.add('out');
        setTimeout(() => row.remove(), 300);
    }, 5000);
}

/* ---------------- Center message ---------------- */

let centerQueue = [];
function pushCenter(text) {
    centerQueue.push(text);
    if (centerQueue.length === 1) showNextCenter();
}
function showNextCenter() {
    if (!centerQueue.length) return;
    qs('#xpcenter_top').innerHTML = centerQueue[0];
    qs('#xpcenter_bottom').style.display = 'none';
    qs('#xpcenter').style.display = 'block';
    setTimeout(() => {
        qs('#xpcenter').style.display = 'none';
        centerQueue.shift();
        showNextCenter();
    }, 5000);
}

/* ---------------- Kill feed ---------------- */

function addKill(killer, victim, weapon, colora, colorv, headshot) {
    const feed = qs('#killevent');
    const ev = document.createElement('div');
    ev.className = 'event';
    ev.innerHTML =
        `<span id="killer" class="${colora || ''}">${killer}</span>` +
        `<div class="weapon"><img src="./hud/equiped/${weapon}.png">` +
        (headshot ? `<img id="headshot" src="./hud/headshot.png">` : '') +
        `</div>` +
        `<span id="killed" class="${colorv || ''}">${victim}</span>`;
    feed.appendChild(ev);
    while (feed.children.length > 5) feed.firstChild.remove();
    setTimeout(() => ev.remove(), 6000);
}

/* ---------------- Messages ---------------- */

window.addEventListener('message', (event) => {
    const data = event.data || {};

    // show / hide
    if (data.hud) qs('#hud').style.display = 'none';
    if (data.huds) qs('#hud').style.display = 'block';

    if (data.heading !== undefined) setHeading(data.heading);

    // health (GTA: 100 = dead, 200 = full)
    if (data.life !== undefined) {
        const hp = Math.max(0, Math.min(100, data.life - 100));
        const bar = qs('#life');
        bar.style.width = `${hp}%`;
        bar.classList.toggle('low', hp <= 30);
    }

    // medkit cooldown
    if (data.startCooldown && qs('#weapon3').style.display === 'flex' && !qs('#medkitCD')) {
        let cd = Math.round(data.startCooldown / 1000);
        const el = document.createElement('div');
        el.id = 'medkitCD';
        el.textContent = `${cd}s`;
        qs('#weapon3').appendChild(el);
        const iv = setInterval(() => {
            cd--;
            el.textContent = `${cd}s`;
            if (cd <= 0) { el.remove(); clearInterval(iv); }
        }, 1000);
    }

    // reload bar
    if (data.reload) {
        const r = qs('#reload');
        r.style.display = 'block';
        clearTimeout(reloadTimer);
        reloadTimer = setTimeout(() => { r.style.display = 'none'; }, 2000);
    }

    // player stats
    if (data.player) {
        const p = data.player;
        if (p.name) qs('#player').textContent = String(p.name).slice(0, 20);
        if (p.money !== undefined) qs('#money').textContent = fmt(p.money);
        if (p.xp !== undefined) qs('#xp').textContent = fmt(p.xp);
        if (p.nextExp !== undefined) qs('#xp2').textContent = fmt(p.nextExp);
        if (p.lvl !== undefined) qs('#from').textContent = p.lvl;
        if (p.lvls !== undefined) qs('#to').textContent = p.lvls;
        if (p.progress !== undefined) qs('#mana').style.width = p.progress;
    }

    // teams
    if (Array.isArray(data.teams)) {
        data.teams.forEach(t => {
            if (!['red', 'blue', 'green'].includes(t.color)) return;
            document.getElementById(`${t.color}players`).textContent = t.players ?? 0;
            document.getElementById(`${t.color}point`).textContent = t.point ?? 0;
            document.getElementById(`${t.color}target`).textContent = t.target ?? 0;
        });
    }

    // held weapon
    // (the client sends equiped="false" then the real weapon every tick,
    //  so hiding is delayed a little to avoid flicker)
    if (data.equiped !== undefined) {
        if (data.equiped && data.equiped !== 'false') {
            clearTimeout(unequipTimer);
            if (currentWeapons.equiped !== data.equiped) {
                currentWeapons.equiped = data.equiped;
                qs('#equipedWepon').innerHTML = `<img src="hud/equiped/${data.equiped}.png">`;
                updateActiveSlot();
            }
            qs('#equiped').style.display = 'flex';
            qs('#ammo').textContent = data.ammo ? data.ammo : '0';
        } else {
            clearTimeout(unequipTimer);
            unequipTimer = setTimeout(() => {
                currentWeapons.equiped = null;
                qs('#equiped').style.display = 'none';
                qs('#equipedWepon').innerHTML = '';
                updateActiveSlot();
            }, 250);
        }
    }

    // loadout slots
    if (data.weapon1 !== undefined) setSlot('weapon1', data.weapon1);
    if (data.weapon2 !== undefined) setSlot('weapon2', data.weapon2);
    if (data.weapon3 !== undefined) setSlot('weapon3', data.weapon3);

    // notifications
    if (data.type === 'right') pushXpFeed(data.notif_reason, data.notif_money, data.notif_exp);
    if (data.type === 'center') pushCenter(data.notif_reasons);

    // kill feed
    if (data.killer && data.killed) {
        addKill(data.killer, data.killed, data.weaponkill, data.ca, data.cv, data.headshot);
    }
});
