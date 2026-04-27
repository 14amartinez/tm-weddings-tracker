/**
 * tmw-core.js
 * TM Weddings — Shared Configuration & Utilities
 * All dashboards import this file. Change here = changes everywhere.
 */

// ── CONFIG ──────────────────────────────────────────────
const TMW = {
  supabase: {
    url: 'https://rafygjaemcjhnououmwn.supabase.co',
    key: 'sb_publishable_2rv2vfk2vKGFrd36RdVb6g_RaJWQSCp',
  },
  emailjs: {
    publicKey: '3EteBapWG4a_hy5ol',
    serviceId:  'service_qoodzdb',
    templateId: 'template_p1hyj87',
  },
  admin: {
    password: 'Post-Production_2026!',
  },
  notify: {
    tony:  'tonyellismartinez@gmail.com',
    brynn: 'brynn.weller95@gmail.com',
    lexi:  'leximartinez43@gmail.com',
  },
  editors: ['Tony','Lexi','Zyara','Nick','Nathan','Luke','Zach'],
  photoEditors: ['Tony','Brynn'],
  teamMembers: ['Tony','Brynn','Lexi','Zyara','Nick','Nathan','Luke','Zach','PJ','Nolan','Isabella','Bella','Kaitlyn','Chris','Dylan'],
  shooterRoles: [
    { key: 'leadPhoto',       label: 'Lead Photo' },
    { key: 'secondPhoto',     label: '2nd Photo' },
    { key: 'photoShadow',     label: 'Photo Shadow' },
    { key: 'leadVideo',       label: 'Lead Video' },
    { key: 'secondVideo',     label: '2nd Video' },
    { key: 'videoShadow',     label: 'Video Shadow' },
    { key: 'contentCreator',  label: 'Content Creator' },
    { key: 'bts',             label: 'BTS' },
  ],
  videoStages: {
    keys:   ['qnas','obtained','sync','edit','color','deliver'],
    labels: ['Files on QNAS','Files obtained','Sync/sift','Edit','Color','Deliver'],
  },
  photoStages: {
    keys:   ['qnas','obtained','cull','edit','export','deliver'],
    labels: ['Files on QNAS','Files obtained','Cull','Edit','Export','Deliver'],
  },
  bookStages: {
    keys:   ['qnas','obtained','selections','design','ordered'],
    labels: ['Files on QNAS','Files obtained','Selections submitted','Design stage','Order placed'],
  },
  statusCycle: ['not-started','in-progress','complete'],
};

// ── SUPABASE FETCH ───────────────────────────────────────
async function sbFetch(path, opts = {}) {
  const res = await fetch(TMW.supabase.url + '/rest/v1/' + path, {
    ...opts,
    headers: {
      'apikey':        TMW.supabase.key,
      'Authorization': 'Bearer ' + TMW.supabase.key,
      'Content-Type':  'application/json',
      'Prefer':        'return=representation',
      ...(opts.headers || {}),
    },
  });
  if (!res.ok) { const t = await res.text(); throw new Error(t); }
  const t = await res.text();
  return t ? JSON.parse(t) : null;
}

// ── EMAIL NOTIFICATION ───────────────────────────────────
function tmwInitEmail() {
  if (typeof emailjs !== 'undefined') emailjs.init(TMW.emailjs.publicKey);
}

async function tmwNotify(params) {
  // Always notify Tony + Brynn
  const recipients = [TMW.notify.tony, TMW.notify.brynn];
  // Add assigned editor if they have an email
  const editorEmails = {
    Tony:  TMW.notify.tony,
    Brynn: TMW.notify.brynn,
    Lexi:  TMW.notify.lexi,
  };
  if (params.editor && editorEmails[params.editor]) {
    const editorEmail = editorEmails[params.editor];
    if (!recipients.includes(editorEmail)) recipients.push(editorEmail);
  }
  const payload = {
    client:      params.client      || '',
    deliverable: params.deliverable || '',
    stage:       params.stage       || '',
    editor:      params.editor      || 'Unassigned',
    time:        new Date().toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }),
  };
  try {
    for (const email of recipients) {
      await emailjs.send(TMW.emailjs.serviceId, TMW.emailjs.templateId, { ...payload, to_email: email });
    }
    tmwToast('✓ Notification sent');
  } catch (e) {
    console.warn('Notification failed:', e);
  }
}

// ── ASSIGNMENT NOTIFICATION ──────────────────────────────
async function tmwNotifyAssignment(client, deliverable, editor) {
  if (!editor) return;
  const editorEmails = { Tony: TMW.notify.tony, Brynn: TMW.notify.brynn, Lexi: TMW.notify.lexi };
  const email = editorEmails[editor];
  if (!email) return;
  const payload = {
    client, deliverable,
    stage:  'New assignment',
    editor,
    time:   new Date().toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }),
    to_email: email,
  };
  try {
    await emailjs.send(TMW.emailjs.serviceId, TMW.emailjs.templateId, payload);
    // Also notify Tony
    await emailjs.send(TMW.emailjs.serviceId, TMW.emailjs.templateId, { ...payload, to_email: TMW.notify.tony });
  } catch (e) {
    console.warn('Assignment notification failed:', e);
  }
}

// ── ADMIN ────────────────────────────────────────────────
function tmwIsAdmin(sessionKey) {
  return sessionStorage.getItem(sessionKey) === '1';
}
function tmwSetAdmin(sessionKey, val) {
  if (val) sessionStorage.setItem(sessionKey, '1');
  else sessionStorage.removeItem(sessionKey);
}
function tmwCheckAdminPw(input) {
  return input === TMW.admin.password;
}

// ── SYNC STATUS ──────────────────────────────────────────
function tmwSetSyncStatus(dotId, textId, state, text) {
  const dot  = document.getElementById(dotId);
  const span = document.getElementById(textId);
  if (dot)  dot.className  = 'sync-dot ' + state;
  if (span) span.textContent = text;
}

// ── TOAST ────────────────────────────────────────────────
function tmwToast(msg) {
  let t = document.getElementById('tmw-toast');
  if (!t) {
    t = document.createElement('div');
    t.id = 'tmw-toast';
    t.style.cssText = 'position:fixed;bottom:24px;right:24px;background:#1a1714;color:#fff;font-size:12px;padding:10px 16px;border-radius:8px;z-index:999;opacity:0;transition:opacity 0.3s;pointer-events:none;font-family:DM Sans,sans-serif;';
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.style.opacity = '1';
  clearTimeout(t._timeout);
  t._timeout = setTimeout(() => { t.style.opacity = '0'; }, 3200);
}

// ── DATE HELPERS ─────────────────────────────────────────
function tmwNextMonday(dateStr) {
  const d = new Date(dateStr + 'T12:00:00');
  const day = d.getDay();
  const diff = day === 1 ? 7 : (8 - day) % 7;
  d.setDate(d.getDate() + diff);
  return d.toISOString().split('T')[0];
}
function tmwAddWeeks(dateStr, weeks) {
  const d = new Date(dateStr + 'T12:00:00');
  d.setDate(d.getDate() + weeks * 7);
  return d.toISOString().split('T')[0];
}
function tmwRisk(dateStr) {
  if (!dateStr) return 'ok';
  const now = new Date(); now.setHours(0, 0, 0, 0);
  const diff = Math.round((new Date(dateStr + 'T12:00:00') - now) / 86400000);
  if (diff < 0)  return 'overdue';
  if (diff <= 5) return 'at-risk';
  return 'ok';
}
function tmwFmtDate(d, opts) {
  if (!d) return '—';
  return new Date(d + 'T12:00:00').toLocaleDateString('en-US', opts || { month: 'short', day: 'numeric' });
}

// ── PHOTO STAGE HELPERS ──────────────────────────────────
function tmwIsBookDel(name) {
  return name && name.toLowerCase().includes('photo book');
}
function tmwGetStageKeys(name) {
  return tmwIsBookDel(name) ? TMW.bookStages.keys : TMW.photoStages.keys;
}
function tmwGetStageLabels(name) {
  return tmwIsBookDel(name) ? TMW.bookStages.labels : TMW.photoStages.labels;
}
function tmwMakeStages(name) {
  const s = {};
  tmwGetStageKeys(name).forEach(k => s[k] = 'not-started');
  return s;
}

console.log('%c TMW Core loaded', 'color:#4aacac;font-weight:600;');
