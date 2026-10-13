// Load harness only: never imported by production entrypoints.
if (typeof process.send === 'function') {
  let previous = process.cpuUsage();
  let at = performance.now();
  setInterval(() => {
    const now = performance.now();
    const current = process.cpuUsage();
    const cpuMs = (current.user - previous.user + current.system - previous.system) / 1000;
    process.send?.({ probe: true, rssBytes: process.memoryUsage().rss,
      cpuPercentOneCore: 100 * cpuMs / (now - at) });
    previous = current; at = now;
  }, 500).unref();
}
