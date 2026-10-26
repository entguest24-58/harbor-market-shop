#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with three orders (placed, shipped, cancelled) created at different times, plus another shopper's order" $LINENO
cv_new_product "CV Lamp" 1200 50 $LINENO
P1=$PRODUCT_ID
cv_new_shopper other $LINENO
OTHER_TOKEN=$SHOPPER_TOKEN
cv_place_order "$OTHER_TOKEN" "$P1" 1 "" $LINENO
OTHER_ORDER=$ORDER_ID
cv_new_shopper main $LINENO
TOKEN=$SHOPPER_TOKEN
MAIN_ID=$SHOPPER_ID
cv_place_order "$TOKEN" "$P1" 1 "" $LINENO
OLDEST=$ORDER_ID
cv_place_order "$TOKEN" "$P1" 2 "" $LINENO
MIDDLE=$ORDER_ID
cv_place_order "$TOKEN" "$P1" 3 "" $LINENO
NEWEST=$ORDER_ID
cv_prereq "backdate orders and set statuses" $LINENO
cv_set_order_created "$OLDEST" '3 days' $LINENO
cv_set_order_created "$MIDDLE" '2 days' $LINENO
cv_set_order_created "$NEWEST" '1 day' $LINENO
cv_set_order_status "$OLDEST" cancelled $LINENO
cv_set_order_status "$MIDDLE" shipped $LINENO

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "only the shopper's three orders are returned newest first with correct status and totals" $LINENO
COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq '.orders | length')
[ "$COUNT" = "3" ] || cv_fail "expected 3 orders got $COUNT" $LINENO
IDS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.orders[].id] | join(",")')
[ "$IDS" = "$NEWEST,$MIDDLE,$OLDEST" ] || cv_fail "expected order ids $NEWEST,$MIDDLE,$OLDEST got $IDS" $LINENO
STATUSES=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.orders[].status] | join(",")')
[ "$STATUSES" = "placed,shipped,cancelled" ] || cv_fail "expected statuses placed,shipped,cancelled got $STATUSES" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --argjson u "$MAIN_ID" 'all(.orders[]; .userId == $u)' >/dev/null \
  || cv_fail "expected all orders to have userId $MAIN_ID got others" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --argjson o "$OTHER_ORDER" 'any(.orders[]; .id == $o) | not' >/dev/null \
  || cv_fail "expected other shopper's order $OTHER_ORDER absent got present" $LINENO
SORTED=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.orders[].createdAt] as $c | ($c == ($c | sort | reverse))')
[ "$SORTED" = "true" ] || cv_fail "expected createdAt descending got unsorted" $LINENO
NEWQ=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.orders[0] | "\(.items[0].quantity) \(.subtotalCents) \(.totalCents)"')
[ "$NEWQ" = "3 3600 4199" ] || cv_fail "expected newest order qty 3 subtotal 3600 total 4199 got $NEWQ" $LINENO

# Cleanup
cv_step Cleanup "remove created shoppers, orders and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_multi_status_newest_first"
