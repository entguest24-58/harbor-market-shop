#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3982746672_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with a placed order of two products that reduced stock" $LINENO
cv_new_product "CV Vase" 1100 10 $LINENO
P1=$PRODUCT_ID
cv_new_product "CV Frame" 700 8 $LINENO
P2=$PRODUCT_ID
cv_new_shopper canceller $LINENO
TOKEN=$SHOPPER_TOKEN
cv_prereq "add second product to cart" $LINENO
cv_http POST /cart/items "{\"productId\":$P2,\"quantity\":3}" 200 -H "Authorization: Bearer $TOKEN"
cv_place_order "$TOKEN" "$P1" 2 "" $LINENO
OID=$ORDER_ID
S1=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
S2=$(cv_sql "SELECT stock FROM products WHERE id = $P2")
[ "$S1 $S2" = "8 5" ] || cv_fail "expected stock '8 5' after checkout got '$S1 $S2'" $LINENO

# When
cv_step When "the shopper cancels the order" $LINENO
cv_http POST "/orders/$OID/cancel" "" 200 -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the order is cancelled and stock is restored for every line item" $LINENO
got=$(printf '%s' "$CV_HTTP_BODY" | jq -r '"\(.order.id) \(.order.status)"')
[ "$got" = "$OID cancelled" ] || cv_fail "expected '$OID cancelled' got '$got'" $LINENO
S1=$(cv_sql "SELECT stock FROM products WHERE id = $P1")
S2=$(cv_sql "SELECT stock FROM products WHERE id = $P2")
[ "$S1" = "10" ] || cv_fail "expected product $P1 stock 10 got $S1" $LINENO
[ "$S2" = "8" ] || cv_fail "expected product $P2 stock 8 got $S2" $LINENO
DBST=$(cv_sql "SELECT status FROM orders WHERE id = $OID")
[ "$DBST" = "cancelled" ] || cv_fail "expected stored status cancelled got $DBST" $LINENO
cv_http GET "/orders/$OID" "" 200 -H "Authorization: Bearer $TOKEN"
got=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.status')
[ "$got" = "cancelled" ] || cv_fail "expected GET status cancelled got $got" $LINENO

# Cleanup
cv_step Cleanup "remove created shopper, order and products" $LINENO
cv_cleanup
echo "CODEVALID_TEST_ASSERTION_OK:cancel_own_placed_order_restores_stock"
