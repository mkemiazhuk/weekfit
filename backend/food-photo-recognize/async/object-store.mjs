import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { mkdir, writeFile, readFile, unlink, readdir, stat } from 'node:fs/promises';
import { createExclusive, removeQuiet } from './atomic-fs.mjs';

/**
 * Local object store for photo bytes.
 * Staging/production: set OBJECT_STORE=s3 and wire S3/R2 (see render blueprint).
 * Photos are never logged; keys are opaque user/analysis paths.
 */
export function createLocalObjectStore({ root, ttlMs = 24 * 60 * 60_000 }) {
  const photosRoot = path.join(path.resolve(root), 'photos');

  const keyFor = (userId, analysisId) => {
    const userHash = createHash('sha256').update(userId).digest('hex').slice(0, 16);
    return `${userHash}/${analysisId}.jpg`;
  };

  const abs = (key) => path.join(photosRoot, key);

  return {
    kind: 'local',
    keyFor,
    async putJpeg(userId, analysisId, bytes) {
      const key = keyFor(userId, analysisId);
      const file = abs(key);
      await mkdir(path.dirname(file), { recursive: true });
      const tmp = `${file}.${randomUUID()}.tmp`;
      await writeFile(tmp, bytes);
      const { rename } = await import('node:fs/promises');
      await rename(tmp, file);
      return { key, bytes: bytes.length };
    },
    async getJpeg(key) {
      return readFile(abs(key));
    },
    async delete(key) {
      await removeQuiet(abs(key));
    },
    async cleanupExpired(now = Date.now()) {
      let removed = 0;
      const walk = async (dir) => {
        let entries;
        try {
          entries = await readdir(dir, { withFileTypes: true });
        } catch (error) {
          if (error.code === 'ENOENT') return;
          throw error;
        }
        for (const entry of entries) {
          const full = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            await walk(full);
            continue;
          }
          if (!entry.name.endsWith('.jpg')) continue;
          const st = await stat(full);
          if (now - st.mtimeMs > ttlMs) {
            await removeQuiet(full);
            removed += 1;
          }
        }
      };
      await walk(photosRoot);
      return { removed };
    },
  };
}

/**
 * S3-compatible stub used only when OBJECT_STORE=s3.
 * Requires env: S3_BUCKET, S3_ENDPOINT (optional), AWS credentials via env.
 * Not exercised in local mock suites (no paid resources).
 */
export function createS3ObjectStoreConfig(env = process.env) {
  return {
    kind: 's3',
    bucket: env.S3_BUCKET ?? '',
    endpoint: env.S3_ENDPOINT ?? '',
    region: env.S3_REGION ?? 'auto',
    prefix: env.S3_PREFIX ?? 'food-photos/',
    ttlDays: Number(env.PHOTO_TTL_DAYS ?? 1),
    note: 'Wire @aws-sdk/client-s3 or fetch-presigned PUT in staging; local tests use LocalObjectStore.',
  };
}

/** Marker file so concurrent cleanups do not thrash. */
export async function tryAcquireCleanupLock(metaDir, ttlMs = 60_000) {
  const lockPath = path.join(metaDir, 'cleanup.lock');
  const ok = await createExclusive(lockPath, String(Date.now()));
  if (!ok) {
    try {
      const { readFile } = await import('node:fs/promises');
      const started = Number(await readFile(lockPath, 'utf8'));
      if (Number.isFinite(started) && Date.now() - started > ttlMs) {
        await removeQuiet(lockPath);
        return createExclusive(lockPath, String(Date.now()));
      }
    } catch { /* ignore */ }
    return false;
  }
  return true;
}
