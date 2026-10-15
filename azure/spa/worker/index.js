// The Entra token endpoint refuses a client_credentials request that carries a browser Origin header
// (AADSTS9002326), so the SPA posts the token request to this Worker, which repeats it server-side without an Origin.
// Everything else (the SPA files) is served from static assets without running this script.
//
// This is a pass-through, not a backend: no secrets, no state, and the Auth0 access token in the request body is the
// only credential. It forwards exactly one kind of call, so it cannot be used as a general proxy.

const LOGIN_URL = 'https://login.microsoftonline.com';
const TENANT_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STORAGE_SCOPE = 'https://storage.azure.com/.default';

const reply = (status, message, headers = {}) =>
  new Response(JSON.stringify({ error: message }), { status, headers: { 'content-type': 'application/json', ...headers } });

export async function handleTokenRequest(request, fetchImpl = fetch) {
  const url = new URL(request.url);
  const tenant = url.pathname.match(/^\/entra\/([^/]+)\/token$/)?.[1];
  if (!tenant || !TENANT_ID.test(tenant)) return reply(404, 'not_found');
  if (request.method !== 'POST') return reply(405, 'method_not_allowed', { allow: 'POST' });

  // Only the SPA's own origin may use it (a browser always sends Origin on a cross-origin POST)
  const origin = request.headers.get('origin');
  if (origin && origin !== url.origin) return reply(403, 'forbidden_origin');

  const form = new URLSearchParams(await request.text());
  const allowed =
    form.get('grant_type') === 'client_credentials' &&
    form.get('client_assertion_type') === 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer' &&
    form.get('scope') === STORAGE_SCOPE &&
    form.has('client_id') &&
    form.has('client_assertion') &&
    !form.has('client_secret');
  if (!allowed) return reply(400, 'unsupported_request');

  const upstream = await fetchImpl(`${LOGIN_URL}/${tenant}/oauth2/v2.0/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: form.toString(),
  });
  return new Response(upstream.body, {
    status: upstream.status,
    headers: { 'content-type': upstream.headers.get('content-type') ?? 'application/json', 'cache-control': 'no-store' },
  });
}

export default {
  fetch: (request) => handleTokenRequest(request),
};
