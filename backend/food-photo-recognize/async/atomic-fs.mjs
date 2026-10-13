import { randomUUID } from 'node:crypto';
import { rename, writeFile, readFile, unlink, open, mkdir } from 'node:fs/promises';
import path from 'node:path';

/** Write JSON atomically (temp + rename). */
export async function writeJsonAtomic(filePath, value) {
  await mkdir(path.dirname(filePath), { recursive: true });
  const tmp = `${filePath}.${process.pid}.${randomUUID()}.tmp`;
  const body = `${JSON.stringify(value, null, 0)}\n`;
  await writeFile(tmp, body, { encoding: 'utf8', flag: 'w' });
  await rename(tmp, filePath);
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
  await mkdir(path.dirname(filePath), { recursive: true });
  try {
    const handle = await open(filePath, 'wx');
    await handle.writeFile(contents);
    await handle.close();
    return true;
  } catch (error) {
    if (error.code === 'EEXIST') return false;
    throw error;
  }
}

export async function removeQuiet(filePath) {
  try {
    await unlink(filePath);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}
