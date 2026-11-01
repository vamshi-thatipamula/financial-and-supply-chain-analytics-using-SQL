/*
==============================================================================================
  Purpose: Answer the finance business questions on sales, deductions, costs and profitability
==============================================================================================
*/

USE your_database;

-- =========================================================
-- SECTION 1: Subqueries
-- =========================================================

-- 1. Markets whose FY2021 gross margin % beat the company's overall FY2021 gross margin %
SELECT
    market_name,
    ROUND(SUM(net_sales) / 1000000, 2)                 AS net_sales_mln,
    ROUND(SUM(gross_margin) / SUM(net_sales) * 100, 2) AS gm_pct
FROM pnl_sales
WHERE fiscal_year = 2021
GROUP BY market_name
HAVING SUM(gross_margin) / SUM(net_sales) >
       (SELECT SUM(gross_margin) / SUM(net_sales)
        FROM pnl_sales
        WHERE fiscal_year = 2021)
ORDER BY gm_pct DESC, market_name;

-- 2. Markets whose FY2021 gross margin % is below the company's overall FY2021 gross margin %
SELECT
    market_name,
    ROUND(SUM(net_sales) / 1000000, 2)                 AS net_sales_mln,
    ROUND(SUM(gross_margin) / SUM(net_sales) * 100, 2) AS gm_pct
FROM pnl_sales
WHERE fiscal_year = 2021
GROUP BY market_name
HAVING SUM(gross_margin) / SUM(net_sales) <
       (SELECT SUM(gross_margin) / SUM(net_sales)
        FROM pnl_sales
        WHERE fiscal_year = 2021)
ORDER BY gm_pct DESC, market_name;

-- 3. Each region's FY2021 net sales next to the company total
SELECT
    region,
    ROUND(SUM(net_sales) / 1000000, 2) AS region_net_sales_mln,
    ROUND((SELECT SUM(net_sales)
           FROM pnl_sales
           WHERE fiscal_year = 2021) / 1000000, 2) AS company_net_sales_mln
FROM pnl_sales
WHERE fiscal_year = 2021
GROUP BY region
ORDER BY region_net_sales_mln DESC;

-- 4. Customers who bought in FY2020 but not at all in FY2021
SELECT DISTINCT customer, market_name
FROM pnl_sales
WHERE fiscal_year = 2020
  AND customer_code NOT IN (SELECT customer_code
                            FROM pnl_sales
                            WHERE fiscal_year = 2021)
ORDER BY customer, market_name;

-- 5. Active customers per fiscal year
SELECT fiscal_year, COUNT(DISTINCT customer_code) AS active_customers
FROM pnl_sales
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- 6. The average market's net sales in FY2021, with the largest and smallest
SELECT
    COUNT(*)                                  AS markets,
    ROUND(AVG(market_net_sales) / 1000000, 2) AS avg_market_net_sales_mln,
    ROUND(MAX(market_net_sales) / 1000000, 2) AS largest_market_mln,
    ROUND(MIN(market_net_sales) / 1000000, 2) AS smallest_market_mln
FROM (SELECT market_name, SUM(net_sales) AS market_net_sales
      FROM pnl_sales
      WHERE fiscal_year = 2021
      GROUP BY market_name) AS market_totals;

-- =========================================================
-- SECTION 2: Multi-step questions with CTEs
-- =========================================================

-- 7. Query 6 rewritten as a CTE: the average market's FY2021 net sales
WITH market_totals AS (
    SELECT market_name, SUM(net_sales) AS market_net_sales
    FROM pnl_sales
    WHERE fiscal_year = 2021
    GROUP BY market_name
)
SELECT
    COUNT(*)                                  AS markets,
    ROUND(AVG(market_net_sales) / 1000000, 2) AS avg_market_net_sales_mln,
    ROUND(MAX(market_net_sales) / 1000000, 2) AS largest_market_mln,
    ROUND(MIN(market_net_sales) / 1000000, 2) AS smallest_market_mln
FROM market_totals;

-- 8. How concentrated are sales? Markets above the average size, and their share of FY2021 net sales
WITH market_totals AS (
    SELECT market_name, SUM(net_sales) AS market_net_sales
    FROM pnl_sales
    WHERE fiscal_year = 2021
    GROUP BY market_name
),
summary AS (
    SELECT AVG(market_net_sales) AS avg_size,
           SUM(market_net_sales) AS company_total
    FROM market_totals
)
SELECT
    COUNT(*)                                                  AS markets_above_average,
    ROUND(SUM(m.market_net_sales) / 1000000, 2)               AS their_net_sales_mln,
    ROUND(SUM(m.market_net_sales) / s.company_total * 100, 2) AS share_of_company_pct
FROM market_totals AS m
CROSS JOIN summary AS s
WHERE m.market_net_sales > s.avg_size
GROUP BY s.company_total;

-- 9. FY2022 so far vs the same months a year earlier (Sep–Dec 2021 vs Sep–Dec 2020)
WITH ytd_2022 AS (
    SELECT
        SUM(sold_quantity) AS units,
        SUM(net_sales)     AS net_sales,
        SUM(gross_margin)  AS gross_margin
    FROM pnl_sales
    WHERE date BETWEEN '2021-09-01' AND '2021-12-01'
),
ytd_2021 AS (
    SELECT
        SUM(sold_quantity) AS units,
        SUM(net_sales)     AS net_sales,
        SUM(gross_margin)  AS gross_margin
    FROM pnl_sales
    WHERE date BETWEEN '2020-09-01' AND '2020-12-01'
)
SELECT
    ROUND(cur.net_sales  / 1000000, 2) AS net_sales_sep_dec_2021_mln,
    ROUND(prev.net_sales / 1000000, 2) AS net_sales_sep_dec_2020_mln,
    ROUND((cur.net_sales / prev.net_sales - 1) * 100, 2) AS net_sales_growth_pct,
    ROUND((CAST(cur.units AS DECIMAL(20,2)) / CAST(prev.units AS DECIMAL(20,2)) - 1) * 100, 2) AS unit_growth_pct,
    ROUND(cur.gross_margin  / cur.net_sales  * 100, 2) AS gm_pct_sep_dec_2021,
    ROUND(prev.gross_margin / prev.net_sales * 100, 2) AS gm_pct_sep_dec_2020
FROM ytd_2022 AS cur
CROSS JOIN ytd_2021 AS prev;

-- =========================================================
-- SECTION 3: Ranking with window functions
-- =========================================================

-- 10. The three ranking functions side by side (markets by number of E-Commerce companies)
SELECT
    market_name,
    COUNT(DISTINCT customer) AS companies,
    ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT customer) DESC, market_name) AS row_num,
    RANK()       OVER (ORDER BY COUNT(DISTINCT customer) DESC)              AS rnk,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT customer) DESC)              AS dense_rnk
FROM pnl_sales
WHERE platform = 'E-Commerce'
GROUP BY market_name
ORDER BY companies DESC, market_name;

-- 11. Product mix: segments ranked by net sales within each fiscal year (does the ranking change over time?)
SELECT
    fiscal_year,
    segment,
    ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln,
    RANK() OVER (PARTITION BY fiscal_year ORDER BY SUM(net_sales) DESC) AS rank_in_year
FROM pnl_sales
GROUP BY fiscal_year, segment
ORDER BY fiscal_year, rank_in_year;

-- 12. Top 3 products in each division by FY2021 net sales
WITH product_sales AS (
    SELECT
        division,
        CONCAT(product, ' - ', variant) AS product_label,
        SUM(net_sales) AS net_sales,
        DENSE_RANK() OVER (PARTITION BY division ORDER BY SUM(net_sales) DESC) AS rank_in_division
    FROM pnl_sales
    WHERE fiscal_year = 2021
    GROUP BY division, product, variant
)
SELECT
    division,
    rank_in_division,
    product_label,
    ROUND(net_sales / 1000000, 2) AS net_sales_mln
FROM product_sales
WHERE rank_in_division <= 3
ORDER BY division, rank_in_division;

-- 13. Top 5 customers by FY2021 net sales (customers ranked by name, all their markets combined)
WITH customer_sales AS (
    SELECT
        customer,
        SUM(net_sales) AS net_sales,
        RANK() OVER (ORDER BY SUM(net_sales) DESC) AS customer_rank
    FROM pnl_sales
    WHERE fiscal_year = 2021
    GROUP BY customer
)
SELECT
    customer_rank,
    customer,
    ROUND(net_sales / 1000000, 2) AS net_sales_mln
FROM customer_sales
WHERE customer_rank <= 5
ORDER BY customer_rank;

-- =========================================================
-- SECTION 4: Year-on-year growth with LAG and LEAD
-- =========================================================

-- 14. Company net sales per fiscal year with growth versus the previous year (FY2022 is Sep–Dec only)
WITH yearly AS (
    SELECT
        fiscal_year,
        SUM(net_sales) AS net_sales
    FROM pnl_sales
    GROUP BY fiscal_year
)
SELECT
    fiscal_year,
    ROUND(net_sales / 1000000, 2)                                   AS net_sales_mln,
    ROUND(LAG(net_sales)  OVER (ORDER BY fiscal_year) / 1000000, 2) AS previous_year_mln,
    ROUND(LEAD(net_sales) OVER (ORDER BY fiscal_year) / 1000000, 2) AS next_year_mln,
    ROUND((net_sales / LAG(net_sales) OVER (ORDER BY fiscal_year) - 1) * 100, 2) AS yoy_growth_pct
FROM yearly
ORDER BY fiscal_year;

-- 15. Markets that added the most net sales from FY2020 to FY2021 (amount and percentage)
WITH market_years AS (
    SELECT
        market_name,
        fiscal_year,
        SUM(net_sales) AS net_sales
    FROM pnl_sales
    GROUP BY market_name, fiscal_year
),
with_previous AS (
    SELECT
        market_name,
        fiscal_year,
        net_sales,
        LAG(net_sales) OVER (PARTITION BY market_name ORDER BY fiscal_year) AS previous_net_sales
    FROM market_years
)
SELECT
    market_name,
    ROUND(previous_net_sales / 1000000, 2)                 AS fy2020_mln,
    ROUND(net_sales / 1000000, 2)                          AS fy2021_mln,
    ROUND((net_sales - previous_net_sales) / 1000000, 2)   AS growth_mln,
    ROUND((net_sales / previous_net_sales - 1) * 100, 2)   AS yoy_growth_pct
FROM with_previous
WHERE fiscal_year = 2021
ORDER BY growth_mln DESC, market_name
LIMIT 10;

-- 16. Average year-on-year price change across all products, using LAG
WITH price_changes AS (
    SELECT
        fiscal_year,
        gross_price / LAG(gross_price) OVER (PARTITION BY product_code ORDER BY fiscal_year) - 1 AS price_change
    FROM fact_gross_price
)
SELECT
    fiscal_year,
    COUNT(price_change)                AS products_compared,
    ROUND(AVG(price_change) * 100, 2)  AS avg_price_change_pct
FROM price_changes
WHERE price_change IS NOT NULL
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- =========================================================
-- SECTION 5: Shares of the total
-- =========================================================

-- 17. Each region's share of FY2021 net sales (the percentage version of query 3)
SELECT
    region,
    ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln,
    ROUND(SUM(net_sales) / SUM(SUM(net_sales)) OVER () * 100, 2) AS share_pct
FROM pnl_sales
WHERE fiscal_year = 2021
GROUP BY region
ORDER BY share_pct DESC;

-- 18. Product mix: each segment's share of net sales, per fiscal year (FY2022 is Sep–Dec only)
SELECT
    fiscal_year,
    segment,
    ROUND(SUM(net_sales) / 1000000, 2) AS net_sales_mln,
    ROUND(SUM(net_sales) / SUM(SUM(net_sales)) OVER (PARTITION BY fiscal_year) * 100, 2) AS share_of_year_pct
FROM pnl_sales
GROUP BY fiscal_year, segment
ORDER BY fiscal_year, share_of_year_pct DESC;

-- 19. Each channel's share of FY2021 net sales and its gross margin %
SELECT
    channel,
    ROUND(SUM(net_sales) / 1000000, 2)                             AS net_sales_mln,
    ROUND(SUM(net_sales) / SUM(SUM(net_sales)) OVER () * 100, 2)   AS share_pct,
    ROUND(SUM(gross_margin) / SUM(net_sales) * 100, 2)             AS gm_pct
FROM pnl_sales
WHERE fiscal_year = 2021
GROUP BY channel
ORDER BY share_pct DESC;

-- 20. Discount leakage: deductions given to the top 10 customers by FY2021 gross sales, and their margin
WITH customer_deductions AS (
    SELECT
        customer,
        SUM(gross_sales)             AS gross_sales,
        SUM(pre_invoice_deductions)  AS pre_deductions,
        SUM(net_invoice_sales)       AS net_invoice_sales,
        SUM(post_invoice_deductions) AS post_deductions,
        SUM(net_sales)               AS net_sales,
        SUM(gross_margin)            AS gross_margin
    FROM pnl_sales
    WHERE fiscal_year = 2021
    GROUP BY customer
)
SELECT
    customer,
    ROUND(gross_sales / 1000000, 2)                                   AS gross_sales_mln,
    ROUND(pre_deductions / gross_sales * 100, 2)                      AS pre_invoice_pct_of_gross,
    ROUND(net_invoice_sales / 1000000, 2)                             AS net_invoice_sales_mln,
    ROUND(post_deductions / net_invoice_sales * 100, 2)               AS post_invoice_pct_of_net_invoice,
    ROUND(net_sales / 1000000, 2)                                     AS net_sales_mln,
    ROUND((pre_deductions + post_deductions) / gross_sales * 100, 2)  AS total_deductions_pct_of_gross,
    ROUND(gross_margin / net_sales * 100, 2)                          AS gm_pct
FROM customer_deductions
ORDER BY gross_sales DESC
LIMIT 10;

-- 21. Which channels AtliQ's own stores are recorded under
SELECT
    customer,
    channel,
    COUNT(DISTINCT customer_code)       AS customer_codes,
    ROUND(SUM(net_sales) / 1000000, 2)  AS net_sales_mln
FROM pnl_sales
WHERE fiscal_year = 2021
  AND customer LIKE 'Atliq%'
GROUP BY customer, channel
ORDER BY customer, channel;

-- =========================================================
-- SECTION 6: Reusable reports with stored procedures
-- =========================================================

-- 22. A P&L report for any market and fiscal year
DROP PROCEDURE IF EXISTS get_market_pnl;

CREATE PROCEDURE get_market_pnl(IN p_market VARCHAR(45), IN p_fiscal_year INT)
SELECT
    market_name,
    fiscal_year,
    ROUND(SUM(gross_sales) / 1000000, 2)             AS gross_sales_mln,
    ROUND(SUM(pre_invoice_deductions) / 1000000, 2)  AS pre_invoice_deductions_mln,
    ROUND(SUM(net_invoice_sales) / 1000000, 2)       AS net_invoice_sales_mln,
    ROUND(SUM(post_invoice_deductions) / 1000000, 2) AS post_invoice_deductions_mln,
    ROUND(SUM(net_sales) / 1000000, 2)               AS net_sales_mln,
    ROUND(SUM(cogs) / 1000000, 2)                    AS cogs_mln,
    ROUND(SUM(gross_margin) / 1000000, 2)            AS gross_margin_mln,
    ROUND(SUM(gross_margin) / SUM(net_sales) * 100, 2) AS gm_pct
FROM pnl_sales
WHERE market_name = p_market
  AND fiscal_year = p_fiscal_year
GROUP BY market_name, fiscal_year;

-- Examples
CALL get_market_pnl('India', 2021);
CALL get_market_pnl('USA', 2021);

-- 23. The top N products by net sales for any market and fiscal year
DROP PROCEDURE IF EXISTS get_top_products;

CREATE PROCEDURE get_top_products(IN p_market VARCHAR(45), IN p_fiscal_year INT, IN p_top_n INT)
SELECT
    CONCAT(product, ' - ', variant)                    AS product_label,
    segment,
    ROUND(SUM(net_sales) / 1000000, 2)                 AS net_sales_mln,
    ROUND(SUM(gross_margin) / SUM(net_sales) * 100, 2) AS gm_pct
FROM pnl_sales
WHERE market_name = p_market
  AND fiscal_year = p_fiscal_year
GROUP BY product, variant, segment
ORDER BY SUM(net_sales) DESC, product_label
LIMIT p_top_n;

-- Examples
CALL get_top_products('India', 2021, 5);
CALL get_top_products('Germany', 2021, 5);





























