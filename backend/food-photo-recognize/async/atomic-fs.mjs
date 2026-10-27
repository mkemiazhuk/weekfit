import { randomUUID } from 'node:crypto';
import { rename, readFile, unlink, open, mkdir } from 'node:fs/promises';
import path from 'node:path';

async function syncDirectory(directory) {
  const handle = await open(directory, 'r');
  try {
    await handle.sync();
  } catch (error) {
    // Some filesystems reject fsync on a directory. The file itself was already synced.
    if (error.code !== 'EINVAL' && error.code !== 'ENOTSUP' && error.code !== 'EPERM') throw error;
  } finally {
    await handle.close();
  }
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
