-- =====================================================================
-- BrightCart Financial Model
-- Builds on: orders.csv, marketing_spend.csv (same tables as the EDA)
-- Sections:
--   1. P&L waterfall           (gross revenue -> profit, with a tie-out check)
--   2. Channel unit economics  (per-order P&L by channel)
--   3. Marketing efficiency    (spend-weighted ROAS by platform)
--   4. Scenario model          (change the assumptions, rerun)
--   5. Sensitivity grid        (fee cut x return reduction)
-- Each section is a standalone query. Written in plain SQL so it runs in
-- PostgreSQL, Snowflake, DuckDB and SQLite.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. P&L WATERFALL
-- Rebuilds profit line by line from the raw cost columns.
-- The last three rows check the rebuild against the reported profit column.
-- If the gap is not ~0, adjust the formula to match how profit is defined
-- in your dataset (e.g. whether returned orders still carry product cost).
-- ---------------------------------------------------------------------
WITH t AS (
    SELECT
        SUM(gross_revenue)   AS gross_revenue,
        SUM(discount_amount) AS discounts,
        SUM(refund_amount)   AS refunds,
        SUM(product_cost)    AS product_cost,
        SUM(shipping_cost)   AS shipping_cost,
        SUM(platform_fee)    AS platform_fees,
        SUM(transaction_fee) AS transaction_fees,
        SUM(profit)          AS reported_profit
    FROM orders
),
lines AS (
    SELECT 1 AS line_no, 'Gross revenue'          AS line_item, gross_revenue AS amount FROM t
    UNION ALL SELECT 2,  'Less: discounts',        -discounts        FROM t
    UNION ALL SELECT 3,  'Less: refunds',          -refunds          FROM t
    UNION ALL SELECT 4,  'Net revenue',            gross_revenue - discounts - refunds FROM t
    UNION ALL SELECT 5,  'Less: product cost',     -product_cost     FROM t
    UNION ALL SELECT 6,  'Less: shipping',         -shipping_cost    FROM t
    UNION ALL SELECT 7,  'Less: platform fees',    -platform_fees    FROM t
    UNION ALL SELECT 8,  'Less: transaction fees', -transaction_fees FROM t
    UNION ALL SELECT 9,  'Profit (rebuilt)',
        gross_revenue - discounts - refunds - product_cost - shipping_cost - platform_fees - transaction_fees FROM t
    UNION ALL SELECT 10, 'Profit (reported)',      reported_profit   FROM t
    UNION ALL SELECT 11, 'Tie-out gap',
        gross_revenue - discounts - refunds - product_cost - shipping_cost - platform_fees - transaction_fees - reported_profit FROM t
)
SELECT
    line_item,
    ROUND(amount, 2) AS amount,
    ROUND(100.0 * amount / (SELECT amount FROM lines WHERE line_no = 1), 2) AS pct_of_gross
FROM lines
ORDER BY line_no;


-- ---------------------------------------------------------------------
-- 2. CHANNEL UNIT ECONOMICS  (everything per order)
-- Shows where margin is actually made or lost, channel by channel.
-- ---------------------------------------------------------------------
SELECT
    channel,
    COUNT(*)                                                   AS orders,
    ROUND(SUM(gross_revenue)   / COUNT(*), 2)                  AS rev_per_order,
    ROUND(SUM(discount_amount) / COUNT(*), 2)                  AS discount_per_order,
    ROUND(SUM(product_cost)    / COUNT(*), 2)                  AS product_cost_per_order,
    ROUND(SUM(shipping_cost)   / COUNT(*), 2)                  AS shipping_per_order,
    ROUND(SUM(platform_fee)    / COUNT(*), 2)                  AS platform_fee_per_order,
    ROUND(SUM(refund_amount)   / COUNT(*), 2)                  AS refund_per_order,
    ROUND(SUM(profit)          / COUNT(*), 2)                  AS profit_per_order,
    ROUND(100.0 * SUM(profit) / SUM(net_revenue), 2)           AS profit_margin_pct,
    ROUND(100.0 * SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS return_rate_pct,
    ROUND(100.0 * SUM(platform_fee) / SUM(gross_revenue), 2)   AS platform_fee_rate_pct
FROM orders
GROUP BY channel
ORDER BY profit_per_order DESC;


-- ---------------------------------------------------------------------
-- 3. MARKETING EFFICIENCY
-- Spend-weighted ROAS (total attributed revenue / total spend) rather than
-- AVG(roas), so a small month can't distort a platform's number.
-- ---------------------------------------------------------------------
SELECT
    platform,
    ROUND(SUM(spend), 2)                                   AS total_spend,
    ROUND(SUM(revenue_attributed), 2)                      AS attributed_revenue,
    ROUND(SUM(revenue_attributed) / SUM(spend), 2)         AS weighted_roas,
    ROUND(SUM(spend) / SUM(conversions), 2)                AS cost_per_acquisition,
    ROUND(SUM(revenue_attributed) - SUM(spend), 2)         AS net_return,
    CASE
        WHEN SUM(revenue_attributed) < SUM(spend)  THEN 'Underperforming'
        WHEN SUM(revenue_attributed) = SUM(spend)  THEN 'Breaks Even'
        ELSE 'Profitable'
    END AS performance
FROM marketing_spend
GROUP BY platform
ORDER BY weighted_roas DESC;


-- ---------------------------------------------------------------------
-- 4. SCENARIO MODEL
-- Edit the numbers in `assumptions`, rerun, read the bridge.
--   platform_fee_cut    : % reduction in platform fees (renegotiate / mix shift)
--   return_reduction    : % reduction in refunds (better sizing info, QC, etc.)
--   budget_shift        : % of the worst platform's spend moved to the best one
--   marginal_efficiency : new dollars earn only this share of the best
--                         platform's average ROAS (diminishing returns)
-- Simplifications: refund savings are treated as fully recovered profit, and
-- incremental ad revenue is converted to profit at the blended margin.
-- ---------------------------------------------------------------------
WITH assumptions AS (
    SELECT
        0.10 AS platform_fee_cut,
        0.15 AS return_reduction,
        0.10 AS budget_shift,
        0.50 AS marginal_efficiency
),
base AS (
    SELECT
        SUM(net_revenue)  AS net_revenue,
        SUM(profit)       AS profit,
        SUM(platform_fee) AS platform_fees,
        SUM(refund_amount) AS refunds
    FROM orders
),
mkt AS (
    SELECT
        platform,
        SUM(spend) AS spend,
        SUM(revenue_attributed) / SUM(spend) AS roas
    FROM marketing_spend
    GROUP BY platform
),
best  AS (SELECT roas FROM mkt ORDER BY roas DESC LIMIT 1),
worst AS (SELECT spend, roas FROM mkt ORDER BY roas ASC LIMIT 1),
levers AS (
    SELECT
        b.profit                                                        AS base_profit,
        b.net_revenue                                                   AS base_net_revenue,
        b.platform_fees * a.platform_fee_cut                            AS fee_savings,
        b.refunds       * a.return_reduction                            AS refund_savings,
        (w.spend * a.budget_shift)
            * (bst.roas * a.marginal_efficiency - w.roas)
            * (b.profit / b.net_revenue)                                AS ad_realloc_profit
    FROM base b, assumptions a, best bst, worst w
),
bridge AS (
    SELECT 1 AS step, 'Baseline profit'         AS line_item, base_profit       AS amount FROM levers
    UNION ALL SELECT 2, '+ Platform fee savings',            fee_savings        FROM levers
    UNION ALL SELECT 3, '+ Refund reduction',                refund_savings     FROM levers
    UNION ALL SELECT 4, '+ Ad budget reallocation',          ad_realloc_profit  FROM levers
    UNION ALL SELECT 5, 'Scenario profit',
        base_profit + fee_savings + refund_savings + ad_realloc_profit FROM levers
)
SELECT
    line_item,
    ROUND(amount, 2) AS amount,
    ROUND(100.0 * amount / (SELECT amount FROM bridge WHERE step = 1), 2) AS pct_of_baseline
FROM bridge
ORDER BY step;


-- ---------------------------------------------------------------------
-- 5. SENSITIVITY GRID
-- Scenario profit for every combination of fee cut and return reduction.
-- Add more values to either list to widen the grid.
-- ---------------------------------------------------------------------
WITH base AS (
    SELECT SUM(profit) AS profit, SUM(platform_fee) AS platform_fees, SUM(refund_amount) AS refunds
    FROM orders
),
fee_cases AS (
    SELECT 0.00 AS fee_cut UNION ALL SELECT 0.05 UNION ALL SELECT 0.10 UNION ALL SELECT 0.20
),
return_cases AS (
    SELECT 0.00 AS return_cut UNION ALL SELECT 0.10 UNION ALL SELECT 0.20 UNION ALL SELECT 0.30
)
SELECT
    ROUND(100 * f.fee_cut, 0)    AS platform_fee_cut_pct,
    ROUND(100 * r.return_cut, 0) AS return_reduction_pct,
    ROUND(b.profit + b.platform_fees * f.fee_cut + b.refunds * r.return_cut, 2) AS scenario_profit,
    ROUND(100.0 * (b.platform_fees * f.fee_cut + b.refunds * r.return_cut) / b.profit, 2) AS uplift_pct
FROM base b
CROSS JOIN fee_cases f
CROSS JOIN return_cases r
ORDER BY f.fee_cut, r.return_cut;
