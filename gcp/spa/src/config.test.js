import { describe, expect, it } from 'vitest';
import { loadConfig } from './config.js';

const full = {
  VITE_AUTH0_DOMAIN: 'd.auth0.com',
  VITE_AUTH0_CLIENT_ID: 'cid',
  VITE_AUTH0_AUDIENCE: 'https://gcp.wif',
  VITE_GCP_WIP_AUDIENCE: '//iam.googleapis.com/projects/1/locations/global/workloadIdentityPools/p/providers/auth0',
  VITE_GCS_BUCKET: 'b',
};

describe('loadConfig', () => {
  it('maps env variables to config keys', () => {
    expect(loadConfig(full)).toEqual({
      domain: 'd.auth0.com',
      clientId: 'cid',
      audience: 'https://gcp.wif',
      providerAudience: '//iam.googleapis.com/projects/1/locations/global/workloadIdentityPools/p/providers/auth0',
      bucket: 'b',
    });
  });

  it('lists every missing variable and points at the generator script', () => {
    expect(() => loadConfig({ VITE_AUTH0_DOMAIN: 'd' })).toThrow(/VITE_AUTH0_CLIENT_ID.*VITE_GCS_BUCKET.*spa-env\.sh/);
  });
});
