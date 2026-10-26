#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "shopper A has a placed discounted order and shopper B is logged in" $LINENO
cv_new_product "CV Kettle" 2200 10 $LINENO
P1=$PRODUCT_ID
cv_new_discount CVOTH fixed 100 $LINENO
CODE=$DISCOUNT_CODE
DID=$DISCOUNT_ID
cv_new_shopper ownera $LINENO
cv_place_order "$SHOPPER_TOKEN" "$P1" 2 "$CODE" $LINENO
OID=$ORDER_ID
cv_new_shopper intruder $LINENO
TOKEN_B=$SHOPPER_TOKEN
MISSING=$(cv_sql "SELECT COALESCE(MAX(id), 0) + 100000 FROM orders")

# When
cv_step When "shopper B tries to cancel shopper A's order" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $TOKEN_B"
STATUS=$CV_HTTP_STATUS
BODY=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.' 2>/dev/null || printf '%s' "$CV_HTTP_BODY")

# Then
cv_step Then "404 not found like a missing order, and no stock, status or discount change" $LINENO
[ "$STATUS" = "404" ] || cv_fail "expected 404 cancelling another shopper's order got $STATUS" $LINENO
cv_http POST "/orders/$MISSING/cancel" "" -H "Authorization: Bearer $TOKEN_B"
MBODY=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.' 2>/dev/null || printf '%s' "$CV_HTTP_BODY")
[ "$MBODY" = "$BODY" ] || cv_fail "expected same body as missing order got '$BODY' vs '$MBODY'" $LINENO
st=$(cv_sql "SELECT status FROM orders WHERE id = $OID")
[ "$st" = "placed" ] || cv_fail "expected order still placed got $st" $LINENO
S=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
[ "$S" = "8" ] || cv_fail "expected stock unchanged at 8 got $S" $LINENO
held=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id = $DID AND status <> 'cancelled'")
[ "$held" = "1" ] || cv_fail "expected discount code still held by 1 order got $held" $LINENO

# Cleanup
cv_step Cleanup "remove created shoppers, order, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:cannot_cancel_another_shoppers_order"
