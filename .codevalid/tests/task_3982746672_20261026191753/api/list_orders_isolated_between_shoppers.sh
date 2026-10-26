#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "shopper A and shopper B each with their own orders" $LINENO
cv_new_product "CV Pen" 500 50 $LINENO
P=$PRODUCT_ID
cv_new_shopper a $LINENO
A_TOKEN=$SHOPPER_TOKEN
A_ID=$SHOPPER_ID
cv_place_order "$A_TOKEN" "$P" 1 "" $LINENO
A1=$ORDER_ID
cv_place_order "$A_TOKEN" "$P" 2 "" $LINENO
A2=$ORDER_ID
cv_new_shopper b $LINENO
B_TOKEN=$SHOPPER_TOKEN
cv_place_order "$B_TOKEN" "$P" 1 "" $LINENO
B1=$ORDER_ID
cv_place_order "$B_TOKEN" "$P" 3 "" $LINENO
B2=$ORDER_ID

# When
cv_step When "shopper A lists their orders" $LINENO
cv_http GET /orders "" 200 -H "Authorization: Bearer $A_TOKEN"

# Then
cv_step Then "only shopper A's orders are returned and none of shopper B's" $LINENO
IDS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.orders[].id] | sort | join(",")')
EXPECTED=$(printf '%s\n%s\n' "$A1" "$A2" | sort -n | paste -sd, -)
[ "$IDS" = "$EXPECTED" ] || cv_fail "expected order ids $EXPECTED got $IDS" $LINENO
for b in "$B1" "$B2"; do
  printf '%s' "$CV_HTTP_BODY" | jq -e --argjson o "$b" 'any(.orders[]; .id == $o) | not' >/dev/null \
    || cv_fail "expected shopper B order $b absent got present" $LINENO
done
printf '%s' "$CV_HTTP_BODY" | jq -e --argjson u "$A_ID" 'all(.orders[]; .userId == $u)' >/dev/null \
  || cv_fail "expected all orders userId $A_ID got other user ids" $LINENO

# Cleanup
cv_step Cleanup "remove created shoppers, orders and product" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:list_orders_isolated_between_shoppers"
