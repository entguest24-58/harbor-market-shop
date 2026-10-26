#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_5637790689_20261026191753/api/_infra.sh

cv_step Given "staff user and a placed customer order with a discount" $LINENO
SFX=$(cv_suffix)
create_user "cv-sec-cust-$SFX@example.com" customer || exit 1
CUST_ID=$CV_USER_ID
create_user "cv-sec-staff-$SFX@example.com" staff || exit 1
STAFF_ID=$CV_USER_ID; STAFF_TOKEN=$CV_TOKEN
seed_order "$CUST_ID" placed "CVSEC$RANDOM" || exit 1
ORDER_ID=$CV_ORDER_ID; PRODUCT_ID=$CV_PRODUCT_ID

cv_step When "staff ships the order" $LINENO
cv_http POST "/orders/$ORDER_ID/ship" -H "Authorization: Bearer $STAFF_TOKEN"
STATUS=$CV_HTTP_STATUS
LEAKED=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.order // {} | keys[] | select(. == "subtotalCents" or . == "discountCode" or . == "discountCents" or . == "shippingCents" or . == "totalCents" or . == "createdAt" or . == "updatedAt")] | join(",")' 2>/dev/null || echo "")

cv_step Cleanup "remove probe data" $LINENO
cleanup_data "$ORDER_ID" "$PRODUCT_ID" "$CUST_ID $STAFF_ID"

if [ "$STATUS" = "200" ] && [ -n "$LEAKED" ]; then
  printf 'CV_SECURITY|vulnerable|access|serious|Staff shipping endpoint leaks full order financial details|POST ship returned %s with order fields %s\n' "$STATUS" "$LEAKED"
else
  printf 'CV_SECURITY|secure|access|serious|Staff shipping endpoint leaks full order financial details|POST ship returned %s without financial fields\n' "$STATUS"
fi
exit 0
