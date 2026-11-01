/*
======================================================================================
  Purpose: Explore the tables by selecting, filtering, sorting and removing duplicates
======================================================================================
*/

USE your_database;

-- =========================================================
-- SECTION 1: Selecting columns and limiting rows
-- =========================================================

-- 1. Quick look at the product table: all columns, first 5 rows
SELECT * FROM dim_product LIMIT 5;

-- 2. Only the product name, category and variant for every product
SELECT product, category, variant FROM dim_product;

-- 3. First 10 rows of sales: date, customer and quantity sold
SELECT date, customer_code, sold_quantity FROM fact_sales_monthly LIMIT 10;


-- =========================================================
-- SECTION 2: Filtering rows with WHERE
-- =========================================================

-- 4. All customers in the Indian market
SELECT customer_code, customer, platform, channel FROM dim_customer WHERE market = 'India';

-- 5. All products in the Mouse category
SELECT product_code, product, variant FROM dim_product WHERE category = 'Mouse';

-- 6. E-Commerce customers in India (both conditions must be true)
SELECT customer_code, customer, channel FROM dim_customer WHERE market = 'India' AND platform = 'E-Commerce';

-- 7. Customers in India or the USA (either condition is enough)
SELECT customer_code, customer, market FROM dim_customer WHERE market = 'India' OR market = 'USA';

-- 8. Customers in several markets, using IN instead of many ORs
SELECT customer_code, customer, market FROM dim_customer WHERE market IN ('India', 'USA', 'Germany');

-- 9. Sales between two dates (both dates included)
SELECT date, customer_code, product_code, sold_quantity FROM fact_sales_monthly WHERE date BETWEEN '2020-09-01' AND '2020-12-01' LIMIT 10;

-- 10. Products whose variant contains the word 'Premium'
SELECT product, variant FROM dim_product WHERE variant LIKE '%Premium%';

-- 11. Large sales: more than 1,000 units in a single month
SELECT date, customer_code, product_code, sold_quantity FROM fact_sales_monthly WHERE sold_quantity > 1000 LIMIT 10;

-- 12. E-Commerce customers in India or the USA (brackets make AND + OR work correctly)
SELECT customer_code, customer, market, platform FROM dim_customer WHERE (market = 'India' OR market = 'USA') AND platform = 'E-Commerce';


-- =========================================================
-- SECTION 3: Sorting, removing duplicates and renaming columns
-- =========================================================

-- 13. Customers sorted alphabetically by name
SELECT customer, market FROM dim_customer ORDER BY customer;

-- 14. Largest monthly sales first (DESC = highest to lowest)
SELECT date, customer_code, product_code, sold_quantity FROM fact_sales_monthly ORDER BY sold_quantity DESC LIMIT 10;

-- 15. Sort by region first, then by market within each region
SELECT region, market, customer FROM dim_customer ORDER BY region, market;

-- 16. The list of markets, each shown only once
SELECT DISTINCT market FROM dim_customer ORDER BY market;

-- 17. Every unique region and market combination
SELECT DISTINCT region, market FROM dim_customer ORDER BY region, market;

-- 18. Renaming columns in the output with AS
SELECT customer AS customer_name, market AS country, channel  AS sales_channel FROM dim_customer LIMIT 10;

-- 19. Most expensive products in FY2021, with a clearer column name
SELECT product_code, gross_price AS price_usd FROM fact_gross_price WHERE fiscal_year = 2021 ORDER BY price_usd DESC LIMIT 10;
select distinct fiscal_year, count(fiscal_year) from fact_gross_price order by fiscal_year;

-- 20. Short table name (alias) to save typing, used a lot with joins later
SELECT c.customer, c.market FROM dim_customer AS c WHERE c.region = 'APAC' ORDER BY c.market;



