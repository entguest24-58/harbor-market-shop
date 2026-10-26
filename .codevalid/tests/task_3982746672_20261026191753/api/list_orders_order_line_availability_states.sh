#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with historical orders whose lines are in stock, removed, and sold out" $LINENO
cv_new_product "CV Avail" 1000 10 $LINENO
PA=$PRODUCT_ID
cv_new_product "CV Gone" 1100 10 $LINENO
PR=$PRODUCT_ID
cv_new_product "CV Empty" 1300 10 $LINENO
PS=$PRODUCT_ID
cv_new_shopper listavail $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$PA" 1 "" $LINENO
O1=$ORDER_ID
cv_prereq "add sold-out-to-be product to cart" $LINENO
cv_http POST /cart/items "{\"productId\":$PS,\"quantity\":1}" 200 -H "Authorization: Bearer $TOKEN"
cv_place_order "$TOKEN" "$PR" 2 "" $LINENO
O2=$ORDER_ID
cv_prereq "remove one product from the catalog and sell out another" $LINENO
cv_remove_product "$PR" $LINENO
cv_set_stock "$PS" 0 $LINENO

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "each order line carries availability: in-stock true, removed and sold-out false" $LINENO
n=$(printf '%s' "$CV_HTTP_BODY" | jq '.orders | length')
[ "$n" = "2" ] || cv_fail "expected 2 orders got $n" $LINENO
A=$(printf '%s' "$CV_HTTP_BODY" | jq -c --argjson i "$O1" '.orders[] | select(.id == $i)')
B=$(printf '%s' "$CV_HTTP_BODY" | jq -c --argjson i "$O2" '.orders[] | select(.id == $i)')
[ -n "$A" ] && [ -n "$B" ] || cv_fail "expected orders $O1 and $O2 in list got '$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.orders[].id]')'" $LINENO
av=$(cv_line_available "$A" "$PA")
[ "$av" = "true" ] || cv_fail "expected in-stock line available=true got $av" $LINENO
got=$(printf '%s' "$B" | jq -r --argjson p "$PR" '[.items[] | select(.productId == $p)][0] | "\(.name) \(.quantity)"')
[ "$got" = "CV Gone $CV_SUFFIX 2" ] || cv_fail "expected removed product retained as 'CV Gone $CV_SUFFIX 2' got '$got'" $LINENO
av=$(cv_line_available "$B" "$PR")
[ "$av" = "false" ] || cv_fail "expected removed-from-catalog line available=false got $av" $LINENO
av=$(cv_line_available "$B" "$PS")
[ "$av" = "false" ] || cv_fail "expected out-of-stock line available=false got $av" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, orders and products" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_order_line_availability_states"
