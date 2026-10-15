import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { configuration } from './server.mjs';

/** PID 1 supervises both processes. A dead worker must never leave a healthy API. */
export function supervise({ env = process.env, spawnProcess = spawn, signals = process, shutdownMs = 28_000 } = {}) {
  const config = configuration(env);
  const children = new Set();
  let stopping = false;
  let exitCode = 0;
  let killTimer;
  let finish;
  const completion = new Promise(resolve => { finish = resolve; });
  const onTerm = () => stop(0);
  const stop = code => {
    if (stopping) return;
    stopping = true;
    exitCode = code;
    for (const child of children) child.kill('SIGTERM');
    killTimer = setTimeout(() => {
      for (const child of children) child.kill('SIGKILL');
    }, shutdownMs);
    killTimer.unref();
  };
  const done = child => {
    if (!children.delete(child)) return;
    if (!stopping) stop(1);
    if (!children.size) {
      clearTimeout(killTimer);
      signals.off('SIGTERM', onTerm);
      signals.off('SIGINT', onTerm);
      finish(exitCode);
    }
  };
  signals.on('SIGTERM', onTerm);
  signals.on('SIGINT', onTerm);
  for (const script of ['server.mjs', ...(config.asyncEnabled ? ['worker.mjs'] : [])]) {
    const child = spawnProcess(process.execPath, [script], { env, stdio: 'inherit' });
    children.add(child);
    child.once('error', () => done(child));
    child.once('exit', () => done(child));
  }
  return { completion, stop };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  supervise().completion.then(code => process.exit(code));
}
