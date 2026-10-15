import { describe, expect, it } from 'vitest';
import { objectKey, userPrefix } from './keys.js';

describe('userPrefix', () => {
  it('keeps the Auth0 subject verbatim', () => {
    expect(userPrefix('auth0|6aced1')).toBe('users/auth0|6aced1/');
  });

  it('requires a subject', () => {
    expect(() => userPrefix('')).toThrow();
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
