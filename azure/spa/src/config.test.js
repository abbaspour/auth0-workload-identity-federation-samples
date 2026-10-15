import { describe, expect, it } from 'vitest';
import { loadConfig } from './config.js';

const full = {
  VITE_AUTH0_DOMAIN: 'd.auth0.com',
  VITE_AUTH0_CLIENT_ID: 'cid',
  VITE_AUTH0_AUDIENCE: 'api://AzureADTokenExchange',
  VITE_AZURE_TENANT_ID: 'tenant',
  VITE_AZURE_APP_CLIENT_ID: 'app',
  VITE_AZURE_STORAGE_ACCOUNT: 'acct',
  VITE_AZURE_CONTAINER: 'demo',
};

describe('loadConfig', () => {
  it('maps env variables to config keys', () => {
    expect(loadConfig(full)).toEqual({
      domain: 'd.auth0.com',
      clientId: 'cid',
      audience: 'api://AzureADTokenExchange',
      tenantId: 'tenant',
      appClientId: 'app',
      account: 'acct',
      container: 'demo',
    });
  });

  it('lists every missing variable and points at the generator script', () => {
    expect(() => loadConfig({ VITE_AUTH0_DOMAIN: 'd' })).toThrow(/VITE_AUTH0_CLIENT_ID.*VITE_AZURE_CONTAINER.*spa-env\.sh/);
  });
});
