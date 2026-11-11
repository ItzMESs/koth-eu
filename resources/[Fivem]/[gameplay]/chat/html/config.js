// KOTH chat config (overrides config.default.js)
window.CONFIG = {
  defaultTemplateId: 'default',
  defaultAltTemplateId: 'defaultAlt',
  templates: {
    // system messages: TriggerClientEvent('chat:addMessage', id, { args = { 'Title', 'text' } })
    'default': '<div class="kmsg sys"><span class="kname">{0}</span> <span class="ktext">{1}</span></div>',
    'defaultAlt': '<div class="kmsg sys"><span class="ktext">{0}</span></div>',
    'print': '<pre>{0}</pre>',
    // player messages (koth-main/server/chat.lua): id, rank, name, message, team, prestige
    'koth': '<div class="kmsg team{4}"><span class="kid">{0}</span><span class="krank {1}">{1}</span><span class="kpres p{5}">P{5}</span><span class="kflag f{6}"><img src="https://flagcdn.com/h20/{6}.png"></span><span class="kname">{2}:</span> <span class="ktext">{3}</span></div>'
  },
  fadeTimeout: 9000,
  suggestionLimit: 5,
  style: {
    display: 'block',
    background: 'rgba(10, 10, 12, 0.55)',
    width: '30%',
    height: '22%',
  },
  styles: {
    display: 'none',
    background: 'rgba(10, 10, 12, 0.55)',
    width: '30%',
    height: '22%',
  }
};
