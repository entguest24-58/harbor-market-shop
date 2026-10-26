#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5637790689_20261026191753/api/_infra.sh

# Given
cv_step Given "a staff user and a customer's order in placed status" $LINENO
SFX=$(cv_suffix)
create_user "cv-ship-cust-$SFX@example.com" customer
CUST_ID=$CV_USER_ID
create_user "cv-ship-staff-$SFX@example.com" staff
STAFF_ID=$CV_USER_ID; STAFF_TOKEN=$CV_TOKEN
seed_order "$CUST_ID" placed
ORDER_ID=$CV_ORDER_ID; PRODUCT_ID=$CV_PRODUCT_ID

# When
cv_step When "staff calls POST /orders/{id}/ship" $LINENO
cv_http POST "/orders/$ORDER_ID/ship" -H "Authorization: Bearer $STAFF_TOKEN"

# Then
cv_step Then "response is 200 with the order in shipped status and DB updated" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
RID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.id')
[ "$RID" = "$ORDER_ID" ] || cv_fail "expected order.id $ORDER_ID got $RID" $LINENO
RSTATUS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.order.status')
[ "$RSTATUS" = "shipped" ] || cv_fail "expected order.status shipped got $RSTATUS" $LINENO
DBSTATUS=$(order_status "$ORDER_ID")
[ "$DBSTATUS" = "shipped" ] || cv_fail "expected DB status shipped got $DBSTATUS" $LINENO

# Cleanup
cv_step Cleanup "remove seeded order, product and users" $LINENO
cleanup_data "$ORDER_ID" "$PRODUCT_ID" "$CUST_ID $STAFF_ID"
echo "CODEVALID_TEST_ASSERTION_OK:ship_placed_order_as_staff_success"
