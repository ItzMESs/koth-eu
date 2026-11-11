// "Repurchase Loadout?" popup shown after respawning (see client/client.lua)
(function () {
    const box = document.getElementById('rebuy');
    const slotsEl = document.getElementById('rebuySlots');
    const buyBtn = document.getElementById('rebuyBuy');
    const cancelBtn = document.getElementById('rebuyCancel');
    const timerEl = document.getElementById('rebuyTimer');
    const errEl = document.getElementById('rebuyError');
    let timer = null;

    const post = (name) => fetch(`https://koth-weaponshop/${name}`, { method: 'POST', body: '{}' })
        .then(r => r.json()).catch(() => ({}));
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    function slotEl(n, s) {
        const el = document.createElement('div');
        el.className = 'rb-slot';
        el.innerHTML = `<span class="n">${n}</span>`;
        if (!s) return el;

        if (s.owned) el.insertAdjacentHTML('beforeend', '<span class="own">OWNED</span>');
        // white silhouettes from koth-hud, fall back to the shop picture
        const img = document.createElement('img');
        img.src = `nui://koth-hud/hud/equiped/${s.id}.png`;
        img.onerror = () => {
            if (s.thumb && !img.dataset.fallback) { img.dataset.fallback = '1'; img.src = `content/item_images/${s.thumb}`; }
            else img.style.display = 'none';
        };
        el.appendChild(img);
        el.insertAdjacentHTML('beforeend',
            `<span class="lbl">${esc(s.name)}${s.price ? ` · $${Number(s.price).toLocaleString('en-US')}` : ''}</span>`);
        return el;
    }

    function open(d) {
        const bySlot = {};
        (d.slots || []).forEach(s => { bySlot[s.slot] = s; });
        slotsEl.innerHTML = '';
        [1, 2, 3, 4].forEach(n => slotsEl.appendChild(slotEl(n, bySlot[n])));

        document.getElementById('rebuyClass').textContent = `${d.class} Class`;
        const total = Number(d.total) || 0;
        buyBtn.textContent = total ? `BUY: $${total.toLocaleString('en-US')}` : 'TAKE (FREE)';
        const cantPay = Number(d.money) < total;
        buyBtn.classList.toggle('disabled', cantPay);
        errEl.textContent = cantPay ? 'Not enough money!' : '';
        box.classList.add('open');

        let left = Number(d.timeout) || 20;
        timerEl.textContent = `${left}s`;
        clearInterval(timer);
        timer = setInterval(() => {
            left--;
            timerEl.textContent = `${left}s`;
            if (left <= 0) { clearInterval(timer); cancel(); }
        }, 1000);
    }

    function hide() {
        clearInterval(timer);
        box.classList.remove('open');
    }

    function cancel() { hide(); post('repurchaseCancel'); }

    buyBtn.onclick = async () => {
        if (buyBtn.classList.contains('disabled')) return;
        const r = await post('repurchaseBuy');
        if (r && r.error) { errEl.textContent = r.error; return; }
        hide();
    };
    cancelBtn.onclick = cancel;
    document.addEventListener('keydown', (e) => {
        if (!box.classList.contains('open')) return;
        if (e.key === 'Escape') cancel();
        if (e.key === 'Enter') buyBtn.click();
    });

    window.addEventListener('message', (e) => {
        const d = e.data || {};
        if (d.type === 'repurchase') open(d);
        if (d.type === 'repurchaseClose') hide();
    });
})();
