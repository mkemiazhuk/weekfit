/**
 * Redis adapters are implemented in redis-backend.mjs + redis-client.mjs.
 * Local multi-process tests use mini-redis.mjs (RESP-compatible).
 * Production requires REDIS_URL + STATE_BACKEND=redis (see bootstrap.mjs).
 */
export {
  createRedisJobStore,
  createRedisQuotaStore,
  createRedisAiSlots,
  createRedisCircuitBreaker,
  createRedisProviderBudget,
} from './redis-backend.mjs';

export { createRedisClient, parseRedisUrl } from './redis-client.mjs';
export { createMiniRedisServer } from './mini-redis.mjs';

export function describeRedisPlan() {
  return {
    required: ['REDIS_URL', 'STATE_BACKEND=redis'],
    objectStore: ['OBJECT_STORE=s3|http', 'OBJECT_STORE_BASE_URL or S3_*'],
    keys: [
      'wf:job:{analysisId}',
      'wf:idem:{user}:{key}',
      'wf:queue:ready',
      'wf:lease:{analysisId}',
      'wf:lease:z',
      'wf:quota:res:{analysisId}',
      'wf:quota:user:{day}:{user}',
      'wf:quota:global:{day}',
      'wf:ai-slots:z',
      'wf:circuit',
      'wf:spend:{day}',
    ],
    note: 'Photos never in Redis — object store keys only. Production forbids shared DATA_DIR.',
  };
}
