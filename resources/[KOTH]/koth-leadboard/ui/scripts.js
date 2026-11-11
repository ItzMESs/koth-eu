// KOTH scoreboard (hold TAB)
// Messages from client.lua:
//   { action: 'update', players: [...], selfId }   players = PlayerDataInfo sorted by score
//   { action: 'show' } / { action: 'hide' }

const TEAMS = [
    { color: 'blue',  label: 'BLUFOR' },
    { color: 'red',   label: 'REDFOR' },
    { color: 'green', label: 'INDEPENDENT' },
];
const MIN_ROWS = 8;   // empty striped rows so the tables keep their shape

const board = document.getElementById('board');
const tables = document.getElementById('tables');

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const n = (v) => Number(v) || 0;
const kd = (k, d) => (n(d) === 0 ? n(k) : n(k) / n(d)).toFixed(2);
const set = (id, v) => { document.getElementById(id).textContent = v; };

// build the 3 tables once
TEAMS.forEach(t => {
    const sec = document.createElement('section');
    sec.className = `team-table ${t.color}`;
    sec.innerHTML = `
        <div class="bar ${t.color} cols">
            <span class="c-uid">UID</span>
            <span class="c-name">PLAYER</span>
            <span class="c-num"><i class="fas fa-crown"></i> SCORE</span>
            <span class="c-num"><i class="fas fa-skull"></i> KILLS</span>
            <span class="c-num"><i class="fas fa-cross"></i> DEATH</span>
            <span class="c-num"><i class="fas fa-hands-helping"></i> ASSIST</span>
            <span class="c-num"><i class="fas fa-crosshairs"></i> K/D</span>
        </div>
        <div class="rows" id="rows-${t.color}"></div>`;
    tables.appendChild(sec);
});

function render(players, selfId) {
    players = Array.isArray(players) ? players : Object.values(players || {});

    TEAMS.forEach(t => {
        const list = players.filter(p => (p.color || p.team) === t.color);
        let html = '';
        list.forEach(p => {
            html += `<div class="row${p.id == selfId ? ' self' : ''}">
                <span class="c-uid">${esc(p.id)}</span>
                <span class="c-name">${p.prestige ? `<span class="pmark" title="Prestige ${p.prestige}">${p.prestige}</span>` : ''}${p.vip ? '<i class="fas fa-crown vip" title="VIP"></i>' : ''}${esc(p.name)}</span>
                <span class="c-num">${n(p.score)}</span>
                <span class="c-num">${n(p.kill)}</span>
                <span class="c-num">${n(p.death)}</span>
                <span class="c-num">${n(p.assist)}</span>
                <span class="c-num">${kd(p.kill, p.death)}</span>
            </div>`;
        });
        for (let i = list.length; i < MIN_ROWS; i++) html += '<div class="row empty"></div>';
        document.getElementById(`rows-${t.color}`).innerHTML = html;
    });

    // team summary
    document.getElementById('teamSummary').innerHTML = TEAMS.map(t => {
        const list = players.filter(p => (p.color || p.team) === t.color);
        const kills = list.reduce((a, p) => a + n(p.kill), 0);
        const score = list.reduce((a, p) => a + n(p.score), 0);
        return `<div class="ts ${t.color}">
            <span class="ts-name">${t.label}</span>
            <span><i class="fas fa-user"></i> ${list.length}</span>
            <span><i class="fas fa-skull"></i> ${kills}</span>
            <span><i class="fas fa-crown"></i> ${score}</span>
        </div>`;
    }).join('');

    // self
    const idx = players.findIndex(p => p.id == selfId);
    const me = players[idx];
    set('meTotal', players.length);
    if (!me) return;
    const team = TEAMS.find(t => t.color === (me.color || me.team));
    set('meName', me.name);
    const tag = document.getElementById('meTeam');
    tag.textContent = team ? team.label : '-';
    tag.className = `team-tag ${team ? team.color : ''}`;
    set('meRank', `#${idx + 1}`);
    set('meKills', n(me.kill));
    set('meDeaths', n(me.death));
    set('meAssists', n(me.assist));
    set('meScore', n(me.score));
    set('meKd', kd(me.kill, me.death));
    set('meMoney', `$${n(me.money).toLocaleString('en-US')}`);
    const bkey = `${me.banner}|${me.name}|${me.prestige}`;
    const mb = document.getElementById('meBanner');
    if (window.KothBanners && mb.dataset.k !== bkey) {
        mb.dataset.k = bkey;
        mb.innerHTML = window.KothBanners.render(me.banner, { name: me.name, sub: me.prestige ? `Prestige ${me.prestige}` : (team ? team.label : ''), height: 90 });
    }
}

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'show') board.classList.add('open');
    if (d.action === 'hide') board.classList.remove('open');
    if (d.action === 'update') render(d.players, d.selfId);
});
