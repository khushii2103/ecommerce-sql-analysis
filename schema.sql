/* ============================================================================
 *  PROJECT      : Olist Brazilian E-Commerce — Order & Revenue Analysis
 *  FILE         : schema.sql
 *  PURPOSE      : Create the `ecommerce` database, define all 9 tables with
 *                 proper data types, load the raw CSV files, and enforce
 *                 PRIMARY KEY / FOREIGN KEY constraints for referential
 *                 integrity.
 *  DATABASE     : MySQL 8.x
 *  AUTHOR       : Khushi
 *  DATA SOURCE  : Brazilian E-Commerce Public Dataset by Olist (Kaggle)
 *  HOW TO RUN   : Execute top-to-bottom in MySQL Workbench or CLI.
 *                 Ensure `local_infile` is enabled on both server and client.
 * ============================================================================
 */


/* ----------------------------------------------------------------------------
 *  1. DATABASE INITIALISATION
 * ----------------------------------------------------------------------------
 */
CREATE DATABASE ecommerce;
USE ecommerce;
SET GLOBAL local_infile = 1;


/* ----------------------------------------------------------------------------
 *  2. TABLE : customers
 *     Stores one row per customer account with location info.
 * ----------------------------------------------------------------------------
 */
CREATE TABLE customers (
    customer_id              VARCHAR(50),
    customer_unique_id       VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city            VARCHAR(100),
    customer_state           VARCHAR(10)
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(customer_id, customer_unique_id, customer_zip_code_prefix,
 customer_city, customer_state);


/* ----------------------------------------------------------------------------
 *  3. TABLE : orders
 *     One row per order, with status and key timestamps.
 * ----------------------------------------------------------------------------
 */
CREATE TABLE orders (
    order_id                      VARCHAR(50),
    customer_id                   VARCHAR(50),
    order_status                  VARCHAR(20),
    order_purchase_timestamp      DATETIME,
    order_approved_at             DATETIME,
    order_delivered_carrier_date  DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, order_purchase_timestamp,
 order_approved_at, order_delivered_carrier_date,
 order_delivered_customer_date, order_estimated_delivery_date);


/* ----------------------------------------------------------------------------
 *  4. TABLE : order_items
 *     Each product line within an order. Composite key (order_id, order_item_id).
 * ----------------------------------------------------------------------------
 */
CREATE TABLE order_items (
    order_id            VARCHAR(50),
    order_item_id       INT,
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date DATETIME,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id,
 shipping_limit_date, price, freight_value);


/* ----------------------------------------------------------------------------
 *  5. TABLE : products
 *     Catalogue of every product with category and physical dimensions.
 * ----------------------------------------------------------------------------
 */
CREATE TABLE products (
    product_id                  VARCHAR(50),
    product_category_name       VARCHAR(100),
    product_name_length         INT,
    product_description_length  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_category_name, product_name_length,
 product_description_length, product_photos_qty, product_weight_g,
 product_length_cm, product_height_cm, product_width_cm);


/* ----------------------------------------------------------------------------
 *  6. TABLE : category_translation
 *     Maps Portuguese category names → English (for readable reports).
 * ----------------------------------------------------------------------------
 */
CREATE TABLE category_translation (
    product_category_name         VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/product_category_name_translation.csv'
INTO TABLE category_translation
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_category_name, product_category_name_english);


/* ----------------------------------------------------------------------------
 *  7. TABLE : payments
 *     Payment transactions per order. Composite key (order_id, payment_sequential).
 * ----------------------------------------------------------------------------
 */
CREATE TABLE payments (
    order_id             VARCHAR(50),
    payment_sequential   INT,
    payment_type         VARCHAR(20),
    payment_installments INT,
    payment_value        DECIMAL(10,2)
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_order_payments_dataset.csv'
INTO TABLE payments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, payment_sequential, payment_type,
 payment_installments, payment_value);


/* ----------------------------------------------------------------------------
 *  8. TABLE : reviews
 *     Customer feedback per order (star score + optional text).
 * ----------------------------------------------------------------------------
 */
CREATE TABLE reviews (
    review_id              VARCHAR(50),
    order_id               VARCHAR(50),
    review_score           INT,
    review_comment_title   TEXT,
    review_comment_message TEXT,
    review_creation_date   DATETIME,
    review_answer_timestamp DATETIME
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_order_reviews_dataset.csv'
INTO TABLE reviews
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title,
 review_comment_message, review_creation_date, review_answer_timestamp);


/* ----------------------------------------------------------------------------
 *  9. TABLE : sellers
 *     Marketplace seller master with location.
 * ----------------------------------------------------------------------------
 */
CREATE TABLE sellers (
    seller_id              VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city            VARCHAR(100),
    seller_state           VARCHAR(10)
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(seller_id, seller_zip_code_prefix, seller_city, seller_state);


/* ----------------------------------------------------------------------------
 *  10. TABLE : geolocation
 *      Reference for Brazilian zip-code prefixes → lat / long / city / state.
 * ----------------------------------------------------------------------------
 */
CREATE TABLE geolocation (
    geolocation_zip_code_prefix INT,
    geolocation_lat             DECIMAL(10,6),
    geolocation_lng             DECIMAL(10,6),
    geolocation_city            VARCHAR(100),
    geolocation_state           VARCHAR(10)
);

LOAD DATA LOCAL INFILE 'D:/Khushi backup/Khushi backup/SQL Projects/archive/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
 geolocation_city, geolocation_state);


/* ----------------------------------------------------------------------------
 *  11. NOT NULL + PRIMARY KEY CONSTRAINTS
 *      Promote the staged tables into a production-grade schema.
 * ----------------------------------------------------------------------------
 */

-- customers
ALTER TABLE customers
MODIFY customer_id              VARCHAR(50)  NOT NULL,
MODIFY customer_unique_id       VARCHAR(50)  NOT NULL,
MODIFY customer_zip_code_prefix INT          NOT NULL,
MODIFY customer_city            VARCHAR(100) NOT NULL,
MODIFY customer_state           VARCHAR(10)  NOT NULL;
ALTER TABLE customers ADD PRIMARY KEY (customer_id);

-- orders
ALTER TABLE orders
MODIFY order_id                      VARCHAR(50) NOT NULL,
MODIFY customer_id                   VARCHAR(50) NOT NULL,
MODIFY order_status                  VARCHAR(20) NOT NULL,
MODIFY order_purchase_timestamp      DATETIME    NOT NULL,
MODIFY order_estimated_delivery_date DATETIME    NOT NULL;
ALTER TABLE orders ADD PRIMARY KEY (order_id);

-- order_items
ALTER TABLE order_items
MODIFY order_id            VARCHAR(50)    NOT NULL,
MODIFY order_item_id       INT            NOT NULL,
MODIFY product_id          VARCHAR(50)    NOT NULL,
MODIFY seller_id           VARCHAR(50)    NOT NULL,
MODIFY shipping_limit_date DATETIME       NOT NULL,
MODIFY price               DECIMAL(10,2)  NOT NULL,
MODIFY freight_value       DECIMAL(10,2)  NOT NULL;
ALTER TABLE order_items ADD PRIMARY KEY (order_id, order_item_id);

-- products
ALTER TABLE products MODIFY product_id VARCHAR(50) NOT NULL;
ALTER TABLE products ADD PRIMARY KEY (product_id);

-- sellers
ALTER TABLE sellers
MODIFY seller_id              VARCHAR(50)  NOT NULL,
MODIFY seller_zip_code_prefix INT          NOT NULL,
MODIFY seller_city            VARCHAR(100) NOT NULL,
MODIFY seller_state           VARCHAR(10)  NOT NULL;
ALTER TABLE sellers ADD PRIMARY KEY (seller_id);

-- payments
ALTER TABLE payments
MODIFY order_id             VARCHAR(50)   NOT NULL,
MODIFY payment_sequential   INT           NOT NULL,
MODIFY payment_type         VARCHAR(20)   NOT NULL,
MODIFY payment_installments INT           NOT NULL,
MODIFY payment_value        DECIMAL(10,2) NOT NULL;
ALTER TABLE payments ADD PRIMARY KEY (order_id, payment_sequential);

-- reviews
ALTER TABLE reviews
MODIFY review_id    VARCHAR(50) NOT NULL,
MODIFY order_id     VARCHAR(50) NOT NULL,
MODIFY review_score INT         NOT NULL;
ALTER TABLE reviews ADD PRIMARY KEY (review_id);

-- category_translation
ALTER TABLE category_translation
MODIFY product_category_name         VARCHAR(100) NOT NULL,
MODIFY product_category_name_english VARCHAR(100) NOT NULL;
ALTER TABLE category_translation ADD PRIMARY KEY (product_category_name);


/* ----------------------------------------------------------------------------
 *  12. FIX BAD DATES
 *      Replace MySQL's invalid '0000-00-00 00:00:00' placeholders with NULL.
 * ----------------------------------------------------------------------------
 */
SET sql_mode = '';
SET SQL_SAFE_UPDATES = 0;

UPDATE orders SET order_approved_at             = NULL WHERE order_approved_at             = '0000-00-00 00:00:00';
UPDATE orders SET order_delivered_carrier_date  = NULL WHERE order_delivered_carrier_date  = '0000-00-00 00:00:00';
UPDATE orders SET order_delivered_customer_date = NULL WHERE order_delivered_customer_date = '0000-00-00 00:00:00';


/* ----------------------------------------------------------------------------
 *  13. FOREIGN KEY CONSTRAINTS
 *      Establish referential integrity between fact and dimension tables.
 * ----------------------------------------------------------------------------
 */
ALTER TABLE orders
ADD CONSTRAINT fk_orders_customers
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_products
FOREIGN KEY (product_id) REFERENCES products(product_id);

ALTER TABLE order_items
ADD CONSTRAINT fk_order_items_sellers
FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);

ALTER TABLE payments
ADD CONSTRAINT fk_payments_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE reviews
ADD CONSTRAINT fk_reviews_orders
FOREIGN KEY (order_id) REFERENCES orders(order_id);

/* ============================================================================
 *  END OF schema.sql
 * ============================================================================
 */
