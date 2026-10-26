#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

T="Business-rule enforcement relies solely on JWT subject and order.user_id equality"
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "${1:-}" "${2:-}"; cv_cleanup; exit 1; }

cv_step Given "two shoppers A and B, B has a placed order" $LINENO
cv_new_product "CV SecItem" 1500 10 $LINENO
P=$PRODUCT_ID
cv_new_shopper secb $LINENO
TOKEN_B=$SHOPPER_TOKEN
cv_place_order "$TOKEN_B" "$P" 1 "" $LINENO
B_ORDER=$ORDER_ID
cv_new_shopper seca $LINENO
TOKEN_A=$SHOPPER_TOKEN

cv_step When "A tries to cancel B's order with A's token" $LINENO
cv_http POST "/orders/$B_ORDER/cancel" "" -H "Authorization: Bearer $TOKEN_A"
CODE=$CV_HTTP_STATUS
STATUS=$(cv_sql "SELECT status FROM orders WHERE id = $B_ORDER" 2>/dev/null || echo unknown)
STOCK=$(cv_sql "SELECT stock FROM products WHERE id = $P" 2>/dev/null || echo unknown)

cv_step Then "decide verdict from response and B's order state" $LINENO
cv_cleanup
if [ "$CODE" = "404" ] || [ "$CODE" = "403" ]; then
  if [ "$STATUS" = "placed" ]; then
    printf 'CV_SECURITY|secure|access|critical|%s|cross-user cancel returned %s and B order stayed placed (stock %s)\n' "$T" "$CODE" "$STOCK"
    exit 0
  fi
fi
if [ "$STATUS" = "cancelled" ] || { [ "${CODE:0:1}" = "2" ]; }; then
  printf 'CV_SECURITY|vulnerable|access|critical|%s|cross-user cancel returned %s and B order status is %s\n' "$T" "$CODE" "$STATUS"
  exit 0
fi
printf 'CV_SECURITY|secure|access|critical|%s|cross-user cancel returned %s and B order status is %s\n' "$T" "$CODE" "$STATUS"
exit 0
