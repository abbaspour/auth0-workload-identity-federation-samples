import { decodeJwt } from './jwt.js';
import { objectKey, userPrefix } from './keys.js';

const STORAGE_SCOPE = 'https://storage.azure.com/.default';
// Any Blob service version from 2017-11-09 on accepts OAuth bearer tokens.
const BLOB_API_VERSION = '2023-11-03';

// Entra errors are JSON ({error, error_description}); Blob Storage errors are XML (<Error><Code/><Message/>).
async function failure(response, what) {
  let detail = '';
  try {
    const text = await response.text();
    try {
      const body = JSON.parse(text);
      detail = body.error_description || body.error?.message || (typeof body.error === 'string' ? body.error : '');
    } catch {
      detail = text.match(/<Message>([\s\S]*?)<\/Message>/)?.[1] ?? text.match(/<Code>([\s\S]*?)<\/Code>/)?.[1] ?? '';
    }
  } catch {
    // no readable body; the status line is enough
  }
  const error = new Error(`${what} failed (HTTP ${response.status})${detail ? `: ${detail.split('\n')[0]}` : ''}`);
  error.status = response.status;
  return error;
}

// Exchanges the Auth0 access token for a Microsoft Entra access token: an OAuth client_credentials request in
// which the Auth0 token is the client assertion (workload identity federation). There is no client secret or
// certificate; Entra trusts the assertion through the app registration's federated credential, which matches the
// token's issuer, subject (`sub`) and audience exactly.
//
// The request goes to this app's own /entra/<tenant>/token path, not to login.microsoftonline.com: Entra refuses
// a client_credentials request that carries a browser Origin header (AADSTS9002326). In production a Cloudflare
// Worker (worker/index.js) repeats the request server-side; in `vite dev` and `vite preview` the dev server's
// proxy does (vite.config.js).
export function createTokenExchange({ tenantId, appClientId }, { fetchImpl = fetch, now = Date.now } = {}) {
  return async function exchange(accessToken) {
    const response = await fetchImpl(`/entra/${tenantId}/token`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: appClientId,
        scope: STORAGE_SCOPE,
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        client_assertion: accessToken,
      }),
    });
    if (!response.ok) throw await failure(response, 'Entra token exchange');

    const out = await response.json();
    return {
      credentials: {
        accessToken: out.access_token,
        expiration: new Date(now() + out.expires_in * 1000),
      },
      // The subject the federated credential matched
      subject: decodeJwt(accessToken).sub,
    };
  };
}

const text = (parent, tag) => parent.getElementsByTagName(tag)[0]?.textContent ?? '';

// Blob names keep their "/" separators in the URL path; every segment is encoded ("|" in an Auth0 sub becomes %7C).
const blobPath = (key) => key.split('/').map(encodeURIComponent).join('/');

// Blob Storage REST API, called straight from the browser with the Entra token as the bearer.
export function createBlobStore({ account, container, accessToken }, { fetchImpl = fetch, parseXml = (xml) => new DOMParser().parseFromString(xml, 'text/xml') } = {}) {
  const base = `https://${account}.blob.core.windows.net/${container}`;

  async function call(what, url, init = {}) {
    const response = await fetchImpl(url, {
      ...init,
      headers: { ...init.headers, authorization: `Bearer ${await accessToken()}`, 'x-ms-version': BLOB_API_VERSION },
    });
    if (!response.ok) throw await failure(response, what);
    return response;
  }

  return {
    async list(subject) {
      const prefix = userPrefix(subject);
      const objects = [];
      let marker = '';
      do {
        const params = new URLSearchParams({ restype: 'container', comp: 'list', prefix });
        if (marker) params.set('marker', marker);
        const xml = parseXml(await (await call('List blobs', `${base}?${params}`)).text());
        for (const blob of xml.getElementsByTagName('Blob')) {
          const key = text(blob, 'Name');
          if (key !== prefix) {
            objects.push({
              key,
              name: key.slice(prefix.length),
              size: Number(text(blob, 'Content-Length')),
              lastModified: new Date(text(blob, 'Last-Modified')),
            });
          }
        }
        marker = text(xml, 'NextMarker');
      } while (marker);
      return objects;
    },

    async upload(subject, file) {
      const key = objectKey(subject, file.name);
      await call('Upload', `${base}/${blobPath(key)}`, {
        method: 'PUT',
        headers: { 'x-ms-blob-type': 'BlockBlob', 'content-type': file.type || 'application/octet-stream' },
        body: file,
      });
      return key;
    },

    async download(key) {
      const response = await call('Download', `${base}/${blobPath(key)}`);
      return { bytes: new Uint8Array(await response.arrayBuffer()), contentType: response.headers.get('content-type') };
    },
  };
}
