#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a cart with an in-stock line and a line whose stock dropped below the cart quantity" $LINENO
SFX=$(cv_suffix)
USER_ID=""; P1=""; P2=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "${P1:-0},${P2:-0}"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.unav.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
P1=$(cv_seed_product "CV OK Product $SFX" 2000 10) || cv_fail "expected product row created got error" $LINENO
P2=$(cv_seed_product "CV Scarce Product $SFX" 1500 5) || cv_fail "expected product row created got error" $LINENO
CODE="UNA$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" percentage 10 0 NULL true) || cv_fail "expected discount code row created got error" $LINENO
cv_add_to_cart "$TOKEN" "$P1" 2 $LINENO
cv_add_to_cart "$TOKEN" "$P2" 3 $LINENO
cv_prereq "drop stock of second product to 1" $LINENO
cv_sql "UPDATE products SET stock = 1 WHERE id = $P2" >/dev/null || cv_fail "expected stock update to succeed" $LINENO

# When
cv_step When "shopper checks out with a valid code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "checkout refused naming the line; stock, orders, cart and code usage unchanged" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -q "CV Scarce Product $SFX" || cv_fail "expected error naming the unavailable product got '$ERR'" $LINENO
S1=$(cv_count "SELECT stock FROM products WHERE id=$P1"); S2=$(cv_count "SELECT stock FROM products WHERE id=$P2")
[ "$S1" = "10" ] || cv_fail "expected stock of available product 10 got $S1" $LINENO
[ "$S2" = "1" ] || cv_fail "expected stock of scarce product 1 got $S2" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID")
[ "$ORD" = "0" ] || cv_fail "expected 0 orders got $ORD" $LINENO
CART=$(cv_count "SELECT count(*) || ':' || coalesce(sum(quantity),0) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "2:5" ] || cv_fail "expected cart unchanged (2 lines, 5 units) got $CART" $LINENO
USED=$(cv_count "SELECT count(*) FROM orders WHERE discount_code_id=$CID")
[ "$USED" = "0" ] || cv_fail "expected code usage 0 got $USED" $LINENO

# Cleanup
cv_step Cleanup "remove user, products and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_refused_unavailable_line"
