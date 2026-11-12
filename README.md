# Retail Sales Analysis | MySQL + Power BI

## Problem
Company ki sales badh rahi hai, par profit nahi. Profit kahan leak ho raha hai?
## Data

Synthetic Indian e-commerce data (2023-2025): 4 tables, ~14,000 orders, ~23,000 order items.

## Cleaning
- 60 duplicate orders hataye
- 25 galat quantity wali rows hatayi
- 30 NULL discounts ko 0% maana (assumption)

## Key Insights
1. Net sales ₹17.17 crore, lekin overall margin sirf 10.38%
2. Electronics ka margin sirf 5.5%, jabki baaki categories 18-24%
3. 15% se upar ka discount profit khatam kar deta hai (30% discount pe margin -14%)
4. COD ka cancellation rate 16%, baaki payment modes ~5%
5. Oct-Nov (festive) mein sales kaafi badhti hain, par margin gir jata hai

## Recommendations
- 15% se upar ke discounts par cap lagao, khaaskar Electronics par
- COD par confirmation ya chhota fee lagao, prepaid ko promote karo

## Dashboard
(Dashboard screenshot yahan judega)

## Tools
MySQL (joins, CTE, window functions, CASE WHEN), Power BI (DAX)

## Files
- PROJECT_ALL_QUERIES_MYSQL.sql : saari cleaning aur analysis queries
- SALES_PROJECT_MYSQL_IMPORT.sql : database aur data
- CSV files : dataset
