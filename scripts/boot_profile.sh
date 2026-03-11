#!/bin/bash
# Rails boot time profiling script
# Usage: ./scripts/boot_profile.sh [production|development]

set -e

ENV="${1:-development}"
echo "=== Rails Boot Profile (RAILS_ENV=$ENV) ==="
echo ""
echo "Cold boot measurement:"
RAILS_ENV=$ENV time -p bundle exec rails runner 'puts :ok' 2>&1
echo ""
echo "Run multiple times for consistency; production boot is slower (eager_load)."
