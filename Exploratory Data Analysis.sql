
-- Exploratory Data Analysis

-- CATEGORY PROFITABILITY
--Lets see which categories are the most profitable and which are dragging the portfolio down.
 
WITH category_profitability AS (
    SELECT
        primary_category,
        SUM(gross_revenue) AS total_revenue,
        SUM(total_costs) AS total_costs,
        SUM(profit) AS total_profit,
        ROUND(100.0 * SUM(profit) / SUM(net_revenue), 2) AS profit_margin
        -- kept numeric (no '%' concatenation) so it stays sortable via ORDER BY
    FROM orders
    GROUP BY primary_category
)
 
-- Let's the best and worst performer side by side, like a "before/after"
SELECT *
FROM category_profitability
ORDER BY profit_margin DESC
LIMIT 1
 
UNION ALL
 
SELECT *
FROM category_profitability
ORDER BY profit_margin ASC
LIMIT 1;
 

 
-- CHANNEL ANALYSIS

--This section builds channel-level fee rates first, applies them, then compares AOV, average profit, and return rate side by side. This determines how the proftability differs across sales channels (Website, Mobile App, Marketplace, Social Commerce).
 
WITH orders_with_pf_rate AS (
    SELECT
        *,
        gross_revenue AS total_revenue,
        ROUND(
            SUM(platform_fee) OVER (PARTITION BY channel)
            / SUM(gross_revenue) OVER (PARTITION BY channel), 2
        ) AS platform_fee_rate
    FROM orders
),
 
orders_with_platform_fees AS (
    SELECT
        *,
        profit - CASE
            WHEN channel = 'Marketplace' THEN total_revenue * platform_fee_rate
            WHEN channel = 'Social Commerce' THEN total_revenue * platform_fee_rate
            ELSE 0
        END AS profit_after_fees
    FROM orders_with_pf_rate
)
 
SELECT
    channel,
    ROUND(SUM(total_revenue) / COUNT(DISTINCT order_id), 2) AS average_order_value,
    ROUND(AVG(profit_after_fees), 2) AS average_profit,
    ROUND(
        1.0 * SUM(CASE WHEN returned = 'Yes' THEN 1 ELSE 0 END)
        / COUNT(DISTINCT order_id), 2
    ) AS return_rate -- the 1.0 forces float division so this doesn't silently floor to 0
FROM orders_with_platform_fees
GROUP BY channel;
 
 

-- MARKETING ROI

--Lets analyze the  marketing spend. Let's see which advertising platform delivers the best ROAS (Return on Ad Spend).
 
WITH roi AS (
    SELECT
        platform,
        AVG(roas) AS return_on_ad_spend,
        AVG(cpa) AS cost_per_acquisition,
        AVG(cpc) AS cost_per_click,
        AVG(roas) - 1 AS return_on_investment
    FROM marketing_spend
    GROUP BY platform
)
 
SELECT
    platform,
    return_on_ad_spend,
    cost_per_acquisition,
    cost_per_click,
    return_on_investment,
    CASE
        WHEN return_on_investment < 0 THEN 'Underperforming'
        WHEN return_on_investment = 0 THEN 'Breaks Even'
        ELSE 'Profitable'
    END AS marketing_spend_performance
FROM roi
ORDER BY return_on_investment ASC;
 
 