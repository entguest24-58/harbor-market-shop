#!/usr/bin/env bash
# Shared helpers for this feature's API tests. Sourced first by every script.
export BASE_URL="${BASE_URL:-http://app:6713}"
export DATABASE_URL="${DATABASE_URL:-postgresql://app:app@toxiproxy:5432/appdb}"

# --- CodeValid diagnosis markers (parsed by the test runner; do not edit) ---
# cv_step  <Given|When|Then|Cleanup> "<what this section does>" $LINENO
# cv_prereq "<setup being done>" $LINENO
# cv_http  <METHOD> <url|/path> [json-body] [expected-status] [extra curl args, e.g. -H "Authorization: Bearer $T"]
#          performs the request (relative paths go to $BASE_URL), prints REQUEST_*/RESPONSE_*
#          and CV_HTTP|METHOD|url|status|ms, sets CV_HTTP_STATUS CV_HTTP_BODY CV_HTTP_MS
#          CV_HTTP_BODY_FILE CV_HTTP_HEADERS_FILE. Call it directly, never inside $(...).
#          A 3-digit expected-status (with or without a body) is asserted: a different status
#          fails the test via cv_fail. Omit it to assert on $CV_HTTP_STATUS yourself.
# cv_http  <METHOD> <url> <http_status>          (legacy: marker only, right after your own curl)
# cv_fail  "<expected X got Y>" $LINENO           (prints marker, exits 1)
cv_step() { printf 'CV_STEP|%s|%s|line=%s\n' "${1:-}" "${2:-}" "${3:-}"; }
cv_prereq() { printf 'CV_PREREQ|%s|line=%s\n' "${1:-}" "${2:-}"; }
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "${1:-}" "${2:-}"; exit 1; }
_cv_is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
_cv_now_ms() {
  _cv_n=${EPOCHREALTIME:-}
  if [ -n "$_cv_n" ]; then _cv_secs_to_ms "$_cv_n"; return 0; fi
  _cv_n=$(date +%s%3N 2>/dev/null || true)
  _cv_is_int "$_cv_n" || _cv_n=$(( $(date +%s) * 1000 ))
  printf '%s' "$_cv_n"
}
_cv_ms_file() { printf '%s/.cv_last_ms.%s' "${TMPDIR:-/tmp}" "$$"; }
curl() {
  _cv_t0=$(_cv_now_ms)
  _cv_rc=0
  command curl "$@" || _cv_rc=$?
  _cv_t1=$(_cv_now_ms)
  printf '%s' "$((_cv_t1 - _cv_t0))" > "$(_cv_ms_file)" 2>/dev/null || :
  return $_cv_rc
}
# psql without a connection falls back to a local socket seed-test does not have; when
# DATABASE_URL is set and the call names no connection, connect through it.
psql() {
  if [ -n "${DATABASE_URL:-}" ]; then
    case " $* " in
      *" $DATABASE_URL "*|*" -h "*|*" --host"*|*" -d "*|*" --dbname"*|*"postgres://"*|*"postgresql://"*) ;;
      *) command psql "$DATABASE_URL" "$@"; return $? ;;
    esac
  fi
  command psql "$@"
}
_cv_secs_to_ms() {
  _cv_t=$(printf '%s' "${1:-0}" | tr ',' '.')
  _cv_s=${_cv_t%%.*}
  case "$_cv_t" in *.*) _cv_f=${_cv_t#*.}000 ;; *) _cv_f=000 ;; esac
  _cv_f=${_cv_f%"${_cv_f#???}"}
  while [ "${_cv_f#0}" != "$_cv_f" ]; do _cv_f=${_cv_f#0}; done
  _cv_is_int "$_cv_s" || _cv_s=0
  _cv_is_int "$_cv_f" || _cv_f=0
  printf '%s' "$(( _cv_s * 1000 + _cv_f ))"
}
_cv_is_status() { _cv_is_int "${1:-}" && [ ${#1} -eq 3 ]; }
cv_http() {
  if [ $# -ge 3 ] && [ $# -le 4 ] && _cv_is_status "$3" && { [ $# -eq 3 ] || _cv_is_int "$4"; }      && { [ -n "${4:-}" ] || [ -f "$(_cv_ms_file)" ]; }; then
    _cv_ms=${4:-}
    if [ -z "$_cv_ms" ] && [ -f "$(_cv_ms_file)" ]; then
      _cv_ms=$(cat "$(_cv_ms_file)" 2>/dev/null || true)
      rm -f "$(_cv_ms_file)" 2>/dev/null || :
    fi
    _cv_is_int "$_cv_ms" || _cv_ms=''
    printf 'CV_HTTP|%s|%s|%s%s\n' "$1" "$2" "$3" "${_cv_ms:+|$_cv_ms}"
    return 0
  fi
  _cv_method=${1:-GET}
  _cv_url=${2:-/}
  _cv_data=''
  _cv_expect=''
  if [ $# -ge 2 ]; then shift 2; else shift $#; fi
  if [ $# -ge 1 ] && ! _cv_is_status "$1"; then
    case "$1" in -*) ;; *) _cv_data=$1; shift ;; esac
  fi
  if [ $# -ge 1 ] && _cv_is_status "$1"; then _cv_expect=$1; shift; fi
  case "$_cv_url" in /*) _cv_url="${BASE_URL:-http://app:6713}$_cv_url" ;; esac
  CV_HTTP_BODY_FILE="${TMPDIR:-/tmp}/cv_http_body.$$"
  CV_HTTP_HEADERS_FILE="${TMPDIR:-/tmp}/cv_http_headers.$$"
  : > "$CV_HTTP_BODY_FILE"; : > "$CV_HTTP_HEADERS_FILE"
  printf 'REQUEST_HEADERS:\n%s %s\n' "$_cv_method" "$_cv_url"
  printf 'REQUEST_BODY:\n%s\n' "$_cv_data"
  if [ -n "$_cv_data" ]; then
    _cv_w=$(command curl -sS -X "$_cv_method" -H 'Content-Type: application/json' --data "$_cv_data" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  else
    _cv_w=$(command curl -sS -X "$_cv_method" \
      -D "$CV_HTTP_HEADERS_FILE" -o "$CV_HTTP_BODY_FILE" -w '%{http_code} %{time_total}' "$@" "$_cv_url") || true
  fi
  CV_HTTP_STATUS=${_cv_w%% *}
  _cv_is_int "$CV_HTTP_STATUS" || CV_HTTP_STATUS=000
  case "$_cv_w" in *' '*) CV_HTTP_MS=$(_cv_secs_to_ms "${_cv_w#* }") ;; *) CV_HTTP_MS=0 ;; esac
  CV_HTTP_BODY=$(cat "$CV_HTTP_BODY_FILE" 2>/dev/null || true)
  printf 'RESPONSE_HEADERS:\n'; cat "$CV_HTTP_HEADERS_FILE" 2>/dev/null || true
  printf 'RESPONSE_BODY:\n%s\n' "$CV_HTTP_BODY"
  rm -f "$(_cv_ms_file)" 2>/dev/null || :
  printf 'CV_HTTP|%s|%s|%s|%s\n' "$_cv_method" "$_cv_url" "$CV_HTTP_STATUS" "$CV_HTTP_MS"
  if [ -n "$_cv_expect" ] && [ "$CV_HTTP_STATUS" != "$_cv_expect" ]; then
    cv_fail "expected HTTP $_cv_expect from $_cv_method $_cv_url got $CV_HTTP_STATUS: $(printf '%s' "$CV_HTTP_BODY" | head -c 300)" ""
  fi
  return 0
}
# --- end CodeValid diagnosis markers ---

# --- feature helpers (orders history / view / cancel) ---
CV_SUFFIX="${CV_SUFFIX:-$(date +%s%N)$RANDOM}"
CV_PASSWORD="Passw0rd!cv"

# cv_sql "<sql>" -> prints single tab-free result (tuples only)
cv_sql() { command psql "$DATABASE_URL" -tAqX -v ON_ERROR_STOP=1 -c "$1"; }

# cv_new_shopper <label> -> sets SHOPPER_ID SHOPPER_TOKEN SHOPPER_EMAIL
cv_new_shopper() {
  local label=$1 email
  email="cv_${label}_${CV_SUFFIX}@example.com"
  cv_prereq "register shopper $label" "${2:-}"
  cv_http POST /auth/register "{\"email\":\"$email\",\"name\":\"CV $label\",\"password\":\"$CV_PASSWORD\"}"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $label got $CV_HTTP_STATUS" "${2:-}"
  SHOPPER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id')
  cv_http POST /auth/login "{\"email\":\"$email\",\"password\":\"$CV_PASSWORD\"}"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 logging in $label got $CV_HTTP_STATUS" "${2:-}"
  SHOPPER_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
  SHOPPER_EMAIL=$email
  [ -n "$SHOPPER_TOKEN" ] && [ "$SHOPPER_TOKEN" != "null" ] || cv_fail "expected token for $label got none" "${2:-}"
  CV_USER_IDS="${CV_USER_IDS:-} $SHOPPER_ID"
}

# cv_new_product <name> <price_cents> <stock> -> sets PRODUCT_ID
cv_new_product() {
  PRODUCT_ID=$(cv_sql "INSERT INTO products (name, category, price_cents, stock) VALUES ('$1 $CV_SUFFIX', 'cvtest', $2, $3) RETURNING id") \
    || cv_fail "expected product $1 inserted got psql error" "${4:-}"
  [ -n "$PRODUCT_ID" ] || cv_fail "expected product id for $1 got empty" "${4:-}"
  CV_PRODUCT_IDS="${CV_PRODUCT_IDS:-} $PRODUCT_ID"
}

# cv_new_discount <prefix> <type> <value> -> sets DISCOUNT_CODE DISCOUNT_ID
cv_new_discount() {
  DISCOUNT_CODE="$1$(printf '%s' "$CV_SUFFIX" | tail -c 12)"
  DISCOUNT_CODE=${DISCOUNT_CODE:0:20}
  DISCOUNT_ID=$(cv_sql "INSERT INTO discount_codes (code, type, value) VALUES ('$DISCOUNT_CODE', '$2', $3) RETURNING id") \
    || cv_fail "expected discount code inserted got psql error" "${4:-}"
  CV_DISCOUNT_IDS="${CV_DISCOUNT_IDS:-} $DISCOUNT_ID"
}

# cv_place_order <token> <product_id> <qty> [discount_code] -> sets ORDER_ID ORDER_JSON
cv_place_order() {
  local token=$1 pid=$2 qty=$3 code=${4:-} body='{}'
  cv_http POST /cart/items "{\"productId\":$pid,\"quantity\":$qty}" -H "Authorization: Bearer $token"
  [ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 adding to cart got $CV_HTTP_STATUS" "${5:-}"
  [ -n "$code" ] && body="{\"discountCode\":\"$code\"}"
  cv_http POST /orders/checkout "$body" -H "Authorization: Bearer $token"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from checkout got $CV_HTTP_STATUS" "${5:-}"
  ORDER_JSON=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
  ORDER_ID=$(printf '%s' "$ORDER_JSON" | jq -r '.id')
  _cv_is_int "$ORDER_ID" || cv_fail "expected order id from checkout got $ORDER_ID" "${5:-}"
}

# cv_set_order_status <order_id> <status>
cv_set_order_status() {
  cv_sql "UPDATE orders SET status = '$2', updated_at = now() WHERE id = $1" >/dev/null \
    || cv_fail "expected order $1 set to $2 got psql error" "${3:-}"
}

# cv_set_order_created <order_id> <interval ago, e.g. '3 days'>
cv_set_order_created() {
  cv_sql "UPDATE orders SET created_at = now() - interval '$2' WHERE id = $1" >/dev/null \
    || cv_fail "expected order $1 created_at set got psql error" "${3:-}"
}

cv_cleanup() {
  local u p d
  for u in ${CV_USER_IDS:-}; do
    cv_sql "DELETE FROM orders WHERE user_id = $u; DELETE FROM cart_items WHERE user_id = $u; DELETE FROM users WHERE id = $u" >/dev/null || true
  done
  for p in ${CV_PRODUCT_IDS:-}; do
    cv_sql "DELETE FROM order_items WHERE product_id = $p; DELETE FROM cart_items WHERE product_id = $p; DELETE FROM products WHERE id = $p" >/dev/null || true
  done
  for d in ${CV_DISCOUNT_IDS:-}; do
    cv_sql "DELETE FROM orders WHERE discount_code_id = $d; DELETE FROM discount_codes WHERE id = $d" >/dev/null || true
  done
}
