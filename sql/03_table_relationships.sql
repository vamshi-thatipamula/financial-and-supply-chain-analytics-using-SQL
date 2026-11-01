/*
======================================================================================
  Purpose: Connect the tables with joins and check that no rows are lost or duplicated
======================================================================================
*/

USE your_database;

-- =========================================================
-- SECTION 1: Joining tables on their keys
-- =========================================================

-- 1. Sales rows with the customer's name and market attached
SELECT
    s.date,
    s.customer_code,
    c.customer,
    c.market,
    s.sold_quantity
FROM fact_sales_monthly AS s
JOIN dim_customer AS c
    ON s.customer_code = c.customer_code
LIMIT 10;

-- 2. Sales rows with the product's name and category attached
SELECT
    s.date,
    s.product_code,
    p.product,
    p.category,
    s.sold_quantity
FROM fact_sales_monthly AS s
JOIN dim_product AS p
    ON s.product_code = p.product_code
LIMIT 10;

-- 3. Three tables at once: sales with both customer and product details
SELECT
    s.date,
    c.customer,
    c.market,
    p.product,
    p.variant,
    s.sold_quantity
FROM fact_sales_monthly AS s
JOIN dim_customer AS c
    ON s.customer_code = c.customer_code
JOIN dim_product AS p
    ON s.product_code = p.product_code
LIMIT 10;

-- 4. Units sold per market (join, then group)
SELECT
    c.market,
    SUM(s.sold_quantity) AS units_sold
FROM fact_sales_monthly AS s
JOIN dim_customer AS c
    ON s.customer_code = c.customer_code
GROUP BY c.market
ORDER BY units_sold DESC, c.market
LIMIT 10;

-- 5. Joining on two columns: price and manufacturing cost for the same product and year
SELECT
    g.product_code,
    g.fiscal_year,
    g.gross_price,
    m.manufacturing_cost
FROM fact_gross_price AS g
JOIN fact_manufacturing_cost AS m
    ON g.product_code = m.product_code
   AND g.fiscal_year  = m.cost_year
LIMIT 10;

-- =========================================================
-- SECTION 2: Checking joins for lost or duplicated rows
-- =========================================================

-- 6. Does every sale find its customer? (should equal 1,425,706, the sales row count)
SELECT COUNT(*) AS matched_rows
FROM fact_sales_monthly AS s
JOIN dim_customer AS c
    ON s.customer_code = c.customer_code;

-- 7. Does every sale find its product? (should also equal 1,425,706)
SELECT COUNT(*) AS matched_rows
FROM fact_sales_monthly AS s
JOIN dim_product AS p
    ON s.product_code = p.product_code;

-- 8. Correct join on the full key: price and cost matched by product AND year (should be 1,182)
SELECT COUNT(*) AS matched_rows
FROM fact_gross_price AS g
JOIN fact_manufacturing_cost AS m
    ON g.product_code = m.product_code
   AND g.fiscal_year  = m.cost_year;

-- 9. WRONG on purpose: joined on product only, year ignored (watch the count jump)
SELECT COUNT(*) AS matched_rows
FROM fact_gross_price AS g
JOIN fact_manufacturing_cost AS m
    ON g.product_code = m.product_code;

-- =========================================================
-- SECTION 3: Finding unmatched rows with LEFT JOIN
-- =========================================================

-- 10. Products that have never been sold (expect 8: 397 products, 389 sold)
SELECT p.product_code, p.product, p.variant
FROM dim_product AS p
LEFT JOIN (SELECT DISTINCT product_code FROM fact_sales_monthly) AS s
    ON p.product_code = s.product_code
WHERE s.product_code IS NULL;

-- 11. Products that have no gross price in any year (expect the same 8)
SELECT p.product_code, p.product, p.variant
FROM dim_product AS p
LEFT JOIN fact_gross_price AS g
    ON p.product_code = g.product_code
WHERE g.product_code IS NULL;

-- 12. Customers that have never bought anything (expect none)
SELECT c.customer_code, c.customer, c.market
FROM dim_customer AS c
LEFT JOIN (SELECT DISTINCT customer_code FROM fact_sales_monthly) AS s
    ON c.customer_code = s.customer_code
WHERE s.customer_code IS NULL;

-- 13. Sales rows with no matching post-invoice deduction, by year and quantity
SELECT
    YEAR(s.date)         AS calendar_year,
    COUNT(*)             AS unmatched_rows,
    SUM(s.sold_quantity) AS units
FROM fact_sales_monthly AS s
LEFT JOIN fact_post_invoice_deductions AS po
    ON s.customer_code = po.customer_code
   AND s.product_code  = po.product_code
   AND s.date          = po.date
WHERE po.customer_code IS NULL
GROUP BY YEAR(s.date);

-- 14. Keep unmatched rows but replace the missing value with 0
SELECT
    p.product_code,
    p.product,
    COALESCE(g.gross_price, 0) AS gross_price_fy2021
FROM dim_product AS p
LEFT JOIN fact_gross_price AS g
    ON p.product_code = g.product_code
   AND g.fiscal_year  = 2021
ORDER BY gross_price_fy2021, p.product_code
LIMIT 20;

-- =========================================================
-- SECTION 4: Comparing rows within the same table (self-join)
-- =========================================================

-- 15. Year-on-year gross price change for each product
SELECT
    cur.product_code,
    cur.fiscal_year,
    prev.gross_price AS previous_price,
    cur.gross_price  AS current_price,
    ROUND(
        (CAST(cur.gross_price AS DECIMAL(15,4)) - CAST(prev.gross_price AS DECIMAL(15,4)))
        / prev.gross_price * 100,
    2) AS price_change_pct
FROM fact_gross_price AS cur
JOIN fact_gross_price AS prev
    ON cur.product_code = prev.product_code
   AND cur.fiscal_year  = prev.fiscal_year + 1
ORDER BY cur.product_code, cur.fiscal_year
LIMIT 20;


