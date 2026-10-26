#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with a placed order of two products using a fixed 500-cent discount code" $LINENO
cv_new_product "CV Desk" 3000 20 $LINENO
P1=$PRODUCT_ID
cv_new_product "CV Shelf" 1000 20 $LINENO
P2=$PRODUCT_ID
cv_new_discount CVFIX fixed 500 $LINENO
CODE=$DISCOUNT_CODE
cv_new_shopper viewer $LINENO
TOKEN=$SHOPPER_TOKEN
USER_ID=$SHOPPER_ID
cv_prereq "add second product to cart" $LINENO
cv_http POST /cart/items "{\"productId\":$P2,\"quantity\":2}" 200 -H "Authorization: Bearer $TOKEN"
cv_place_order "$TOKEN" "$P1" 1 "$CODE" $LINENO
OID=$ORDER_ID

# When
cv_step When "the shopper fetches the order by id" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "full order details with status, items, totals and discount are returned" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
got=$(printf '%s' "$O" | jq -r '"\(.id) \(.userId) \(.status)"')
[ "$got" = "$OID $USER_ID placed" ] || cv_fail "expected '$OID $USER_ID placed' got '$got'" $LINENO
got=$(printf '%s' "$O" | jq -r '"\(.subtotalCents) \(.discountCode) \(.discountCents) \(.shippingCents) \(.totalCents)"')
[ "$got" = "5000 $CODE 500 599 5099" ] || cv_fail "expected totals '5000 $CODE 500 599 5099' got '$got'" $LINENO
NITEMS=$(printf '%s' "$O" | jq '.items | length')
[ "$NITEMS" = "2" ] || cv_fail "expected 2 items got $NITEMS" $LINENO
got=$(printf '%s' "$O" | jq -r --argjson p "$P1" '.items[] | select(.productId == $p) | "\(.unitPriceCents) \(.quantity) \(.lineTotalCents)"')
[ "$got" = "3000 1 3000" ] || cv_fail "expected desk line '3000 1 3000' got '$got'" $LINENO
got=$(printf '%s' "$O" | jq -r --argjson p "$P2" '.items[] | select(.productId == $p) | "\(.unitPriceCents) \(.quantity) \(.lineTotalCents)"')
[ "$got" = "1000 2 2000" ] || cv_fail "expected shelf line '1000 2 2000' got '$got'" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order, discount code and products" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_own_placed_order_with_discount"
