/*
=====================================================================================
  Purpose: Build the profit and loss foundation from gross sales down to gross margin
=====================================================================================
*/

USE your_database;

-- =========================================================
-- SECTION 1: Calculated columns
-- =========================================================

-- 1. Gross sales for each sale in FY2021: quantity × that year's price
SELECT
    s.date,
    s.product_code,
    s.sold_quantity,
    g.gross_price,
    s.sold_quantity * g.gross_price AS gross_sales
FROM fact_sales_monthly AS s
JOIN fact_gross_price AS g
    ON s.product_code = g.product_code
   AND g.fiscal_year  = YEAR(DATE_ADD(s.date, INTERVAL 4 MONTH))
WHERE s.date BETWEEN '2020-09-01' AND '2021-08-01'
LIMIT 10;

-- 2. Manufacturing cost as a share of the gross price, per product in FY2021
SELECT
    g.product_code,
    g.gross_price,
    m.manufacturing_cost,
    ROUND(m.manufacturing_cost / g.gross_price * 100, 2) AS cost_share_pct
FROM fact_gross_price AS g
JOIN fact_manufacturing_cost AS m
    ON g.product_code = m.product_code
   AND g.fiscal_year  = m.cost_year
WHERE g.fiscal_year = 2021
ORDER BY cost_share_pct DESC
LIMIT 10;


-- =========================================================
-- SECTION 2: Labelling rows with CASE
-- =========================================================

-- 3. Group products into price bands for FY2021
SELECT
    product_code,
    gross_price,
    CASE
        WHEN gross_price < 20  THEN 'Low'
        WHEN gross_price < 200 THEN 'Medium'
        ELSE 'High'
    END AS price_band
FROM fact_gross_price
WHERE fiscal_year = 2021
ORDER BY gross_price
LIMIT 20;

-- 4. Count how many products fall into each price band
SELECT
    CASE
        WHEN gross_price < 20  THEN 'Low'
        WHEN gross_price < 200 THEN 'Medium'
        ELSE 'High'
    END AS price_band,
    COUNT(*) AS products
FROM fact_gross_price
WHERE fiscal_year = 2021
GROUP BY price_band
ORDER BY products DESC;

-- 5. Correct the misspelled market names for reporting (source data unchanged)
SELECT DISTINCT
    market,
    CASE market
        WHEN 'Columbia'    THEN 'Colombia'
        WHEN 'Philiphines' THEN 'Philippines'
        WHEN 'Newzealand'  THEN 'New Zealand'
        ELSE market
    END AS market_name
FROM dim_customer
ORDER BY market_name;

-- =========================================================
-- SECTION 3: Working with dates
-- =========================================================

-- 6. Pulling parts out of a date
SELECT DISTINCT
    date,
    YEAR(date) AS calendar_year,
    MONTH(date) AS month_number,
    MONTHNAME(date) AS month_name,
    DATE_FORMAT(date, '%b %Y') AS month_label
FROM fact_sales_monthly
ORDER BY date
LIMIT 12;

-- 7. Total units sold per month
SELECT
    date,
    SUM(sold_quantity) AS units_sold
FROM fact_sales_monthly
GROUP BY date
ORDER BY date;

-- 8. Working out the fiscal year and fiscal quarter from a date (fiscal year starts in September)
SELECT DISTINCT
    date,
    DATE_ADD(date, INTERVAL 4 MONTH) AS shifted_date,
    YEAR(DATE_ADD(date, INTERVAL 4 MONTH)) AS fiscal_year,
    QUARTER(DATE_ADD(date, INTERVAL 4 MONTH)) AS fiscal_quarter
FROM fact_sales_monthly
ORDER BY date
LIMIT 12;


-- =========================================================
-- SECTION 4: A reusable fiscal year function
-- =========================================================

-- 9. Remove any older version, then create the function
DROP FUNCTION IF EXISTS get_fiscal_year;

CREATE FUNCTION get_fiscal_year(calendar_date DATE)
RETURNS INT
DETERMINISTIC
RETURN YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));

-- 10. Test it on known dates (expect 2018, 2018, 2019)
SELECT
    get_fiscal_year('2017-09-01') AS should_be_2018,
    get_fiscal_year('2018-08-01') AS should_be_2018_too,
    get_fiscal_year('2018-09-01') AS should_be_2019;

-- 11. Validate against the company's own fiscal years in the forecast table (expect 0)
SELECT COUNT(*) AS mismatches
FROM fact_forecast_monthly
WHERE get_fiscal_year(date) <> fiscal_year;

-- =========================================================
-- SECTION 5: Clearing earlier versions
-- =========================================================

-- 12. Remove the saved table and views from the earlier build (dependent objects first)
DROP TABLE IF EXISTS pnl_sales;
DROP VIEW  IF EXISTS v_sales_pnl;
DROP VIEW  IF EXISTS v_net_sales;
DROP VIEW  IF EXISTS v_sales_post_invoice;
DROP VIEW  IF EXISTS v_sales_gross;

-- =========================================================
-- SECTION 6: Adding a stored fiscal year to the sales table
-- =========================================================

-- 13. Add a fiscal year column calculated once from the date (run once only; it gives an error if the column already exists)
ALTER TABLE fact_sales_monthly
ADD COLUMN fiscal_year YEAR
GENERATED ALWAYS AS (YEAR(DATE_ADD(date, INTERVAL 4 MONTH))) STORED;

-- 14. Check the stored column agrees with the function (expect 0)
SELECT COUNT(*) AS mismatches
FROM fact_sales_monthly
WHERE fiscal_year <> get_fiscal_year(date);

-- =========================================================
-- SECTION 7: Building the P&L layers as views
-- =========================================================

-- 15. Layer 1: gross sales, with customer and product details and the pre-invoice discount %
CREATE OR REPLACE VIEW v_sales_gross AS
SELECT
    s.date,
    s.fiscal_year,
    s.customer_code,
    c.customer,
    c.platform,
    CASE
        WHEN c.customer IN ('Atliq Exclusive', 'Atliq e Store') THEN 'Direct'
        ELSE c.channel
    END AS channel,
    c.market,
    CASE c.market
        WHEN 'Columbia'    THEN 'Colombia'
        WHEN 'Philiphines' THEN 'Philippines'
        WHEN 'Newzealand'  THEN 'New Zealand'
        ELSE c.market
    END AS market_name,
    c.sub_zone,
    c.region,
    s.product_code,
    p.division,
    p.segment,
    p.category,
    p.product,
    p.variant,
    s.sold_quantity,
    g.gross_price,
    s.sold_quantity * g.gross_price AS gross_sales,
    pre.pre_invoice_discount_pct
FROM fact_sales_monthly AS s
JOIN dim_customer AS c
    ON s.customer_code = c.customer_code
JOIN dim_product AS p
    ON s.product_code = p.product_code
JOIN fact_gross_price AS g
    ON s.product_code = g.product_code
   AND s.fiscal_year  = g.fiscal_year
JOIN fact_pre_invoice_deductions AS pre
    ON s.customer_code = pre.customer_code
   AND s.fiscal_year   = pre.fiscal_year;

-- 16. Layer 2: pre-invoice deductions, net invoice sales, and the post-invoice deduction % (0 where none exists)
CREATE OR REPLACE VIEW v_sales_post_invoice AS
SELECT
    sg.*,
    sg.gross_sales * sg.pre_invoice_discount_pct       AS pre_invoice_deductions,
    sg.gross_sales * (1 - sg.pre_invoice_discount_pct) AS net_invoice_sales,
    COALESCE(po.discounts_pct + po.other_deductions_pct, 0) AS post_invoice_discount_pct
FROM v_sales_gross AS sg
LEFT JOIN fact_post_invoice_deductions AS po
    ON sg.customer_code = po.customer_code
   AND sg.product_code  = po.product_code
   AND sg.date          = po.date;

-- 17. Layer 3: post-invoice deductions and net sales
CREATE OR REPLACE VIEW v_net_sales AS
SELECT
    spi.*,
    spi.net_invoice_sales * spi.post_invoice_discount_pct       AS post_invoice_deductions,
    spi.net_invoice_sales * (1 - spi.post_invoice_discount_pct) AS net_sales
FROM v_sales_post_invoice AS spi;

-- 18. Layer 4: costs and gross margin (freight and other costs as % of net sales)
CREATE OR REPLACE VIEW v_sales_pnl AS
SELECT
    ns.*,
    mc.manufacturing_cost                    AS manufacturing_cost_per_unit,
    ns.sold_quantity * mc.manufacturing_cost AS manufacturing_cost,
    ns.net_sales * f.freight_pct             AS freight_cost,
    ns.net_sales * f.other_cost_pct          AS other_cost,
    ns.sold_quantity * mc.manufacturing_cost
      + ns.net_sales * (f.freight_pct + f.other_cost_pct) AS cogs,
    CAST(ns.net_sales AS DECIMAL(38,12))
      - CAST(ns.sold_quantity * mc.manufacturing_cost
             + ns.net_sales * (f.freight_pct + f.other_cost_pct) AS DECIMAL(38,12)) AS gross_margin
FROM v_net_sales AS ns
JOIN fact_manufacturing_cost AS mc
    ON ns.product_code = mc.product_code
   AND ns.fiscal_year  = mc.cost_year
JOIN fact_freight_cost AS f
    ON ns.market      = f.market
   AND ns.fiscal_year = f.fiscal_year;

-- 19. Check no rows were lost or duplicated in any layer (each should be 1,425,706)
SELECT
    (SELECT COUNT(*) FROM v_sales_gross)        AS layer_1,
    (SELECT COUNT(*) FROM v_sales_post_invoice) AS layer_2,
    (SELECT COUNT(*) FROM v_net_sales)          AS layer_3,
    (SELECT COUNT(*) FROM v_sales_pnl)          AS layer_4;

-- =========================================================
-- SECTION 8: Saving the finished P&L as a table
-- =========================================================

-- 20. Store the full P&L once, so analysis queries don't recalculate four layers every time
DROP TABLE IF EXISTS pnl_sales;

CREATE TABLE pnl_sales AS
SELECT * FROM v_sales_pnl;

-- =========================================================
-- SECTION 9: Indexes for faster analysis
-- =========================================================

-- 21. Indexes on the columns used most for filtering and grouping
CREATE INDEX idx_pnl_fiscal_year  ON pnl_sales (fiscal_year);
CREATE INDEX idx_pnl_market       ON pnl_sales (market);
CREATE INDEX idx_pnl_customer     ON pnl_sales (customer);
CREATE INDEX idx_pnl_product_code ON pnl_sales (product_code);
CREATE INDEX idx_pnl_date         ON pnl_sales (date);

-- =========================================================
-- SECTION 10: Checking the saved P&L
-- =========================================================

-- 22. Rows and units must match the original sales table (expect 1,425,706 rows and 125,291,556 units)
SELECT
    COUNT(*)           AS total_rows,
    SUM(sold_quantity) AS total_units
FROM pnl_sales;

-- 23. No missing values in any money column (all should be 0)
SELECT
    SUM(gross_sales IS NULL)       AS null_gross_sales,
    SUM(net_invoice_sales IS NULL) AS null_net_invoice_sales,
    SUM(net_sales IS NULL)         AS null_net_sales,
    SUM(cogs IS NULL)              AS null_cogs,
    SUM(gross_margin IS NULL)      AS null_gross_margin
FROM pnl_sales;

-- 24. Every formula adds up on every row (all should be 0)
SELECT
    SUM(ROUND(pre_invoice_deductions + net_invoice_sales, 4) <> ROUND(gross_sales, 4))       AS gross_check,
    SUM(ROUND(post_invoice_deductions + net_sales, 4)        <> ROUND(net_invoice_sales, 4)) AS net_invoice_check,
    SUM(ROUND(manufacturing_cost + freight_cost + other_cost, 4) <> ROUND(cogs, 4))          AS cogs_check,
    SUM(ROUND(cogs + gross_margin, 4)                        <> ROUND(net_sales, 4))         AS margin_check
FROM pnl_sales;

DESCRIBE v_net_sales;

-- 25. The P&L by fiscal year, in millions
SELECT
    fiscal_year,
    ROUND(SUM(gross_sales) / 1000000, 2)       AS gross_sales_mln,
    ROUND(SUM(net_invoice_sales) / 1000000, 2) AS net_invoice_sales_mln,
    ROUND(SUM(net_sales) / 1000000, 2)         AS net_sales_mln,
    ROUND(SUM(cogs) / 1000000, 2)              AS cogs_mln,
    ROUND(SUM(gross_margin) / 1000000, 2)      AS gross_margin_mln,
    ROUND(SUM(gross_margin) / SUM(net_sales) * 100, 2) AS gm_pct
FROM pnl_sales
GROUP BY fiscal_year
ORDER BY fiscal_year;






