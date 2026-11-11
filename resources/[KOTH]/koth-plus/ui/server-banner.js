// ============================================================
//  SERVER BANNER — shown on the scoreboard (PLAYER INFO) and on
//  the death screen under "Killed by".
//
//  Put your pictures in koth-plus/ui/img/ (840 x 200 px works best,
//  .png / .jpg / .gif) and list them below. With more than one image
//  they rotate every `rotate` seconds. If an image is missing, a
//  text banner with `title` / `subtitle` is shown instead.
// ============================================================
window.KOTH_SERVER_BANNER = {
    images: [
        'img/banner1.png',
        // 'img/banner2.png',
    ],
    rotate: 8,
    title: 'KOTH EU',
    subtitle: 'discord.gg/yourserver',
};

(function () {
    const C = window.KOTH_SERVER_BANNER;
    const BASE = 'nui://koth-plus/ui/';
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    function fallback(h) {
        return `<div style="position:relative;width:100%;height:100%;overflow:hidden;
            background:repeating-linear-gradient(135deg,rgba(255,255,255,.06) 0 6px,transparent 6px 18px),linear-gradient(120deg,#5b21b6,#1e1b4b);">
            <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#fff;text-shadow:0 2px 6px rgba(0,0,0,.7)">
                <div style="font-size:${Math.round(h * .32)}px;font-weight:900;letter-spacing:2px">${esc(C.title)}</div>
                <div style="margin-top:2px;font-size:${Math.round(h * .14)}px;font-weight:700;opacity:.85">${esc(C.subtitle)}</div>
            </div></div>`;
    }

    // mount(element, height): fills the element with the rotating banner
    function mount(el, h) {
        if (!el) return;
        h = h || 96;
        el.style.height = h + 'px';
        el.style.overflow = 'hidden';
        el.style.position = 'relative';
        el.innerHTML = fallback(h);
        const imgs = (C.images || []).slice();
        if (!imgs.length) return;

        const good = [];
        let checked = 0, idx = 0, timer = null;
        const show = () => {
            if (!good.length) return;
            el.innerHTML = `<img src="${good[idx % good.length]}" style="width:100%;height:100%;object-fit:cover;display:block">`;
            idx++;
        };
        imgs.forEach((src) => {
            const url = /^(https?:|nui:)/.test(src) ? src : BASE + src;
            const im = new Image();
            im.onload = () => { good.push(url); if (++checked === imgs.length) start(); };
            im.onerror = () => { if (++checked === imgs.length) start(); };
            im.src = url;
        });
        function start() {
            if (!good.length) return;
            show();
            clearInterval(el._kbTimer);
            if (good.length > 1) el._kbTimer = setInterval(show, (C.rotate || 8) * 1000);
        }
    }

    window.KothServerBanner = { mount };
})();
