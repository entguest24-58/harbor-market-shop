#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with a placed order that used a discount code" $LINENO
cv_new_product "CV Clock" 3000 10 $LINENO
P1=$PRODUCT_ID
cv_new_discount CVREL fixed 500 $LINENO
CODE=$DISCOUNT_CODE
DID=$DISCOUNT_ID
cv_new_shopper releaser $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P1" 2 "$CODE" $LINENO
OID=$ORDER_ID
S=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
[ "$S" = "8" ] || cv_fail "expected stock 8 after checkout got $S" $LINENO

# When
cv_step When "the shopper cancels the order" $LINENO
cv_http POST "/orders/$OID/cancel" "" 200 -H "Authorization: Bearer $TOKEN"
CANCEL_BODY=$CV_HTTP_BODY

# Then
cv_step Then "order is cancelled, stock restored and the code can be applied again on a new order" $LINENO
got=$(printf '%s' "$CANCEL_BODY" | jq -r '"\(.order.id) \(.order.status)"')
[ "$got" = "$OID cancelled" ] || cv_fail "expected '$OID cancelled' got '$got'" $LINENO
S=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
[ "$S" = "10" ] || cv_fail "expected stock restored to 10 got $S" $LINENO
held=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id = $DID AND status <> 'cancelled'")
[ "$held" = "0" ] || cv_fail "expected discount code held by 0 active orders got $held" $LINENO
cv_http POST /cart/items "{\"productId\":$P1,\"quantity\":1}" 200 -H "Authorization: Bearer $TOKEN"
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 reusing released code got $CV_HTTP_STATUS" $LINENO
got=$(printf '%s' "$CV_HTTP_BODY" | jq -r '"\(.order.status) \(.order.discountCode) \(.order.discountCents)"')
[ "$got" = "placed $CODE 500" ] || cv_fail "expected new order 'placed $CODE 500' got '$got'" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, orders, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:cancel_own_placed_order_with_discount_releases_code"
