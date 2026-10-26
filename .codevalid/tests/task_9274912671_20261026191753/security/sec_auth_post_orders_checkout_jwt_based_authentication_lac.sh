#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

CAT=auth; SEV=warning
TITLE="JWT-based authentication lacks explicit rate limiting or lockout on invalid tokens"

cv_step When "flood POST /orders/checkout with invalid bearer tokens" $LINENO
cv_http GET /health
[ "$CV_HTTP_STATUS" = "200" ] || { echo "app unreachable (health $CV_HTTP_STATUS)"; exit 1; }

N=25; C401=0; C429=0; OTHER=0; FIRST_MS=""; LAST_MS=""; RL_HDR=0
for i in $(seq 1 "$N"); do
  case $((i % 3)) in
    0) TOK="not-a-jwt-$RANDOM" ;;
    1) TOK="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiaWQiOjF9.wrongsig$RANDOM" ;;
    2) TOK="eyJhbGciOiJub25lIn0.eyJpZCI6MX0." ;;
  esac
  cv_http POST /orders/checkout '{}' -H "Authorization: Bearer $TOK"
  case "$CV_HTTP_STATUS" in
    401) C401=$((C401 + 1)) ;;
    429) C429=$((C429 + 1)) ;;
    *) OTHER=$((OTHER + 1)) ;;
  esac
  grep -qiE '^(x-)?ratelimit|^retry-after' "$CV_HTTP_HEADERS_FILE" 2>/dev/null && RL_HDR=$((RL_HDR + 1))
  [ -z "$FIRST_MS" ] && FIRST_MS=$CV_HTTP_MS
  LAST_MS=$CV_HTTP_MS
done

cv_step Then "decide whether repeated invalid tokens were throttled" $LINENO
EVID="$N invalid-token requests: 401=$C401 429=$C429 other=$OTHER ratelimit-headers=$RL_HDR first=${FIRST_MS}ms last=${LAST_MS}ms"
if [ "$C429" -eq 0 ] && [ "$RL_HDR" -eq 0 ]; then
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "$EVID - no throttling or lockout observed"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "$EVID"
fi
exit 0
