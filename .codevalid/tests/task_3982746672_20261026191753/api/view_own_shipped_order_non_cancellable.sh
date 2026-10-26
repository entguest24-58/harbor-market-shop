#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with an order that has moved to shipped" $LINENO
cv_new_product "CV Rug" 2500 10 $LINENO
P1=$PRODUCT_ID
cv_new_shopper shipview $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P1" 1 "" $LINENO
OID=$ORDER_ID
cv_set_order_status "$OID" shipped $LINENO

# When
cv_step When "the shopper fetches the shipped order by id" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order is returned with status shipped and is not offered as cancellable" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
got=$(printf '%s' "$O" | jq -r '"\(.id) \(.status | ascii_downcase)"')
[ "$got" = "$OID shipped" ] || cv_fail "expected '$OID shipped' got '$got'" $LINENO
cc=$(printf '%s' "$O" | jq -r '.canCancel // "absent"')
[ "$cc" != "true" ] || cv_fail "expected canCancel not true on shipped order got $cc" $LINENO
cv_prereq "confirm cancel is refused for the shipped order" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 cancelling a shipped order got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_own_shipped_order_non_cancellable"
