#!/usr/bin/env bash
# Print "<the id OpenCode files a model's route under>/<model>", so nothing outside
# configs.jsonc has to spell a model id or a provider prefix.
#
#   bin/model-ref.sh <provider> [main|small]

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1090
source "$ROOT/bin/common.sh"

provider=${1:?usage: model-ref.sh <provider> [main|small]}
role=${2:-main}

models_resolve "$provider"

case $role in
  main) printf '%s/%s\n' "$(route_id "$M_DEFAULT_API")" "$M_DEFAULT_MODEL" ;;
  small) printf '%s/%s\n' "$(route_id "$M_SMALL_API")" "$M_SMALL_MODEL" ;;
  *) echo "model-ref.sh: role must be 'main' or 'small', got '$role'" >&2; exit 2 ;;
esac
