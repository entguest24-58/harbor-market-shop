#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5637790689_20261026191753/api/_infra.sh

# Given
cv_step Given "a customer user owning an order in placed status" $LINENO
SFX=$(cv_suffix)
create_user "cv-ship-nonstaff-$SFX@example.com" customer
CUST_ID=$CV_USER_ID; CUST_TOKEN=$CV_TOKEN
seed_order "$CUST_ID" placed
ORDER_ID=$CV_ORDER_ID; PRODUCT_ID=$CV_PRODUCT_ID

# When
cv_step When "customer calls POST /orders/{id}/ship" $LINENO
cv_http POST "/orders/$ORDER_ID/ship" -H "Authorization: Bearer $CUST_TOKEN"

# Then
cv_step Then "response is 403 forbidden and the order stays placed" $LINENO
[ "$CV_HTTP_STATUS" = "403" ] || cv_fail "expected 403 got $CV_HTTP_STATUS" $LINENO
DBSTATUS=$(order_status "$ORDER_ID")
[ "$DBSTATUS" = "placed" ] || cv_fail "expected DB status placed got $DBSTATUS" $LINENO

# Cleanup
cv_step Cleanup "remove seeded order, product and user" $LINENO
cleanup_data "$ORDER_ID" "$PRODUCT_ID" "$CUST_ID"
echo "CODEVALID_TEST_ASSERTION_OK:ship_order_as_non_staff_forbidden"
