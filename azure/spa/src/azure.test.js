// @vitest-environment happy-dom
import { describe, expect, it, vi } from 'vitest';
import { createBlobStore, createTokenExchange } from './azure.js';

const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const jwt = (claims) => `${b64url({ alg: 'RS256' })}.${b64url(claims)}.sig`;

const json = (body, init = {}) => new Response(JSON.stringify(body), { status: 200, ...init });
const xml = (body, init = {}) => new Response(body, { status: 200, headers: { 'content-type': 'application/xml' }, ...init });

describe('createTokenExchange', () => {
  const config = { tenantId: 'tenant-1', appClientId: 'app-1' };

  it('posts a client_credentials request with the Auth0 token as client assertion to the same-origin proxy path', async () => {
    const fetchImpl = vi.fn(async () => json({ access_token: 'eyJ.entra.token', token_type: 'Bearer', expires_in: 3599 }));
    const exchange = createTokenExchange(config, { fetchImpl, now: () => 1_000_000 });

    const auth0Token = jwt({ sub: 'auth0|abc' });
    const session = await exchange(auth0Token);

    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe('/entra/tenant-1/token');
    expect(init.method).toBe('POST');
    expect(Object.fromEntries(init.body)).toEqual({
      grant_type: 'client_credentials',
      client_id: 'app-1',
      scope: 'https://storage.azure.com/.default',
      client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      client_assertion: auth0Token,
    });
    expect(session.subject).toBe('auth0|abc');
    expect(session.credentials.accessToken).toBe('eyJ.entra.token');
    expect(session.credentials.expiration.getTime()).toBe(1_000_000 + 3599 * 1000);
  });

  it('turns an Entra error into a one-line message', async () => {
    const description = 'AADSTS700212: No matching federated identity record found for presented assertion audience.\r\nTrace ID: abc\r\nCorrelation ID: def';
    const fetchImpl = async () => json({ error: 'invalid_request', error_description: description }, { status: 400 });
    const exchange = createTokenExchange(config, { fetchImpl });
    const error = await exchange(jwt({ sub: 'x' })).catch((e) => e);
    expect(error.message).toMatch(/HTTP 400.*AADSTS700212/);
    expect(error.message).not.toMatch(/Trace ID/);
  });
});

describe('createBlobStore', () => {
  const accessToken = async () => 'entra-token';
  const listing = (blobs, next = '') =>
    `<?xml version="1.0" encoding="utf-8"?><EnumerationResults><Blobs>${blobs
      .map(([name, size, modified]) => `<Blob><Name>${name}</Name><Properties><Last-Modified>${modified}</Last-Modified><Content-Length>${size}</Content-Length></Properties></Blob>`)
      .join('')}</Blobs><NextMarker>${next}</NextMarker></EnumerationResults>`;

  it('lists blobs under the user prefix, following markers and skipping the prefix placeholder', async () => {
    const pages = [
      listing([['users/auth0|a/', 0, 'Thu, 01 Jan 2026 00:00:00 GMT'], ['users/auth0|a/one.txt', 3, 'Thu, 01 Jan 2026 00:00:00 GMT']], 'm2'),
      listing([['users/auth0|a/two &amp; three.txt', 5, 'Fri, 02 Jan 2026 00:00:00 GMT']]),
    ];
    const fetchImpl = vi.fn(async () => xml(pages.shift()));
    const store = createBlobStore({ account: 'acct', container: 'demo', accessToken }, { fetchImpl });

    const objects = await store.list('auth0|a');

    expect(objects.map((o) => [o.name, o.size])).toEqual([['one.txt', 3], ['two & three.txt', 5]]);
    expect(objects[1].key).toBe('users/auth0|a/two & three.txt');
    const first = new URL(fetchImpl.mock.calls[0][0]);
    expect(first.origin + first.pathname).toBe('https://acct.blob.core.windows.net/demo');
    expect(first.searchParams.get('restype')).toBe('container');
    expect(first.searchParams.get('comp')).toBe('list');
    expect(first.searchParams.get('prefix')).toBe('users/auth0|a/');
    expect(new URL(fetchImpl.mock.calls[1][0]).searchParams.get('marker')).toBe('m2');
    const headers = fetchImpl.mock.calls[0][1].headers;
    expect(headers.authorization).toBe('Bearer entra-token');
    expect(headers['x-ms-version']).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('uploads a block blob to an encoded path under the user prefix', async () => {
    const fetchImpl = vi.fn(async () => new Response(null, { status: 201 }));
    const store = createBlobStore({ account: 'acct', container: 'demo', accessToken }, { fetchImpl });

    const key = await store.upload('auth0|a', { name: 'my file.txt', type: 'text/plain' });

    expect(key).toBe('users/auth0|a/my file.txt');
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe('https://acct.blob.core.windows.net/demo/users/auth0%7Ca/my%20file.txt');
    expect(init.method).toBe('PUT');
    expect(init.headers['x-ms-blob-type']).toBe('BlockBlob');
    expect(init.headers['content-type']).toBe('text/plain');
  });

  it('downloads by encoded path', async () => {
    const fetchImpl = vi.fn(async () => new Response('hello', { headers: { 'content-type': 'text/plain' } }));
    const store = createBlobStore({ account: 'acct', container: 'demo', accessToken }, { fetchImpl });

    const { bytes, contentType } = await store.download('users/auth0|a/x y.txt');

    expect(fetchImpl.mock.calls[0][0]).toBe('https://acct.blob.core.windows.net/demo/users/auth0%7Ca/x%20y.txt');
    expect(new TextDecoder().decode(bytes)).toBe('hello');
    expect(contentType).toBe('text/plain');
  });

  it('reports Blob Storage XML errors with the HTTP status', async () => {
    const body = '<?xml version="1.0"?><Error><Code>AuthorizationPermissionMismatch</Code><Message>This request is not authorized to perform this operation using this permission.\nRequestId:1</Message></Error>';
    const fetchImpl = async () => xml(body, { status: 403 });
    const store = createBlobStore({ account: 'acct', container: 'demo', accessToken }, { fetchImpl });
    await expect(store.list('auth0|a')).rejects.toThrow(/HTTP 403.*not authorized to perform this operation/);
  });
});
