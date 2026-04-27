/**
 * tmw-auth.js
 * Include at the top of any page that requires authentication.
 * Usage: <script src="/tmw-auth.js"></script>
 * For owner-only pages: <script src="/tmw-auth.js" data-owner-only="true"></script>
 */
(async function() {
  const SUPABASE_URL = 'https://rafygjaemcjhnououmwn.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_2rv2vfk2vKGFrd36RdVb6g_RaJWQSCp';

  const APPROVED_EMAILS = [
    'tonyellismartinez@gmail.com',
    'brynn.weller95@gmail.com',
    'leximartinez43@gmail.com',
  ];

  const OWNER_EMAILS = [
    'tonyellismartinez@gmail.com',
    'brynn.weller95@gmail.com',
  ];

  // Load Supabase if not already loaded
  if (!window.supabase) {
    await new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
      s.onload = resolve;
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  const { data: { session } } = await client.auth.getSession();

  const currentScript = document.currentScript;
  const ownerOnly = currentScript && currentScript.getAttribute('data-owner-only') === 'true';

  if (!session) {
    window.location.href = '/login.html?redirect=' + encodeURIComponent(window.location.pathname);
    return;
  }

  const email = session.user.email;

  if (!APPROVED_EMAILS.includes(email)) {
    await client.auth.signOut();
    window.location.href = '/login.html?error=unauthorized';
    return;
  }

  if (ownerOnly && !OWNER_EMAILS.includes(email)) {
    window.location.href = '/?error=owner_only';
    return;
  }

  // Expose session info globally
  window.TMW_USER = {
    email,
    name: session.user.user_metadata?.full_name || email.split('@')[0],
    avatar: session.user.user_metadata?.avatar_url || null,
    isOwner: OWNER_EMAILS.includes(email),
    supabase: client,
  };

  // Expose sign out function
  window.tmwSignOut = async function() {
    await client.auth.signOut();
    window.location.href = '/login.html';
  };

})();
