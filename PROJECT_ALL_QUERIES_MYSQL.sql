-- ============================================================
-- RETAIL SALES ANALYSIS | MySQL | Saari queries ek jagah, sahi order mein
-- Pehle SALES_PROJECT_MYSQL_IMPORT.sql chalao, phir ye file upar se neeche.
-- ============================================================
USE sales_project;

-- ############ PART 1: DATA CHECK (problems dhundhna) ############
-- 1.1 Duplicate orders (60 aane chahiye)
SELECT order_id, COUNT(*) FROM orders_raw GROUP BY order_id HAVING COUNT(*) > 1;
-- 1.2 Region formatting (BINARY = capital/small letter alag dikhaye)
SELECT DISTINCT BINARY region, LENGTH(region) FROM orders_raw;
-- 1.3 Galat quantity (25) aur NULL discount (30)
SELECT COUNT(*) FROM order_items_raw WHERE quantity <= 0;
SELECT COUNT(*) FROM order_items_raw WHERE discount_pct IS NULL;
SELECT MIN(discount_pct), MAX(discount_pct) FROM order_items_raw;   -- 0 aur 30

-- ############ PART 2: CLEANING (clean tables banana) ############
CREATE TABLE order_items_clean AS
SELECT order_item_id, order_id, product_id, quantity,
       COALESCE(discount_pct, 0) AS discount_pct
FROM order_items_raw
WHERE quantity > 0;
ALTER TABLE order_items_clean ADD PRIMARY KEY (order_item_id);      -- 23444 rows

CREATE TABLE orders_clean_tbl AS
SELECT DISTINCT order_id, customer_id, order_date, ship_date, ship_mode,
       sales_channel, payment_mode, order_status,
       CONCAT(UPPER(LEFT(TRIM(region),1)), LOWER(SUBSTRING(TRIM(region),2))) AS region
FROM orders_raw;
ALTER TABLE orders_clean_tbl ADD PRIMARY KEY (order_id);            -- 14000 rows

-- ############ PART 3: ANALYSIS TABLE (sales_fact view) ############
CREATE OR REPLACE VIEW sales_fact AS
SELECT o.order_id, o.order_date, o.ship_date, o.order_status,
       o.payment_mode, o.sales_channel, o.ship_mode, o.region,
       oi.order_item_id, oi.quantity, oi.discount_pct,
       p.category, p.sub_category, p.list_price, p.unit_cost,
       c.customer_id, c.segment, c.state,
       COALESCE(c.city, 'Unknown') AS city,
       p.list_price * oi.quantity AS gross_sales,
       p.list_price * oi.quantity * oi.discount_pct/100 AS discount_amt,
       p.list_price * oi.quantity * (1 - oi.discount_pct/100) AS net_sales,
       p.unit_cost * oi.quantity AS cogs,
       p.list_price * oi.quantity * (1 - oi.discount_pct/100) - p.unit_cost * oi.quantity AS profit
FROM orders_clean_tbl o
JOIN order_items_clean oi ON o.order_id = oi.order_id
JOIN products_raw p ON oi.product_id = p.product_id
JOIN customers_raw c ON o.customer_id = c.customer_id;

-- ############ PART 4: ANALYSIS (insights) ############
-- Q1 KPIs (sirf Delivered)
-- Result: 12068 orders | net sales 171,691,343 | profit 17,825,964 | margin 10.38% | AOV 14,227
SELECT COUNT(DISTINCT order_id) AS delivered_orders,
       ROUND(SUM(net_sales)) AS net_sales, ROUND(SUM(profit)) AS profit,
       ROUND(SUM(profit)/SUM(net_sales)*100, 2) AS margin_pct,
       ROUND(SUM(net_sales)/COUNT(DISTINCT order_id)) AS avg_order_value
FROM sales_fact WHERE order_status = 'Delivered';

-- Q2 Delivered / Cancelled / Returned %
-- Result: Delivered 86.26% | Returned 6.93% | Cancelled 6.81%
SELECT order_status, COUNT(*) AS orders,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders_clean_tbl GROUP BY order_status;

-- Q3 Category profit
-- Insight: Electronics = sabse badi sales par margin sirf 5.51%, baaki 18-24%
SELECT category, ROUND(SUM(net_sales)) AS net_sales, ROUND(SUM(profit)) AS profit,
       ROUND(SUM(profit)/SUM(net_sales)*100, 2) AS margin_pct
FROM sales_fact WHERE order_status = 'Delivered'
GROUP BY category ORDER BY profit DESC;

-- Q4 Discount vs margin
-- Insight: 15% se upar discount = lagbhag zero ya loss (30% pe -14%)
SELECT CASE WHEN discount_pct = 0 THEN '1. No discount'
            WHEN discount_pct <= 10 THEN '2. 5-10%'
            WHEN discount_pct <= 20 THEN '3. 15-20%'
            ELSE '4. 30%' END AS discount_bucket,
       COUNT(*) AS items, ROUND(SUM(net_sales)) AS net_sales,
       ROUND(SUM(profit)/SUM(net_sales)*100, 2) AS margin_pct
FROM sales_fact WHERE order_status = 'Delivered'
GROUP BY discount_bucket ORDER BY discount_bucket;

-- Q4b Wahi, sirf Electronics (WHERE mein category add)
-- Insight: Electronics mein 15% se upar har discount loss karata hai
SELECT CASE WHEN discount_pct = 0 THEN '1. No discount'
            WHEN discount_pct <= 10 THEN '2. 5-10%'
            WHEN discount_pct <= 20 THEN '3. 15-20%'
            ELSE '4. 30%' END AS discount_bucket,
       COUNT(*) AS items, ROUND(SUM(net_sales)) AS net_sales,
       ROUND(SUM(profit)/SUM(net_sales)*100, 2) AS margin_pct
FROM sales_fact WHERE order_status = 'Delivered' AND category = 'Electronics'
GROUP BY discount_bucket ORDER BY discount_bucket;

-- Q5 Monthly trend (simple version)
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       ROUND(SUM(net_sales)) AS net_sales, ROUND(SUM(profit)) AS profit
FROM sales_fact WHERE order_status = 'Delivered'
GROUP BY month ORDER BY month;

-- Q6 Payment mode vs cancellation
-- Insight: COD cancel 16.13% vs baaki ~5%
SELECT payment_mode, COUNT(*) AS total_orders,
       SUM(order_status = 'Cancelled') AS cancelled,
       ROUND(SUM(order_status = 'Cancelled') * 100.0 / COUNT(*), 2) AS cancel_pct
FROM orders_clean_tbl GROUP BY payment_mode ORDER BY cancel_pct DESC;

-- Q7 Cancel/Return se kitni sales gayi (abhi chalana baaki)
SELECT order_status, COUNT(DISTINCT order_id) AS orders, ROUND(SUM(net_sales)) AS net_sales
FROM sales_fact GROUP BY order_status;

-- Check: Delivered orders jinke saare items cleaning mein hat gaye (abhi chalana baaki)
SELECT COUNT(*) FROM orders_clean_tbl o
WHERE o.order_status = 'Delivered'
  AND NOT EXISTS (SELECT 1 FROM order_items_clean oi WHERE oi.order_id = o.order_id);
