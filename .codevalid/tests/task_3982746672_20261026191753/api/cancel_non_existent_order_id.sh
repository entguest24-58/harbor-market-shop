#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with a placed discounted order and an order id that does not exist" $LINENO
cv_new_product "CV Plate" 1500 10 $LINENO
P1=$PRODUCT_ID
cv_new_discount CVNEX fixed 100 $LINENO
DID=$DISCOUNT_ID
cv_new_shopper ghost $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P1" 2 "$DISCOUNT_CODE" $LINENO
OID=$ORDER_ID
MISSING=$(cv_sql "SELECT COALESCE(MAX(id), 0) + 100000 FROM orders") || cv_fail "expected max order id got psql error" $LINENO
cnt=$(cv_sql "SELECT count(*) FROM orders WHERE id = $MISSING")
[ "$cnt" = "0" ] || cv_fail "expected order $MISSING not to exist got count $cnt" $LINENO

# When
cv_step When "the shopper cancels the non-existent order id" $LINENO
cv_http POST "/orders/$MISSING/cancel" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "404 not found and no stock, order or discount side effects" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
has=$(printf '%s' "$CV_HTTP_BODY" | jq 'has("order")')
[ "$has" = "false" ] || cv_fail "expected no order object in response got $has" $LINENO
st=$(cv_sql "SELECT status FROM orders WHERE id = $OID")
[ "$st" = "placed" ] || cv_fail "expected own order still placed got $st" $LINENO
S=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
[ "$S" = "8" ] || cv_fail "expected stock unchanged at 8 got $S" $LINENO
held=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id = $DID AND status <> 'cancelled'")
[ "$held" = "1" ] || cv_fail "expected discount code still held by 1 order got $held" $LINENO
cnt=$(cv_sql "SELECT count(*) FROM orders WHERE id = $MISSING")
[ "$cnt" = "0" ] || cv_fail "expected no order created with id $MISSING got $cnt" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:cancel_non_existent_order_id"
