#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a cart subtotal of 2000 cents and a code requiring 10000 cents minimum" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.min.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
PID=$(cv_seed_product "CV Min Product $SFX" 1000 10) || cv_fail "expected product row created got error" $LINENO
CODE="MIN$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" fixed 500 10000 NULL true) || cv_fail "expected discount code row created got error" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO

# When
cv_step When "shopper checks out with the minimum-spend code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "refused explaining the minimum subtotal; no order, stock or usage change" $LINENO
[ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -q '100\.00' || cv_fail "expected error stating minimum subtotal \$100.00 got '$ERR'" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID")
[ "$ORD" = "0" ] || cv_fail "expected 0 orders got $ORD" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "10" ] || cv_fail "expected stock 10 got $STOCK" $LINENO
CART=$(cv_count "SELECT coalesce(sum(quantity),0) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "2" ] || cv_fail "expected cart quantity 2 got $CART" $LINENO
USED=$(cv_count "SELECT count(*) FROM orders WHERE discount_code_id=$CID")
[ "$USED" = "0" ] || cv_fail "expected code usage 0 got $USED" $LINENO

# Cleanup
cv_step Cleanup "remove user, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_refused_minimum_subtotal_not_met"
