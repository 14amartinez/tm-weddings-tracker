/**
 * TMW Auth Guard — centralized, role-aware, hybrid-cached.
 *
 * USAGE:
 *   <script src="/tmw-auth.js" data-required-role="any"></script>
 *
 *   data-required-role values:
 *     "any"     — any logged-in approved team member (default if omitted)
 *     "owner"   — owner role only
 *     "admin"   — owner OR admin
 *     "editor"  — owner, admin, OR editor
 *     "shooter" — owner, admin, OR shooter
 *     "post-production" — owner, admin, OR editor (semantic alias)
 *     "shoot"   — owner, admin, OR shooter (semantic alias)
 *     "marketing" — owner OR marketing (external partner role)
 *
 * AFTER LOAD, GLOBALS:
 *   window.TMW_USER           — { email, name, roles: [], isOwner, isAdmin, isEditor, isShooter }
 *   window.TMW_JWT            — User's Supabase access token (for RLS-aware API calls)
 *   window.tmwSbFetch(p, o)   — Authenticated Supabase REST helper (uses JWT)
 *   window.tmwSignOut()       — clears session, redirects to login
 *   window.tmwHasRole(role)   — returns boolean
 *   window.tmwCanAccess(area) — checks against required-role semantics
 *
 * Hybrid cache strategy:
 *   1. On script load, immediately check localStorage cache (TTL 1 hour)
 *   2. If cache valid → use it, but fire background refresh
 *   3. If cache stale or missing → fetch from Supabase synchronously
 *   4. If Supabase fetch fails → fall back to hardcoded EMERGENCY_OWNERS list (owners only)
 *
 * The hardcoded fallback ensures owners can always log in even if Supabase is down.
 *
 * EXTERNAL ROLE PATH-RESTRICTION:
 *   Users whose only role is 'marketing' (or any non-internal role) are
 *   path-restricted to /marketing/*. They cannot navigate to internal
 *   wedding/post-production/dashboard routes even if those pages use a
 *   permissive 'any' guard. Internal roles are: owner, admin, editor, shooter.
 */

(function(){
  'use strict';

  // ─── CONFIG ───
  var SUPABASE_URL = 'https://rafygjaemcjhnououmwn.supabase.co';
  var SUPABASE_KEY = 'sb_publishable_2rv2vfk2vKGFrd36RdVb6g_RaJWQSCp';
  var SESSION_KEY  = 'sb-rafygjaemcjhnououmwn-auth-token';
  var TEAM_CACHE_KEY = 'tmw_team_cache_v1';
  var TEAM_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

  // Internal team roles — users with at least one of these can access the
  // full portal. Users with only external roles (marketing, etc.) are
  // path-restricted to their dedicated subdirectory.
  var INTERNAL_ROLES = ['owner', 'admin', 'editor', 'shooter'];

  // External role → allowed path prefix. Users whose only role is the key
  // are restricted to navigating within the value's path.
  var EXTERNAL_ROLE_PATHS = {
    'marketing': '/marketing'
  };

  // Emergency fallback — used only if Supabase fetch fails AND no valid cache.
  // Just owners, so the people who can fix things can always log in.
  var EMERGENCY_OWNERS = [
    {email:'tonyellismartinez@gmail.com', name:'Tony Martinez', roles:['owner'], active:true},
    {email:'brynn.weller95@gmail.com',    name:'Brynn Weller',  roles:['owner'], active:true}
  ];

  // ─── ROLE HIERARCHY ───
  var AREA_ACCESS = {
    'any':             function(roles){ return roles.length > 0; },
    'owner':           function(roles){ return roles.indexOf('owner') !== -1; },
    'admin':           function(roles){ return roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1; },
    'editor':          function(roles){ return roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1 || roles.indexOf('editor') !== -1; },
    'shooter':         function(roles){ return roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1 || roles.indexOf('shooter') !== -1; },
    'post-production': function(roles){ return roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1 || roles.indexOf('editor') !== -1; },
    'shoot':           function(roles){ return roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1 || roles.indexOf('shooter') !== -1; },
    'marketing':       function(roles){ return roles.indexOf('owner') !== -1 || roles.indexOf('marketing') !== -1; }
  };

  // ─── EXPOSE SIGN OUT IMMEDIATELY ───
  window.tmwSignOut = function(){
    try {
      for (var i = localStorage.length - 1; i >= 0; i--) {
        var k = localStorage.key(i);
        if (k && (k.indexOf('sb-') === 0 || k.indexOf('supabase') === 0 || k === TEAM_CACHE_KEY)) {
          localStorage.removeItem(k);
        }
      }
      sessionStorage.clear();
    } catch(e) {}
    window.location.replace('/login.html');
  };

  // ─── CENTRALIZED SUPABASE FETCH (RLS-AWARE) ───
  // Uses the user's JWT for authenticated requests so RLS policies see the
  // signed-in user. Falls back to publishable key if called before the user
  // is authenticated (e.g. login page).
  window.tmwSbFetch = async function(path, opts){
    opts = opts || {};
    var token = window.TMW_JWT || SUPABASE_KEY;
    var headers = {
      'apikey': SUPABASE_KEY,
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    };
    if (opts.headers) {
      for (var h in opts.headers) {
        if (Object.prototype.hasOwnProperty.call(opts.headers, h)) {
          headers[h] = opts.headers[h];
        }
      }
    }
    var fetchOpts = {};
    for (var k in opts) {
      if (Object.prototype.hasOwnProperty.call(opts, k) && k !== 'headers') {
        fetchOpts[k] = opts[k];
      }
    }
    fetchOpts.headers = headers;
    var res = await fetch(SUPABASE_URL + '/rest/v1/' + path, fetchOpts);
    if (!res.ok) {
      var t = await res.text();
      throw new Error(t || ('HTTP ' + res.status));
    }
    var body = await res.text();
    return body ? JSON.parse(body) : null;
  };

  // ─── READ SESSION FROM LOCALSTORAGE ───
  function readSession(){
    var raw = null;
    try { raw = localStorage.getItem(SESSION_KEY); } catch(e) { return null; }
    if (!raw) return null;
    try {
      var s = JSON.parse(raw);
      if (!s || !s.user || !s.user.email) return null;
      var notExpired = !s.expires_at || (s.expires_at * 1000 > Date.now());
      if (!notExpired) {
        try { localStorage.removeItem(SESSION_KEY); } catch(e) {}
        return null;
      }
      return s;
    } catch(e) {
      try { localStorage.removeItem(SESSION_KEY); } catch(e2) {}
      return null;
    }
  }

  // ─── TEAM CACHE ───
  function readTeamCache(){
    try {
      var raw = localStorage.getItem(TEAM_CACHE_KEY);
      if (!raw) return null;
      var c = JSON.parse(raw);
      if (!c || !c.cachedAt || !Array.isArray(c.members)) return null;
      var age = Date.now() - c.cachedAt;
      return { members: c.members, fresh: age < TEAM_CACHE_TTL_MS, age: age };
    } catch(e) { return null; }
  }

  function writeTeamCache(members){
    try {
      localStorage.setItem(TEAM_CACHE_KEY, JSON.stringify({ cachedAt: Date.now(), members: members }));
    } catch(e) {}
  }

  // ─── FETCH TEAM FROM SUPABASE (SYNC) ───
  // Note: This runs BEFORE we have a JWT (it's called during guard execution
  // to determine team membership). Uses publishable key + JWT if available.
  function fetchTeamSync(jwt){
    try {
      var xhr = new XMLHttpRequest();
      xhr.open('GET', SUPABASE_URL + '/rest/v1/projects?id=eq.tmw_team_members&select=data', false);
      xhr.setRequestHeader('apikey', SUPABASE_KEY);
      xhr.setRequestHeader('Authorization', 'Bearer ' + (jwt || SUPABASE_KEY));
      xhr.send(null);
      if (xhr.status >= 200 && xhr.status < 300) {
        var rows = JSON.parse(xhr.responseText);
        if (rows && rows[0] && rows[0].data && Array.isArray(rows[0].data.members)) {
          return rows[0].data.members;
        }
      }
    } catch(e) {}
    return null;
  }

  // Async background refresh — never blocks page load
  function fetchTeamAsync(jwt){
    fetch(SUPABASE_URL + '/rest/v1/projects?id=eq.tmw_team_members&select=data', {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': 'Bearer ' + (jwt || SUPABASE_KEY)
      }
    }).then(function(res){ return res.ok ? res.json() : null; })
      .then(function(rows){
        if (rows && rows[0] && rows[0].data && Array.isArray(rows[0].data.members)) {
          writeTeamCache(rows[0].data.members);
        }
      })
      .catch(function(){ /* silent */ });
  }

  // ─── RESOLVE TEAM LIST (HYBRID) ───
  function getTeamMembers(jwt){
    var cache = readTeamCache();

    if (cache && cache.fresh) {
      setTimeout(function(){ fetchTeamAsync(jwt); }, 100);
      return cache.members;
    }

    var fresh = fetchTeamSync(jwt);
    if (fresh) {
      writeTeamCache(fresh);
      return fresh;
    }

    if (cache && cache.members && cache.members.length) {
      return cache.members;
    }

    return EMERGENCY_OWNERS;
  }

  // ─── MAIN GUARD LOGIC ───
  function getRequiredRole(){
    var script = document.currentScript;
    if (!script) {
      var scripts = document.getElementsByTagName('script');
      for (var i = 0; i < scripts.length; i++) {
        if (scripts[i].src && scripts[i].src.indexOf('tmw-auth.js') !== -1) {
          script = scripts[i]; break;
        }
      }
    }
    if (script && script.dataset && script.dataset.requiredRole) {
      return script.dataset.requiredRole.toLowerCase();
    }
    return 'any';
  }

  function redirectToLogin(){
    var redirectParam = '';
    try { redirectParam = '?redirect=' + encodeURIComponent(window.location.pathname + window.location.search); } catch(e) {}
    window.location.replace('/login.html' + redirectParam);
  }

  function redirectToHome(){
    window.location.replace('/');
  }

  // For external-role-only users, redirect to their allowed path prefix.
  function redirectToExternalHome(externalRole){
    var dest = EXTERNAL_ROLE_PATHS[externalRole];
    if (dest) {
      window.location.replace(dest + '/');
    } else {
      // Unknown external role — sign them out rather than risk lateral access.
      window.tmwSignOut();
    }
  }

  // Determine if a user has any internal team role
  function hasInternalRole(roles){
    for (var i = 0; i < INTERNAL_ROLES.length; i++) {
      if (roles.indexOf(INTERNAL_ROLES[i]) !== -1) return true;
    }
    return false;
  }

  // Determine which external role a user has (if any) when they have NO
  // internal roles. Returns the first matching external role, or null.
  function getExternalOnlyRole(roles){
    if (hasInternalRole(roles)) return null;
    for (var ext in EXTERNAL_ROLE_PATHS) {
      if (Object.prototype.hasOwnProperty.call(EXTERNAL_ROLE_PATHS, ext)) {
        if (roles.indexOf(ext) !== -1) return ext;
      }
    }
    return null;
  }

  // Path-restriction enforcement: external-only users may only navigate
  // within their allowed path prefix. Anything else routes them home.
  function enforcePathRestriction(externalRole){
    var allowedPrefix = EXTERNAL_ROLE_PATHS[externalRole];
    if (!allowedPrefix) return false;
    var path = window.location.pathname || '/';
    // Allow exact prefix match: /marketing or /marketing/ or /marketing/anything
    var withinPrefix = (path === allowedPrefix) ||
                       (path.indexOf(allowedPrefix + '/') === 0) ||
                       (path === allowedPrefix + '/');
    if (!withinPrefix) {
      redirectToExternalHome(externalRole);
      return true;
    }
    return false;
  }

  // ─── EXECUTE GUARD ───
  try {
    var session = readSession();
    if (!session) {
      redirectToLogin();
      return;
    }

    // Expose JWT for authenticated Supabase requests (RLS policies)
    window.TMW_JWT = session.access_token || null;

    var email = String(session.user.email).toLowerCase();
    var team = getTeamMembers(window.TMW_JWT);

    var member = null;
    for (var i = 0; i < team.length; i++) {
      if (team[i].email && team[i].email.toLowerCase() === email && team[i].active !== false) {
        member = team[i];
        break;
      }
    }

    if (!member) {
      console.warn('TMW: ' + email + ' not in approved team. Signing out.');
      window.tmwSignOut();
      return;
    }

    var roles = member.roles || [];

    // Path-restriction for external-only users (e.g. marketing partners).
    // If they're already off-path, redirect and bail before role check runs.
    var externalOnlyRole = getExternalOnlyRole(roles);
    if (externalOnlyRole) {
      var redirected = enforcePathRestriction(externalOnlyRole);
      if (redirected) return;
    }

    var requiredRole = getRequiredRole();
    var checker = AREA_ACCESS[requiredRole] || AREA_ACCESS['any'];
    if (!checker(roles)) {
      console.warn('TMW: ' + email + ' lacks role "' + requiredRole + '" (has ' + roles.join(',') + '). Redirecting.');
      // External-only users get sent to their external home, internal users to /
      if (externalOnlyRole) {
        redirectToExternalHome(externalOnlyRole);
      } else {
        redirectToHome();
      }
      return;
    }

    window.TMW_USER = {
      email: email,
      name: member.name || (session.user.user_metadata && session.user.user_metadata.full_name) || email.split('@')[0],
      roles: roles.slice(),
      isOwner:   roles.indexOf('owner') !== -1,
      isAdmin:   roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1,
      isEditor:  roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1 || roles.indexOf('editor') !== -1,
      isShooter: roles.indexOf('owner') !== -1 || roles.indexOf('admin') !== -1 || roles.indexOf('shooter') !== -1,
      hasOwnerRole:     roles.indexOf('owner') !== -1,
      hasAdminRole:     roles.indexOf('admin') !== -1,
      hasEditorRole:    roles.indexOf('editor') !== -1,
      hasShooterRole:   roles.indexOf('shooter') !== -1,
      hasMarketingRole: roles.indexOf('marketing') !== -1,
      isExternalOnly:   externalOnlyRole !== null
    };

    window.tmwHasRole = function(role){
      if (!role) return false;
      return (window.TMW_USER.roles || []).indexOf(String(role).toLowerCase()) !== -1;
    };

    window.tmwCanAccess = function(area){
      var checker = AREA_ACCESS[String(area).toLowerCase()] || AREA_ACCESS['any'];
      return checker(window.TMW_USER.roles || []);
    };

  } catch(err) {
    try { console.error('TMW auth error:', err); } catch(e){}
    redirectToLogin();
  }
})();
