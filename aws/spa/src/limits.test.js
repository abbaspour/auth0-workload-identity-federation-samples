import { describe, expect, it } from 'vitest';
import { MAX_UPLOAD_BYTES, checkUploadSize } from './limits.js';

describe('checkUploadSize', () => {
  it('allows files up to the limit', () => {
    expect(() => checkUploadSize(0)).not.toThrow();
    expect(() => checkUploadSize(MAX_UPLOAD_BYTES)).not.toThrow();
  });

  it('rejects larger files with a readable message', () => {
    expect(() => checkUploadSize(MAX_UPLOAD_BYTES + 1)).toThrow(/too large.*10 MB/);
  });
});
