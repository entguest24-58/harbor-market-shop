#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper who already placed an order with the code and has a new cart" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.reuse.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
PID=$(cv_seed_product "CV Reuse Product $SFX" 3000 10) || cv_fail "expected product row created got error" $LINENO
CODE="RU$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" percentage 10 0 NULL true) || cv_fail "expected discount code row created got error" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO
cv_prereq "first checkout using the code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" 201 -H "Authorization: Bearer $TOKEN"
cv_add_to_cart "$TOKEN" "$PID" 1 $LINENO

# When
cv_step When "shopper checks out again with the same code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "refused as already used; no new order, stock and cart unchanged" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi 'already been used' || cv_fail "expected 'already been used' reason got '$ERR'" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID")
[ "$ORD" = "1" ] || cv_fail "expected 1 order (the first) got $ORD" $LINENO
USED=$(cv_count "SELECT count(*) FROM orders WHERE discount_code_id=$CID")
[ "$USED" = "1" ] || cv_fail "expected code usage 1 got $USED" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "8" ] || cv_fail "expected stock 8 got $STOCK" $LINENO
CART=$(cv_count "SELECT coalesce(sum(quantity),0) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "1" ] || cv_fail "expected cart quantity 1 got $CART" $LINENO

# Cleanup
cv_step Cleanup "remove user, orders, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_refused_discount_code_reused_by_same_shopper"
