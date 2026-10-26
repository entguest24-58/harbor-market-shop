#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with an order that has moved to shipped" $LINENO
cv_new_product "CV Rug" 2500 10 $LINENO
P1=$PRODUCT_ID
cv_new_product "CV Vase" 1500 5 $LINENO
P2=$PRODUCT_ID
cv_new_shopper shipview $LINENO
TOKEN=$SHOPPER_TOKEN
cv_prereq "add second product to cart" $LINENO
cv_http POST /cart/items "{\"productId\":$P2,\"quantity\":1}" 200 -H "Authorization: Bearer $TOKEN"
cv_place_order "$TOKEN" "$P1" 1 "" $LINENO
OID=$ORDER_ID
cv_set_order_status "$OID" shipped $LINENO
cv_prereq "second product sells out after shipping" $LINENO
cv_set_stock "$P2" 0 $LINENO

# When
cv_step When "the shopper fetches the shipped order by id" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order is shipped, not cancellable, and the sold-out line is kept but not available" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
got=$(printf '%s' "$O" | jq -r '"\(.id) \(.status | ascii_downcase)"')
[ "$got" = "$OID shipped" ] || cv_fail "expected '$OID shipped' got '$got'" $LINENO
cc=$(printf '%s' "$O" | jq -r '.canCancel // "absent"')
[ "$cc" != "true" ] || cv_fail "expected canCancel not true on shipped order got $cc" $LINENO
got=$(printf '%s' "$O" | jq -r --argjson p "$P2" '[.items[] | select(.productId == $p)][0] | "\(.name) \(.unitPriceCents) \(.quantity)"')
[ "$got" = "CV Vase $CV_SUFFIX 1500 1" ] || cv_fail "expected sold-out line kept as 'CV Vase $CV_SUFFIX 1500 1' got '$got'" $LINENO
av=$(cv_line_available "$O" "$P2")
[ "$av" = "false" ] || cv_fail "expected sold-out line available=false got $av" $LINENO
av=$(cv_line_available "$O" "$P1")
[ "$av" = "true" ] || cv_fail "expected in-stock line available=true got $av" $LINENO
cv_prereq "confirm cancel is refused for the shipped order" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 cancelling a shipped order got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_own_shipped_order_non_cancellable"
