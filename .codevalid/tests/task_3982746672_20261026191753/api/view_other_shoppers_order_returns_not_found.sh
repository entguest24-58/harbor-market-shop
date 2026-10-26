#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "shopper B owns an order and shopper A is logged in" $LINENO
cv_new_product "CV Rug" 2500 20 $LINENO
cv_new_shopper owner $LINENO
cv_place_order "$SHOPPER_TOKEN" "$PRODUCT_ID" 1 "" $LINENO
OID=$ORDER_ID
cv_new_shopper intruder $LINENO
A_TOKEN=$SHOPPER_TOKEN
MISSING_ID=$(( $(cv_sql "SELECT COALESCE(max(id),0) FROM orders") + 100000 ))

# When
cv_step When "shopper A requests shopper B's order and a non-existent order" $LINENO
cv_http GET "/orders/$OID" "" -H "Authorization: Bearer $A_TOKEN"
OTHER_STATUS=$CV_HTTP_STATUS
OTHER_BODY=$CV_HTTP_BODY
cv_http GET "/orders/$MISSING_ID" "" -H "Authorization: Bearer $A_TOKEN"
MISSING_STATUS=$CV_HTTP_STATUS
MISSING_BODY=$CV_HTTP_BODY

# Then
cv_step Then "the response is 404 not found, identical to a non-existent order, with no order data" $LINENO
[ "$OTHER_STATUS" = "404" ] || cv_fail "expected 404 for another shopper's order got $OTHER_STATUS" $LINENO
printf '%s' "$OTHER_BODY" | jq -e 'has("order") | not' >/dev/null || cv_fail "expected no order in body got $OTHER_BODY" $LINENO
[ "$OTHER_BODY" = "$MISSING_BODY" ] || cv_fail "expected same body as missing order ($MISSING_BODY) got $OTHER_BODY" $LINENO
[ "$MISSING_STATUS" = "404" ] || cv_fail "expected 404 for missing order got $MISSING_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove created shoppers, order and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_other_shoppers_order_returns_not_found"
