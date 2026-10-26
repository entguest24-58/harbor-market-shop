#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with 1 x 1000-cent product in cart and an active 5000-cent fixed code (larger than subtotal)" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.cap.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
cv_prereq "seed product and oversized fixed discount code" $LINENO
PID=$(cv_seed_product "CV Cap Product $SFX" 1000 5) || cv_fail "expected product row created got error" $LINENO
[ -n "$PID" ] || cv_fail "expected product id got empty" $LINENO
CODE="CAP$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" fixed 5000 0 "now() + interval '1 day'" true) || cv_fail "expected discount code row created got error" $LINENO
[ -n "$CID" ] || cv_fail "expected discount code id got empty" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 1 $LINENO

# When
cv_step When "shopper checks out with the oversized fixed code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "discount capped at 1000, discounted subtotal 0, shipping 599 charged, total 599" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq '.order')
SUB=$(jq -r '.subtotalCents' <<<"$O"); DISC=$(jq -r '.discountCents' <<<"$O")
SHIP=$(jq -r '.shippingCents' <<<"$O"); TOT=$(jq -r '.totalCents' <<<"$O")
[ "$SUB" = "1000" ] || cv_fail "expected subtotalCents 1000 got $SUB" $LINENO
[ "$DISC" = "1000" ] || cv_fail "expected discountCents capped at 1000 got $DISC" $LINENO
[ $((SUB - DISC)) -ge 0 ] || cv_fail "expected non-negative discounted subtotal got $((SUB - DISC))" $LINENO
[ "$SHIP" = "599" ] || cv_fail "expected shippingCents 599 (discounted subtotal 0 below free threshold) got $SHIP" $LINENO
[ "$TOT" = "599" ] || cv_fail "expected totalCents 599 got $TOT" $LINENO
[ "$(jq -r '.discountCode' <<<"$O")" = "$CODE" ] || cv_fail "expected discountCode $CODE got $(jq -r '.discountCode' <<<"$O")" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID AND discount_code_id=$CID AND subtotal_cents=1000 AND discount_cents=1000 AND shipping_cents=599 AND total_cents=599")
[ "$ORD" = "1" ] || cv_fail "expected 1 persisted order with capped discount got $ORD" $LINENO

# Cleanup
cv_step Cleanup "remove user, orders, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_caps_discount_to_prevent_negative_subtotal"
