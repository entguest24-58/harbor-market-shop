#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5637790689_20261026191753/api/_infra.sh

# Given
cv_step Given "a staff user and an order id that does not exist" $LINENO
SFX=$(cv_suffix)
create_user "cv-ship-nf-staff-$SFX@example.com" staff
STAFF_ID=$CV_USER_ID; STAFF_TOKEN=$CV_TOKEN
MISSING_ID=$(db_psql -c "SELECT COALESCE(MAX(id),0) + 100000 FROM orders")
_cv_is_int "$MISSING_ID" || cv_fail "expected numeric missing id got $MISSING_ID" $LINENO
EXISTS=$(db_psql -c "SELECT count(*) FROM orders WHERE id=$MISSING_ID")
[ "$EXISTS" = "0" ] || cv_fail "expected order $MISSING_ID to not exist got count $EXISTS" $LINENO

# When
cv_step When "staff calls POST /orders/{id}/ship with the missing id" $LINENO
cv_http POST "/orders/$MISSING_ID/ship" -H "Authorization: Bearer $STAFF_TOKEN"

# Then
cv_step Then "response is 404 not found" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
MSG=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.. | strings' 2>/dev/null | tr '\n' ' ')
case "$MSG" in *"not found"*) ;; *) cv_fail "expected a not found message got $CV_HTTP_BODY" $LINENO ;; esac

# Cleanup
cv_step Cleanup "remove the staff user" $LINENO
cleanup_data "" "" "$STAFF_ID"
echo "CODEVALID_TEST_ASSERTION_OK:ship_nonexistent_order_not_found"
