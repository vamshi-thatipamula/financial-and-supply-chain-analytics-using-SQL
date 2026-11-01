# Data Dictionary

AtliQ Hardware's data warehouse contains **9 tables**: 2 dimension tables (descriptions of customers and products) and 7 fact tables (sales, forecasts, prices, deductions and costs).

---

## 1. Dimension tables

### dim_customer
One row per **customer code**. **209 rows.** Primary key: `customer_code`

| Column | Description |
|---|---|
| customer_code | Unique identifier of a customer account |
| customer | Company name (74 names across 209 codes; one company can have a code in several markets) |
| platform | Brick & Mortar or E-Commerce |
| channel | Retailer, Direct and Distributor |
| market | Country (27 markets) |
| sub_zone | Geographic sub-zone (7) |
| region | Geographic region (4): APAC, EU, LATAM, NA |

### dim_product
One row per **product code**. **397 rows.** Primary key: `product_code`

| Column | Description |
|---|---|
| product_code | Unique identifier of a product |
| division | P & A (Peripherals and Accessories), PC (Notebook and Desktop), N & S (Networking and Storage) |
| segment | 6 segments: Accessories, Desktop, Networking, Notebook, Peripherals, Storage |
| category | 14 product categories, e.g. Mouse, Gaming Laptop, Internal HDD |
| product | Product name (73 names) |
| variant | Product version, e.g. Standard, Plus, Premium (26 variants) |

---

## 2. Fact tables

### fact_sales_monthly
One row per **product, customer and month**. **1,425,706 rows**, September 2017 to December 2021.
Primary key: `date` + `product_code` + `customer_code`

| Column | Description |
|---|---|
| date | Month of sale (first day of the month) |
| product_code | Product sold |
| customer_code | Customer who bought it |
| sold_quantity | Units sold |
| fiscal_year | *Added in this project:* fiscal year, calculated from the date |

### fact_forecast_monthly
One row per **product, customer and month**. **1,885,941 rows**, September 2017 to August 2022.
Primary key: `date` + `product_code` + `customer_code`

| Column | Description |
|---|---|
| date | Month of the forecast |
| fiscal_year | Fiscal year of the forecast |
| product_code | Product forecast |
| customer_code | Customer forecast for |
| forecast_quantity | Units forecast |

### fact_gross_price
One row per **product and fiscal year**. **1,182 rows.** Primary key: `product_code` + `fiscal_year`

| Column | Description |
|---|---|
| product_code | Product |
| fiscal_year | Fiscal year the price applies to |
| gross_price | List price per unit, before any deductions |

### fact_manufacturing_cost
One row per **product and fiscal year**. **1,182 rows.** Primary key: `product_code` + `cost_year`

| Column | Description |
|---|---|
| product_code | Product |
| cost_year | Fiscal year the cost applies to |
| manufacturing_cost | Cost to make one unit |

### fact_pre_invoice_deductions
One row per **customer and fiscal year**. **1,045 rows.** Primary key: `customer_code` + `fiscal_year`

| Column | Description |
|---|---|
| customer_code | Customer |
| fiscal_year | Fiscal year the discount applies to |
| pre_invoice_discount_pct | Yearly discount agreed with the customer, taken off before the invoice (as a decimal, e.g. 0.20 = 20%) |

### fact_post_invoice_deductions
One row per **customer, product and month**. **2,063,076 rows**, September 2017 to August 2022.
Primary key: `customer_code` + `product_code` + `date`

| Column | Description |
|---|---|
| customer_code | Customer |
| product_code | Product |
| date | Month |
| discounts_pct | Promotional discounts paid back after the sale (as a decimal) |
| other_deductions_pct | Other post-sale payments, such as placement fees and rebates (as a decimal) |

### fact_freight_cost
One row per **market and fiscal year**. **135 rows.** Primary key: `market` + `fiscal_year`

| Column | Description |
|---|---|
| market | Market (country) |
| fiscal_year | Fiscal year the rates apply to |
| freight_pct | Freight cost as a share of net sales (as a decimal) |
| other_cost_pct | Other delivery-related costs as a share of net sales (as a decimal) |

---

## 3. Relationships

| From | To | Joined on | Relationship |
|---|---|---|---|
| dim_customer | fact_sales_monthly, fact_forecast_monthly | customer_code | one to many |
| dim_customer | fact_pre_invoice_deductions | customer_code | one to many |
| dim_customer | fact_post_invoice_deductions | customer_code | one to many |
| dim_customer | fact_freight_cost | market | lookup by market |
| dim_product | fact_sales_monthly, fact_forecast_monthly | product_code | one to many |
| dim_product | fact_gross_price, fact_manufacturing_cost | product_code | one to many |
| dim_product | fact_post_invoice_deductions | product_code | one to many |

**Joining sales to the yearly tables** (prices, costs, pre-invoice deductions, freight) uses the sale's **fiscal year** as well as the code, so that each sale matches exactly one row. Joining on the code alone would match every year's row and duplicate sales.

---

## 4. Objects built in this project

| Object | Type | Purpose |
|---|---|---|
| get_fiscal_year() | Function | Returns the fiscal year for any date |
| v_sales_gross | View | Sales with customer and product details, gross price and gross sales |
| v_sales_post_invoice | View | Adds pre-invoice deductions and net invoice sales |
| v_net_sales | View | Adds post-invoice deductions and net sales |
| v_sales_pnl | View | Adds manufacturing, freight and other costs, COGS and gross margin |
| pnl_sales | Table | Stored result of v_sales_pnl, used for all financial analysis |
| forecast_vs_actual | Table | Forecast and actual sales per product, customer and month, with net and absolute error |
| inventory_estimate | Table | Estimated month-end stock and shortfall per product and month |
| cost_of_errors | Table | Holding cost and revenue at risk per product and month |
| get_market_pnl() | Stored procedure | P&L report for any market and fiscal year |
| get_top_products() | Stored procedure | Top N products for any market and fiscal year |