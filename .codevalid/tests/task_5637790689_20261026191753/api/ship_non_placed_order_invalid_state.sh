#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5637790689_20261026191753/api/_infra.sh

# Given
cv_step Given "a staff user plus one shipped and one cancelled order" $LINENO
SFX=$(cv_suffix)
create_user "cv-ship-inv-cust-$SFX@example.com" customer
CUST_ID=$CV_USER_ID
create_user "cv-ship-inv-staff-$SFX@example.com" staff
STAFF_ID=$CV_USER_ID; STAFF_TOKEN=$CV_TOKEN
seed_order "$CUST_ID" shipped
SHIPPED_ID=$CV_ORDER_ID; P1=$CV_PRODUCT_ID
seed_order "$CUST_ID" cancelled
CANCELLED_ID=$CV_ORDER_ID; P2=$CV_PRODUCT_ID

# When
cv_step When "staff calls POST /orders/{id}/ship on the shipped and the cancelled order" $LINENO
cv_http POST "/orders/$SHIPPED_ID/ship" -H "Authorization: Bearer $STAFF_TOKEN"
S1=$CV_HTTP_STATUS
cv_http POST "/orders/$CANCELLED_ID/ship" -H "Authorization: Bearer $STAFF_TOKEN"
S2=$CV_HTTP_STATUS

# Then
cv_step Then "both are rejected with 409 and statuses are unchanged" $LINENO
[ "$S1" = "409" ] || cv_fail "expected 409 shipping a shipped order got $S1" $LINENO
[ "$S2" = "409" ] || cv_fail "expected 409 shipping a cancelled order got $S2" $LINENO
[ "$(order_status "$SHIPPED_ID")" = "shipped" ] || cv_fail "expected shipped order to stay shipped got $(order_status "$SHIPPED_ID")" $LINENO
[ "$(order_status "$CANCELLED_ID")" = "cancelled" ] || cv_fail "expected cancelled order to stay cancelled got $(order_status "$CANCELLED_ID")" $LINENO

# Cleanup
cv_step Cleanup "remove seeded orders, products and users" $LINENO
cleanup_data "$SHIPPED_ID $CANCELLED_ID" "$P1 $P2" "$CUST_ID $STAFF_ID"
echo "CODEVALID_TEST_ASSERTION_OK:ship_non_placed_order_invalid_state"
