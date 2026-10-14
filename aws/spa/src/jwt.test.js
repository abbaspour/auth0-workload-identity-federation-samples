import { describe, expect, it } from 'vitest';
import { decodeJwt } from './jwt.js';

const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const token = (claims) => `${b64url({ alg: 'RS256' })}.${b64url(claims)}.sig`;

describe('decodeJwt', () => {
  it('decodes a payload, including array audiences', () => {
    const claims = { sub: 'auth0|abc', aud: ['https://aws.wif', 'https://t.auth0.com/userinfo'], azp: 'cid' };
    expect(decodeJwt(token(claims))).toEqual(claims);
  });

  it('handles base64url characters and non-ASCII text', () => {
    const claims = { name: 'Zoë ??>>', sub: 'x' };
    const jwt = token(claims);
    expect(jwt.split('.')[1]).toMatch(/[-_]/); // really exercises base64url, not plain base64
    expect(decodeJwt(jwt)).toEqual(claims);
  });

  it('rejects opaque tokens', () => {
    expect(() => decodeJwt('abc123opaque')).toThrow(/Not a JWT/);
  });
});
