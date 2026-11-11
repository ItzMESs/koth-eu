// KOTH map vote UI
// Messages from client.lua:
//   open   { data }  - show the vote (data = server payload)
//   update { data }  - live counts
//   voted  { id }    - server confirmed this player's vote
//   banner { kind }  - "vote started" banner (no focus)
//   result { map }   - vote closed, next map decided

const RESOURCE = 'koth-mapvote';
const vote   = document.getElementById('vote');
const cards  = document.getElementById('cards');
const banner = document.getElementById('banner');

let state = { maps: [], total: 0, players: 0, myVote: null, active: false, closed: false, winner: null };
let bannerTimer = null;

const post = (name, body) =>
    fetch(`https://${RESOURCE}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).catch(() => {});

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const slug = (s) => String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const initials = (s) => String(s).split(/\s+/).map(w => w[0]).join('').slice(0, 3).toUpperCase();

/* ---------------- render ---------------- */

function apply(data) {
    if (!data) return;
    state.maps = data.maps || state.maps;
    state.total = data.total ?? state.total;
    state.players = data.players ?? state.players;
    state.active = data.active ?? state.active;
    state.closed = data.closed ?? state.closed;
    state.winner = data.winner ?? state.winner;
    state.current = data.current ?? state.current;
    if (data.myVote !== undefined && data.myVote !== null) state.myVote = data.myVote;
    state.leadTeam = data.leadTeam ?? state.leadTeam;
    state.leadPoints = data.leadPoints ?? state.leadPoints;
    render();
}

function render() {
    const maxVotes = Math.max(0, ...state.maps.map(m => m.votes));
    const total = state.maps.reduce((a, m) => a + m.votes, 0);

    cards.innerHTML = '';
    state.maps.forEach((m, i) => {
        const pct = total ? Math.round(m.votes / total * 100) : 0;
        const isLead = maxVotes > 0 && m.votes === maxVotes;
        const isMine = state.myVote === m.id;
        const isWinner = state.closed && state.winner === m.name;

        let tag = '';
        if (isWinner) tag = 'NEXT MAP';
        else if (isMine) tag = 'YOUR VOTE';
        else if (state.current === m.name) tag = 'CURRENT';

        const el = document.createElement('div');
        el.className = 'card' + (isLead ? ' lead' : '') + (isMine ? ' mine' : '') + (isWinner ? ' winner' : '');
        // image is optional: ui/img/<slug>.jpg or .png
        el.style.backgroundImage = `url('img/${slug(m.name)}.jpg'), url('img/${slug(m.name)}.png')`;
        el.innerHTML = `
            <div class="ph">${esc(initials(m.name))}</div>
            <div class="key">${i < 10 ? (i + 1) % 10 : ''}</div>
            ${tag ? `<div class="tag">${tag}</div>` : ''}
            <div class="body">
                <div class="name">${esc(m.name)}${isLead ? '<span class="crown"><i class="fas fa-crown"></i></span>' : ''}</div>
                <div class="bar"><span style="width:${pct}%"></span></div>
                <div class="votes"><span>${m.votes} vote${m.votes === 1 ? '' : 's'}</span><span class="pct">${pct}%</span></div>
            </div>`;
        el.addEventListener('click', () => castVote(m.id));
        cards.appendChild(el);
    });

    document.getElementById('total').textContent = state.total;
    document.getElementById('players').textContent = state.players;

    const mine = state.maps.find(m => m.id === state.myVote);
    document.getElementById('mine').textContent = mine ? `Your vote: ${mine.name}` : 'You have not voted yet';

    const lp = Math.max(0, Math.min(100, Number(state.leadPoints) || 0));
    document.getElementById('leadPoints').textContent = lp;
    document.getElementById('leadBar').style.width = `${lp}%`;
    const lt = document.getElementById('leadTeam');
    lt.textContent = state.leadTeam ? String(state.leadTeam).toUpperCase() : '-';
    lt.className = `team ${state.leadTeam || ''}`;

    vote.classList.toggle('closed', !!state.closed);
    document.getElementById('title').textContent = state.closed
        ? `Next map: ${state.winner || 'Random'}`
        : 'Vote for the next map';
    document.getElementById('subtitle').textContent = state.closed
        ? 'Voting is closed'
        : 'Voting closes when a team reaches 100 points';
}

/* ---------------- actions ---------------- */

function castVote(id) {
    if (!state.active || state.closed) return;
    state.myVote = id;          // optimistic, server confirms with "voted"
    render();
    post('vote', { id });
}

function close() {
    vote.classList.remove('open');
    post('close');
}

function showBanner(html, ms) {
    banner.innerHTML = html;
    banner.classList.add('show');
    clearTimeout(bannerTimer);
    bannerTimer = setTimeout(() => banner.classList.remove('show'), ms);
}

document.getElementById('closebtn').addEventListener('click', close);

document.addEventListener('keydown', (e) => {
    if (!vote.classList.contains('open')) return;
    if (e.key === 'Escape') return close();
    if (/^[0-9]$/.test(e.key)) {
        const idx = e.key === '0' ? 9 : Number(e.key) - 1;
        if (state.maps[idx]) castVote(state.maps[idx].id);
    }
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    switch (d.action) {
        case 'open':
            apply(d.data);
            vote.classList.add('open');
            break;
        case 'update':
            apply(d.data);
            break;
        case 'voted':
            state.myVote = d.id;
            render();
            break;
        case 'banner':
            showBanner('<i class="fas fa-map-marked-alt"></i> Map vote started — type <span class="kbd">/mapvote</span> to vote', 12000);
            break;
        case 'result':
            state.closed = true;
            state.active = false;
            state.winner = d.map || null;
            render();
            showBanner(`<i class="fas fa-flag-checkered"></i> Next map: <b>${esc(d.map || 'Random')}</b>`, 15000);
            break;
    }
});
