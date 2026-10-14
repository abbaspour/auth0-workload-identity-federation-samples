import { describe, expect, it } from 'vitest';
import { objectKey, sessionNameFor, userPrefix } from './keys.js';

describe('userPrefix', () => {
  it('keeps the Auth0 subject verbatim, matching the role policy', () => {
    expect(userPrefix('auth0|6aced1')).toBe('users/auth0|6aced1/');
  });

  it('requires a subject', () => {
    expect(() => userPrefix('')).toThrow();
  });
});

describe('sessionNameFor', () => {
  it('replaces characters STS does not allow', () => {
    expect(sessionNameFor('auth0|6aced1')).toBe('wif-auth0-6aced1');
  });

  it('is at most 64 characters and valid for RoleSessionName', () => {
    const name = sessionNameFor(`google-oauth2|${'1'.repeat(100)}`);
    expect(name.length).toBeLessThanOrEqual(64);
    expect(name).toMatch(/^[\w+=,.@-]{2,64}$/);
  });
});

describe('objectKey', () => {
  it('puts the file under the user prefix', () => {
    expect(objectKey('auth0|a', 'notes.txt')).toBe('users/auth0|a/notes.txt');
  });

  it('strips any path from the file name so keys cannot escape the prefix', () => {
    expect(objectKey('auth0|a', '../../users/other/x.txt')).toBe('users/auth0|a/x.txt');
    expect(objectKey('auth0|a', 'C:\\temp\\x.txt')).toBe('users/auth0|a/x.txt');
  });

  it('rejects empty names', () => {
    expect(() => objectKey('auth0|a', '  ')).toThrow();
  });
});
