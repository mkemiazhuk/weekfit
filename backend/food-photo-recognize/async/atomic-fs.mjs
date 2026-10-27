import { randomUUID } from 'node:crypto';
import { closeSync, fsyncSync, mkdirSync, openSync } from 'node:fs';
import { rename, readFile, unlink, open, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { ServiceError } from '../recognition.mjs';

const loggedDirectoryFsync = new Set();

function logDirectoryFsyncUnconfirmed(errno) {
  const code = errno || 'unknown';
  if (loggedDirectoryFsync.has(code)) return;
  loggedDirectoryFsync.add(code);
  console.error(JSON.stringify({
    event: 'durability_unconfirmed',
    reason: 'directory_fsync_unconfirmed',
    errno: code,
    message: 'Directory fsync did not confirm the rename is durable. Production blocks new AI calls.',
  }));
}

/** A failed directory fsync is not a successful durable publish. */
export function errorForDirectoryFsync(error) {
  const errno = error?.code || 'unknown';
  logDirectoryFsyncUnconfirmed(errno);
  return new ServiceError('durability_unconfirmed', 503, {
    detail: `directory_fsync_${errno}`,
  });
}

async function syncDirectory(directory) {
  const handle = await open(directory, 'r');
  try {
    await handle.sync();
  } catch (error) {
    throw errorForDirectoryFsync(error);
  } finally {
    await handle.close();
  }
}

/**
 * One directory fsync. confirmed:false means this filesystem did not prove the rename is durable.
 */
export function probeDirectoryDurable(directory) {
  mkdirSync(directory, { recursive: true });
  const fd = openSync(directory, 'r');
  try {
    fsyncSync(fd);
    return { confirmed: true, reason: null, errno: null };
  } catch (error) {
    const errno = error.code || 'unknown';
    logDirectoryFsyncUnconfirmed(errno);
    return { confirmed: false, reason: 'directory_fsync_unconfirmed', errno };
  } finally {
    closeSync(fd);
  }
}

/**
 * Production refuses a new provider call when directory durability was not confirmed.
 * The reason is the errno from fsync, not a generic store failure.
 */
export function assertDurableGeneration(config) {
  const status = config?.directoryDurability;
  if (!config?.isProduction || !status || status.confirmed !== false) return;
  const errno = status.errno || 'unknown';
  console.error(JSON.stringify({
    event: 'ai_call_blocked',
    reason: status.reason || 'directory_fsync_unconfirmed',
    errno,
    detail: `directory_fsync_${errno}`,
  }));
  throw new ServiceError('durability_unconfirmed', 503, {
    detail: `directory_fsync_${errno}`,
  });
}

/**
 * Publish JSON only after the temp file is fsynced and renamed.
 * A failed sync leaves the destination untouched and throws, so the caller must not call a provider.
 */
export async function writeJsonAtomic(filePath, value) {
  const directory = path.dirname(filePath);
  await mkdir(directory, { recursive: true });
  const tmp = `${filePath}.${process.pid}.${randomUUID()}.tmp`;
  const body = `${JSON.stringify(value, null, 0)}\n`;
  const handle = await open(tmp, 'w');
  try {
    await handle.writeFile(body);
    await handle.sync();
  } catch (error) {
    await handle.close().catch(() => {});
    await unlink(tmp).catch(() => {});
    throw error;
  }
  await handle.close();
  await rename(tmp, filePath);
  await syncDirectory(directory);
}

export async function readJson(filePath, fallback = null) {
  try {
    const raw = await readFile(filePath, 'utf8');
    return JSON.parse(raw);
  } catch (error) {
    if (error.code === 'ENOENT') return fallback;
    throw error;
  }
}

/** Exclusive create — returns true if we created the file. */
export async function createExclusive(filePath, contents = '') {
  const directory = path.dirname(filePath);
  await mkdir(directory, { recursive: true });
  let handle;
  try {
    handle = await open(filePath, 'wx');
  } catch (error) {
    if (error.code === 'EEXIST') return false;
    throw error;
  }
  try {
    await handle.writeFile(contents);
    await handle.sync();
  } catch (error) {
    await handle.close().catch(() => {});
    throw error;
  }
  await handle.close();
  await syncDirectory(directory);
  return true;
}

export async function removeQuiet(filePath) {
  try {
    await unlink(filePath);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}
