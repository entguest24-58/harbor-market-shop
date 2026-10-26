#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper cancelled an order that used a discount code and reused the code on a new order" $LINENO
cv_new_product "CV Chair" 4000 10 $LINENO
P1=$PRODUCT_ID
cv_new_discount CVRU percentage 10 $LINENO
CODE=$DISCOUNT_CODE
cv_new_shopper reuse $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P1" 1 "$CODE" $LINENO
OLD=$ORDER_ID
cv_prereq "cancel the first order" $LINENO
cv_http POST "/orders/$OLD/cancel" "" 200 -H "Authorization: Bearer $TOKEN"
cv_place_order "$TOKEN" "$P1" 1 "$CODE" $LINENO
NEW=$ORDER_ID

# When
cv_step When "the shopper fetches the old cancelled order and the new order" $LINENO
cv_http GET "/orders/$OLD" "" 200 -H "Authorization: Bearer $TOKEN"
OLDO=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
cv_http GET "/orders/$NEW" "" 200 -H "Authorization: Bearer $TOKEN"
NEWO=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')

# Then
cv_step Then "old order is cancelled with no active discount; new order carries the discount" $LINENO
got=$(printf '%s' "$NEWO" | jq -r '"\(.id) \(.status) \(.discountCode) \(.discountCents) \(.subtotalCents) \(.totalCents)"')
[ "$got" = "$NEW placed $CODE 400 4000 4199" ] || cv_fail "expected new order '$NEW placed $CODE 400 4000 4199' got '$got'" $LINENO
got=$(printf '%s' "$OLDO" | jq -r '"\(.id) \(.status)"')
[ "$got" = "$OLD cancelled" ] || cv_fail "expected old order '$OLD cancelled' got '$got'" $LINENO
dc=$(printf '%s' "$OLDO" | jq -r '"\(.discountCode) \(.discountCents)"')
[ "$dc" = "null 0" ] || cv_fail "expected no active discount on old cancelled order (discountCode null, discountCents 0) got '$dc'" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, orders, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_order_after_discount_reuse"
