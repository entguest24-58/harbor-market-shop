#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with an order placed using a discount code and then cancelled" $LINENO
cv_new_product "CV Lamp" 2000 10 $LINENO
P1=$PRODUCT_ID
cv_new_discount CVCAN fixed 300 $LINENO
CODE=$DISCOUNT_CODE
cv_new_shopper cancview $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P1" 1 "$CODE" $LINENO
OID=$ORDER_ID
cv_prereq "cancel the order" $LINENO
cv_http POST "/orders/$OID/cancel" "" 200 -H "Authorization: Bearer $TOKEN"
cv_prereq "remove the ordered product from the catalog" $LINENO
cv_remove_product "$P1" $LINENO

# When
cv_step When "the shopper fetches the cancelled order by id" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "order is cancelled, has no discount, is not cancellable and its removed line is kept but not available" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.order')
got=$(printf '%s' "$O" | jq -r '.id')
[ "$got" = "$OID" ] || cv_fail "expected order id $OID got $got" $LINENO
st=$(printf '%s' "$O" | jq -r '.status | ascii_downcase')
[ "$st" = "cancelled" ] || cv_fail "expected status cancelled got $st" $LINENO
cc=$(printf '%s' "$O" | jq -r '.canCancel // "absent"')
[ "$cc" != "true" ] || cv_fail "expected canCancel not true on cancelled order got $cc" $LINENO
dc=$(printf '%s' "$O" | jq -r '"\(.discountCode) \(.discountCents)"')
[ "$dc" = "null 0" ] || cv_fail "expected no discount applied on cancelled order (discountCode null, discountCents 0) got '$dc'" $LINENO
got=$(printf '%s' "$O" | jq -r --argjson p "$P1" '[.items[] | select(.productId == $p)][0] | "\(.productName) \(.quantity)"')
[ "$got" = "CV Lamp $CV_SUFFIX 1" ] || cv_fail "expected removed product line retained as 'CV Lamp $CV_SUFFIX 1' got '$got'" $LINENO
av=$(cv_line_available "$O" "$P1")
[ "$av" = "false" ] || cv_fail "expected removed product line available=false got $av" $LINENO
cv_prereq "confirm the order can no longer be cancelled" $LINENO
cv_http POST "/orders/$OID/cancel" "" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 cancelling an already cancelled order got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order, discount code and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:view_own_cancelled_order"
