#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with one order using a 10% discount code and one order without a code" $LINENO
cv_new_product "CV Chair" 2000 50 $LINENO
P=$PRODUCT_ID
cv_new_discount CVTEN percentage 10 $LINENO
CODE=$DISCOUNT_CODE
cv_new_shopper disc $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P" 1 "" $LINENO
PLAIN=$ORDER_ID
cv_place_order "$TOKEN" "$P" 2 "$CODE" $LINENO
DISC=$ORDER_ID

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the discounted order shows its code and discount and the other shows none" $LINENO
COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq '.orders | length')
[ "$COUNT" = "2" ] || cv_fail "expected 2 orders got $COUNT" $LINENO
D=$(printf '%s' "$CV_HTTP_BODY" | jq -r --argjson o "$DISC" '.orders[] | select(.id == $o) | "\(.discountCode) \(.discountCents) \(.subtotalCents) \(.shippingCents) \(.totalCents)"')
[ "$D" = "$CODE 400 4000 599 4199" ] || cv_fail "expected discounted order '$CODE 400 4000 599 4199' got '$D'" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --argjson o "$PLAIN" '.orders[] | select(.id == $o) | "\(.discountCode) \(.discountCents) \(.subtotalCents) \(.totalCents)"')
[ "$N" = "null 0 2000 2599" ] || cv_fail "expected plain order 'null 0 2000 2599' got '$N'" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, orders, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_with_discounted_orders"
