import { describe, expect, it, vi } from 'vitest';
import { handleTokenRequest } from './index.js';

const TENANT = '11111111-2222-3333-4444-555555555555';
const SITE = 'https://azure.wif.abbaspour.net';

const form = (overrides = {}) =>
  new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: 'app-1',
    scope: 'https://storage.azure.com/.default',
    client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
    client_assertion: 'a.b.c',
    ...overrides,
  });

const post = (body = form(), { path = `/entra/${TENANT}/token`, headers = {}, method = 'POST' } = {}) =>
  new Request(`${SITE}${path}`, {
    method,
    headers: { 'content-type': 'application/x-www-form-urlencoded', origin: SITE, ...headers },
    body: method === 'POST' ? body.toString() : undefined,
  });

describe('handleTokenRequest', () => {
  it('forwards the form to the tenant token endpoint without an Origin header and returns the response', async () => {
    const fetchImpl = vi.fn(async () => new Response('{"access_token":"t","expires_in":3599}', { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } }));

    const response = await handleTokenRequest(post(), fetchImpl);

    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe(`https://login.microsoftonline.com/${TENANT}/oauth2/v2.0/token`);
    expect(init.method).toBe('POST');
    expect(Object.keys(init.headers)).toEqual(['content-type']);
    expect(Object.fromEntries(new URLSearchParams(init.body))).toEqual(Object.fromEntries(form()));
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(await response.json()).toEqual({ access_token: 't', expires_in: 3599 });
  });

  it('passes Entra errors through with their status', async () => {
    const fetchImpl = async () => new Response('{"error":"invalid_client"}', { status: 401, headers: { 'content-type': 'application/json' } });
    const response = await handleTokenRequest(post(), fetchImpl);
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: 'invalid_client' });
  });

  it.each([
    ['another path', post(form(), { path: '/entra/other' }), 404],
    ['a tenant that is not a GUID', post(form(), { path: '/entra/evil.example.com/token' }), 404],
    ['a GET', post(form(), { method: 'GET' }), 405],
    ['a foreign origin', post(form(), { headers: { origin: 'https://evil.example.com' } }), 403],
    ['another grant type', post(form({ grant_type: 'authorization_code' })), 400],
    ['another scope', post(form({ scope: 'https://graph.microsoft.com/.default' })), 400],
    ['a client secret', post(form({ client_secret: 'x' })), 400],
    ['no assertion', post(new URLSearchParams({ grant_type: 'client_credentials', client_id: 'a', scope: 'https://storage.azure.com/.default', client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer' })), 400],
  ])('rejects %s without calling Entra', async (_name, request, status) => {
    const fetchImpl = vi.fn();
    const response = await handleTokenRequest(request, fetchImpl);
    expect(response.status).toBe(status);
    expect(fetchImpl).not.toHaveBeenCalled();
  });
});
