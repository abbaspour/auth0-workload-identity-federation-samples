import { describe, expect, it } from 'vitest';
import { loadConfig } from './config.js';

const full = {
  VITE_AUTH0_DOMAIN: 'd.auth0.com',
  VITE_AUTH0_CLIENT_ID: 'cid',
  VITE_AUTH0_AUDIENCE: 'https://aws.wif',
  VITE_AWS_ROLE_ARN: 'arn:aws:iam::1:role/r',
  VITE_AWS_REGION: 'us-east-1',
  VITE_S3_BUCKET: 'b',
};

describe('loadConfig', () => {
  it('maps env variables to config keys', () => {
    expect(loadConfig(full)).toEqual({
      domain: 'd.auth0.com',
      clientId: 'cid',
      audience: 'https://aws.wif',
      roleArn: 'arn:aws:iam::1:role/r',
      region: 'us-east-1',
      bucket: 'b',
    });
  });

  it('lists every missing variable and points at the generator script', () => {
    expect(() => loadConfig({ VITE_AUTH0_DOMAIN: 'd' })).toThrow(/VITE_AUTH0_CLIENT_ID.*VITE_S3_BUCKET.*spa-env\.sh/);
  });
});
