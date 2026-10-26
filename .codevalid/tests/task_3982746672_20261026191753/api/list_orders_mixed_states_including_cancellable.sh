#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with orders in placed, shipped and cancelled states" $LINENO
cv_new_product "CV Bowl" 1500 50 $LINENO
P=$PRODUCT_ID
cv_new_shopper mixed $LINENO
TOKEN=$SHOPPER_TOKEN
cv_place_order "$TOKEN" "$P" 1 "" $LINENO
O_SHIPPED=$ORDER_ID
cv_place_order "$TOKEN" "$P" 1 "" $LINENO
O_CANCELLED=$ORDER_ID
cv_place_order "$TOKEN" "$P" 1 "" $LINENO
O_PLACED=$ORDER_ID
cv_prereq "ship and cancel orders through the database" $LINENO
cv_set_order_status "$O_SHIPPED" shipped $LINENO
cv_set_order_status "$O_CANCELLED" cancelled $LINENO

# When
cv_step When "the shopper lists their orders" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "every order is returned with its accurate status and only the placed one reads placed" $LINENO
COUNT=$(printf '%s' "$CV_HTTP_BODY" | jq '.orders | length')
[ "$COUNT" = "3" ] || cv_fail "expected 3 orders got $COUNT" $LINENO
for pair in "$O_PLACED:placed" "$O_SHIPPED:shipped" "$O_CANCELLED:cancelled"; do
  oid=${pair%%:*}; want=${pair#*:}
  got=$(printf '%s' "$CV_HTTP_BODY" | jq -r --argjson o "$oid" '.orders[] | select(.id == $o) | .status')
  [ "$got" = "$want" ] || cv_fail "expected order $oid status $want got '$got'" $LINENO
done
PLACED_IDS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.orders[] | select(.status == "placed") | .id] | join(",")')
[ "$PLACED_IDS" = "$O_PLACED" ] || cv_fail "expected only order $O_PLACED placed got $PLACED_IDS" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, orders and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_mixed_states_including_cancellable"
