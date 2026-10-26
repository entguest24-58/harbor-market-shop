#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper whose order using the code was cancelled, with a new cart" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.cancel.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
PID=$(cv_seed_product "CV Cancel Product $SFX" 3000 10) || cv_fail "expected product row created got error" $LINENO
CODE="CX$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" percentage 10 0 NULL true) || cv_fail "expected discount code row created got error" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO
cv_prereq "first checkout using the code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" 201 -H "Authorization: Bearer $TOKEN"
FIRST_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.id')
cv_prereq "cancel the first order" $LINENO
cv_http POST "/orders/$FIRST_ID/cancel" "" 200 -H "Authorization: Bearer $TOKEN"
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.status')" = "cancelled" ] || cv_fail "expected first order cancelled" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 3 $LINENO

# When
cv_step When "shopper checks out again with the same code" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "checkout succeeds with discount; stock reduced; cart emptied" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
O=$(printf '%s' "$CV_HTTP_BODY" | jq '.order')
[ "$(jq -r '.id' <<<"$O")" != "$FIRST_ID" ] || cv_fail "expected a new order id got $FIRST_ID" $LINENO
[ "$(jq -r '.discountCode' <<<"$O")" = "$CODE" ] || cv_fail "expected discountCode $CODE got $(jq -r '.discountCode' <<<"$O")" $LINENO
[ "$(jq -r '.subtotalCents' <<<"$O")" = "9000" ] || cv_fail "expected subtotalCents 9000 got $(jq -r '.subtotalCents' <<<"$O")" $LINENO
[ "$(jq -r '.discountCents' <<<"$O")" = "900" ] || cv_fail "expected discountCents 900 got $(jq -r '.discountCents' <<<"$O")" $LINENO
[ "$(jq -r '.shippingCents' <<<"$O")" = "0" ] || cv_fail "expected shippingCents 0 got $(jq -r '.shippingCents' <<<"$O")" $LINENO
[ "$(jq -r '.totalCents' <<<"$O")" = "8100" ] || cv_fail "expected totalCents 8100 got $(jq -r '.totalCents' <<<"$O")" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "7" ] || cv_fail "expected stock 7 (10 restored after cancel, minus 3) got $STOCK" $LINENO
CART=$(cv_count "SELECT count(*) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "0" ] || cv_fail "expected empty cart got $CART lines" $LINENO
ACTIVE=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID AND discount_code_id=$CID AND status <> 'cancelled'")
[ "$ACTIVE" = "1" ] || cv_fail "expected 1 non-cancelled order holding the code got $ACTIVE" $LINENO

# Cleanup
cv_step Cleanup "remove user, orders, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_allows_code_reuse_after_cancellation"
