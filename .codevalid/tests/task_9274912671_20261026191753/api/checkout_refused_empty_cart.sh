#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with an empty cart and a valid discount code" $LINENO
SFX=$(cv_suffix)
USER_ID=""; CID=""
cleanup() { cv_cleanup_user "$USER_ID"; cv_cleanup_codes "$CID"; }
trap cleanup EXIT
cv_register_login "cv.empty.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
CODE="EMP$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" percentage 10 0 NULL true) || cv_fail "expected discount code row created got error" $LINENO

# When
cv_step When "shopper checks out with the empty cart" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "checkout refused with clear error; no order, no code usage, cart still empty" $LINENO
[ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
printf '%s' "$ERR" | grep -qi 'empty' || cv_fail "expected error mentioning empty cart got '$ERR'" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID")
[ "$ORD" = "0" ] || cv_fail "expected 0 orders got $ORD" $LINENO
USED=$(cv_count "SELECT count(*) FROM orders WHERE discount_code_id=$CID")
[ "$USED" = "0" ] || cv_fail "expected code usage 0 got $USED" $LINENO
CART=$(cv_count "SELECT count(*) FROM cart_items WHERE user_id=$USER_ID")
[ "$CART" = "0" ] || cv_fail "expected cart still empty got $CART lines" $LINENO

# Cleanup
cv_step Cleanup "remove user and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_refused_empty_cart"
