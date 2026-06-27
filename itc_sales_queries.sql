
--  ITC DISTRIBUTOR SALES ANALYSIS
--  Table: sales
--  Columns: month, year, month_num, sku, mrp, salesman,
--           qty_sold, revenue_inr

-- 1. OVERVIEW — Total revenue, qty, months covered
    SELECT
        COUNT(DISTINCT month)                     AS total_months,
        COUNT(DISTINCT sku)                       AS unique_skus,
        COUNT(DISTINCT salesman)                  AS unique_salesmen,
        ROUND(SUM(qty_sold), 0)                   AS total_qty_sold,
        ROUND(SUM(revenue_inr), 0)                AS total_revenue_inr,
        ROUND(SUM(revenue_inr) / 10000000.0, 2)   AS total_revenue_crore
    FROM sales;


-- 2. MONTHLY REVENUE TREND
--    Shows growth/decline month over month
    SELECT
        month,
        year,
        month_num,
        ROUND(SUM(qty_sold), 0)             AS total_qty,
        ROUND(SUM(revenue_inr), 0)          AS total_revenue,
        ROUND(SUM(revenue_inr) / 100000.0, 2) AS revenue_lakhs
    FROM sales
    GROUP BY month, year, month_num
    ORDER BY year, month_num;


-- 3. MONTH-OVER-MONTH REVENUE GROWTH %
--    Identifies which months grew or declined

    WITH monthly AS (
        SELECT
            month,
            year,
            month_num,
            ROUND(SUM(revenue_inr), 0) AS revenue
        FROM sales
        GROUP BY month, year, month_num
    ),
    with_prev AS (
        SELECT
            month,
            year,
            month_num,
            revenue,
            LAG(revenue) OVER (ORDER BY year, month_num) AS prev_revenue
        FROM monthly
    )
    SELECT
        month,
        revenue,
        prev_revenue,
        ROUND(
            (revenue - prev_revenue) * 100.0 / prev_revenue, 1
        ) AS growth_pct
    FROM with_prev
    ORDER BY year, month_num;


-- 4. TOP 10 SKUs BY TOTAL REVENUE (All 7 months)
--    Core Pareto input
    SELECT
        sku,
        mrp,
        ROUND(SUM(qty_sold), 1)             AS total_qty,
        ROUND(SUM(revenue_inr), 0)          AS total_revenue,
        ROUND(SUM(revenue_inr) / 100000.0, 2) AS revenue_lakhs
    FROM sales
    GROUP BY sku, mrp
    ORDER BY total_revenue DESC
    LIMIT 10;


-- 5. PARETO ANALYSIS — 80/20 Rule on SKUs
--    Which SKUs contribute 80% of total revenue?
    WITH sku_revenue AS (
        SELECT
            sku,
            ROUND(SUM(revenue_inr), 0) AS revenue
        FROM 
        GROUP BY sku
    ),
    ranked AS (
        SELECT
            sku,
            revenue,
            SUM(revenue) OVER ()                                        AS grand_total,
            SUM(revenue) OVER (ORDER BY revenue DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING
                            AND CURRENT ROW)                         AS running_total
        FROM sku_revenue
    )
    SELECT
        sku,
        revenue,
        ROUND(revenue * 100.0 / grand_total, 1)       AS revenue_pct,
        ROUND(running_total * 100.0 / grand_total, 1) AS cumulative_pct,
        CASE
            WHEN running_total * 100.0 / grand_total <= 80 THEN 'Top 80%'
            ELSE 'Tail 20%'
        END AS pareto_bucket
    FROM ranked
    ORDER BY revenue DESC;



-- 6. SALESMAN PERFORMANCE — Total revenue & qty
--    Ranks all salesmen across 7 months

SELECT
    salesman,
    ROUND(SUM(qty_sold), 1)             AS total_qty,
    ROUND(SUM(revenue_inr), 0)          AS total_revenue,
    ROUND(SUM(revenue_inr) / 100000.0, 2) AS revenue_lakhs,
    COUNT(DISTINCT sku)                 AS skus_sold,
    COUNT(DISTINCT month)               AS months_active
FROM sales
GROUP BY salesman
ORDER BY total_revenue DESC;


-- 7. SALESMAN MONTHLY TREND
--    Track each salesman's performance over time

    SELECT
        salesman,
        month,
        year,
        month_num,
        ROUND(SUM(qty_sold), 1)    AS qty,
        ROUND(SUM(revenue_inr), 0) AS revenue
    FROM sales
    GROUP BY salesman, month, year, month_num
    ORDER BY salesman, year, month_num;


-- 8. SALESMAN RANK PER MONTH
--    Who was #1 each month?

    WITH monthly_sales AS (
        SELECT
            salesman,
            month,
            year,
            month_num,
            ROUND(SUM(revenue_inr), 0) AS revenue
        FROM sales
        GROUP BY salesman, month, year, month_num
    )
    SELECT
        month,
        salesman,
        revenue,
        RANK() OVER (
            PARTITION BY month
            ORDER BY revenue DESC
        ) AS rank_in_month
    FROM monthly_sales
    ORDER BY year, month_num, rank_in_month;


-- 9. TOP SALESMAN EACH MONTH (rank 1 only)

    WITH monthly_sales AS (
        SELECT
            salesman,
            month,
            year,
            month_num,
            ROUND(SUM(revenue_inr), 0) AS revenue
        FROM sales
        GROUP BY salesman, month, year, month_num
    ),
    ranked AS (
        SELECT *,
            RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS rnk
        FROM monthly_sales
    )
    SELECT month, salesman, revenue AS top_revenue
    FROM ranked
    WHERE rnk = 1
    ORDER BY year, month_num;


-- 10. SKU PERFORMANCE BY MONTH
--     Spot which products are growing or fading

    SELECT
        sku,
        month,
        month_num,
        year,
        ROUND(SUM(qty_sold), 1)    AS qty,
        ROUND(SUM(revenue_inr), 0) AS revenue
    FROM sales
    GROUP BY sku, month, month_num, year
    ORDER BY sku, year, month_num;


-- 11. TOP 5 SKUs PER SALESMAN
--     What does each salesman specialize in?

    WITH salesman_sku AS (
        SELECT
            salesman,
            sku,
            ROUND(SUM(revenue_inr), 0) AS revenue,
            RANK() OVER (
                PARTITION BY salesman
                ORDER BY SUM(revenue_inr) DESC
            ) AS rnk
        FROM sales
        GROUP BY salesman, sku
    )
    SELECT salesman, sku, revenue, rnk
    FROM salesman_sku
    WHERE rnk <= 5
    ORDER BY salesman, rnk;


-- 12. PREMIUM vs BUDGET SKU SPLIT
--     MRP > 200 = Premium pack, else Budget pack

    SELECT
        CASE WHEN mrp > 200 THEN 'Premium (MRP > 200)'
            ELSE 'Budget (MRP <= 200)'
        END AS segment,
        COUNT(DISTINCT sku)                        AS sku_count,
        ROUND(SUM(qty_sold), 0)                    AS total_qty,
        ROUND(SUM(revenue_inr), 0)                 AS total_revenue,
        ROUND(SUM(revenue_inr) * 100.0
            / SUM(SUM(revenue_inr)) OVER (), 1)  AS revenue_pct
    FROM sales
    GROUP BY segment
    ORDER BY total_revenue DESC;


-- 13. SALESMAN CONSISTENCY SCORE
--     Low revenue range = consistent performer
--     High revenue range = peaks and troughs

    WITH monthly AS (
        SELECT
            salesman,
            month,
            SUM(revenue_inr) AS monthly_rev
        FROM sales
        GROUP BY salesman, month
    )
    SELECT
        salesman,
        ROUND(AVG(monthly_rev), 0)               AS avg_monthly_revenue,
        ROUND(MIN(monthly_rev), 0)               AS min_month_revenue,
        ROUND(MAX(monthly_rev), 0)               AS max_month_revenue,
        ROUND(MAX(monthly_rev) - MIN(monthly_rev), 0) AS revenue_range
    FROM monthly
    GROUP BY salesman
    ORDER BY avg_monthly_revenue DESC;
