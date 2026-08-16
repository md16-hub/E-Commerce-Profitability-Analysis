--Data Quality Validation
-- Check for orphaned records that violated the new NOT NULL constraintsSELECT o.product_id, COUNT(*) AS orphaned_order_count

--check for duplicate keys in every table
SELECT 
    month,
    platform,
    COUNT(*) AS duplicate_count
FROM marketing_spend
GROUP BY month, platform
HAVING COUNT(*) > 1;

SELECT 
    order_id,
    customer_id,
    COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id, customer_id
HAVING COUNT(*) > 1;

SELECT 
    product_id,
    COUNT(*) AS duplicate_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;


--confirm brief info(number of categories and channels provided)
-- should return 4 channels (Website, Mobile App, Marketplace, Social Commerce) and 8 product categories
SELECT COUNT(DISTINCT channel) AS num_of_channels 
FROM orders; 

SELECT COUNT(DISTINCT category) AS num_of_categories 
FROM products;




---verify date range as 2 years
SELECT
    MIN(order_date) AS earliest,
    MAX(order_date) AS latest,
    MAX(order_date) - MIN(order_date) AS days_span,
    ROUND((MAX(order_date) - MIN(order_date)) / 365.0, 2) AS years_span
FROM orders;


----check and verify total cost 
SELECT 
    order_id,
    total_costs,
    product_cost + shipping_cost + platform_fee + transaction_fee AS manual_calculation,
    CASE 
        WHEN product_cost + shipping_cost + platform_fee + transaction_fee = total_costs 
        THEN 'verified correctly' 
        ELSE 'verified incorrectly' 
    END AS verified_total_cost
FROM orders;


---verify the net revenue
SELECT 
    order_id,
    net_revenue,
    gross_revenue - discount_amount - refund_amount AS manual_calculation,
    CASE 
        WHEN gross_revenue - discount_amount - refund_amount = net_revenue 
        THEN 'verified correctly' 
        ELSE 'verified incorrectly' 
    END AS verified_net_revenue
FROM orders;


--verify the profit
SELECT
    order_id,
    profit,
    net_revenue - total_costs AS manual_calculation,
    CASE 
        WHEN net_revenue - total_costs = profit 
        THEN 'verified correctly' 
        ELSE 'verified incorrectly' 
    END AS verified_profit
FROM orders;


--check for impossible values
SELECT 
    order_id, 
    gross_revenue, 
    product_cost, 
    shipping_cost, 
    discount_pct, 
    items_ordered
FROM orders
WHERE gross_revenue <= 0
   OR product_cost < 0
   OR shipping_cost < 0
   OR discount_pct < 0 
   OR discount_pct > 100
   OR items_ordered <= 0;


--Check for consistency in returns and refunds
SELECT 
    order_id, 
    returned, 
    refund_amount
FROM orders
WHERE (returned = 'Yes' AND refund_amount = 0)
   OR (returned = 'No' AND refund_amount > 0);


---platform fee test the logic
SELECT 
    order_id, 
    channel, 
    platform_fee
FROM orders
WHERE (channel IN ('Website','Mobile App') AND platform_fee > 0)
   OR (channel IN ('Marketplace','Social Commerce') AND platform_fee = 0);


--Exploritory Data Analysis

--Calculate baseline summary statistics for financial and volume metrics
SELECT 
    MIN(gross_revenue),
    MAX(gross_revenue),
    AVG(gross_revenue),
    STDDEV(gross_revenue),
    MIN(profit),
    MAX(profit),
    AVG(profit),
    STDDEV(profit),
    MIN(discount_pct),
    MAX(discount_pct),
    AVG(discount_pct),
    MIN(items_ordered),
    MAX(items_ordered),
    AVG(items_ordered)
FROM orders;


--Cateogry profitability
