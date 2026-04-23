# Data Cleaning Log — Olist E-Commerce Project

This log documents every data-quality decision taken on the raw Olist CSVs
before running revenue and performance analysis. Each section records:
**what was found → what was decided → why → before/after counts**.

---

## 1. Invalid placeholder dates in `orders`

**Issue.** MySQL stored missing delivery dates as `'0000-00-00 00:00:00'`
instead of `NULL` because the CSVs had blank values. This corrupts any
date arithmetic (delivery time, MoM growth).

**Decision.** Replace placeholder with proper `NULL`.

**Action.**
```sql
UPDATE orders SET order_approved_at             = NULL WHERE order_approved_at             = '0000-00-00 00:00:00';
UPDATE orders SET order_delivered_carrier_date  = NULL WHERE order_delivered_carrier_date  = '0000-00-00 00:00:00';
UPDATE orders SET order_delivered_customer_date = NULL WHERE order_delivered_customer_date = '0000-00-00 00:00:00';
```

| Column                          | Before (`0000-…` rows) | After (`NULL` rows) |
|---------------------------------|------------------------|---------------------|
| `order_approved_at`             | 160                    | 160                 |
| `order_delivered_carrier_date`  | 1 783                  | 1 783               |
| `order_delivered_customer_date` | 2 965                  | 2 965               |

---

## 2. Orders with NULL delivery dates — cancelled vs unshipped

**Issue.** ~3 % of orders never reached the customer. We must NOT count
their item value as revenue.

**Decision.** Treat **only `order_status = 'delivered'`** as revenue-eligible.
All revenue queries filter on this status. Other statuses
(`canceled`, `unavailable`, `shipped`, `processing`, `invoiced`,
`approved`, `created`) are reported separately as funnel leakage.

| order_status | rows    | counted as revenue? |
|--------------|---------|---------------------|
| delivered    | 96 478  | ✅                  |
| shipped      | 1 107   | ❌                  |
| canceled     |   625   | ❌                  |
| unavailable  |   609   | ❌                  |
| invoiced     |   314   | ❌                  |
| processing   |   301   | ❌                  |
| approved     |     2   | ❌                  |
| created      |     5   | ❌                  |

---

## 3. Duplicate `order_id` check

**Issue.** Need to confirm `order_id` is truly unique before declaring it
the primary key.

**Action.**
```sql
SELECT order_id, COUNT(*) AS c
FROM orders
GROUP BY order_id HAVING c > 1;
```

**Result.** 0 duplicates found. `order_id` was promoted to PRIMARY KEY.
If duplicates had existed we would have used `ROW_NUMBER() OVER
(PARTITION BY order_id ORDER BY order_purchase_timestamp)` to keep the
earliest record.

---

## 4. `order_items.price` × quantity vs `payments.payment_value`

**Issue.** Per row, the goods total = `price + freight_value`. Summed per
order, this should roughly match the sum of `payment_value`. Mismatches
arise from vouchers, refunds, or installment fees.

**Action.**
```sql
SELECT
    oi.order_id,
    SUM(oi.price + oi.freight_value) AS items_total,
    p.pay_total,
    ROUND(SUM(oi.price + oi.freight_value) - p.pay_total, 2) AS diff
FROM order_items oi
JOIN (SELECT order_id, SUM(payment_value) AS pay_total
      FROM payments GROUP BY order_id) p
  ON oi.order_id = p.order_id
GROUP BY oi.order_id, p.pay_total
HAVING ABS(diff) > 1;
```

**Result.** ~3 100 orders had a mismatch > R$1. Reasons:
- Vouchers reduce `payment_value` below items total
- Installment fees inflate `payment_value` above items total

**Decision.** Keep both metrics separate. **Revenue** = sum of
`price + freight_value` from `order_items` (true goods value). **Payments**
table is reported separately as "amount actually charged" and only used
for payment-method analysis.

---

## 5. Duplicate zip-code prefixes in `geolocation`

**Issue.** Same `geolocation_zip_code_prefix` appears many times with
slightly different lat/long coordinates (multiple businesses inside the
same prefix).

**Decision.** Build a **deduplicated view** that averages lat/long per
zip prefix and keeps the most common city/state.

**Action.**
```sql
CREATE OR REPLACE VIEW v_geolocation_clean AS
SELECT
    geolocation_zip_code_prefix,
    AVG(geolocation_lat) AS lat,
    AVG(geolocation_lng) AS lng,
    MAX(geolocation_city)  AS city,
    MAX(geolocation_state) AS state
FROM geolocation
GROUP BY geolocation_zip_code_prefix;
```

| Metric                            | Before  | After   |
|-----------------------------------|---------|---------|
| Rows in `geolocation`             | 1 000 163 | —     |
| Unique zip prefixes (`v_…clean`)  | —       | 19 015  |

---

## 6. Portuguese category names

**Issue.** `products.product_category_name` is in Portuguese. Reports for
international stakeholders need English.

**Decision.** Always JOIN `category_translation` and surface
`product_category_name_english` in every analytical query. Use `COALESCE`
to handle the ~1.6 % of products whose category is `NULL` —
report them as `'unknown'`.

```sql
COALESCE(ct.product_category_name_english, 'unknown') AS category
```

---

## 7. Orphan-row check before adding foreign keys

**Issue.** A foreign key fails if any child row points to a missing parent.

**Action.** Counted orphans for every relationship before adding the FK:

| Child → Parent                       | Orphan rows found |
|--------------------------------------|------------------:|
| `orders.customer_id` → `customers`   | 0                 |
| `order_items.order_id` → `orders`    | 0                 |
| `order_items.product_id` → `products`| 0                 |
| `order_items.seller_id` → `sellers`  | 0                 |
| `payments.order_id` → `orders`       | 0                 |
| `reviews.order_id` → `orders`        | 0                 |

All FKs were added successfully.

---

## 8. Reviews — duplicate `order_id`

**Issue.** A few orders carry more than one review (resubmissions).

**Decision.** When summarising review score per seller / category, use the
**latest** review per `order_id` via:
```sql
ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_creation_date DESC) = 1
```

**Result.** ~555 duplicate reviews collapsed to a single most-recent
record per order in analysis queries.

---

## 9. Edge case — JOIN row inflation

**Issue.** `orders` ⨝ `order_items` multiplies an order with N items into
N rows. Naïvely summing `payment_value` after this JOIN would multi-count
payments by N.

**Decision.** Always aggregate `order_items` (or `payments`) inside a
sub-query BEFORE joining to `orders`. Validated row counts after every
JOIN in `analysis.sql`.

---

## Summary table

| Cleaning Step                 | Records Touched | Final Outcome                |
|-------------------------------|----------------:|------------------------------|
| Date placeholders → NULL      | 4 908           | Date math now valid          |
| Non-delivered orders excluded | 2 963           | Cleaner revenue figures      |
| Duplicate `order_id`          | 0               | PK enforced safely           |
| Items vs payments mismatch    | 3 100           | Documented, kept separate    |
| Geolocation deduplication     | 1 000 163 → 19 015 | Clean lat/lng per zip      |
| Portuguese categories         | all products    | English surfaced via JOIN    |
| Orphan rows (all 6 FKs)       | 0               | All FKs enforced             |
| Duplicate reviews             | 555             | Latest-only via ROW_NUMBER   |
