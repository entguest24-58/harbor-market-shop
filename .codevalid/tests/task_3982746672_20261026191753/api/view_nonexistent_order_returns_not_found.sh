#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper, another shopper's order, and an order id that does not exist" $LINENO
cv_new_product "CV Mug" 900 10 $LINENO
P1=$PRODUCT_ID
cv_new_shopper owner $LINENO
cv_place_order "$SHOPPER_TOKEN" "$P1" 1 "" $LINENO
FOREIGN=$ORDER_ID
cv_new_shopper seeker $LINENO
TOKEN=$SHOPPER_TOKEN
MISSING=$(cv_sql "SELECT COALESCE(MAX(id), 0) + 100000 FROM orders") || cv_fail "expected max order id got psql error" $LINENO
cnt=$(cv_sql "SELECT count(*) FROM orders WHERE id = $MISSING")
[ "$cnt" = "0" ] || cv_fail "expected order $MISSING not to exist got count $cnt" $LINENO
cv_prereq "fetch another shopper's order for comparison" $LINENO
cv_http GET "/orders/$FOREIGN" "" -H "Authorization: Bearer $TOKEN"
FSTATUS=$CV_HTTP_STATUS
FBODY=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.' 2>/dev/null || printf '%s' "$CV_HTTP_BODY")

# When
cv_step When "the shopper fetches the non-existent order id" $LINENO
cv_http GET "/orders/$MISSING" "" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "404 not found identical to the foreign-order response" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 for non-existent order got $CV_HTTP_STATUS" $LINENO
[ "$FSTATUS" = "404" ] || cv_fail "expected 404 for another shopper's order got $FSTATUS" $LINENO
MBODY=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.' 2>/dev/null || printf '%s' "$CV_HTTP_BODY")
[ "$MBODY" = "$FBODY" ] || cv_fail "expected identical bodies for missing and foreign order got '$MBODY' vs '$FBODY'" $LINENO
has=$(printf '%s' "$CV_HTTP_BODY" | jq 'has("order")')
[ "$has" = "false" ] || cv_fail "expected no order object in not-found response got $has" $LINENO

# Cleanup
cv_step Cleanup "remove created shoppers, order and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_nonexistent_order_returns_not_found"
