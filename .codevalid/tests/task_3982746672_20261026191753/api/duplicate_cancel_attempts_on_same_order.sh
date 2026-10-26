#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with a placed order (qty 3 of a stock-10 product) using a discount code" $LINENO
cv_new_shopper dupcancel $LINENO
cv_new_product "DupCancel Widget" 2000 10 $LINENO
cv_new_discount DUPC percentage 10 $LINENO
cv_place_order "$SHOPPER_TOKEN" "$PRODUCT_ID" 3 "$DISCOUNT_CODE" $LINENO
STATUS_BEFORE=$(printf '%s' "$ORDER_JSON" | jq -r '.status')
[ "$STATUS_BEFORE" = "placed" ] || cv_fail "expected new order status placed got $STATUS_BEFORE" $LINENO
STOCK_AFTER_CHECKOUT=$(cv_sql "SELECT stock FROM products WHERE id = $PRODUCT_ID")
[ "$STOCK_AFTER_CHECKOUT" = "7" ] || cv_fail "expected stock 7 after checkout got $STOCK_AFTER_CHECKOUT" $LINENO
USED_BEFORE=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id = $DISCOUNT_ID AND status <> 'cancelled'")
[ "$USED_BEFORE" = "1" ] || cv_fail "expected discount held by 1 order got $USED_BEFORE" $LINENO

# When
cv_step When "two cancel requests for the same order are sent concurrently" $LINENO
TMPD=$(mktemp -d)
for i in 1 2; do
  command curl -sS -X POST -H "Authorization: Bearer $SHOPPER_TOKEN" \
    -o "$TMPD/body$i" -w '%{http_code}' "$BASE_URL/orders/$ORDER_ID/cancel" > "$TMPD/status$i" 2>/dev/null &
done
wait
S1=$(cat "$TMPD/status1"); S2=$(cat "$TMPD/status2")
B1=$(cat "$TMPD/body1"); B2=$(cat "$TMPD/body2")
echo "RESPONSE_BODY 1: $B1"; echo "RESPONSE_BODY 2: $B2"
cv_http POST "$BASE_URL/orders/$ORDER_ID/cancel" "$S1" 0
cv_http POST "$BASE_URL/orders/$ORDER_ID/cancel" "$S2" 0
cv_prereq "send a third (retry) cancel after both completed" $LINENO
cv_http POST "/orders/$ORDER_ID/cancel" -H "Authorization: Bearer $SHOPPER_TOKEN"
S3=$CV_HTTP_STATUS
rm -rf "$TMPD"

# Then
cv_step Then "exactly one cancel succeeds, duplicates are rejected, stock restored once and discount released once" $LINENO
SORTED=$(printf '%s\n%s\n' "$S1" "$S2" | sort | tr '\n' ' ')
[ "$SORTED" = "200 409 " ] || cv_fail "expected one 200 and one 409 for concurrent cancels got $S1 and $S2" $LINENO
if [ "$S1" = "200" ]; then OK_BODY=$B1; else OK_BODY=$B2; fi
OK_STATUS=$(printf '%s' "$OK_BODY" | jq -r '.order.status')
[ "$OK_STATUS" = "cancelled" ] || cv_fail "expected successful cancel to return status cancelled got $OK_STATUS" $LINENO
OK_ID=$(printf '%s' "$OK_BODY" | jq -r '.order.id')
[ "$OK_ID" = "$ORDER_ID" ] || cv_fail "expected cancelled order id $ORDER_ID got $OK_ID" $LINENO
[ "$S3" = "409" ] || cv_fail "expected 409 for retry cancel of cancelled order got $S3" $LINENO
STOCK_NOW=$(cv_sql "SELECT stock FROM products WHERE id = $PRODUCT_ID")
[ "$STOCK_NOW" = "10" ] || cv_fail "expected stock restored exactly once to 10 got $STOCK_NOW" $LINENO
DB_STATUS=$(cv_sql "SELECT status FROM orders WHERE id = $ORDER_ID")
[ "$DB_STATUS" = "cancelled" ] || cv_fail "expected order status cancelled in DB got $DB_STATUS" $LINENO
USED_NOW=$(cv_sql "SELECT count(*) FROM orders WHERE discount_code_id = $DISCOUNT_ID AND status <> 'cancelled'")
[ "$USED_NOW" = "0" ] || cv_fail "expected discount released (0 holding orders) got $USED_NOW" $LINENO
cv_http GET "/orders/$ORDER_ID" 200 -H "Authorization: Bearer $SHOPPER_TOKEN"
GET_STATUS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.status')
[ "$GET_STATUS" = "cancelled" ] || cv_fail "expected GET order status cancelled got $GET_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove shopper, orders, product and discount code" $LINENO
cv_cleanup

echo "CODEVALID_TEST_ASSERTION_OK:duplicate_cancel_attempts_on_same_order"
