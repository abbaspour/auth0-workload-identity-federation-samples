import { createAuth0Client } from '@auth0/auth0-spa-js';

export async function createAuth({ domain, clientId, audience }) {
  const client = await createAuth0Client({
    domain,
    clientId,
    authorizationParams: {
      audience, // makes the access token a JWT for our API; AWS checks it as `oaud`
      redirect_uri: window.location.origin,
    },
  });

  // Finish a login redirect (?code=...&state=...) or surface an error redirect (?error=...)
  const params = new URLSearchParams(window.location.search);
  if (params.has('error')) {
    const message = params.get('error_description') || params.get('error');
    window.history.replaceState({}, document.title, window.location.pathname);
    throw new Error(`Login failed: ${message}`);
  }
  if (params.has('code') && params.has('state')) {
    await client.handleRedirectCallback();
    window.history.replaceState({}, document.title, window.location.pathname);
  }

  return {
    isAuthenticated: () => client.isAuthenticated(),
    getUser: () => client.getUser(),
    getAccessToken: () => client.getTokenSilently(),
    login: () => client.loginWithRedirect(),
    logout: () => client.logout({ logoutParams: { returnTo: window.location.origin } }),
  };
}
