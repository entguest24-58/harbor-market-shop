#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper order with three lines: one in stock, one removed from catalog, one sold out" $LINENO
cv_new_product "CV Kept" 1000 10 $LINENO
PA=$PRODUCT_ID
cv_new_product "CV Removed" 1200 10 $LINENO
PR=$PRODUCT_ID
cv_new_product "CV Soldout" 1400 10 $LINENO
PS=$PRODUCT_ID
cv_new_shopper unavail $LINENO
TOKEN=$SHOPPER_TOKEN
cv_prereq "add removed and sold-out products to cart" $LINENO
cv_http POST /cart/items "{\"productId\":$PR,\"quantity\":1}" 200 -H "Authorization: Bearer $TOKEN"
cv_http POST /cart/items "{\"productId\":$PS,\"quantity\":2}" 200 -H "Authorization: Bearer $TOKEN"
cv_place_order "$TOKEN" "$PA" 1 "" $LINENO
OID=$ORDER_ID
cv_prereq "remove one product from the catalog and sell out another" $LINENO
cv_remove_product "$PR" $LINENO
cv_set_stock "$PS" 0 $LINENO

# When
cv_step When "the shopper fetches the order by id" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "only the in-stock line is available; removed and sold-out lines are kept but not available" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
got=$(printf '%s' "$O" | jq -r '"\(.id) \(.items | length)"')
[ "$got" = "$OID 3" ] || cv_fail "expected order $OID with 3 lines got '$got'" $LINENO
got=$(printf '%s' "$O" | jq -r --argjson p "$PR" '[.items[] | select(.productId == $p)][0] | "\(.name) \(.unitPriceCents) \(.quantity)"')
[ "$got" = "CV Removed $CV_SUFFIX 1200 1" ] || cv_fail "expected removed product retained as 'CV Removed $CV_SUFFIX 1200 1' got '$got'" $LINENO
av=$(cv_line_available "$O" "$PA")
[ "$av" = "true" ] || cv_fail "expected in-stock line available=true got $av" $LINENO
av=$(cv_line_available "$O" "$PR")
[ "$av" = "false" ] || cv_fail "expected removed-from-catalog line available=false got $av" $LINENO
av=$(cv_line_available "$O" "$PS")
[ "$av" = "false" ] || cv_fail "expected out-of-stock line available=false got $av" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order and products" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_order_with_unavailable_products"
