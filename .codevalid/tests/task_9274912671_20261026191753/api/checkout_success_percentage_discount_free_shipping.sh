#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with 2 x 3000-cent product in cart and an active 10% code" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.pct.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
cv_prereq "seed product and discount code" $LINENO
PID=$(cv_seed_product "CV Pct Product $SFX" 3000 10) || cv_fail "expected product row created got error" $LINENO
CODE="PCT$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" percentage 10 0 NULL true) || cv_fail "expected discount code row created got error" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO

# When
cv_step When "shopper checks out with the percentage code (typed lowercase)" $LINENO
LOWER=$(printf '%s' "$CODE" | tr 'A-Z' 'a-z')
cv_http POST /orders/checkout "{\"couponCode\":\"$LOWER\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order created with 10% off, free shipping, stock reduced, cart emptied" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq '.order')
[ "$(jq -r '.status' <<<"$O")" = "placed" ] || cv_fail "expected status placed got $(jq -r '.status' <<<"$O")" $LINENO
[ "$(jq -r '.subtotalCents' <<<"$O")" = "6000" ] || cv_fail "expected subtotalCents 6000 got $(jq -r '.subtotalCents' <<<"$O")" $LINENO
[ "$(jq -r '.discountCents' <<<"$O")" = "600" ] || cv_fail "expected discountCents 600 got $(jq -r '.discountCents' <<<"$O")" $LINENO
[ "$(jq -r '.shippingCents' <<<"$O")" = "0" ] || cv_fail "expected shippingCents 0 got $(jq -r '.shippingCents' <<<"$O")" $LINENO
[ "$(jq -r '.totalCents' <<<"$O")" = "5400" ] || cv_fail "expected totalCents 5400 got $(jq -r '.totalCents' <<<"$O")" $LINENO
[ "$(jq -r '.discountCode' <<<"$O")" = "$CODE" ] || cv_fail "expected discountCode $CODE got $(jq -r '.discountCode' <<<"$O")" $LINENO
[ "$(jq -r '.items | length' <<<"$O")" = "1" ] || cv_fail "expected 1 order item got $(jq -r '.items|length' <<<"$O")" $LINENO
[ "$(jq -r '.items[0].quantity' <<<"$O")" = "2" ] || cv_fail "expected item quantity 2 got $(jq -r '.items[0].quantity' <<<"$O")" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "8" ] || cv_fail "expected stock 8 got $STOCK" $LINENO
CART=$(cv_count "SELECT count(*) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "0" ] || cv_fail "expected empty cart got $CART lines" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID AND discount_code_id=$CID AND total_cents=5400")
[ "$ORD" = "1" ] || cv_fail "expected 1 persisted order with code and total 5400 got $ORD" $LINENO

# Cleanup
cv_step Cleanup "remove user, orders, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_success_percentage_discount_free_shipping"
