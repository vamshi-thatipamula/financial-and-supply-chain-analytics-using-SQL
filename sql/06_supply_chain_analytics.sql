/*
===========================================================================================
  Purpose: Measure forecast accuracy, estimate inventory and the cost of forecasting errors
===========================================================================================
*/

USE your_database;

-- =========================================================
-- SECTION 1: Stacking results with UNION
-- =========================================================

-- 1. UNION vs UNION ALL: market lists from two tables stacked together
SELECT
    (SELECT COUNT(*) FROM (SELECT market FROM dim_customer
                           UNION
                           SELECT market FROM fact_freight_cost) AS u)     AS union_rows,
    (SELECT COUNT(*) FROM (SELECT market FROM dim_customer
                           UNION ALL
                           SELECT market FROM fact_freight_cost) AS ua)    AS union_all_rows;

-- 2. How well do forecasts and sales line up? Rows with both, forecast only, or sales only (Sep 2017 – Dec 2021)
WITH combined AS (
    SELECT date, product_code, customer_code, forecast_quantity AS forecast_qty, 0 AS sold_qty
    FROM fact_forecast_monthly
    WHERE date <= '2021-12-01'
    UNION ALL
    SELECT date, product_code, customer_code, 0 AS forecast_qty, sold_quantity AS sold_qty
    FROM fact_sales_monthly
),
matched AS (
    SELECT
        date, product_code, customer_code,
        SUM(forecast_qty) AS forecast_qty,
        SUM(sold_qty)     AS sold_qty,
        COUNT(*)          AS source_rows
    FROM combined
    GROUP BY date, product_code, customer_code
)
SELECT
    SUM(source_rows = 2)                         AS in_both,
    SUM(source_rows = 1 AND forecast_qty > 0 AND sold_qty = 0) AS forecast_only,
    SUM(source_rows = 1 AND sold_qty > 0 AND forecast_qty = 0) AS sales_only,
    COUNT(*)                                     AS total_combinations
FROM matched;

-- =========================================================
-- SECTION 2: Forecast accuracy
-- =========================================================

-- 3. One row per product, customer and month with forecast, actual sales and the errors
--    (Sep 2017 – Dec 2021, the period where both forecast and actual sales exist)
DROP TABLE IF EXISTS forecast_vs_actual;

CREATE TABLE forecast_vs_actual AS
SELECT
    m.date,
    get_fiscal_year(m.date) AS fiscal_year,
    m.product_code,
    m.customer_code,
    c.customer,
    CASE c.market
        WHEN 'Columbia'    THEN 'Colombia'
        WHEN 'Philiphines' THEN 'Philippines'
        WHEN 'Newzealand'  THEN 'New Zealand'
        ELSE c.market
    END AS market_name,
    c.region,
    c.channel,
    p.segment,
    p.category,
    m.forecast_qty,
    m.sold_qty,
    CAST(m.forecast_qty AS SIGNED) - CAST(m.sold_qty AS SIGNED)      AS net_error,
    ABS(CAST(m.forecast_qty AS SIGNED) - CAST(m.sold_qty AS SIGNED)) AS abs_error
FROM (
    SELECT
        date, product_code, customer_code,
        SUM(forecast_qty) AS forecast_qty,
        SUM(sold_qty)     AS sold_qty
    FROM (
        SELECT date, product_code, customer_code, forecast_quantity AS forecast_qty, 0 AS sold_qty
        FROM fact_forecast_monthly
        WHERE date <= '2021-12-01'
        UNION ALL
        SELECT date, product_code, customer_code, 0 AS forecast_qty, sold_quantity AS sold_qty
        FROM fact_sales_monthly
    ) AS combined
    GROUP BY date, product_code, customer_code
) AS m
JOIN dim_customer AS c
    ON m.customer_code = c.customer_code
JOIN dim_product AS p
    ON m.product_code = p.product_code;

CREATE INDEX idx_fva_fiscal_year ON forecast_vs_actual (fiscal_year);
CREATE INDEX idx_fva_customer    ON forecast_vs_actual (customer);
CREATE INDEX idx_fva_product     ON forecast_vs_actual (product_code);

-- 4. Checks: rows should match query 2 (1,488,187) and units sold the sales table (125,291,556)
SELECT
    COUNT(*)          AS combinations,
    SUM(sold_qty)     AS total_sold,
    SUM(forecast_qty) AS total_forecast
FROM forecast_vs_actual;

-- 5. Forecast accuracy by fiscal year (FY2022 is Sep–Dec 2021 only)
SELECT
    fiscal_year,
    SUM(forecast_qty) AS forecast_units,
    SUM(sold_qty)     AS actual_units,
    ROUND(SUM(net_error) / SUM(forecast_qty) * 100, 2) AS net_error_pct,
    ROUND(SUM(abs_error) / SUM(forecast_qty) * 100, 2) AS abs_error_pct,
    ROUND(GREATEST(0, 100 - SUM(abs_error) / SUM(forecast_qty) * 100), 2) AS forecast_accuracy_pct
FROM forecast_vs_actual
GROUP BY fiscal_year
ORDER BY fiscal_year;

-- 6. Forecast accuracy by segment, FY2021
SELECT
    segment,
    SUM(forecast_qty) AS forecast_units,
    SUM(sold_qty)     AS actual_units,
    ROUND(SUM(net_error) / SUM(forecast_qty) * 100, 2) AS net_error_pct,
    ROUND(GREATEST(0, 100 - SUM(abs_error) / SUM(forecast_qty) * 100), 2) AS forecast_accuracy_pct,
    CASE
        WHEN SUM(net_error) > 0 THEN 'Over-forecast: excess stock risk'
        WHEN SUM(net_error) < 0 THEN 'Under-forecast: stock-out risk'
        ELSE 'Balanced'
    END AS risk
FROM forecast_vs_actual
WHERE fiscal_year = 2021
GROUP BY segment
ORDER BY forecast_accuracy_pct;

-- 7. The 10 customers with the least accurate forecasts, FY2021 (customers with at least 100,000 forecast units)
SELECT
    customer,
    SUM(forecast_qty) AS forecast_units,
    SUM(sold_qty)     AS actual_units,
    ROUND(SUM(net_error) / SUM(forecast_qty) * 100, 2) AS net_error_pct,
    ROUND(GREATEST(0, 100 - SUM(abs_error) / SUM(forecast_qty) * 100), 2) AS forecast_accuracy_pct,
    CASE
        WHEN SUM(net_error) > 0 THEN 'Over-forecast: excess stock risk'
        WHEN SUM(net_error) < 0 THEN 'Under-forecast: stock-out risk'
        ELSE 'Balanced'
    END AS risk
FROM forecast_vs_actual
WHERE fiscal_year = 2021
GROUP BY customer
HAVING SUM(forecast_qty) >= 100000
ORDER BY forecast_accuracy_pct, customer
LIMIT 10;

-- 8. Forecast accuracy by market, FY2021, worst first
SELECT
    market_name,
    SUM(forecast_qty) AS forecast_units,
    SUM(sold_qty)     AS actual_units,
    ROUND(SUM(net_error) / SUM(forecast_qty) * 100, 2) AS net_error_pct,
    ROUND(GREATEST(0, 100 - SUM(abs_error) / SUM(forecast_qty) * 100), 2) AS forecast_accuracy_pct,
    CASE
        WHEN SUM(net_error) > 0 THEN 'Over-forecast: excess stock risk'
        WHEN SUM(net_error) < 0 THEN 'Under-forecast: stock-out risk'
        ELSE 'Balanced'
    END AS risk
FROM forecast_vs_actual
WHERE fiscal_year = 2021
GROUP BY market_name
ORDER BY forecast_accuracy_pct, market_name;

-- =========================================================
-- SECTION 3: Running totals and the inventory estimate
-- =========================================================

-- 9. Running total of net sales through FY2021, month by month
SELECT
    date,
    ROUND(SUM(net_sales) / 1000000, 2) AS month_net_sales_mln,
    ROUND(SUM(SUM(net_sales)) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) / 1000000, 2) AS running_total_mln
FROM pnl_sales
WHERE fiscal_year = 2021
GROUP BY date
ORDER BY date;

-- 10. Estimated month-end stock and shortfall per product
--     (assumes production = forecast, one shared stock per product, starting stock of zero)
DROP TABLE IF EXISTS inventory_estimate;

CREATE TABLE inventory_estimate AS
SELECT
    product_code,
    date,
    get_fiscal_year(date) AS fiscal_year,
    forecast_qty,
    sold_qty,
    running_flow - LEAST(0, lowest_flow)   AS stock_end,
    -LEAST(0, lowest_flow)
      - COALESCE(LAG(-LEAST(0, lowest_flow)) OVER (PARTITION BY product_code ORDER BY date), 0) AS shortfall_qty
FROM (
    SELECT
        product_code, date, forecast_qty, sold_qty, running_flow,
        MIN(running_flow) OVER (PARTITION BY product_code ORDER BY date ROWS UNBOUNDED PRECEDING) AS lowest_flow
    FROM (
        SELECT
            product_code, date, forecast_qty, sold_qty,
            SUM(forecast_qty - sold_qty) OVER (PARTITION BY product_code ORDER BY date ROWS UNBOUNDED PRECEDING) AS running_flow
        FROM (
            SELECT
                g.product_code,
                g.date,
                COALESCE(CAST(m.forecast_qty AS SIGNED), 0) AS forecast_qty,
                COALESCE(CAST(m.sold_qty AS SIGNED), 0)     AS sold_qty
            FROM (
                SELECT p.product_code, d.date
                FROM (SELECT DISTINCT product_code FROM forecast_vs_actual) AS p
                CROSS JOIN (SELECT DISTINCT date FROM forecast_vs_actual) AS d
            ) AS g
            LEFT JOIN (
                SELECT product_code, date,
                       SUM(forecast_qty) AS forecast_qty,
                       SUM(sold_qty)     AS sold_qty
                FROM forecast_vs_actual
                GROUP BY product_code, date
            ) AS m
                ON g.product_code = m.product_code
               AND g.date         = m.date
        ) AS monthly
    ) AS with_running
) AS with_lowest;

CREATE INDEX idx_inv_product ON inventory_estimate (product_code);
CREATE INDEX idx_inv_fy      ON inventory_estimate (fiscal_year);

-- 11. Checks: grid size, and units sold must still total 125,291,556; stock can never be negative
SELECT
    COUNT(*)                   AS product_months,
    SUM(sold_qty)              AS total_sold,
    SUM(forecast_qty)          AS total_forecast,
    SUM(stock_end < 0)         AS negative_stock_rows,
    SUM(shortfall_qty < 0)     AS negative_shortfall_rows
FROM inventory_estimate;

-- 12. Check the logic on an under-forecast product: sales beat forecast every month, so stock stays at 0 and each month's gap is a shortfall (it does not carry forward)
SELECT date, forecast_qty, sold_qty, stock_end, shortfall_qty
FROM inventory_estimate
WHERE product_code = 'A0118150101'
ORDER BY date
LIMIT 15;

-- 13. The five products with the largest estimated stock build-up (all external SSDs)
SELECT
    i.product_code,
    p.segment,
    p.category,
    CONCAT(p.product, ' - ', p.variant) AS product_label,
    MAX(i.stock_end) AS highest_stock
FROM inventory_estimate AS i
JOIN dim_product AS p
    ON i.product_code = p.product_code
GROUP BY i.product_code, p.segment, p.category, p.product, p.variant
ORDER BY highest_stock DESC
LIMIT 5;

-- 14. Check the logic on an over-forecast product: stock builds up, carries forward, and is drawn down when sales beat forecast (AQ Digit SSD - Plus)
SELECT date, forecast_qty, sold_qty, stock_end, shortfall_qty
FROM inventory_estimate
WHERE product_code = 'A6218160102'
ORDER BY date;

-- =========================================================
-- SECTION 4: The cost of forecast errors
-- =========================================================

-- 15. Holding cost on estimated stock and revenue at risk on shortfalls, per product and month 
-- (holding cost at 1%, 2% and 3% of manufacturing cost per month; revenue at risk at net sales per unit)
DROP TABLE IF EXISTS cost_of_errors;

CREATE TABLE cost_of_errors AS
SELECT
    i.product_code,
    i.date,
    i.fiscal_year,
    p.segment,
    p.category,
    i.stock_end,
    i.shortfall_qty,
    COALESCE(mc.manufacturing_cost, lc.latest_cost)           AS unit_cost,
    np.net_price_per_unit,
    i.stock_end * COALESCE(mc.manufacturing_cost, lc.latest_cost) * 0.01 AS holding_cost_1pct,
    i.stock_end * COALESCE(mc.manufacturing_cost, lc.latest_cost) * 0.02 AS holding_cost_2pct,
    i.stock_end * COALESCE(mc.manufacturing_cost, lc.latest_cost) * 0.03 AS holding_cost_3pct,
    i.shortfall_qty * COALESCE(np.net_price_per_unit, 0)      AS revenue_at_risk
FROM inventory_estimate AS i
JOIN dim_product AS p
    ON i.product_code = p.product_code
LEFT JOIN fact_manufacturing_cost AS mc
    ON i.product_code = mc.product_code
   AND i.fiscal_year  = mc.cost_year
LEFT JOIN (
    SELECT product_code, manufacturing_cost AS latest_cost
    FROM (
        SELECT
            product_code,
            manufacturing_cost,
            ROW_NUMBER() OVER (PARTITION BY product_code ORDER BY cost_year DESC) AS rn
        FROM fact_manufacturing_cost
    ) AS ranked
    WHERE rn = 1
) AS lc
    ON i.product_code = lc.product_code
LEFT JOIN (
    SELECT
        product_code,
        fiscal_year,
        SUM(net_sales) / SUM(sold_quantity) AS net_price_per_unit
    FROM pnl_sales
    GROUP BY product_code, fiscal_year
    HAVING SUM(sold_quantity) > 0
) AS np
    ON i.product_code = np.product_code
   AND i.fiscal_year  = np.fiscal_year;

-- 16. Checks: full grid kept, and no missing prices where they're needed (both should be 0)
SELECT
    COUNT(*)                                                 AS product_months,
    SUM(stock_end > 0     AND unit_cost IS NULL)             AS stock_without_cost,
    SUM(shortfall_qty > 0 AND net_price_per_unit IS NULL)    AS shortfall_without_price
FROM cost_of_errors;

-- 17. The cost of forecast errors by fiscal year, against net sales (FY2022 is Sep–Dec only)
WITH costs AS (
    SELECT
        fiscal_year,
        SUM(holding_cost_1pct) AS holding_1,
        SUM(holding_cost_2pct) AS holding_2,
        SUM(holding_cost_3pct) AS holding_3,
        SUM(revenue_at_risk)   AS revenue_at_risk
    FROM cost_of_errors
    GROUP BY fiscal_year
),
sales AS (
    SELECT fiscal_year, SUM(net_sales) AS net_sales
    FROM pnl_sales
    GROUP BY fiscal_year
)
SELECT
    c.fiscal_year,
    ROUND(s.net_sales / 1000000, 2)                    AS net_sales_mln,
    ROUND(c.holding_1 / 1000000, 2)                    AS holding_cost_1pct_mln,
    ROUND(c.holding_2 / 1000000, 2)                    AS holding_cost_2pct_mln,
    ROUND(c.holding_3 / 1000000, 2)                    AS holding_cost_3pct_mln,
    ROUND(c.holding_2 / s.net_sales * 100, 2)          AS holding_2pct_share_of_sales,
    ROUND(c.revenue_at_risk / 1000000, 2)              AS revenue_at_risk_mln,
    ROUND(c.revenue_at_risk / s.net_sales * 100, 2)    AS revenue_at_risk_share_of_sales
FROM costs AS c
JOIN sales AS s
    ON c.fiscal_year = s.fiscal_year
ORDER BY c.fiscal_year;


