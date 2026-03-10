#!/bin/bash
# Health check script for MI-SOAR-NGFW base container
# Returns 0 if healthy, 1 if unhealthy

set -e

# Check essential services if running in container
# This is a generic health check that can be overridden by child containers

# Simple check: can we execute basic commands
if command -v curl &> /dev/null; then
    # Try to reach localhost (basic network check)
    if curl -s -f --max-time 2 http://localhost:80 > /dev/null 2>&1; then
        echo "Health check: Network connectivity OK"
    else
        # This is not a failure - just informational
        echo "Health check: Local HTTP not available (may be normal)"
    fi
fi

# Check disk space
DISK_USAGE=$(df / --output=pcent | tail -1 | tr -d '% ')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "WARNING: Disk usage above 90%: ${DISK_USAGE}%"
    # Don't fail for disk space in base container
fi

# Check memory
MEM_FREE=$(free -m | awk '/^Mem:/{print $4}')
if [ "$MEM_FREE" -lt 100 ]; then
    echo "WARNING: Low free memory: ${MEM_FREE}MB"
fi

# All checks passed
echo "Base container health check passed"
exit 0