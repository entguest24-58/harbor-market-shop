#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with 2 x 2500-cent product in cart and an active 1500-cent fixed code (discounted subtotal 3500 < 4000)" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.fix.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
cv_prereq "seed product and discount code" $LINENO
PID=$(cv_seed_product "CV Fixed Product $SFX" 2500 5) || cv_fail "expected product row created got error" $LINENO
CODE="FIX$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" fixed 1500 0 "now() + interval '1 day'" true) || cv_fail "expected discount code row created got error" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO

# When
cv_step When "shopper checks out with the fixed code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order has 1500 off, 599 shipping, total 4099; stock reduced; cart emptied" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq '.order')
[ "$(jq -r '.subtotalCents' <<<"$O")" = "5000" ] || cv_fail "expected subtotalCents 5000 got $(jq -r '.subtotalCents' <<<"$O")" $LINENO
[ "$(jq -r '.discountCents' <<<"$O")" = "1500" ] || cv_fail "expected discountCents 1500 got $(jq -r '.discountCents' <<<"$O")" $LINENO
[ "$(jq -r '.shippingCents' <<<"$O")" = "599" ] || cv_fail "expected shippingCents 599 got $(jq -r '.shippingCents' <<<"$O")" $LINENO
[ "$(jq -r '.totalCents' <<<"$O")" = "4099" ] || cv_fail "expected totalCents 4099 got $(jq -r '.totalCents' <<<"$O")" $LINENO
[ "$(jq -r '.discountCode' <<<"$O")" = "$CODE" ] || cv_fail "expected discountCode $CODE got $(jq -r '.discountCode' <<<"$O")" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "3" ] || cv_fail "expected stock 3 got $STOCK" $LINENO
CART=$(cv_count "SELECT count(*) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "0" ] || cv_fail "expected empty cart got $CART lines" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID AND discount_code_id=$CID AND total_cents=4099 AND shipping_cents=599")
[ "$ORD" = "1" ] || cv_fail "expected 1 persisted order total 4099 got $ORD" $LINENO

# Cleanup
cv_step Cleanup "remove user, orders, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_success_fixed_discount_with_shipping"
