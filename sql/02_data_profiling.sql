/*
============================================================================================
  Purpose: Profile the tables by counting rows, summarising values and checking data quality
============================================================================================
*/

USE your_database;

-- =========================================================
-- SECTION 1: Summarising whole tables with aggregate functions
-- =========================================================

-- 1. How many rows are in the sales table
SELECT COUNT(*) AS total_rows FROM fact_sales_monthly;

-- 2. How many different customers and products appear in sales
SELECT
    COUNT(DISTINCT customer_code) AS unique_customers,
    COUNT(DISTINCT product_code)  AS unique_products
FROM fact_sales_monthly;

-- 3. Total units ever sold
SELECT SUM(sold_quantity) AS total_units_sold FROM fact_sales_monthly;

-- 4. Average units per sales row, rounded to 2 decimals
SELECT ROUND(AVG(sold_quantity), 2) AS avg_units_per_row FROM fact_sales_monthly;

-- 5. First and last month of sales data
SELECT
    MIN(date) AS first_month,
    MAX(date) AS last_month
FROM fact_sales_monthly;

-- 6. Smallest and largest monthly sale
SELECT
    MIN(sold_quantity) AS min_units,
    MAX(sold_quantity) AS max_units
FROM fact_sales_monthly;

-- 7. Cheapest, most expensive and average product price in FY2021
SELECT
    MIN(gross_price) AS cheapest,
    MAX(gross_price) AS most_expensive,
    ROUND(AVG(gross_price), 2) AS average_price
FROM fact_gross_price 
WHERE fiscal_year = 2021;

-- 8. Units sold in calendar year 2020 only (aggregate combined with WHERE)
SELECT SUM(sold_quantity) AS units_2020
FROM fact_sales_monthly
WHERE date BETWEEN '2020-01-01' AND '2020-12-01';

-- 9. How many sales rows have zero quantity
SELECT COUNT(*) AS zero_quantity_rows
FROM fact_sales_monthly
WHERE sold_quantity = 0;

-- =========================================================
-- SECTION 2: Summarising by groups with GROUP BY
-- =========================================================

-- 10. Number of price rows per fiscal year
SELECT fiscal_year, COUNT(*) AS rows_count
FROM fact_gross_price
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- 11. Number of customer codes in each market
SELECT market, COUNT(*) AS customer_codes
FROM dim_customer
GROUP BY market
ORDER BY customer_codes DESC;

-- 12. Number of customer codes per region and channel
SELECT region, channel, COUNT(*) AS customer_codes
FROM dim_customer
GROUP BY region, channel
ORDER BY region, channel;

-- 13. Number of products in each segment and category
SELECT segment, category, COUNT(*) AS products
FROM dim_product
GROUP BY segment, category
ORDER BY segment, category;

-- 14. How many different categories each segment has
SELECT segment, COUNT(DISTINCT category) AS categories
FROM dim_product
GROUP BY segment
ORDER BY categories DESC;

-- 15. Units sold per calendar year
SELECT YEAR(date) AS calendar_year, SUM(sold_quantity) AS units_sold
FROM fact_sales_monthly
GROUP BY YEAR(date)
ORDER BY calendar_year;

-- 16. Average pre-invoice discount given each fiscal year
SELECT fiscal_year, ROUND(AVG(pre_invoice_discount_pct) * 100, 2) AS avg_discount_pct
FROM fact_pre_invoice_deductions
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- 17. Top 10 products by total units sold
SELECT product_code, SUM(sold_quantity) AS units_sold
FROM fact_sales_monthly
GROUP BY product_code
ORDER BY units_sold DESC
LIMIT 10;

-- 18. Sales rows with actual units sold (quantity above zero), per calendar year
SELECT YEAR(date) AS calendar_year, COUNT(*) AS rows_with_sales
FROM fact_sales_monthly
WHERE sold_quantity > 0
GROUP BY YEAR(date)
ORDER BY calendar_year;

-- =========================================================
-- SECTION 3: Filtering groups with HAVING
-- =========================================================

-- 19. Markets with more than 10 customer codes
SELECT market, COUNT(*) AS customer_codes
FROM dim_customer
GROUP BY market
HAVING COUNT(*) > 10
ORDER BY customer_codes DESC;

-- 20. Categories with at least 20 products
SELECT category, COUNT(*) AS products
FROM dim_product
GROUP BY category
HAVING COUNT(*) >= 20
ORDER BY products DESC;

-- 21. Products that sold more than 1 million units in total
SELECT product_code, SUM(sold_quantity) AS units_sold
FROM fact_sales_monthly
GROUP BY product_code
HAVING SUM(sold_quantity) > 1000000
ORDER BY units_sold DESC;

-- 22. Fiscal years where the average pre-invoice discount was above 23%
SELECT fiscal_year, ROUND(AVG(pre_invoice_discount_pct) * 100, 2) AS avg_discount_pct
FROM fact_pre_invoice_deductions
GROUP BY fiscal_year
HAVING AVG(pre_invoice_discount_pct) > 0.23
ORDER BY fiscal_year;

-- 23. Markets with at least 5 E-Commerce customer codes (WHERE filters rows first, HAVING then filters the groups)
SELECT market, COUNT(*) AS ecommerce_codes
FROM dim_customer
WHERE platform = 'E-Commerce'
GROUP BY market
HAVING COUNT(*) >= 5
ORDER BY ecommerce_codes DESC;

-- 24. Customer names that have more than one customer code (one company, several markets or platforms)
SELECT customer, COUNT(*) AS customer_codes
FROM dim_customer
GROUP BY customer
HAVING COUNT(*) > 1
ORDER BY customer_codes DESC;

-- =========================================================
-- SECTION 4: Checking for missing values and messy text
-- =========================================================

-- 25. Check for missing values in key columns of the sales table (0 = none missing)
SELECT
    SUM(date IS NULL) AS missing_date,
    SUM(product_code IS NULL) AS missing_product,
    SUM(customer_code IS NULL) AS missing_customer,
    SUM(sold_quantity IS NULL) AS missing_quantity
FROM fact_sales_monthly;

-- 26. Another way to spot missing values: COUNT(*) vs COUNT(column) should match
SELECT
    COUNT(*) AS all_rows,
    COUNT(market) AS rows_with_market,
    COUNT(sub_zone) AS rows_with_sub_zone
FROM dim_customer;

-- 27. How NULL behaves: comparisons with NULL give NULL, not true or false
SELECT
    NULL = NULL AS equals_check,
    NULL IS NULL AS is_null_check,
    COALESCE(NULL, 0) AS coalesce_result;

-- 28. Look for names with extra spaces at the start or end (should return nothing)
SELECT customer
FROM dim_customer
WHERE customer <> TRIM(customer);

-- 29. Length of each market name, longest first
SELECT DISTINCT market, CHAR_LENGTH(market) AS name_length
FROM dim_customer
ORDER BY name_length DESC, market;

-- 30. Combine columns into one readable label
SELECT DISTINCT CONCAT(product, ' - ', variant) AS product_label
FROM dim_product
LIMIT 10;

-- 31. Upper and lower case versions of a column
SELECT DISTINCT
    region,
    UPPER(market) AS market_upper,
    LOWER(market) AS market_lower
FROM dim_customer
LIMIT 10;

-- 32. Shorten the variant to its first word (Plus, Premium, Standard)
SELECT DISTINCT
    variant,
    SUBSTRING_INDEX(variant, ' ', 1) AS variant_tier
FROM dim_product
ORDER BY variant_tier, variant;

-- 33. Replace part of a text value
SELECT DISTINCT market, REPLACE(market, 'Newzealand', 'New Zealand') AS market_fixed
FROM dim_customer
WHERE market = 'Newzealand';



