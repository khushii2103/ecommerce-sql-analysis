/* ============================================================================
 *  PROJECT      : Olist Brazilian E-Commerce — Order & Revenue Analysis
 *  FILE         : analysis.sql
 *  PURPOSE      : 18 business queries grouped into 6 sections.
 *                 Every query is preceded by the BUSINESS QUESTION it answers.
 *  AUTHOR       : Khushi
 *  PREREQ       : schema.sql executed successfully.
 *  CONVENTIONS  :
 *      - Revenue  = SUM(order_items.price + order_items.freight_value)
 *      - Revenue universe = orders WHERE order_status = 'delivered'
 *      - Categories surfaced in English via category_translation
 *      - COALESCE used to handle NULL category names
 * ============================================================================
 */

USE ecommerce;


/* ############################################################################
 *  SECTION A : SANITY CHECKS & TOTALS
 * ############################################################################
 */

-- Q1. How many orders fall in each status bucket?
--     (Tells us how much of the funnel actually completes.)
SELECT order_status,
       COUNT(*)                                        AS total_orders,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- Q2. Headline revenue: total goods value from delivered orders.
SELECT ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue_brl
FROM   orders      o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_status = 'delivered';


-- Q3. Headline volumes: distinct orders, items, customers, sellers, products.
SELECT
    COUNT(DISTINCT o.order_id)            AS delivered_orders,
    COUNT(oi.order_item_id)               AS line_items,
    COUNT(DISTINCT o.customer_id)         AS customers,
    COUNT(DISTINCT oi.seller_id)          AS sellers,
    COUNT(DISTINCT oi.product_id)         AS products
FROM   orders      o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_status = 'delivered';


/* ############################################################################
 *  SECTION B : REVENUE TRENDS (TIME)
 * ############################################################################
 */

-- Q4. Monthly revenue trend — how does revenue evolve over time?
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')        AS year_month,
    COUNT(DISTINCT o.order_id)                              AS orders,
    ROUND(SUM(oi.price + oi.freight_value), 2)              AS revenue_brl
FROM   orders      o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_status = 'delivered'
GROUP BY year_month
ORDER BY year_month;


-- Q5. Month-over-Month (MoM) revenue growth using LAG().
--     First month's growth is intentionally NULL — do NOT show 0 %.
WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')      AS year_month,
        SUM(oi.price + oi.freight_value)                      AS revenue
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY year_month
)
SELECT
    year_month,
    ROUND(revenue, 2)                                          AS revenue_brl,
    ROUND(LAG(revenue) OVER (ORDER BY year_month), 2)          AS prev_month_revenue,
    ROUND( (revenue - LAG(revenue) OVER (ORDER BY year_month))
           / LAG(revenue) OVER (ORDER BY year_month) * 100, 2) AS mom_growth_pct
FROM monthly
ORDER BY year_month;


-- Q6. Seasonal pattern — average revenue per calendar month (Jan..Dec).
SELECT
    MONTH(o.order_purchase_timestamp)             AS month_num,
    MONTHNAME(o.order_purchase_timestamp)         AS month_name,
    ROUND(SUM(oi.price + oi.freight_value), 2)    AS revenue_brl,
    COUNT(DISTINCT o.order_id)                    AS orders
FROM   orders      o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_status = 'delivered'
GROUP BY month_num, month_name
ORDER BY month_num;


/* ############################################################################
 *  SECTION C : REVENUE BY CATEGORY (PRODUCT MIX)
 * ############################################################################
 */

-- Q7. Top 10 categories by revenue (English names).
--     Reports order count alongside revenue so averages aren't misleading.
SELECT
    COALESCE(ct.product_category_name_english, 'unknown')  AS category,
    COUNT(DISTINCT o.order_id)                             AS orders,
    ROUND(SUM(oi.price + oi.freight_value), 2)             AS revenue_brl,
    ROUND(AVG(oi.price + oi.freight_value), 2)             AS avg_item_value
FROM   orders               o
JOIN   order_items          oi ON oi.order_id            = o.order_id
JOIN   products             p  ON p.product_id           = oi.product_id
LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
WHERE  o.order_status = 'delivered'
GROUP BY category
HAVING orders >= 50          -- ignore tiny categories so averages mean something
ORDER BY revenue_brl DESC
LIMIT 10;


-- Q8. Bottom 10 categories by revenue (with at least 50 orders).
SELECT
    COALESCE(ct.product_category_name_english, 'unknown')  AS category,
    COUNT(DISTINCT o.order_id)                             AS orders,
    ROUND(SUM(oi.price + oi.freight_value), 2)             AS revenue_brl
FROM   orders               o
JOIN   order_items          oi ON oi.order_id            = o.order_id
JOIN   products             p  ON p.product_id           = oi.product_id
LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
WHERE  o.order_status = 'delivered'
GROUP BY category
HAVING orders >= 50
ORDER BY revenue_brl ASC
LIMIT 10;


-- Q9. Margin-style proxy: avg item price vs avg freight per category.
--     High freight ratio → margin pressure.
SELECT
    COALESCE(ct.product_category_name_english, 'unknown')   AS category,
    ROUND(AVG(oi.price), 2)                                 AS avg_price,
    ROUND(AVG(oi.freight_value), 2)                         AS avg_freight,
    ROUND(AVG(oi.freight_value) / AVG(oi.price) * 100, 2)   AS freight_pct_of_price
FROM   orders               o
JOIN   order_items          oi ON oi.order_id            = o.order_id
JOIN   products             p  ON p.product_id           = oi.product_id
LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
WHERE  o.order_status = 'delivered'
GROUP BY category
HAVING COUNT(*) >= 100
ORDER BY freight_pct_of_price DESC
LIMIT 15;


/* ############################################################################
 *  SECTION D : REVENUE BY GEOGRAPHY (CUSTOMER STATE)
 * ############################################################################
 */

-- Q10. Top 10 customer states by revenue.
SELECT
    c.customer_state                                AS state,
    COUNT(DISTINCT o.order_id)                      AS orders,
    ROUND(SUM(oi.price + oi.freight_value), 2)      AS revenue_brl,
    ROUND(AVG(oi.price + oi.freight_value), 2)      AS avg_item_value
FROM   orders      o
JOIN   customers   c  ON c.customer_id = o.customer_id
JOIN   order_items oi ON oi.order_id   = o.order_id
WHERE  o.order_status = 'delivered'
GROUP BY state
ORDER BY revenue_brl DESC
LIMIT 10;


-- Q11. Bottom 10 customer states by revenue (still need >=100 orders).
SELECT
    c.customer_state                                AS state,
    COUNT(DISTINCT o.order_id)                      AS orders,
    ROUND(SUM(oi.price + oi.freight_value), 2)      AS revenue_brl
FROM   orders      o
JOIN   customers   c  ON c.customer_id = o.customer_id
JOIN   order_items oi ON oi.order_id   = o.order_id
WHERE  o.order_status = 'delivered'
GROUP BY state
HAVING orders >= 100
ORDER BY revenue_brl ASC
LIMIT 10;


/* ############################################################################
 *  SECTION E : CUSTOMER BEHAVIOUR
 * ############################################################################
 */

-- Q12. Average Order Value (AOV) overall.
WITH order_totals AS (
    SELECT o.order_id,
           SUM(oi.price + oi.freight_value) AS order_value
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.order_status = 'delivered'
    GROUP BY o.order_id
)
SELECT
    COUNT(*)                  AS delivered_orders,
    ROUND(AVG(order_value),2) AS aov_brl,
    ROUND(MIN(order_value),2) AS min_order,
    ROUND(MAX(order_value),2) AS max_order
FROM order_totals;


-- Q13. Repeat-buyer rate — how many customers placed >1 order?
WITH per_customer AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders
    FROM   customers c
    JOIN   orders    o ON o.customer_id = c.customer_id
    WHERE  o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                                  AS unique_customers,
    SUM(CASE WHEN orders = 1 THEN 1 ELSE 0 END)               AS one_time_buyers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)               AS repeat_buyers,
    ROUND(SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) * 100.0
          / COUNT(*), 2)                                      AS repeat_rate_pct
FROM per_customer;


-- Q14. Customer order-volume buckets (CASE WHEN segmentation).
WITH per_customer AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders
    FROM   customers c
    JOIN   orders    o ON o.customer_id = c.customer_id
    WHERE  o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN orders = 1            THEN '1 order'
        WHEN orders BETWEEN 2 AND 3 THEN '2-3 orders'
        WHEN orders BETWEEN 4 AND 9 THEN '4-9 orders'
        ELSE '10+ orders'
    END                       AS segment,
    COUNT(*)                  AS customers
FROM per_customer
GROUP BY segment
ORDER BY customers DESC;


-- Q15. Payment-method distribution — share of orders & total value.
SELECT
    payment_type,
    COUNT(*)                                                  AS transactions,
    ROUND(SUM(payment_value), 2)                              AS total_paid_brl,
    ROUND(AVG(payment_value), 2)                              AS avg_payment,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)        AS pct_of_transactions
FROM   payments
GROUP BY payment_type
ORDER BY total_paid_brl DESC;


/* ############################################################################
 *  SECTION F : SELLER PERFORMANCE
 * ############################################################################
 */

-- Q16. Top 10 sellers by revenue.
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id)                  AS orders,
    ROUND(SUM(oi.price + oi.freight_value), 2)   AS revenue_brl
FROM   order_items oi
JOIN   orders      o ON o.order_id = oi.order_id
WHERE  o.order_status = 'delivered'
GROUP BY oi.seller_id
ORDER BY revenue_brl DESC
LIMIT 10;


-- Q17. Average delivery time per seller (purchase → customer delivery).
--      Slow sellers = candidates for SLA enforcement.
SELECT
    oi.seller_id,
    COUNT(DISTINCT o.order_id)                                          AS delivered_orders,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date,
                       o.order_purchase_timestamp)), 1)                 AS avg_delivery_days
FROM   orders      o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_status = 'delivered'
  AND  o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id
HAVING delivered_orders >= 50      -- only sellers with enough volume
ORDER BY avg_delivery_days DESC
LIMIT 15;


-- Q18. Does slow delivery hurt review scores?
--      Bucket sellers by delivery speed and compare avg review score.
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        AVG(DATEDIFF(o.order_delivered_customer_date,
                     o.order_purchase_timestamp)) AS avg_delivery_days,
        AVG(r.review_score)                       AS avg_review,
        COUNT(DISTINCT o.order_id)                AS orders
    FROM   orders      o
    JOIN   order_items oi ON oi.order_id = o.order_id
    JOIN   reviews     r  ON r.order_id  = o.order_id
    WHERE  o.order_status = 'delivered'
      AND  o.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
    HAVING orders >= 50
)
SELECT
    CASE
        WHEN avg_delivery_days <  7  THEN '1. <7 days'
        WHEN avg_delivery_days < 15  THEN '2. 7-14 days'
        WHEN avg_delivery_days < 25  THEN '3. 15-24 days'
        ELSE                              '4. 25+ days'
    END                              AS delivery_bucket,
    COUNT(*)                         AS sellers,
    ROUND(AVG(avg_review), 2)        AS avg_review_score,
    SUM(orders)                      AS total_orders
FROM seller_stats
GROUP BY delivery_bucket
ORDER BY delivery_bucket;


/* ============================================================================
 *  END OF analysis.sql
 * ============================================================================
 */
