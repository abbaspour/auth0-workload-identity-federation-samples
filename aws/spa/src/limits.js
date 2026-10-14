// The role policy cannot cap object size, so the app enforces a client-side limit.
// Uploads are read fully into memory, which also makes large files a poor fit.
export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

export function checkUploadSize(bytes, max = MAX_UPLOAD_BYTES) {
  if (bytes > max) {
    throw new Error(`File is too large (${(bytes / (1024 * 1024)).toFixed(1)} MB). The demo limit is ${max / (1024 * 1024)} MB.`);
  }
}
