import { decodeJwt } from './jwt.js';
import { objectKey, userPrefix } from './keys.js';

const STS_URL = 'https://sts.googleapis.com/v1/token';
const STORAGE_URL = 'https://storage.googleapis.com';

async function failure(response, what) {
  let detail = '';
  try {
    const body = await response.json();
    detail = body.error_description || body.error?.message || (typeof body.error === 'string' ? body.error : '') || '';
  } catch {
    // not JSON; the status line is enough
  }
  const error = new Error(`${what} failed (HTTP ${response.status})${detail ? `: ${detail}` : ''}`);
  error.status = response.status;
  return error;
}

// Exchanges the Auth0 access token for a Google federated access token (OAuth 2.0 token exchange,
// RFC 8693). The call is unauthenticated: no Google credentials exist in the browser before this step.
export function createTokenExchange({ providerAudience }, { fetchImpl = fetch, now = Date.now } = {}) {
  return async function exchange(accessToken) {
    const response = await fetchImpl(STS_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
        audience: providerAudience,
        scope: 'https://www.googleapis.com/auth/cloud-platform',
        requested_token_type: 'urn:ietf:params:oauth:token-type:access_token',
        subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
        subject_token: accessToken,
      }),
    });
    if (!response.ok) throw await failure(response, 'Google STS token exchange');

    const out = await response.json();
    return {
      credentials: {
        accessToken: out.access_token,
        expiration: new Date(now() + out.expires_in * 1000),
      },
      // google.subject is mapped from the token's `sub` claim
      subject: decodeJwt(accessToken).sub,
    };
  };
}

// Cloud Storage JSON API, called straight from the browser with the federated token as the bearer.
// (@google-cloud/storage is not meant for browsers, so this uses fetch.)
export function createGcsStore({ bucket, accessToken }, { fetchImpl = fetch } = {}) {
  const object = (key) => `${STORAGE_URL}/storage/v1/b/${bucket}/o/${encodeURIComponent(key)}`;

  async function call(what, url, init = {}) {
    const response = await fetchImpl(url, {
      ...init,
      headers: { ...init.headers, authorization: `Bearer ${await accessToken()}` },
    });
    if (!response.ok) throw await failure(response, what);
    return response;
  }

  return {
    async list(subject) {
      const prefix = userPrefix(subject);
      const objects = [];
      let pageToken;
      do {
        const params = new URLSearchParams({ prefix });
        if (pageToken) params.set('pageToken', pageToken);
        const out = await (await call('List objects', `${STORAGE_URL}/storage/v1/b/${bucket}/o?${params}`)).json();
        for (const o of out.items ?? []) {
          if (o.name !== prefix) {
            objects.push({ key: o.name, name: o.name.slice(prefix.length), size: Number(o.size), lastModified: new Date(o.updated) });
          }
        }
        pageToken = out.nextPageToken;
      } while (pageToken);
      return objects;
    },

    async upload(subject, file) {
      const key = objectKey(subject, file.name);
      const params = new URLSearchParams({ uploadType: 'media', name: key });
      await call('Upload', `${STORAGE_URL}/upload/storage/v1/b/${bucket}/o?${params}`, {
        method: 'POST',
        headers: { 'content-type': file.type || 'application/octet-stream' },
        body: file,
      });
      return key;
    },

    async download(key) {
      const response = await call('Download', `${object(key)}?alt=media`);
      return { bytes: new Uint8Array(await response.arrayBuffer()), contentType: response.headers.get('content-type') };
    },
  };
}
