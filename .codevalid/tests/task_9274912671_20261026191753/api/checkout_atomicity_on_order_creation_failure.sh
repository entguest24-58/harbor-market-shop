#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_9274912671_20261026191753/api/_infra.sh

# Given
cv_step Given "a shopper with a valid cart and code, and a DB trigger that makes this shopper's order INSERT fail" $LINENO
SFX=$(cv_suffix)
USER_ID=""; PID=""; CID=""; FN="cv_fail_order_$SFX"
cleanup() {
  cv_sql "DROP TRIGGER IF EXISTS ${FN}_trg ON orders; DROP FUNCTION IF EXISTS ${FN}();" >/dev/null 2>&1 || true
  cv_cleanup_user "$USER_ID"; cv_cleanup_products "$PID"; cv_cleanup_codes "$CID"
}
trap cleanup EXIT
cv_register_login "cv.atom.$SFX@example.com" $LINENO
USER_ID=$CV_USER_ID; TOKEN=$CV_TOKEN
cv_prereq "seed product and discount code" $LINENO
PID=$(cv_seed_product "CV Atomic Product $SFX" 2500 5) || cv_fail "expected product row created got error" $LINENO
[ -n "$PID" ] || cv_fail "expected product id got empty" $LINENO
CODE="ATM$SFX"; CODE=${CODE:0:20}
CID=$(cv_seed_code "$CODE" fixed 500 0 "now() + interval '1 day'" true) || cv_fail "expected discount code row created got error" $LINENO
[ -n "$CID" ] || cv_fail "expected discount code id got empty" $LINENO
cv_add_to_cart "$TOKEN" "$PID" 2 $LINENO
cv_prereq "install trigger simulating a DB failure on order insert for this shopper only" $LINENO
cv_sql "CREATE FUNCTION ${FN}() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN RAISE EXCEPTION 'cv simulated order insert failure'; END \$\$;
        CREATE TRIGGER ${FN}_trg BEFORE INSERT ON orders FOR EACH ROW WHEN (NEW.user_id = $USER_ID) EXECUTE FUNCTION ${FN}();" >/dev/null \
  || cv_fail "expected failure trigger installed got error" $LINENO
STOCK_BEFORE=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK_BEFORE" = "5" ] || cv_fail "expected starting stock 5 got $STOCK_BEFORE" $LINENO

# When
cv_step When "shopper checks out with the valid code while order creation fails" $LINENO
cv_http POST /orders/checkout "{\"discountCode\":\"$CODE\"}" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "error returned; stock, orders, cart and discount usage are all unchanged" $LINENO
[ "$CV_HTTP_STATUS" -ge 500 ] || cv_fail "expected 5xx error on order creation failure got $CV_HTTP_STATUS" $LINENO
STOCK=$(cv_count "SELECT stock FROM products WHERE id=$PID")
[ "$STOCK" = "5" ] || cv_fail "expected stock unchanged at 5 got $STOCK" $LINENO
ORD=$(cv_count "SELECT count(*) FROM orders WHERE user_id=$USER_ID")
[ "$ORD" = "0" ] || cv_fail "expected no orders persisted got $ORD" $LINENO
ITEMS=$(cv_count "SELECT count(*) FROM order_items WHERE product_id=$PID")
[ "$ITEMS" = "0" ] || cv_fail "expected no order_items persisted got $ITEMS" $LINENO
CART=$(cv_count "SELECT quantity FROM cart_items WHERE user_id=$USER_ID AND product_id=$PID")
[ "$CART" = "2" ] || cv_fail "expected cart line intact with quantity 2 got '$CART'" $LINENO
USED=$(cv_count "SELECT count(*) FROM orders WHERE discount_code_id=$CID")
[ "$USED" = "0" ] || cv_fail "expected discount code not used by any order got $USED" $LINENO
ACTIVE=$(cv_count "SELECT active FROM discount_codes WHERE id=$CID")
[ "$ACTIVE" = "t" ] || cv_fail "expected discount code still active got $ACTIVE" $LINENO

# Cleanup
cv_step Cleanup "drop trigger, remove user, orders, product and code" $LINENO
cleanup; trap - EXIT
echo "CODEVALID_TEST_ASSERTION_OK:checkout_atomicity_on_order_creation_failure"
