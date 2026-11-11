// Player banners (calling cards). Shared by koth-plus, koth-leadboard and the
// koth-main death screen (loaded with nui://koth-plus/ui/banners.js).
// Unlock rules are checked on the server (koth-main/server/stats.lua).
(function () {
    const stripes = (c, a = .07) => `repeating-linear-gradient(135deg, rgba(255,255,255,${a}) 0 6px, transparent 6px 18px)`;
    const dots = (a = .12) => `radial-gradient(rgba(255,255,255,${a}) 1px, transparent 1.5px) 0 0/10px 10px`;
    const camo = (a, b) => `radial-gradient(circle at 20% 30%, ${a} 0 18%, transparent 19%), radial-gradient(circle at 70% 60%, ${a} 0 22%, transparent 23%), radial-gradient(circle at 45% 85%, ${b} 0 15%, transparent 16%), radial-gradient(circle at 85% 15%, ${b} 0 14%, transparent 15%)`;

    const LIST = [
        { id: 'recruit',    name: 'Recruit',     icon: 'fa-user-shield', color: '#cbd5e1', bg: `${stripes()}, linear-gradient(120deg, #1f2937, #0f172a)`,                         unlock: {} },
        { id: 'desert',     name: 'Desert Storm', icon: 'fa-sun',        color: '#fde68a', bg: `${dots(.1)}, linear-gradient(120deg, #b45309, #78350f)`,                          unlock: { level: 10 } },
        { id: 'nightops',   name: 'Night Ops',   icon: 'fa-moon',        color: '#93c5fd', bg: `${stripes('#fff', .05)}, linear-gradient(120deg, #1e3a8a, #020617)`,             unlock: { level: 25 } },
        { id: 'jungle',     name: 'Jungle',      icon: 'fa-leaf',        color: '#bbf7d0', bg: `${camo('#14532d', '#3f6212')}, linear-gradient(120deg, #166534, #1a2e05)`,       unlock: { level: 40 } },
        { id: 'arctic',     name: 'Arctic',      icon: 'fa-snowflake',   color: '#e0f2fe', bg: `${dots(.25)}, linear-gradient(120deg, #0ea5e9, #0c4a6e)`,                         unlock: { level: 60 } },
        { id: 'inferno',    name: 'Inferno',     icon: 'fa-fire',        color: '#fed7aa', bg: `${stripes('#fff', .06)}, linear-gradient(120deg, #dc2626, #7c2d12)`,             unlock: { kills: 1000 } },
        { id: 'headhunter', name: 'Headhunter',  icon: 'fa-skull',       color: '#fca5a5', bg: `${stripes('#f00', .08)}, linear-gradient(120deg, #111111, #450a0a)`,             unlock: { kills: 5000 } },
        { id: 'gold',       name: 'VIP Gold',    icon: 'fa-crown',       color: '#fff7cc', bg: `${stripes('#fff', .12)}, linear-gradient(120deg, #ca8a04, #713f12)`,             unlock: { vip: true } },
        { id: 'neon',       name: 'Neon',        icon: 'fa-bolt',        color: '#f0abfc', bg: `${dots(.15)}, linear-gradient(120deg, #6d28d9, #1e1b4b)`,                         unlock: { prestige: 1 } },
        { id: 'diamond',    name: 'Diamond',     icon: 'fa-gem',         color: '#a5f3fc', bg: `${stripes('#fff', .1)}, linear-gradient(120deg, #7c3aed, #0891b2)`,              unlock: { prestige: 5 } },
    ];
    const BY = {};
    LIST.forEach(b => BY[b.id] = b);

    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    function unlockText(u) {
        if (!u || (!u.level && !u.kills && !u.prestige && !u.vip)) return 'Default';
        if (u.vip) return 'VIP only';
        if (u.prestige) return `Prestige ${u.prestige}`;
        if (u.level) return `Level ${u.level}`;
        if (u.kills) return `${Number(u.kills).toLocaleString('en-US')} kills`;
        return '';
    }

    // name / sub are optional text shown on the left of the banner
    function render(id, opts = {}) {
        const b = BY[id] || BY.recruit;
        const h = opts.height || 96;
        const name = opts.name ? `<div style="font-size:${Math.round(h * .24)}px;font-weight:800;line-height:1.1;text-shadow:0 2px 6px rgba(0,0,0,.7);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(opts.name)}</div>` : '';
        const sub = opts.sub ? `<div style="margin-top:3px;font-size:${Math.round(h * .13)}px;font-weight:700;letter-spacing:1px;opacity:.85;text-transform:uppercase">${esc(opts.sub)}</div>` : '';
        return `<div class="kbanner" style="position:relative;width:100%;height:${h}px;overflow:hidden;background:${b.bg};border:1px solid rgba(255,255,255,.12);box-shadow:inset 0 0 0 1px rgba(0,0,0,.4)">
            <i class="fas ${b.icon}" style="position:absolute;right:-${Math.round(h * .1)}px;top:50%;transform:translateY(-50%) rotate(-12deg);font-size:${Math.round(h * 1.25)}px;color:${b.color};opacity:.16"></i>
            <i class="fas ${b.icon}" style="position:absolute;right:${Math.round(h * .3)}px;top:50%;transform:translateY(-50%);font-size:${Math.round(h * .5)}px;color:${b.color};filter:drop-shadow(0 3px 6px rgba(0,0,0,.6))"></i>
            <div style="position:absolute;left:${Math.round(h * .22)}px;right:${Math.round(h * 1.1)}px;top:50%;transform:translateY(-50%);color:#fff">${name}${sub}</div>
        </div>`;
    }

    window.KothBanners = { list: LIST, get: (id) => BY[id] || BY.recruit, render, unlockText };
})();
