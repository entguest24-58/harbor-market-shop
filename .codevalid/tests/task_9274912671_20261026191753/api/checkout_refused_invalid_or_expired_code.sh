#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with items in cart, an expired code and a deactivated code" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CEXP=""; COFF=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "${CEXP:-0},${COFF:-0}"; }
trap cleanup EXIT
cv_register_login "cv.badcode.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
PID=$(cv_seed_product "CV BadCode Product $SFX" 3000 10) || cv_fail "expected product row created got error" $LINENO
EXP="EXP$SFX"; EXP=${EXP:0:20}
OFF="OFF$SFX"; OFF=${OFF:0:20}
MISSING="NOPE$SFX"; MISSING=${MISSING:0:20}
CEXP=$(cv_seed_code "$EXP" percentage 10 0 "now() - interval '1 day'" true) || cv_fail "expected expired code created got error" $LINENO
COFF=$(cv_seed_code "$OFF" percentage 10 0 NULL false) || cv_fail "expected deactivated code created got error" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO

# When
cv_step When "shopper checks out with a nonexistent, an expired and a deactivated code" $LINENO
cv_http POST /orders/checkout "{\"couponCode\":\"$MISSING\"}" -H "Authorization: Bearer $TOKEN"
ST_MISSING=$CV_HTTP_STATUS; ERR_MISSING=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
cv_http POST /orders/checkout "{\"couponCode\":\"$EXP\"}" -H "Authorization: Bearer $TOKEN"
ST_EXP=$CV_HTTP_STATUS; ERR_EXP=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
cv_http POST /orders/checkout "{\"couponCode\":\"$OFF\"}" -H "Authorization: Bearer $TOKEN"
ST_OFF=$CV_HTTP_STATUS; ERR_OFF=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')

# Then
cv_step Then "each refused with a clear reason; no order, stock, cart or usage change" $LINENO
[ "$ST_MISSING" = "400" ] || cv_fail "expected 400 for nonexistent code got $ST_MISSING" $LINENO
printf '%s' "$ERR_MISSING" | grep -qi 'not exist' || cv_fail "expected 'does not exist' reason got '$ERR_MISSING'" $LINENO
[ "$ST_EXP" = "400" ] || cv_fail "expected 400 for expired code got $ST_EXP" $LINENO
printf '%s' "$ERR_EXP" | grep -qi 'expired' || cv_fail "expected 'expired' reason got '$ERR_EXP'" $LINENO
[ "$ST_OFF" = "400" ] || cv_fail "expected 400 for deactivated code got $ST_OFF" $LINENO
printf '%s' "$ERR_OFF" | grep -qi 'no longer active' || cv_fail "expected 'no longer active' reason got '$ERR_OFF'" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID")
[ "$ORD" = "0" ] || cv_fail "expected 0 orders got $ORD" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "10" ] || cv_fail "expected stock 10 got $STOCK" $LINENO
CART=$(cv_count "SELECT coalesce(sum(quantity),0) FROM cart_items WHERE user_id=$USER_ID AND product_id=$PID")
[ "$CART" = "2" ] || cv_fail "expected cart quantity 2 got $CART" $LINENO
USED=$(cv_count "SELECT count(*) FROM orders WHERE discount_code_id IN ($CEXP,$COFF)")
[ "$USED" = "0" ] || cv_fail "expected code usage 0 got $USED" $LINENO

# Cleanup
cv_step Cleanup "remove user, product and codes" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_refused_invalid_or_expired_code"
