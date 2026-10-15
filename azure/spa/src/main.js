import './style.css';
import { loadConfig } from './config.js';
import { createAuth } from './auth.js';
import { createBlobStore, createTokenExchange } from './azure.js';
import { createCredentialsProvider } from './credentials.js';
import { decodeJwt } from './jwt.js';
import { checkUploadSize } from './limits.js';
import { userPrefix } from './keys.js';

const $ = (id) => document.getElementById(id);

// Build DOM with textContent only: object names are user-controlled and must never be parsed as HTML.
function el(tag, props = {}, ...children) {
  const node = Object.assign(document.createElement(tag), props);
  node.append(...children);
  return node;
}

function show(id) {
  for (const section of ['loading', 'signed-out', 'signed-in']) $(section).hidden = section !== id;
}

function log(message) {
  const item = el('li', { textContent: `${new Date().toLocaleTimeString()}  ${message}` });
  $('log').prepend(item);
}

function showError(error) {
  console.error(error);
  let message = error?.message || String(error);
  if (error?.name === 'TypeError' && /fetch/i.test(message)) {
    message += '\n(Network or CORS failure: check that the storage account CORS allows this origin.)';
  }
  if (['login_required', 'consent_required', 'missing_refresh_token'].includes(error?.error)) {
    message = 'Your session has expired. Please log in again.';
  }
  $('error').textContent = message;
  $('error').hidden = false;
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function saveBlob(name, bytes, contentType) {
  const url = URL.createObjectURL(new Blob([bytes], { type: contentType || 'application/octet-stream' }));
  el('a', { href: url, download: name }).click();
  URL.revokeObjectURL(url);
}

async function main() {
  const config = loadConfig();
  const auth = await createAuth(config);

  if (!(await auth.isAuthenticated())) {
    show('signed-out');
    $('login').onclick = () => auth.login();
    return;
  }

  show('signed-in');
  const user = await auth.getUser();
  $('user-bar').replaceChildren(
    el('span', { textContent: user?.email ?? user?.name ?? user?.sub ?? '' }),
    el('button', { type: 'button', textContent: 'Log out', onclick: () => auth.logout() }),
  );

  const exchangeToken = createTokenExchange(config);
  const provider = createCredentialsProvider({
    getToken: auth.getAccessToken,
    exchange: async (accessToken) => {
      log('Auth0 access token acquired. Calling the Entra token exchange…');
      const session = await exchangeToken(accessToken);
      log(`Entra access token issued for ${session.subject}`);
      return session;
    },
  });
  const store = createBlobStore({ account: config.account, container: config.container, accessToken: provider.accessToken });

  async function renderFederation() {
    const session = await provider.get();
    const claims = decodeJwt(await auth.getAccessToken());
    const entra = decodeJwt(session.credentials.accessToken);
    const rows = [
      ['Token issuer (iss)', claims.iss],
      ['Token audience (aud)', [].concat(claims.aud).join(', ')],
      ['Token client (azp)', claims.azp],
      ['Subject (sub)', session.subject],
      ['Entra app (client ID)', config.appClientId],
      ['Entra token audience (aud)', entra.aud],
      ['Entra token expires', session.credentials.expiration.toLocaleString()],
    ];
    $('federation').replaceChildren(...rows.flatMap(([k, v]) => [el('dt', { textContent: k }), el('dd', { textContent: v ?? '' })]));
    $('prefix').textContent = `https://${config.account}.blob.core.windows.net/${config.container}/${userPrefix(session.subject)}`;
  }

  async function refreshList() {
    const { subject } = await provider.get();
    const objects = await store.list(subject);
    const rows = objects.map((o) =>
      el(
        'tr',
        {},
        el('td', { textContent: o.name }),
        el('td', { textContent: formatSize(o.size) }),
        el('td', { textContent: o.lastModified?.toLocaleString() ?? '' }),
        el('td', {}, el('button', { type: 'button', textContent: 'Download', onclick: () => run(() => download(o)) })),
      ),
    );
    $('objects').querySelector('tbody').replaceChildren(...rows);
    $('empty').hidden = objects.length > 0;
    log(`Listed ${objects.length} object(s) under ${userPrefix(subject)}`);
  }

  async function download(object) {
    const { bytes, contentType } = await store.download(object.key);
    saveBlob(object.name, bytes, contentType);
    log(`Downloaded ${object.key}`);
  }

  // Run an action, show any error, and always refresh the federation panel (the Entra token may have been renewed)
  async function run(action) {
    $('error').hidden = true;
    const controls = document.querySelectorAll('#signed-in button, #signed-in input');
    controls.forEach((c) => (c.disabled = true));
    try {
      await action();
      await renderFederation();
    } catch (error) {
      showError(error);
    } finally {
      controls.forEach((c) => (c.disabled = false));
    }
  }

  $('refresh').onclick = () => run(refreshList);
  $('upload-form').onsubmit = (event) => {
    event.preventDefault();
    const file = $('file').files[0];
    if (!file) return;
    run(async () => {
      checkUploadSize(file.size);
      const { subject } = await provider.get();
      const key = await store.upload(subject, file);
      log(`Uploaded ${key} (${formatSize(file.size)})`);
      $('upload-form').reset();
      await refreshList();
    });
  };

  await run(async () => {
    await renderFederation();
    await refreshList();
  });
}

main().catch((error) => {
  show('signed-out');
  showError(error);
});
