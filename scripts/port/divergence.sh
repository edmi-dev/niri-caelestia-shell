#!/usr/bin/env bash
# Lists every NIRI-PORT(<ID>) marker grouped by ID — our divergence from upstream.
#
# Usage: divergence.sh [ID]        markers (optionally only for one ID)
#        divergence.sh --files     files containing markers, with counts
set -euo pipefail

root="${PORT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$root"

marker='NIRI-PORT\(([A-Za-z0-9_-]+)\)'
excl=(-g '!.git' -g '!build/**' -g '!docs/**' -g '!scripts/port/**' -g '!*.md')

if [[ "${1:-}" == "--files" ]]; then
    rg -c "${excl[@]}" -e "$marker" . | sed 's|^\./||' | sort
    exit 0
fi

id_re="${1:-[A-Za-z0-9_-]+}"
rg -n --no-heading "${excl[@]}" -e "NIRI-PORT\(($id_re)\)" . \
    | sed -E 's|^\./||; s|^([^:]+:[0-9]+):.*NIRI-PORT\(([^)]+)\):?\s*(.*)$|\2\t\1\t\3|' \
    | sort -t$'\t' -k1,1V -k2,2 \
    | awk -F'\t' '$1 != cur { cur = $1; print "## " cur } { printf "  %-55s %s\n", $2, $3 }'
