# Assumptions and Data Notes

This document records the decisions, assumptions and data-quality notes behind the analysis, and the reasoning for each.

---

## 1. Time scope

- **Fiscal year:** AtliQ Hardware's fiscal year runs from September to August. FY2018 covers September 2017 to August 2018. A sale's fiscal year is derived from its date by adding four months and taking the calendar year; this logic matches the fiscal years in the forecast table on all 1,885,941 rows.
- **Full years:** FY2018 to FY2021 are complete fiscal years and form the basis of year-on-year comparisons.
- **FY2022:** Sales data ends in December 2021, so FY2022 covers September–December 2021 only. These are AtliQ Hardware's peak months, so FY2022 is never compared directly with full years. Instead, it is compared with the same months a year earlier (September–December 2020).
- **Snapshot year:** FY2021, the most recent complete year, is used for point-in-time comparisons (markets, customers, products, channels). Trends use all years.

---

## 2. Data handling

- **Source data is never modified.** All corrections are applied in the analysis layer (views), so every figure can be traced back to the original tables.
- **Stored fiscal year column:** A generated `fiscal_year` column was added to `fact_sales_monthly`, calculated from the date. It changes the table's structure but none of its values, and was added for performance when joining sales to yearly tables.
- **Market names:** Three markets are misspelled in the source data (Columbia, Philiphines, Newzealand). They are corrected for reporting (Colombia, Philippines, New Zealand) in the `market_name` column; the original spelling is kept for joining to the freight table.
- **Channel correction:** One AtliQ Hardware Exclusive customer code is classified as Retailer in the source data. Since AtliQ Hardware's own stores are Direct by definition, it is reclassified as Direct in the analysis layer.
- **Customers:** Customer rankings use the customer name, combining all customer codes of the same company (209 codes belong to 74 names). Codes are used only for joining tables.
- **Manufacturing cost year:** `cost_year` in `fact_manufacturing_cost` is treated as the fiscal year. Both cost and price tables have identical row counts per year and match one-to-one on product and year.
- **Divisions:** PC = Notebook and Desktop; P & A = Peripherals and Accessories; N & S = Networking and Storage. Confirmed from the data: each division's net sales equal the sum of its segments.

---

## 3. Financial assumptions

- **Freight and other costs** are calculated as a percentage of **net sales**, using the market- and year-specific rates in `fact_freight_cost`. The data does not specify the base; net sales was chosen because it reflects the revenue AtliQ Hardware actually keeps. Using gross sales would overstate costs and understate margin.
- **Gross margin %** is always calculated from totals (total gross margin ÷ total net sales), never by averaging row-level percentages, so that larger sales carry their proper weight.
- **Scope:** The analysis covers revenue and product profitability up to gross margin. Operating expenses (salaries, marketing, overheads), interest and taxes are not in the dataset, so operating and net profit are out of scope.

---

## 4. Supply chain assumptions

- **Comparison period:** Forecasts are compared with actual sales only for the 52 months where both exist (September 2017 to December 2021). Forecasts for January–August 2022 have no sales to compare against and are excluded.
- **Combining forecast and sales:** The two tables are stacked with UNION ALL rather than joined, so that no rows are lost. All 1,488,187 product-customer-month combinations are kept: forecasts with no sale (62,052 cases) and sales with no forecast (34,089 cases) are counted as errors, with the missing side set to 0, since nothing was forecast or nothing was sold. A further 1,209 combinations have zero on both sides; they are kept for completeness and have no effect on any result.
- **Forecast accuracy:** Absolute error is calculated for each product, customer and month, then totalled. Accuracy = 100% − (total absolute error ÷ total forecast), with a minimum of 0%. Measuring at this detailed level is standard, but gives lower accuracy than forecasts for whole categories or quarters would.
- **Inventory estimate:** The data has no production or stock records, so stock is estimated per product and month, assuming that:
  - production each month equals the forecast,
  - all customers are served from one shared stock per product,
  - stock starts at zero in September 2017,
  - stock can never fall below zero; sales beyond available stock are recorded as a shortfall.

  A real company would cut production if stock piled up, so this likely overstates stock for persistently over-forecast products.
- **Holding cost:** Leftover stock is valued at its manufacturing cost and charged 2% of that value per month (24% a year), a common rule of thumb for storage, insurance, handling and obsolescence. Results are also shown at 1% and 3% to test how much the conclusion depends on this rate. For months after a product stopped selling, its most recent manufacturing cost is used.
- **Revenue at risk:** Shortfall units are valued at the product's net sales per unit for that year. These sales did happen, but relied on stock that was not planned; they represent sales exposed to stock-out risk, not confirmed lost sales.
- **Margin at risk:** Revenue at risk × that year's overall gross margin %, used to compare under-forecasting with holding cost on the same profit basis. It assumes the shortfall products earn the average margin.

---

## 5. Data quality notes

- **Zero-quantity sales:** 783 FY2018 sales rows have no matching post-invoice deduction record. All have a sold quantity of 0, so they carry no revenue; they are kept, with a post-invoice deduction of 0%.
- **Products without sales:** 8 of 397 products have no sales, prices or costs in any year. They remain in the product table but are naturally excluded from all analysis, since the P&L and forecast analysis start from actual sales and forecasts.
- **Unsigned number columns:** Prices and quantities are stored as numbers that cannot be negative. Calculations that can produce negative results (price changes, forecast errors, gross margin) convert values first to avoid errors.

---

## 6. Limitations

- **No order data:** The dataset records delivered sales, not customer orders, so sales lost to stock-outs cannot be measured.
- **Consumer sales not recorded:** AtliQ Hardware's data covers sales to its customers (retailers, distributors and its own stores), not what those customers sell on to consumers.
- **Course dataset:** AtliQ Hardware is a fictional company, and the data comes from a training course. Findings describe what the data shows, not the performance of a real business.