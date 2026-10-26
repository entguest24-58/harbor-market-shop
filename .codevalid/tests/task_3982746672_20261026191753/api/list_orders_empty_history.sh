#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a newly registered shopper with no orders while another shopper has one" $LINENO
cv_new_product "CV Mug" 900 20 $LINENO
cv_new_shopper other $LINENO
cv_place_order "$SHOPPER_TOKEN" "$PRODUCT_ID" 1 "" $LINENO
cv_new_shopper fresh $LINENO
TOKEN=$SHOPPER_TOKEN

# When
cv_step When "the new shopper lists their orders" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "an empty orders list is returned" $LINENO
TYPE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.orders | type')
[ "$TYPE" = "array" ] || cv_fail "expected orders to be an array got $TYPE" $LINENO
COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq '.orders | length')
[ "$COUNT" = "0" ] || cv_fail "expected 0 orders got $COUNT" $LINENO

# Cleanup
cv_step Cleanup "remove created shoppers, orders and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_empty_history"
