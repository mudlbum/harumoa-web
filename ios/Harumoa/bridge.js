/* Only injected into the bundled main frame by the iOS shell. No tokens in storage. */
(() => {
  const send = (method, args = []) => window.webkit.messageHandlers.harumoa.postMessage({method, args});
  if (!crypto.randomUUID) Object.defineProperty(crypto, 'randomUUID', {value: () => {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
    const hex = Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
  }});
  window.HarumoaGoogle = {
    info: () => JSON.stringify(window.__harumoaIdentity || {}),
    signIn: id => send('signIn', [id]),
    authorize: (id, scopes, interactive) => send('authorize', [id, scopes, interactive]),
    invalidateToken: id => send('invalidateToken', [id]),
    forget: id => send('forget', [id]),
    pickFile: (id, file) => send('pickFile', [id, file])
  };
  window.addEventListener('harumoa:google-auth', e => {
    if (e.detail?.email && !e.detail?.error) window.__harumoaIdentity = {email: e.detail.email, name: e.detail.name || e.detail.email};
  });
  window.HarumoaRecorder = {
    start: id => send('recordStart', [id]), stop: id => send('recordStop', [id]),
    cancel: id => send('recordCancel', [id]), discardFile: token => send('recordDiscard', [token]),
    openSettings: () => send('openSettings')
  };
  window.HarumoaFeedback = {
    tap: (sound, haptic, volume) => send('tap', [sound, haptic, volume]),
    success: (sound, volume) => send('success', [sound, volume]), stop: () => send('stopFeedback')
  };
  window.HarumoaNative = {shareInvitation: text => send('shareInvitation', [text]), pickContact: () => send('pickContact')};
  // A custom WKWebView scheme has no web service worker. Native bundle works offline.
})();
