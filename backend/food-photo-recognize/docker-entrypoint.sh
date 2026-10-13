#!/bin/sh
# Single-container API + optional async worker (Render disk / ALLOW_SINGLE_NODE_ASYNC).
set -eu

start_worker=0
case "${ASYNC_ANALYSIS:-}" in
  1|true|TRUE) start_worker=1 ;;
esac
if [ -n "${DATA_DIR:-}${WEEKFIT_DATA_DIR:-}" ]; then
  start_worker=1
fi
if [ "${STATE_BACKEND:-}" = "redis" ]; then
  start_worker=1
fi

worker_pid=""
cleanup() {
  if [ -n "$worker_pid" ]; then
    kill "$worker_pid" 2>/dev/null || true
    wait "$worker_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if [ "$start_worker" = "1" ]; then
  node worker.mjs &
  worker_pid=$!
fi

exec node server.mjs
