#!/bin/sh
set -eu
# Supervise API and worker together, including shutdown and unexpected exits.
exec node container.mjs
