import path from 'node:path';
import { mkdir } from 'node:fs/promises';

export function dataPaths(root) {
  const base = path.resolve(root);
  return {
    root: base,
    photos: path.join(base, 'photos'),
    jobs: path.join(base, 'jobs'),
    results: path.join(base, 'results'),
    idempotency: path.join(base, 'idempotency'),
    queueReady: path.join(base, 'queue', 'ready'),
    queueLeased: path.join(base, 'queue', 'leased'),
    quotaUsers: path.join(base, 'quota', 'users'),
    quotaGlobal: path.join(base, 'quota', 'global'),
    meta: path.join(base, 'meta'),
  };
}

export async function ensureDataDirs(paths) {
  await Promise.all([
    paths.photos,
    paths.jobs,
    paths.results,
    paths.idempotency,
    paths.queueReady,
    paths.queueLeased,
    paths.quotaUsers,
    paths.quotaGlobal,
    paths.meta,
  ].map((dir) => mkdir(dir, { recursive: true })));
}
