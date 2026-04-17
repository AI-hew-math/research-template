#!/bin/bash
# Root wrapper for the legacy bootstrap_logging.sh helper
# Usage: ./scripts/bootstrap_logging.sh /path/to/existing_project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../templates/scripts/bootstrap_logging.sh" "$@"
