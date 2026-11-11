// koth-plus UI: admin panel, report, career/prestige, killstreaks, bounty, toasts
const RES = 'koth-plus';
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (n) => Number(n || 0).toLocaleString('en-US');
const post = (name, body) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) })
    .then(r => r.json()).catch(() => ({}));
const TEAM = { 1: ['OPFOR', 't-r'], 2: ['BLUFOR', 't-b'], 3: ['INDFOR', 't-g'] };
const teamTag = (t) => TEAM[t] ? `<span class="${TEAM[t][1]}">${TEAM[t][0]}</span>` : '<span class="muted">—</span>';
const roman = (n) => ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'][n] || String(n);
const hours = (sec) => Math.floor((Number(sec) || 0) / 3600) + 'h';
const PANELS = ['admin', 'report', 'career', 'ks'];

function showPanel(id) {
    PANELS.forEach(p => $(p).classList.toggle('hidden', p !== id));
    $('dim').classList.toggle('on', !!id);
}
function closePanel() {
    showPanel(null);
    clearInterval(Admin.timer);
    post('close');
}
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && PANELS.some(p => !$(p).classList.contains('hidden'))) closePanel();
});
const hdr = (icon, color, title, sub, extra = '') => `
    <div class="hdr"><div class="ico" style="background:${color}"><i class="fas ${icon}"></i></div>
    <div><h1>${title}</h1><div class="s">${sub}</div></div>${extra}<div class="x" data-close style="${extra ? 'margin-left:14px' : 'margin-left:auto'}"><i class="fas fa-times"></i></div></div>`;
function bindClose(root) { root.querySelectorAll('[data-close]').forEach(b => b.onclick = closePanel); }

/* ================= toasts / announce / big message ================= */
function toast(text, kind) {
    const t = document.createElement('div');
    t.className = `toast ${kind || ''}`;
    t.textContent = text;
    $('toasts').appendChild(t);
    setTimeout(() => t.remove(), 4500);
}
let annTimer, bigTimer;
function announce(d) {
    $('announce').innerHTML = `<small><i class="fas fa-bullhorn"></i> ANNOUNCEMENT · ${esc(d.by || 'Staff')}</small><p>${esc(d.text)}</p>`;
    $('announce').classList.add('on');
    clearTimeout(annTimer); annTimer = setTimeout(() => $('announce').classList.remove('on'), 9000);
}
function bigmsg(d) {
    const el = $('bigmsg');
    el.className = `bigmsg on ${d.color || ''}`;
    el.innerHTML = `<h2>${esc(d.title)}</h2><p>${esc(d.sub || '')}</p>`;
    clearTimeout(bigTimer); bigTimer = setTimeout(() => el.classList.remove('on'), 3500);
}

/* ================= ADMIN ================= */
const Admin = { d: null, tab: 'players', sel: null, info: null, search: '', bans: [], now: 0, confirm: null, timer: null };

function adminOpen(d) {
    Admin.d = d; Admin.tab = 'players'; Admin.info = null; Admin.confirm = null;
    if (!Admin.sel && d.players.length) Admin.sel = d.players[0].id;
    showPanel('admin');
    adminRender();
    if (Admin.sel) post('admin', { action: 'info', target: Admin.sel });
    clearInterval(Admin.timer);
    Admin.timer = setInterval(() => post('admin', { action: 'refresh' }), 5000);
}

function adminAct(action, target, args) {
    post('admin', { action, target, args }).then(r => {
        if (r && r.self) { Admin.d.self = r.self; if (Admin.tab === 'self') adminRender(); }
    });
}

function adminRender() {
    const d = Admin.d, root = $('admin');
    const open = d.reports.filter(r => r.status !== 'closed').length;
    const tabs = [['players', 'fa-users', 'Players'], ['reports', 'fa-flag', 'Reports'], ['bans', 'fa-ban', 'Bans'], ['self', 'fa-user-shield', 'Self'], ['server', 'fa-server', 'Server']];
    root.innerHTML = hdr('fa-shield-alt', 'var(--red)', 'Admin Panel', `${esc(d.rankLabel)} · F11`,
        `<span class="pill" style="margin-left:auto;background:rgba(34,197,94,.15);color:#4ade80">${d.players.length} / ${d.maxPlayers} ONLINE</span>
         <div class="staffbtn ${d.staffMode ? 'on' : ''}" id="staffBtn" style="margin-left:10px"><i class="fas fa-user-shield"></i> STAFF MODE ${d.staffMode ? 'ON' : 'OFF'}</div>`) +
        `<div class="body"><div class="side">${tabs.map(([id, ic, l]) =>
            `<div data-tab="${id}" class="${Admin.tab === id ? 'on' : ''}"><i class="fas ${ic}"></i>${l}${id === 'reports' && open ? `<span class="n">${open}</span>` : ''}</div>`).join('')}</div>
         <div id="adminMain" style="flex:1;display:flex;min-width:0;min-height:0"></div></div>`;
    bindClose(root);
    $('staffBtn').onclick = () => adminAct('staffmode');
    root.querySelectorAll('[data-tab]').forEach(t => t.onclick = () => {
        Admin.tab = t.dataset.tab; Admin.confirm = null;
        if (Admin.tab === 'bans') post('admin', { action: 'bans' });
        adminRender();
    });
    ({ players: adminPlayers, reports: adminReports, bans: adminBans, self: adminSelf, server: adminServer })[Admin.tab]();
}

function adminPlayers() {
    const d = Admin.d, q = Admin.search.toLowerCase();
    const list = d.players.filter(p => !q || p.name.toLowerCase().includes(q) || String(p.id) === q);
    $('adminMain').innerHTML = `
        <div class="plist">
            <div class="search"><i class="fas fa-search"></i><input id="psearch" placeholder="Search name or ID…" value="${esc(Admin.search)}"></div>
            <div class="prow phead"><span>ID</span><span>PLAYER</span><span>TEAM</span><span style="text-align:right">PING</span></div>
            <div class="scroll" style="flex:1">${list.map(p => `
                <div class="prow ${p.id === Admin.sel ? 'sel' : ''}" data-id="${p.id}"><span class="id">${p.id}</span>
                <span>${p.vip ? '<i class="fas fa-crown gold" style="font-size:10px"></i> ' : ''}${p.prestige ? `<span class="pmark">${p.prestige}</span>` : ''}${esc(p.name)}${p.reports ? `<span class="rep"><i class="fas fa-flag"></i>${p.reports}</span>` : ''}</span>
                <span>${teamTag(p.team)}</span><span class="ping">${p.ping}</span></div>`).join('') || '<div class="empty">No players</div>'}</div>
        </div>
        <div class="pdet scroll" id="pdet"></div>`;
    const s = $('psearch');
    s.oninput = () => { Admin.search = s.value; const pos = s.selectionStart; adminPlayers(); $('psearch').focus(); $('psearch').setSelectionRange(pos, pos); };
    $('adminMain').querySelectorAll('[data-id]').forEach(r => r.onclick = () => {
        Admin.sel = Number(r.dataset.id); Admin.info = null; Admin.confirm = null; adminPlayers();
        post('admin', { action: 'info', target: Admin.sel });
    });
    adminDetail();
}

function adminDetail() {
    const el = $('pdet'); if (!el) return;
    const i = Admin.info, perms = Admin.d.perms;
    if (!i || i.id !== Admin.sel) { el.innerHTML = '<div class="empty">Select a player</div>'; return; }
    const kd = i.deaths ? (i.kills / i.deaths).toFixed(2) : i.kills;
    const b = (act, icon, label, cls = '') => `<span class="btn ${cls} ${perms[act] ? '' : 'off'}" data-act="${act}"><i class="fas ${icon}"></i>${label}</span>`;
    el.innerHTML = `
        <div class="pcard"><div class="avatar">${esc(i.name[0] || '?')}</div><div>
            <h2 style="font-size:20px">${esc(i.name)} ${i.vip ? '<span class="pill" style="background:rgba(250,204,21,.14);color:var(--gold)">VIP</span>' : ''}
            ${i.prestige ? `<span class="pill" style="background:rgba(168,85,247,.18);color:#c084fc">PRESTIGE ${roman(i.prestige)}</span>` : ''}
            ${i.reports ? `<span class="pill" style="background:rgba(239,68,68,.15);color:#f87171">${i.reports} REPORT${i.reports > 1 ? 'S' : ''}</span>` : ''}</h2>
            <div class="muted" style="font-size:12px;margin-top:3px">ID ${i.id} · ${esc((i.license || '').slice(0, 14))}… · ${teamTag(i.team)} · Level ${i.level} · ${i.ping}ms</div></div></div>
        <div class="kv"><div><small>KILLS (ALL TIME)</small><b>${fmt(i.kills)}</b></div><div><small>K/D</small><b>${kd}</b></div>
            <div><small>PLAYTIME</small><b>${hours(i.playtime)}</b></div><div><small>MONEY</small><b class="t-g">$${fmt(i.money)}</b></div></div>
        <div class="sec">Actions</div>
        <div class="acts">
            ${b('goto', 'fa-location-arrow', 'Goto')}${b('bring', 'fa-magnet', 'Bring')}${b('spectate', 'fa-eye', 'Spectate')}${b('freeze', 'fa-snowflake', 'Freeze')}
            ${b('revive', 'fa-heart', 'Revive')}${b('slay', 'fa-skull', 'Slay')}${b('vip', 'fa-crown', i.vip ? 'Remove VIP' : 'Set VIP')}
            <span class="btn ${perms.money ? '' : 'off'}" data-act="money"><i class="fas fa-dollar-sign"></i>Give money</span>
        </div>
        <div class="form" style="margin-top:8px">
            <label class="field"><small>AMOUNT ($)</small><input id="amt" type="number" min="1" value="1000"></label>
            <label class="field"><small>DURATION (BAN)</small><select id="dur"><option value="1">1 hour</option><option value="24">1 day</option><option value="72">3 days</option><option value="168">7 days</option><option value="0" selected>Permanent</option></select></label>
        </div>
        <div class="sec">Punish</div>
        <label class="field"><small>REASON</small><input id="why" placeholder="Reason shown to the player" value=""></label>
        <div style="display:flex;gap:8px;margin-top:10px">
            <span class="btn ${perms.kick ? '' : 'off'} ${Admin.confirm === 'kick' ? 'confirm' : ''}" style="flex:1" data-act="kick"><i class="fas fa-door-open"></i>${Admin.confirm === 'kick' ? 'Click again to kick' : 'Kick'}</span>
            <span class="btn red ${perms.ban ? '' : 'off'} ${Admin.confirm === 'ban' ? 'confirm' : ''}" style="flex:1" data-act="ban"><i class="fas fa-gavel"></i>${Admin.confirm === 'ban' ? 'Click again to ban' : 'Ban player'}</span>
        </div>`;
    el.querySelectorAll('[data-act]').forEach(btn => btn.onclick = () => {
        const act = btn.dataset.act;
        const reason = ($('why').value || '').trim();
        if (act === 'kick' || act === 'ban') {
            if (Admin.confirm !== act) { Admin.confirm = act; const keep = $('why').value; adminDetail(); $('why').value = keep; return; }
            Admin.confirm = null;
            adminAct(act, i.id, { reason: reason || 'No reason', hours: Number($('dur').value) });
            return;
        }
        if (act === 'money') return adminAct('money', i.id, { amount: Number($('amt').value) });
        adminAct(act, i.id, {});
        if (act === 'vip') setTimeout(() => post('admin', { action: 'info', target: i.id }), 600);
    });
}

function adminReports() {
    const list = Admin.d.reports.filter(r => r.status !== 'closed').sort((a, b) => b.time - a.time);
    $('adminMain').innerHTML = `<div class="pdet scroll"><h2 style="font-size:16px">Open reports</h2><div class="muted" style="font-size:12px;margin:4px 0 14px">Players send these with /report</div>
        ${list.map(r => `<div class="rcard ${r.status}">
            <div class="top"><b>#${r.id}</b><span class="muted">${new Date(r.time * 1000).toLocaleTimeString()}</span>
            <span class="pill" style="background:rgba(249,115,22,.15);color:var(--orange)">${esc(r.reason)}</span>
            ${r.claimedBy ? `<span class="pill" style="background:rgba(59,130,246,.15);color:#60a5fa">${esc(r.claimedBy)}</span>` : ''}</div>
            <p><b>${esc(r.reporter)}</b> [${r.reporterId}] reported <b class="t-r">${esc(r.target)}</b> [${r.targetId}]<br>${esc(r.details) || '<span class="muted">No details</span>'}</p>
            <div class="acts2"><span class="btn" data-r="${r.id}" data-w="goto"><i class="fas fa-location-arrow"></i>Goto player</span>
            <span class="btn" data-r="${r.id}" data-w="view"><i class="fas fa-user"></i>Open player</span>
            ${r.status === 'open' ? `<span class="btn blue" data-r="${r.id}" data-w="claim"><i class="fas fa-hand-paper"></i>Claim</span>` : ''}
            <span class="btn green" data-r="${r.id}" data-w="close"><i class="fas fa-check"></i>Close</span></div></div>`).join('') || '<div class="empty">No open reports 🎉</div>'}</div>`;
    $('adminMain').querySelectorAll('[data-r]').forEach(b => b.onclick = () => {
        const id = Number(b.dataset.r), w = b.dataset.w;
        if (w === 'view') {
            const r = Admin.d.reports.find(x => x.id === id);
            Admin.sel = r.targetId; Admin.tab = 'players'; Admin.info = null; adminRender();
            post('admin', { action: 'info', target: r.targetId });
            return;
        }
        post('admin', { action: 'report', id, what: w });
    });
}

function adminBans() {
    const now = Admin.now || Date.now() / 1000;
    $('adminMain').innerHTML = `<div class="pdet scroll" style="padding:12px 0"><div class="brow" style="font-size:10px;color:var(--muted);font-weight:700;letter-spacing:1px"><span>PLAYER</span><span>BY</span><span>REASON</span><span>EXPIRES</span><span></span></div>
        ${Admin.bans.map(b => {
            const left = b.permanent == 1 ? 'Permanent' : (b.expiration > now ? Math.ceil((b.expiration - now) / 3600) + 'h left' : 'Expired');
            return `<div class="brow"><span>${esc(b.targetName || '—')}</span><span class="muted">${esc(b.sourceName || '—')}</span><span>${esc(b.reason)}</span><span class="${b.permanent == 1 ? 't-r' : ''}">${left}</span>
                <span class="btn ${Admin.d.perms.unban ? '' : 'off'}" data-l="${esc(b.licenseid)}">Unban</span></div>`;
        }).join('') || '<div class="empty">No bans</div>'}</div>`;
    $('adminMain').querySelectorAll('[data-l]').forEach(b => b.onclick = () => {
        adminAct('unban', null, { license: b.dataset.l });
        setTimeout(() => post('admin', { action: 'bans' }), 500);
    });
}

function adminSelf() {
    const s = Admin.d.self || {};
    const row = (k, t, sub) => `<div class="toggle-row ${s[k] ? 'on' : ''}" data-self="${k}"><div>${t}<small>${sub}</small></div><span class="tg"></span></div>`;
    $('adminMain').innerHTML = `<div class="pdet"><h2 style="font-size:16px">Self</h2><div class="muted" style="font-size:12px;margin:4px 0 14px">Needs staff mode ON. Everything is logged.</div>
        ${row('noclip', 'Noclip', 'Fly with W/A/S/D, Space / Ctrl up and down, Shift = faster')}
        ${row('invisible', 'Invisible', 'Other players cannot see you')}
        ${row('god', 'God mode', 'You cannot take damage')}</div>`;
    $('adminMain').querySelectorAll('[data-self]').forEach(r => r.onclick = () => post('admin', { action: 'self', what: r.dataset.self }).then(res => {
        if (res && res.self) { Admin.d.self = res.self; adminSelf(); }
    }));
}

function adminServer() {
    const p = Admin.d.perms;
    $('adminMain').innerHTML = `<div class="pdet"><h2 style="font-size:16px">Server</h2>
        <div class="sec">Announcement</div>
        <label class="field"><small>MESSAGE TO ALL PLAYERS</small><input id="ann" maxlength="200" placeholder="Server restart in 10 minutes…"></label>
        <span class="btn gold ${p.announce ? '' : 'off'}" id="annBtn" style="margin-top:8px"><i class="fas fa-bullhorn"></i>Send announcement</span>
        <div class="sec">Match</div>
        <span class="btn ${p.mapvote ? '' : 'off'}" id="mvBtn"><i class="fas fa-map-marked-alt"></i>Start map vote now</span></div>`;
    $('annBtn').onclick = () => { const t = $('ann').value.trim(); if (t) { adminAct('announce', null, { text: t }); $('ann').value = ''; } };
    $('mvBtn').onclick = () => adminAct('mapvote');
}

/* ================= REPORT ================= */
const Rep = { d: null, target: null, reason: 'Cheating', q: '' };
function reportOpen(d) {
    Rep.d = d; Rep.q = ''; Rep.reason = 'Cheating';
    Rep.target = d.lastKiller ? d.lastKiller.id : null;
    showPanel('report'); reportRender();
}
function reportRender() {
    const d = Rep.d, root = $('report');
    const list = d.players.filter(p => !Rep.q || p.name.toLowerCase().includes(Rep.q.toLowerCase()) || String(p.id) === Rep.q);
    const reasons = ['Cheating', 'Teamkill', 'Toxic', 'Base camping', 'Bug abuse', 'Other'];
    root.innerHTML = hdr('fa-flag', 'var(--orange)', 'Report a player', `Staff online: ${d.staff}`) + `<div class="rbody">
        <div class="sec" style="margin-top:0">Player</div>
        <div class="search"><i class="fas fa-search"></i><input id="rq" placeholder="Search name or ID…" value="${esc(Rep.q)}"></div>
        <div class="plpick scroll">${list.map(p => `<div data-p="${p.id}" class="${p.id === Rep.target ? 'on' : ''}"><span>[${p.id}] ${esc(p.name)}</span>
            <span style="font-size:11px">${teamTag(p.team)}${d.lastKiller && d.lastKiller.id === p.id ? ` <span class="t-r">· killed you ${Math.round(d.lastKiller.ago / 60)} min ago</span>` : ''}</span></div>`).join('') || '<div class="muted">No players</div>'}</div>
        <div class="sec">Reason</div>
        <div class="chips">${reasons.map(r => `<span class="chip ${r === Rep.reason ? 'on' : ''}" data-c="${r}">${r}</span>`).join('')}</div>
        <div class="sec">Details</div>
        <textarea class="ta" id="rd" maxlength="400" placeholder="What happened? Where?"></textarea>
        <div style="display:flex;align-items:center;gap:10px;margin-top:14px">
            <span class="muted" style="font-size:11px"><i class="fas fa-info-circle"></i> ${d.cooldown > 0 ? `Wait ${d.cooldown}s before the next report.` : 'False reports can get you punished. 1 report / 60s.'}</span>
            <span class="btn orange ${Rep.target && d.cooldown <= 0 ? '' : 'off'}" id="rsend" style="margin-left:auto"><i class="fas fa-paper-plane"></i>Send report</span></div></div>`;
    bindClose(root);
    const keep = Rep.details || '';
    $('rd').value = keep; $('rd').oninput = () => Rep.details = $('rd').value;
    const q = $('rq'); q.oninput = () => { Rep.q = q.value; reportRender(); $('rq').focus(); };
    root.querySelectorAll('[data-p]').forEach(e => e.onclick = () => { Rep.target = Number(e.dataset.p); reportRender(); });
    root.querySelectorAll('[data-c]').forEach(e => e.onclick = () => { Rep.reason = e.dataset.c; reportRender(); });
    $('rsend').onclick = () => {
        post('report', { target: Rep.target, reason: Rep.reason, details: Rep.details || '' });
        Rep.details = ''; showPanel(null);
    };
}
let rtTimer;
function reportToast(r) {
    const el = $('reportToast');
    el.innerHTML = `<b><i class="fas fa-flag" style="color:var(--orange)"></i> New report #${r.id}</b>
        <p><b>${esc(r.reporter)}</b> reported <b class="t-r">${esc(r.target)}</b> for <b style="color:var(--orange)">${esc(r.reason)}</b>${r.details ? `<br>"${esc(r.details.slice(0, 90))}${r.details.length > 90 ? '…' : ''}"` : ''}</p>
        <p class="muted" style="font-size:11px"><span class="kbd">F11</span> open admin panel → Reports</p>`;
    el.classList.add('on');
    clearTimeout(rtTimer); rtTimer = setTimeout(() => el.classList.remove('on'), 10000);
}

/* ================= CAREER / PRESTIGE ================= */
const Car = { d: null, tab: 'stats' };
const wName = (w) => String(w || '').replace(/^WEAPON_/, '').replace(/MK2$/, ' Mk II').replace(/_/g, ' ').toLowerCase().replace(/\b\w/g, c => c.toUpperCase());
const wImg = (w) => { w = String(w || ''); return w.replace(/MK2$/, '_MK2').replace(/__/g, '_'); };
function careerOpen(d) { Car.d = d; Car.tab = d.tab || 'stats'; showPanel('career'); careerRender(); }
function careerRender() {
    const d = Car.d, root = $('career'), me = d.me || {};
    const tabs = [['stats', 'My stats'], ['top', 'Top players'], ['prestige', 'Prestige']];
    root.style.borderTopColor = Car.tab === 'prestige' ? 'var(--purple)' : 'var(--blue)';
    root.innerHTML = hdr(Car.tab === 'prestige' ? 'fa-gem' : 'fa-chart-line', Car.tab === 'prestige' ? 'var(--purple)' : 'var(--blue2)', 'Career',
        `${esc(d.name)} · rank #${d.rank} · level ${d.level}${d.prestige ? ' · Prestige ' + roman(d.prestige) : ''}`,
        `<div class="tabs">${tabs.map(([id, l]) => `<span data-t="${id}" class="${Car.tab === id ? 'on' : ''}">${l}</span>`).join('')}</div><span style="margin-left:auto"></span>`) +
        `<div class="cbody" id="cbody"></div>`;
    bindClose(root);
    root.querySelectorAll('[data-t]').forEach(t => t.onclick = () => { Car.tab = t.dataset.t; careerRender(); });
    const body = $('cbody');

    if (Car.tab === 'stats' || Car.tab === 'top') {
        const kd = me.deaths ? (me.kills / me.deaths).toFixed(2) : (me.kills || 0);
        const maxW = Math.max(1, ...(d.weapons || []).map(w => w.kills));
        const top = `<div class="sec" style="margin-top:0">All-time top killers</div>${(d.top || []).map((t, i) => `
            <div class="lb ${t.me ? 'me' : ''}"><span class="r" style="${i === 0 ? 'color:var(--gold)' : i === 1 ? 'color:#d4d4d8' : i === 2 ? 'color:#d97706' : ''}">#${i + 1}</span>
            <span>${t.prestige ? `<span class="pmark">${t.prestige}</span>` : ''}${esc(t.name)}${t.me ? ' (you)' : ''}</span><span>${fmt(t.kills)}</span>
            <span class="muted">${t.deaths ? (t.kills / t.deaths).toFixed(1) : t.kills}</span></div>`).join('') || '<div class="empty">No data yet</div>'}`;
        if (Car.tab === 'top') { body.innerHTML = `<div style="max-width:640px;margin:0 auto">${top}</div>`; return; }
        body.innerHTML = `<div class="cgrid"><div>
            <div class="big"><div><small>TOTAL KILLS</small><b>${fmt(me.kills)}</b></div><div><small>DEATHS</small><b>${fmt(me.deaths)}</b></div>
            <div><small>K/D</small><b class="t-b">${kd}</b></div><div><small>HEADSHOTS</small><b>${fmt(me.headshots)}</b></div>
            <div><small>ASSISTS</small><b>${fmt(me.assists)}</b></div><div><small>MATCHES</small><b>${fmt(me.matches)}</b></div>
            <div><small>WINS</small><b class="t-g">${fmt(me.wins)}</b></div><div><small>PLAYTIME</small><b>${hours(me.playtime)}</b></div>
            <div><small>BEST STREAK</small><b style="color:var(--orange)">${fmt(me.best_streak)}</b></div><div><small>BOUNTIES</small><b>${fmt(me.bounties)}</b></div></div>
            <div class="sec">Most kills by weapon</div>
            ${(d.weapons || []).map(w => `<div class="wbar"><div class="wn"><img src="nui://koth-hud/hud/equiped/${esc(wImg(w.weapon))}.png" onerror="this.remove()"><span>${esc(wName(w.weapon))}</span></div>
                <div class="bar"><span style="width:${Math.round(w.kills / maxW * 100)}%"></span></div><b>${fmt(w.kills)}</b></div>`).join('') || '<div class="muted" style="font-size:12px">Get some kills first!</div>'}
            </div><div>${top}</div></div>`;
        return;
    }

    // prestige
    const p = d.prestige, max = d.prestigeMax, can = d.level >= d.prestigeLevel && p < max;
    const next = Math.min(p + 1, max);
    body.innerHTML = `<div class="pgrid">
        <div class="emblem"><div class="hex ${p ? '' : 'zero'}"><b>${p}</b></div>
            <h2>${p >= max ? 'Max prestige' : `Prestige ${p ? roman(p) : '0'} → ${roman(next)}`}</h2>
            <p>You are level <b style="color:#fff">${d.level}</b> · need level ${d.prestigeLevel}</p>
            <div class="lvlbar"><div class="bar"><span style="width:${Math.min(100, d.level / d.prestigeLevel * 100)}%"></span></div>
            <div style="display:flex;justify-content:space-between;font-size:11px;margin-top:6px" class="muted"><span>Level ${d.level}</span><span>${d.prestigeLevel}</span></div></div>
            <span class="btn purple ${can ? '' : 'off'}" id="presBtn" style="margin-top:18px;width:100%;height:44px;font-size:14px"><i class="fas fa-gem"></i>${p >= max ? 'MAX PRESTIGE' : can ? 'PRESTIGE NOW' : `REACH LEVEL ${d.prestigeLevel}`}</span></div>
        <div><div class="sec" style="margin-top:0">Prestige ranks</div>
            <div class="tiers">${Array.from({ length: max }, (_, i) => i + 1).map(n => `<div class="tier ${n <= p ? 'done' : n === p + 1 ? 'next' : 'lock'}"><span class="m">${n}</span>${roman(n)}</div>`).join('')}</div>
            <div class="sec">Every prestige gives</div>
            <div class="rew"><i class="fas fa-gem"></i>Prestige emblem next to your name on the scoreboard</div>
            <div class="rew"><i class="fas fa-angle-double-up"></i>+${Math.round(d.prestigeBonus * 100)}% XP permanently (stacks: +${Math.round(d.prestigeBonus * 100 * max)}% at Prestige ${roman(max)})</div>
            <div class="rew"><i class="fas fa-gift"></i>$${fmt(d.prestigeMoney)} prestige bonus</div>
            ${(d.killstreaks || []).filter(k => k.prestige).map(k => `<div class="rew"><i class="fas ${esc(k.icon)}"></i>Prestige ${roman(k.prestige)} unlocks the ${esc(k.label)} killstreak</div>`).join('')}
            <div class="warn"><i class="fas fa-exclamation-triangle"></i> Your level goes back to 1. You keep your money, purchased weapons, stats and VIP.</div></div></div>`;
    let armed = false;
    $('presBtn').onclick = () => {
        if (!can) return;
        if (!armed) { armed = true; $('presBtn').innerHTML = '<i class="fas fa-exclamation-triangle"></i>CLICK AGAIN TO CONFIRM'; return; }
        post('prestige');
    };
}

/* ================= KILLSTREAKS ================= */
const KS = { s: null, pick: [] };
function ksOpen(s) { KS.s = s; KS.pick = [...(s.selected || [])]; showPanel('ks'); ksRender(); }
function ksRender() {
    const s = KS.s, root = $('ks'), slots = s.slots || 3;
    root.innerHTML = hdr('fa-fire', 'var(--red)', 'Select killstreaks', `Pick ${slots} · kills without dying unlock them · resets on death · use with <span class="kbd">4</span>`,
        `<span class="pill" style="margin-left:auto;background:rgba(239,68,68,.15);color:#f87171">${KS.pick.length} / ${slots} SELECTED</span>`) +
        `<div class="kgrid">${(s.killstreaks || []).map(k => {
            const lock = (k.prestige || 0) > (s.prestige || 0), on = KS.pick.includes(k.id);
            return `<div class="kcard ${on ? 'on' : ''} ${lock ? 'lock' : ''}" data-k="${k.id}"><span class="kk">${k.kills} KILLS</span>
                <div class="ki"><i class="fas ${esc(k.icon)}"></i></div><h3>${esc(k.label)}</h3><p>${esc(k.text)}${lock ? ` <b class="gold">Prestige ${roman(k.prestige)}</b>` : ''}</p>
                ${on ? '<span class="sel"><i class="fas fa-check"></i> SELECTED</span>' : ''}</div>`;
        }).join('')}</div>
        <div class="kfoot"><span>Your streak now: <b style="color:#fff">${s.streak || 0}</b></span><span class="btn red" id="ksSave"><i class="fas fa-save"></i>Save</span></div>`;
    bindClose(root);
    root.querySelectorAll('[data-k]').forEach(c => c.onclick = () => {
        if (c.classList.contains('lock')) return;
        const id = c.dataset.k;
        if (KS.pick.includes(id)) KS.pick = KS.pick.filter(x => x !== id);
        else if (KS.pick.length < slots) KS.pick.push(id);
        ksRender();
    });
    $('ksSave').onclick = () => { post('ksSelect', { list: KS.pick }); showPanel(null); };
}
function ksHud(s) {
    KS.s = s;
    const map = {}; (s.killstreaks || []).forEach(k => map[k.id] = k);
    const sel = (s.selected || []).map(id => map[id]).filter(Boolean);
    const streak = s.streak || 0, used = s.used || {};
    $('ksHud').innerHTML = sel.map(k => {
        const done = used[k.id], ready = !done && streak >= k.kills;
        return `<div class="kh ${ready ? 'ready' : ''} ${done ? 'used' : ''}"><i class="fas ${esc(k.icon)}"></i><b>${esc(k.label)}</b>
            <div class="p"><span style="width:${Math.min(100, streak / k.kills * 100)}%"></span></div><small>${done ? 'USED' : ready ? 'READY' : `${Math.min(streak, k.kills)} / ${k.kills}`}</small></div>`;
    }).join('');
    const firstReady = sel.find(k => !used[k.id] && streak >= k.kills);
    const tip = $('ksTip');
    if (firstReady) { tip.innerHTML = `<i class="fas fa-fire" style="color:var(--red)"></i> ${esc(firstReady.label)} ready — press <span class="kbd">4</span>`; tip.classList.add('on'); }
    else tip.classList.remove('on');
}

/* ================= BOUNTY ================= */
let bbTimer, bcTimer;
function bountyBoard(list) {
    const el = $('bountyBoard');
    if (!list || !list.length) { el.classList.remove('on'); return; }
    el.innerHTML = `<div class="h"><i class="fas fa-skull-crossbones" style="color:var(--orange)"></i> ACTIVE BOUNTIES</div>` +
        list.slice(0, 5).map(b => `<div class="r"><span class="${TEAM[b.team] ? TEAM[b.team][1] : ''}">${esc(b.name)}</span><span class="str">${b.streak} <i class="fas fa-fire"></i></span><span class="cash">$${fmt(b.amount)}</span></div>`).join('');
    el.classList.add('on');
}
function bountyPlaced(b) {
    const el = $('bountyBanner');
    el.innerHTML = `<div class="skull"><i class="fas fa-skull-crossbones"></i></div><div>
        <b>${b.me ? 'YOU have a bounty' : `BOUNTY on <span class="t-r">${esc(b.name)}</span>`} — <span class="t-g">$${fmt(b.amount)}</span></b>
        <p>${b.streak} kills without dying · ${b.me ? 'stay alive!' : 'kill them to claim the reward'}</p></div>`;
    el.classList.add('on');
    clearTimeout(bbTimer); bbTimer = setTimeout(() => el.classList.remove('on'), 7000);
}
function bountyClaimed(c) {
    if (!c.me) { toast(`${c.killer} claimed the $${fmt(c.amount)} bounty on ${c.victim}`, 'success'); return; }
    const el = $('bountyClaim');
    el.innerHTML = `<h2>BOUNTY CLAIMED!</h2><p>You killed <span class="t-r">${esc(c.victim)}</span> · <b>+$${fmt(c.amount)}</b> · +${c.xp} XP</p>`;
    el.classList.add('on');
    clearTimeout(bcTimer); bcTimer = setTimeout(() => el.classList.remove('on'), 5000);
}

/* ================= messages ================= */
window.addEventListener('message', (e) => {
    const m = e.data || {};
    const d = m.data;
    switch (m.app) {
        case 'admin':
            if (m.action === 'open') adminOpen(d);
            else if (!Admin.d) return;
            else if (m.action === 'players') { Admin.d.players = d.players; Admin.d.reports = d.reports; if (Admin.tab !== 'self' && Admin.tab !== 'server' && Admin.tab !== 'bans') { const keep = document.activeElement && document.activeElement.id; if (keep !== 'why' && keep !== 'amt' && keep !== 'psearch') adminRender(); } }
            else if (m.action === 'info') { Admin.info = d; adminDetail(); }
            else if (m.action === 'bans') { Admin.bans = d.list || []; Admin.now = d.now; if (Admin.tab === 'bans') adminBans(); }
            else if (m.action === 'staffmode') { Admin.d.staffMode = d.on; if (!$('admin').classList.contains('hidden')) adminRender(); }
            break;
        case 'report': if (m.action === 'open') reportOpen(d); break;
        case 'reportToast': reportToast(d); break;
        case 'career': if (m.action === 'open') careerOpen(d); else if (m.action === 'close') showPanel(null); break;
        case 'ks': if (m.action === 'open') ksOpen(d); else if (m.action === 'hud') ksHud(d); break;
        case 'bounty':
            if (m.action === 'board') bountyBoard(d);
            else if (m.action === 'placed') bountyPlaced(d);
            else if (m.action === 'claimed') bountyClaimed(d);
            break;
        case 'toast': toast(d.text, d.kind); break;
        case 'announce': announce(d); break;
        case 'bigmsg': bigmsg(d); break;
    }
});
