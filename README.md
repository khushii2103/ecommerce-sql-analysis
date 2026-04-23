# Project 1 — Olist E-Commerce: Order & Revenue Analysis

**Domain:** E-Commerce / Retail
**Author:** Khushi
**Database:** MySQL 8.x
**Dataset:** [Brazilian E-Commerce Public Dataset by Olist (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100 K orders across 9 related tables.

---

## 1. Business Problem

> The CEO asks: **"Revenue grew 12 % this year, but profits dropped. Why? Which categories, regions, and customer segments are dragging us down?"**

The goal of this project is to load Olist's raw data into a relational database, clean it, and write SQL queries that answer that question with concrete numbers and recommendations.

---

## 2. Repository Structure

```
project/
├── schema.sql              -- CREATE DATABASE, tables, constraints, FK
├── data_cleaning_log.md    -- every cleaning decision with before/after counts
├── analysis.sql            -- 18 commented business queries
└── README.md               -- this file
```

Run order:
1. `schema.sql` — provisions the `ecommerce` database.
2. (Cleaning steps in `schema.sql` Section 12 fire automatically.)
3. `analysis.sql` — runs all analytical queries.

---

## 3. ER Diagram

```
                ┌──────────────┐
                │  customers   │
                │  PK customer_id
                └──────┬───────┘
                       │ 1
                       │
                       │ ∞
                ┌──────▼───────┐         ┌─────────────┐
                │   orders     │ 1     ∞ │  payments   │
                │  PK order_id ├─────────┤ PK order_id,│
                │  FK customer │         │    pay_seq  │
                └──┬────────┬──┘         └─────────────┘
              1   │        │ 1
                  │        │
              ∞   │        │ ∞
        ┌─────────▼─┐    ┌─▼──────────┐
        │order_items│    │  reviews   │
        │ PK order_ │    │ PK review_ │
        │  +item_id │    │     id     │
        └─┬───────┬─┘    └────────────┘
        ∞ │       │ ∞
          │       │
        1 │       │ 1
   ┌──────▼─┐  ┌──▼────────┐
   │products│  │  sellers  │
   │PK prod │  │ PK seller │
   └───┬────┘  └───────────┘
       │ ∞
       │
       │ 1
┌──────▼──────────────┐
│ category_translation│
│ PK pt_category_name │
└─────────────────────┘

geolocation (zip prefix → lat / lng / city / state) is a reference
table joined ad-hoc on customer or seller zip prefix.
```

**Key relationships**

| Child → Parent                         | Cardinality |
|----------------------------------------|-------------|
| orders.customer_id → customers         | many → 1    |
| order_items.order_id → orders          | many → 1    |
| order_items.product_id → products      | many → 1    |
| order_items.seller_id → sellers        | many → 1    |
| payments.order_id → orders             | many → 1    |
| reviews.order_id → orders              | many → 1    |
| products.product_category_name → category_translation | many → 1 |

---

## 4. Data-Cleaning Summary

Full detail in [`data_cleaning_log.md`](./data_cleaning_log.md). Highlights:

| Step | Records affected | Outcome |
|---|---:|---|
| Replaced `'0000-00-00'` placeholder dates with `NULL` | 4 908 | Date math now valid |
| Excluded non-delivered orders from revenue queries | 2 963 | Truthful revenue figures |
| Verified no duplicate `order_id` in `orders` | 0 found | PK enforced safely |
| Items-vs-payments mismatch documented | ~3 100 orders | Reported separately |
| Geolocation dedup view (`v_geolocation_clean`) | 1 000 163 → 19 015 | Single lat/lng per zip |
| Portuguese → English category via JOIN | all products | International readability |
| Latest review per order via `ROW_NUMBER()` | 555 dupes | One row per order |
| Orphan check before every FK | 0 orphans | All 6 FKs added cleanly |

---

## 5. Insights (with numbers)

> All figures use the `delivered` order universe.

1. **Revenue funnel leakage is small but real.** ~3 % of orders never deliver (`canceled`, `unavailable`, `shipped-but-stuck`), removing ≈ R$ 450 K from headline revenue if naïvely counted (Q1, Q2).
2. **Health & beauty, watches/gifts, and bed-bath-table dominate revenue**, together producing roughly **35 % of total goods value** while sitting in the top-5 by order count too — these are the engines of the business (Q7).
3. **Freight-heavy categories silently kill margin.** Categories like *furniture/decor* and *office furniture* show freight at **30–55 % of average item price** (Q9) — every sale ships a discount-by-postage to the carrier.
4. **Geographic concentration is extreme.** São Paulo (SP), Rio de Janeiro (RJ) and Minas Gerais (MG) generate ~**62 % of revenue**, while the bottom 10 states combined account for under 4 % (Q10, Q11). Marketing spend outside the top three is sub-scale.
5. **The customer base is overwhelmingly one-shot.** ~**97 % of unique customers placed exactly one delivered order** (Q13, Q14). The platform is acquiring, not retaining.
6. **Credit card carries the business.** ~**74 % of payment value** flows through credit cards, but **boleto** (Brazilian bank slip) still represents ~19 % of *transactions* — losing boleto support would cut a meaningful slice of orders (Q15).
7. **Delivery speed materially impacts ratings.** Sellers averaging **<7 days** delivery score ~**4.4 / 5**, while sellers averaging **25+ days** drop to **~3.0 / 5** — a **~1.4-star gap** with a measurable retention cost (Q18).
8. **Nov 2017 ("Black Friday") is the seasonal peak**, with revenue ~**2× the trailing 6-month average**; Q4 is materially stronger than Q1 (Q6).

---

## 6. Recommendations

1. **Renegotiate freight contracts for furniture & bulky-decor categories.** They have the worst freight-to-price ratios (insight #3). Even a 10 % freight reduction on the top 5 freight-heavy categories would lift contribution margin without touching list prices.
2. **Introduce a seller delivery SLA of ≤14 days, with a dashboard ranking and consequences for repeat offenders** (insight #7). The 1.4-star gap between fast and slow sellers is the single most actionable retention lever in the dataset.
3. **Launch a retention / repeat-purchase programme** (loyalty tier, post-purchase email flow, win-back coupon at day 30 / 60 / 90) — insight #5. With 97 % of customers being one-time, even moving the repeat rate to **6 %** doubles repeat revenue with no new acquisition cost.
4. **Shift marketing spend toward the top-3 states (SP / RJ / MG)** until product–market fit in the long-tail states is improved (insight #4). Run a small geo-targeted experiment in 2 mid-tier states to test whether spend can profitably scale outside the core.
5. **Plan inventory and seller capacity for the Q4 / Black Friday peak** (insight #8) — the November spike is the single biggest revenue moment of the year and slow delivery during the spike directly damages ratings (compounding insight #7).

---

## 7. SQL Concepts Demonstrated

- Multi-table JOINs (4–5 tables in Q7, Q10, Q18)
- `GROUP BY` + `HAVING` (volume floors in Q7, Q8, Q17, Q18)
- `CASE WHEN` (segmentation in Q14, Q18)
- Date functions: `DATE_FORMAT`, `MONTH`, `MONTHNAME`, `DATEDIFF`
- Window functions: `LAG()` (Q5), `ROW_NUMBER()` (cleaning step 8)
- CTEs / sub-queries (Q5, Q12, Q13, Q14, Q18)
- `COALESCE` for NULL handling (Q7, Q8, Q9)
- Defensive aggregation BEFORE join to avoid row-inflation (Q12, Q5)

---

## 8. Quality Checklist

- [x] 5+ insights with specific numbers
- [x] 3+ business recommendations tied to insights
- [x] Data cleaning documented with before/after counts
- [x] ER diagram in README
- [x] Every query commented with the business question it answers
- [x] Row counts validated after every JOIN (see `data_cleaning_log.md` § 9)

---

## 9. Interview Story (60-second version)

**Problem.** Olist's leadership saw 12 % revenue growth coupled with declining profit. I needed to find which parts of the business were dragging margin down.

**Approach.** Loaded 9 CSVs (~100 K orders) into MySQL, enforced PK/FK constraints, fixed ~5 K invalid dates and ~555 duplicate reviews, and wrote 18 analytical queries grouped into Sanity, Time, Category, Geography, Customer, and Seller sections.

**Insight.** Furniture and decor categories carried freight equal to 30–55 % of item price, silently eroding margin. Sellers with average delivery >25 days scored 1.4 stars lower than fast sellers. 97 % of customers were one-time buyers.

**Action.** Recommended renegotiating freight on bulky categories, enforcing a 14-day seller delivery SLA, and launching a repeat-purchase programme. Together these address margin, retention, and rating quality — directly attacking the profit-decline thesis.
