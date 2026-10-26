#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper's discounted order that has moved to shipped" $LINENO
cv_new_product "CV Bench" 3500 10 $LINENO
P1=$PRODUCT_ID
cv_new_discount CVSHP fixed 200 $LINENO
CODE=$DISCOUNT_CODE
DID=$DISCOUNT_ID
cv_new_shopper latecancel $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P1" 3 "$CODE" $LINENO
OID=$ORDER_ID
cv_set_order_status "$OID" shipped $LINENO
S=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
[ "$S" = "7" ] || cv_fail "expected stock 7 after checkout got $S" $LINENO

# When
cv_step When "the shopper tries to cancel the shipped order" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "409 conflict and no change to order status, stock or discount code use" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 cancelling shipped order got $CV_HTTP_STATUS" $LINENO
err=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
[ -n "$err" ] || cv_fail "expected error message in body got '$CV_HTTP_BODY'" $LINENO
st=$(cv_sql "SELECT status FROM orders WHERE id = $OID")
[ "$st" = "shipped" ] || cv_fail "expected order status still shipped got $st" $LINENO
S=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
[ "$S" = "7" ] || cv_fail "expected stock unchanged at 7 got $S" $LINENO
held=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id = $DID AND status <> 'cancelled'")
[ "$held" = "1" ] || cv_fail "expected discount code still held by 1 order got $held" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:cannot_cancel_non_placed_order"
