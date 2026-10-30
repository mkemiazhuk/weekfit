import { DatabaseSync } from 'node:sqlite';
import { existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { BillingStore } from './billing-store.mjs';
import { createAppleBilling } from './billing-apple.mjs';
import { createBillingService } from './billing-service.mjs';
import { createPlannerCallLine, createPlannerVoiceHandler } from './planner-voice.mjs';

const reply = (res, status, error) => {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify({ error }));
  return true;
};

// One process, one persistent SQLite connection, two disjoint sets of tables.
// The header chooses a verifier, never an entitlement. Apple must sign that environment.
export function createBillingRouter(config, dependencies = {}) {
  const enabled = { Production: config.billingEnabled === true, Sandbox: config.sandboxBillingEnabled === true };
  if (!enabled.Production && !enabled.Sandbox) return {
    handle: async (req, res) => req.headers['x-weekfit-billing-environment'] === 'Sandbox'
      ? reply(res, 503, 'billing_environment_disabled') : false,
    close() {},
  };
  if (!config.dataDirExplicit || config.stateBackend === 'redis' || !config.allowSingleNode) {
    throw Error('AI billing requires one API process and an explicit persistent DATA_DIR');
  }
  // Never silently start an empty ledger when an older per-environment database exists.
  for (const environment of ['Production', 'Sandbox']) {
    if (existsSync(path.join(config.dataDir, `billing-${environment}.sqlite`))) {
      throw Error('Legacy billing database detected: migrate it before enabling namespaced billing tables');
    }
  }
  const envs = Object.keys(enabled).filter(environment => enabled[environment]);
  const apples = Object.fromEntries(envs.map(environment => {
    const apple = dependencies.apples?.[environment] ?? createAppleBilling({ ...process.env,
      BILLING_APPLE_ENVIRONMENT: environment,
      ...(environment === 'Sandbox' ? { BILLING_EXISTING_PHOTO_CUTOFF: '1970-01-01T00:00:00Z' } : {}),
    });
    if (apple.environment !== environment) throw Error('Billing verifier environment mismatch');
    return [environment, apple];
  }));
  mkdirSync(config.dataDir, { recursive: true });
  const filename = path.join(config.dataDir, 'billing.sqlite');
  const database = new DatabaseSync(filename);
  const line = dependencies.line ?? createPlannerCallLine({ maxCalls: config.plannerVoiceMaxCalls ?? 5,
    maxWaiting: config.plannerVoiceMaxWaiting ?? 100 });
  const services = {}, stores = {}, voices = {};
  // Create both schemas even during Sandbox-only rollout; a disabled environment has no handlers.
  for (const environment of ['Production', 'Sandbox']) {
    stores[environment] = new BillingStore(filename, { database, environment,
      maxVoiceCalls: environment === 'Sandbox' ? 1 : (config.plannerVoiceMaxCalls ?? 5) });
  }
  for (const environment of envs) {
    const sandbox = environment === 'Sandbox';
    const runtime = { ...config, billingEnabled: true,
      ...(sandbox ? { maxConcurrency: 1, plannerVoiceMaxCalls: 1,
        maxProviderCallsPerDay: config.sandboxPhotoBudget ?? 20 } : {}),
    };
    const authenticate = async (...args) => `${environment}:${await dependencies.authenticate(...args)}`;
    const log = entry => (dependencies.log ?? (value => console.info(JSON.stringify(value))))({ ...entry, environment });
    services[environment] = createBillingService(runtime, { ...dependencies, authenticate, line, log,
      apple: apples[environment], store: stores[environment] });
    voices[environment] = createPlannerVoiceHandler(runtime, { authenticate, line,
      log });
  }
  let closeTask;
  return {
    stores,
    async handle(req, res) {
      const route = (req.url ?? '').split('?')[0];
      const hint = req.headers['x-weekfit-billing-environment'];
      const notification = route === '/v2/billing/notifications' || route === '/v2/billing/notifications/sandbox';
      const environment = notification
        ? (route.endsWith('/sandbox') ? 'Sandbox' : 'Production') : (hint ?? 'Production');
      const relevant = route.startsWith('/v2/ai/') || notification || route.startsWith('/v1/planner-voice/');
      if (!relevant) {
        // Sandbox must never fall through to a legacy production photo/provider endpoint.
        return hint === 'Sandbox' ? reply(res, 426, 'app_update_required') : false;
      }
      if (!['Production', 'Sandbox'].includes(environment) || (hint != null && hint !== environment)) {
        return reply(res, 400, 'invalid_billing_environment');
      }
      if (!enabled[environment]) {
        if (environment === 'Sandbox') return reply(res, 503, 'billing_environment_disabled');
        return false; // Existing production endpoints stay available while only Sandbox is enabled.
      }
      const originalURL = req.url;
      try {
        if (notification) req.url = '/v2/billing/notifications';
        if (await services[environment].handle(req, res)) return true;
        if (route.startsWith('/v1/planner-voice/')) {
          if (['/v1/planner-voice/session', '/v1/planner-voice/console'].includes(route)) {
            return reply(res, 426, 'app_update_required');
          }
          return voices[environment](req, res);
        }
        return false;
      } finally { req.url = originalURL; }
    },
    close() {
      closeTask ??= (async () => {
        const results = await Promise.allSettled(Object.values(services).map(service => service.close()));
        database.close();
        const failures = results.filter(result => result.status === 'rejected').map(result => result.reason);
        if (failures.length) throw new AggregateError(failures, 'Billing shutdown failed');
      })();
      return closeTask;
    },
  };
}
