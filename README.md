# Olist E-Commerce — Order & Revenue Analysis

A complete SQL portfolio project analysing 100 K+ orders from Brazil's largest
online marketplace (Olist) to answer a real CEO-level business question.

**Author:** Khushi
**Domain:** E-Commerce / Retail
**Database:** MySQL 8.x

---

## 1. Business Problem

> The CEO asks: **"Revenue grew 12 % this year, but profits dropped. Why?
> Which categories, regions, and customer segments are dragging us down?"**

The goal of this project is to load Olist's raw transactional data into a
relational database, clean it carefully, and write SQL queries that answer
that question with concrete numbers and actionable recommendations.

---

## 2. Dataset

- **Source:** [Brazilian E-Commerce Public Dataset by Olist (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Size:** ~100 K orders, ~112 K order items, ~1 M geolocation rows
- **Tables:** 9 related tables — orders, order_items, customers, sellers,
  products, payments, reviews, geolocation, category_translation
- **Time range:** 2016 – 2018

---

## 3. Tech Stack

| Layer | Tool |
|---|---|
| Database | MySQL 8.x |
| Language | SQL (DDL + DML + analytics) |
| Concepts used | Multi-table JOINs, CTEs, Window functions (`LAG`, `ROW_NUMBER`), `GROUP BY` + `HAVING`, `CASE WHEN`, date functions, `COALESCE` |
| Documentation | Markdown |

---

## 4. ER Diagram

```
                ┌──────────────┐
                │  customers   │
                │ PK customer_id│
                └──────┬───────┘
                       │ 1
                       │ ∞
                ┌──────▼───────┐         ┌─────────────┐
                │   orders     │ 1     ∞ │  payments   │
                │ PK order_id  ├─────────┤ PK order_id,│
                │ FK customer  │         │   pay_seq   │
                └──┬────────┬──┘         └─────────────┘
              1   │        │ 1
              ∞   │        │ ∞
        ┌─────────▼─┐    ┌─▼──────────┐
        │order_items│    │  reviews   │
        │PK order_  │    │ PK review_ │
        │ +item_id  │    │     id     │
        └─┬───────┬─┘    └────────────┘
        ∞ │       │ ∞
        1 │       │ 1
   ┌──────▼─┐  ┌──▼────────┐
   │products│  │  sellers  │
   │PK prod │  │ PK seller │
   └───┬────┘  └───────────┘
       │ ∞
       │ 1
┌──────▼──────────────┐
│ category_translation│
│ PK pt_category_name │
└─────────────────────┘

geolocation (zip prefix → lat / lng / city / state) is a reference
table joined ad-hoc on customer or seller zip prefix.
```

**Key relationships**

| Child → Parent | Cardinality |
|---|---|
| orders.customer_id → customers | many → 1 |
| order_items.order_id → orders | many → 1 |
| order_items.product_id → products | many → 1 |
| order_items.seller_id → sellers | many → 1 |
| payments.order_id → orders | many → 1 |
| reviews.order_id → orders | many → 1 |
| products.product_category_name → category_translation | many → 1 |

---

## 5. Repository Structure & How to Run

```
project/
├── schema.sql      -- creates DB, tables, loads CSVs, adds PK / FK
├── analysis.sql    -- 18 commented business queries
└── README.md       -- this file
```

**Run order in MySQL Workbench:**

1. Open `schema.sql` → **Run** (creates the database, loads all CSVs,
   enforces constraints, and fixes invalid date placeholders).
2. Open `analysis.sql` → **Run** (executes all 18 analytical queries).

> Update the `LOAD DATA LOCAL INFILE` paths inside `schema.sql` to point
> to the location of the Olist CSVs on your machine.

---

## 6. Data Cleaning Summary

Every cleaning decision is documented with **before / after counts** and a
short justification. Highlights:

| Step | Records affected | Outcome |
|---|---:|---|
| Replaced `'0000-00-00'` placeholder dates with `NULL` | 4 908 | Date math (delivery time, MoM growth) now valid |
| Excluded non-delivered orders from revenue queries | 2 963 | Truthful revenue figures |
| Verified no duplicate `order_id` in `orders` | 0 found | Primary key enforced safely |
| Items-vs-payments mismatch documented | ~3 100 orders | Reported separately (vouchers + installment fees) |
| Geolocation deduplicated (avg lat/lng per zip) | 1 000 163 → 19 015 | Clean coordinates per zip prefix |
| Portuguese categories joined to English via lookup | all products | International readability |
| Latest review per order via `ROW_NUMBER()` | 555 duplicates | One row per order in analysis |
| Orphan-row check before every foreign key | 0 orphans | All 6 FKs added cleanly |

**Decisions taken**

- **Revenue universe** = orders WHERE `order_status = 'delivered'`. Cancelled,
  shipped-but-stuck, and unavailable orders are reported as funnel leakage,
  never counted as revenue.
- **Revenue formula** = `SUM(order_items.price + order_items.freight_value)`,
  not `payments.payment_value`. Payment value can include voucher discounts
  or installment fees that distort true goods value.
- **Categories** are surfaced in English using `category_translation`. NULL
  categories are reported as `'unknown'` via `COALESCE`.
- **Row-inflation guard:** when joining `orders` with `order_items`, the
  many-to-one relationship multiplies rows. All revenue aggregates are
  computed inside CTEs / sub-queries before joining onward.

---

## 7. Analysis Approach

The 18 queries in `analysis.sql` are organised into 6 sections:

| Section | Focus | Queries |
|---|---|---|
| A. Sanity & Totals | Order-status mix, headline revenue, headline volumes | Q1 – Q3 |
| B. Revenue Trends (Time) | Monthly revenue, MoM growth via `LAG()`, seasonality | Q4 – Q6 |
| C. Revenue by Category | Top / bottom categories, freight-to-price margin proxy | Q7 – Q9 |
| D. Revenue by Geography | Top / bottom states, regional concentration | Q10 – Q11 |
| E. Customer Behaviour | AOV, repeat-rate, segments, payment methods | Q12 – Q15 |
| F. Seller Performance | Top sellers, delivery time, delivery-vs-rating link | Q16 – Q18 |

Every query is preceded by the **business question** it answers.

---

## 8. Key Insights

> All figures use the `delivered` order universe.

1. **Revenue funnel leakage is small but real** — ~3 % of orders never
   deliver. Counting them naïvely would inflate revenue by ~R$ 450 K
   *(Q1, Q2)*.
2. **Health & beauty, watches/gifts, and bed-bath-table dominate** —
   together producing ~35 % of total goods value while also sitting in
   the top 5 by order count. These are the engines of the business *(Q7)*.
3. **Freight-heavy categories silently kill margin** — categories like
   *furniture/decor* and *office furniture* show freight at **30 – 55 % of
   average item price** *(Q9)*. Every sale ships a hidden discount to the
   carrier.
4. **Geographic concentration is extreme** — São Paulo, Rio de Janeiro and
   Minas Gerais generate ~62 % of revenue, while the bottom 10 states
   combined account for under 4 % *(Q10, Q11)*.
5. **97 % of customers are one-time buyers** — the platform is acquiring,
   not retaining *(Q13, Q14)*.
6. **Credit card carries the business** — ~74 % of payment value flows
   through credit cards, but boleto still represents ~19 % of transactions
   and cannot be ignored *(Q15)*.
7. **Delivery speed materially impacts ratings** — sellers averaging
   < 7 days delivery score ~4.4 / 5, while sellers averaging 25+ days drop
   to ~3.0 / 5 — a **1.4-star gap** with measurable retention cost *(Q18)*.
8. **November ("Black Friday") is the seasonal peak** — revenue ~2× the
   trailing 6-month average; Q4 materially stronger than Q1 *(Q6)*.

---

## 9. Recommendations

1. **Renegotiate freight contracts for furniture & bulky-decor categories.**
   Even a 10 % freight reduction on the top 5 freight-heavy categories
   would lift contribution margin without touching list prices
   *(addresses insight #3)*.
2. **Introduce a seller delivery SLA of ≤ 14 days**, with a dashboard
   ranking sellers and consequences for repeat offenders. The 1.4-star gap
   between fast and slow sellers is the single most actionable retention
   lever in the dataset *(addresses insight #7)*.
3. **Launch a retention / repeat-purchase programme** — loyalty tier,
   post-purchase email flow, win-back coupon at day 30 / 60 / 90. Moving
   the repeat rate from 3 % to even 6 % doubles repeat revenue with no new
   acquisition cost *(addresses insight #5)*.
4. **Concentrate marketing spend on top-3 states (SP / RJ / MG)** until
   product-market fit in the long-tail states is improved. Run a small
   geo-targeted experiment in 2 mid-tier states to test whether spend can
   profitably scale outside the core *(addresses insight #4)*.
5. **Plan inventory and seller capacity for the Q4 / Black Friday peak** —
   the November spike is the biggest revenue moment of the year and slow
   delivery during the spike directly damages ratings *(addresses
   insights #7 + #8)*.

---

## 10. Interview Story (60-second version)

**Problem.** Olist's leadership saw 12 % revenue growth coupled with
declining profit. I needed to find which parts of the business were
dragging margin down.

**Approach.** Loaded 9 CSVs (~100 K orders) into MySQL, enforced PK / FK
constraints, fixed ~5 K invalid dates and ~555 duplicate reviews, and
wrote 18 analytical queries grouped into Sanity, Time, Category,
Geography, Customer and Seller sections.

**Insight.** Furniture and decor categories carried freight equal to
30 – 55 % of item price, silently eroding margin. Sellers with average
delivery > 25 days scored 1.4 stars lower than fast sellers. 97 % of
customers were one-time buyers.

**Action.** Recommended renegotiating freight on bulky categories,
enforcing a 14-day seller delivery SLA, and launching a repeat-purchase
programme. Together these address margin, retention and rating quality —
directly attacking the profit-decline thesis.

---

## 11. Quality Checklist

- [x] 5+ insights with specific numbers
- [x] 3+ business recommendations tied to insights
- [x] Data cleaning documented with before / after counts
- [x] ER diagram included
- [x] Every query commented with the business question it answers
- [x] Row counts validated after every JOIN
