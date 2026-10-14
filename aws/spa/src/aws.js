import { AssumeRoleWithWebIdentityCommand, STSClient } from '@aws-sdk/client-sts';
import { GetObjectCommand, ListObjectsV2Command, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { decodeJwt } from './jwt.js';
import { objectKey, sessionNameFor, userPrefix } from './keys.js';

// Exchanges the Auth0 access token for temporary credentials. The call is unsigned:
// no AWS credentials exist in the browser before this step.
export function createAssumeRole({ region, roleArn }) {
  const sts = new STSClient({ region });

  return async function assumeRole(accessToken) {
    const { sub } = decodeJwt(accessToken);
    const out = await sts.send(
      new AssumeRoleWithWebIdentityCommand({
        RoleArn: roleArn,
        RoleSessionName: sessionNameFor(sub),
        WebIdentityToken: accessToken,
      }),
    );
    return {
      credentials: {
        accessKeyId: out.Credentials.AccessKeyId,
        secretAccessKey: out.Credentials.SecretAccessKey,
        sessionToken: out.Credentials.SessionToken,
        expiration: out.Credentials.Expiration,
      },
      // The subject AWS evaluated for ${...:sub} in the permissions policy
      subject: out.SubjectFromWebIdentityToken,
      assumedRoleArn: out.AssumedRoleUser.Arn,
    };
  };
}

export function createS3Store({ region, bucket, credentials }) {
  const s3 = new S3Client({ region, credentials });

  return {
    async list(subject) {
      const prefix = userPrefix(subject);
      const objects = [];
      let token;
      do {
        const out = await s3.send(
          new ListObjectsV2Command({ Bucket: bucket, Prefix: prefix, ContinuationToken: token }),
        );
        for (const o of out.Contents ?? []) {
          if (o.Key !== prefix) objects.push({ key: o.Key, name: o.Key.slice(prefix.length), size: o.Size, lastModified: o.LastModified });
        }
        token = out.NextContinuationToken;
      } while (token);
      return objects;
    },

    async upload(subject, file) {
      const key = objectKey(subject, file.name);
      await s3.send(
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          // A byte array avoids browser stream-length issues with Blob bodies in the SDK
          Body: new Uint8Array(await file.arrayBuffer()),
          ContentType: file.type || 'application/octet-stream',
        }),
      );
      return key;
    },

    async download(key) {
      const out = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      return { bytes: await out.Body.transformToByteArray(), contentType: out.ContentType };
    },
  };
}
