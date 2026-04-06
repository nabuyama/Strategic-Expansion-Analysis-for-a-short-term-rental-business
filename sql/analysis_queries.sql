/*
BUSINESS QUESTIONS
A: Demand/market validation:
    Is our current occupancy rate enough to justify a second unit?

B: Revenue drivers:
    How does revenue vary by:
        •	Platform
        •	Client groups (repeat vs new). Do we have a reliable customer base to support scaling?
        •	Booking durations (short vs long)


C: Operational efficiency: Is the current unit operating efficiently, 
 are there inefficiencies that scaling would amplify?
    What is the expense-to-revenue ratio per month?
	
D: Risk/stress test: Could we survive a worst case scenario?
    What is the lowest revenue month?
    In that month, does revenue cover average monthly expenses?


E: Performance-profitability/growth:
    What is our Year-to-Date (YTD) profit trend?"
    Is the current cash flow enough to reinvest in the second unit?
    What’s the breakeven occupancy; how many days a month should a unit be occupied to cover the average expenses, how is this rate varying per month, if we are just surviving, scaling is risky

*/

--ANALYSES

-- ============================================================
-- A. DEMAND / MARKET VALIDATION
--    Is our occupancy rate high enough to justify a second unit?
-- ============================================================
/*
  Logic: Sum booked days per month, divide by total days in that
  calendar month, multiply by 100 to get an occupancy percentage.
  A consistently high rate signals unmet demand — i.e., we may be
  turning away guests a second unit could capture.
*/

SELECT 
    year,
    month,
    SUM(booking_duration) AS no_of_booked_days, -- Total number of booked days in each month

    --Getting total number of days in each month
    EXTRACT(DAY FROM (
        DATE_TRUNC('month', MAKE_DATE(year, month, 1)) 
        + INTERVAL '1 month - 1 day'
    )) AS days_in_month,
    
    --Occupancy rate as a percentage: ( total booked days ÷ total days in month) × 100
    ROUND(
        (SUM(booking_duration) * 100.0) /
        EXTRACT(DAY FROM (
            DATE_TRUNC('month', MAKE_DATE(year, month, 1)) 
            + INTERVAL '1 month - 1 day'
        )),
        1
    ) AS occupancy_rate

FROM 
    revenue

GROUP BY year,month -- results grouped by each month/year

ORDER BY year,month; -- results ordered by each month/year for chronological order

/*
  ── RESULTS ──────────────────────────────────────────────────
  Apr 2025:  23.3%  ← partial month (operations started mid-April)
  May 2025:  90.3%
  Jun 2025:  63.3%
  Jul 2025:  74.2%
  Aug 2025:  87.1%
  Sep 2025:  83.3%
  Oct 2025:  71.0%
  Nov 2025:  90.0%
  Dec 2025:  83.9%
  Jan 2026:  54.8%
  Feb 2026: 100.0%
  ─────────────────────────────────────────────────────────────

NB: 
we started operations mid april so I'll remove the apr results from consideration

INSIGHT:
-Kampala’s short-term rental market shows an average occupancy of 
approximately 49% over the last 12months(according to a popular short term rental analytics platform AirDNA), 
indicating structurally underutilized supply conditions.
-In contrast, the subject property achieves 80% occupancy, 
significantly outperforming the market baseline and 
positioning it within a high-efficiency segment of the distribution.
-This suggests that demand is not uniformly distributed across listings, 
with stronger properties capturing a disproportionate share of bookings.
-Expansion decisions in this context are therefore less dependent on market demand constraints and 
more dependent on the ability to replicate existing operational performance at scale.
*/


-- ============================================================
-- B1. REVENUE DRIVERS — BY PLATFORM
-- ============================================================
    SELECT 
        platform,
        SUM(amount_ugx) AS total_revenue,
        ROUND(
            SUM(amount_ugx) * 100.0 / SUM(SUM(amount_ugx)) OVER (),
            1
        ) AS revenue_percetnage
    FROM 
        revenue
    GROUP BY platform
    ORDER BY total_revenue DESC; 

/*
  ── RESULTS ──────────────────────────────────────────────────
  Airbnb                  14,200,270 UGX   49.3%
  ? (unidentified)         8,963,300 UGX   31.1%
  NULL (booking extensions)2,321,000 UGX    8.1%
  House mgr/askari ref.    1,190,000 UGX    4.1%
  Booking.com              1,150,000 UGX    4.0%
  TikTok                     620,000 UGX    2.2%
  Colleague referral         360,000 UGX    1.2%
  ─────────────────────────────────────────────────────────────

INSIGHT:
-- Revenue is highly concentrated, indicating reliance on a small number of acquisition channels.
-- A meaningful share of income comes from extended stays(Seen as NULLS, 
I hadnt added a channel to bookings resulting from extensions off the book/airbnb), 
suggesting strong customer retention associated with the parent booking.
-- However, a significant portion of revenue is unattributed (seen as '??')due to missing platform data, 
limiting the accuracy of channel-level performance insights.
*/

-- ============================================================
-- B2. REVENUE DRIVERS — BY CLIENT GROUP (REPEAT VS. NEW)
-- ============================================================
/*
  Logic: Assign each client_id a booking count. Clients with 1 booking
  are 'New'; clients with 2+ are 'Repeat'. Missing client_id records
  are isolated as a third group to surface the data quality gap.
*/

WITH client_data AS(
SELECT 
    COALESCE(client_id, 'missing_client_data') AS client,
    COUNT(DISTINCT visit_id) AS bookings_count,
    SUM(amount_ugx) AS total_revenue
FROM revenue
GROUP BY client
)
SELECT
    CASE 
        WHEN client = 'missing_client_data' THEN 'Missing_client_identification'
        WHEN bookings_count = 1 THEN 'New'
        ELSE 'Repeat'
    END AS client_group,

    COUNT(client) AS count_of_unique_clients,

    SUM(bookings_count) AS total_bookings_by_group,
    SUM(total_revenue) AS total_revenue_by_group,
    ROUND(
            SUM(total_revenue) * 100.0 / SUM(SUM(total_revenue)) OVER (),
            1
        ) AS revenue_percetnage

FROM 
    client_data

GROUP BY 1;

/*
  ── RESULTS ──────────────────────────────────────────────────
  Missing Client ID   16 bookings    5,550,000 UGX   19.3%
  New (40 clients)    38 bookings   11,085,875 UGX   38.5%
  Repeat (10 clients) 30 bookings   12,168,695 UGX   42.2%
  ─────────────────────────────────────────────────────────────

INSIGHT:
-Revenue is driven by high-value loyalty; just 10 repeat customers (30 bookings) 
generate 42.2% of total revenue, 
outperforming the 40 individual new customers (38.5%). 
-The 'Repeat' segment represents the business's most stable financial backbone, 
with a single repeat customer roughly 3x more valuable than a new one in revenue
-However, 19.3% of the revenue comes from un identifiable clients due to insufficient 
client identifying information. 
This data gap limits the ability to accurately track the full Lifetime Value of clients, 
and may hide additional repeat behavior.

-N.B: The  number of unique clients in the missing client group has 
was counted as one due to the grouping logic, it has 16 unique visits/bookings. 
*/

-- ============================================================
-- B3. REVENUE DRIVERS — BY BOOKING DURATION
-- ============================================================

--checking for distribution of booking durations to determine the appropriate cutoff for short vs long stays
SELECT
    MIN(booking_duration) AS min_booking_duration,
    MAX(booking_duration) AS max_booking_duration,
    AVG(booking_duration) AS avg_booking_duration
FROM revenue;

/*── RESULTS ──────────────────────────────────────────────────

"min_booking_duration": 1,
"max_booking_duration": 28,
"avg_booking_duration": 2.8953488372093023
*/


SELECT 
    CASE 
        WHEN booking_duration <= 3 THEN 'Short-term (<=3 days)' --Threshold for long vs short stays defined using average stay duration (3 days).
        ELSE 'Long-term (>3 days)'
    END AS booking_type,
    COUNT(visit_id) AS total_bookings,
    SUM(amount_ugx) AS total_revenue,
    ROUND(
            SUM(amount_ugx) * 100.0 / SUM(SUM(amount_ugx)) OVER (),
            1
        ) AS revenue_percetnage    
FROM 
    revenue 
GROUP BY booking_type;

/*
  ── RESULTS ──────────────────────────────────────────────────
  Long-term (>3 days)    18 bookings   18,103,710 UGX   62.9%
  Short-term (≤3 days)   68 bookings   10,700,860 UGX   37.1%
  ─────────────────────────────────────────────────────────────

INSIGHT:
-Revenue is heavily dominated by longer stays (>3 days), which contribute 62.9% 
   of total income despite representing only 21% of total booking volume.
-'Short-term' stays (<=3 days) drive the highest operational turnover with 68 individual 
   bookings, yet generate significantly lower proportional revenue (37.1%).
-This indicates that the business strategy should prioritize long-term guest 
   acquisition to maximize profit margins and reduce the high overhead costs 
   associated with frequent guest changeovers and cleaning cycles.
*/




-- ============================================================
-- C. OPERATIONAL EFFICIENCY
--    Expense-to-revenue ratio and profitability per month
-- ============================================================
	
WITH monthly_expenses AS (
    SELECT 
        EXTRACT(YEAR FROM expense_date) AS exp_year,
        EXTRACT(MONTH FROM expense_date) AS exp_month,
        SUM(amount_ugx) +1500000 AS total_expenses -- Sum variable costs, then add the 1.5M fixed rent
    FROM expenses
    GROUP BY 1, 2
)
SELECT 
    r.year,
    r.month,
    SUM(r.amount_ugx) AS total_revenue,
    MAX(e.total_expenses) AS total_expenses,
    
    -- Calculation: Expense-to-Revenue Ratio
    ROUND(
        (MAX(e.total_expenses) * 100.0) / NULLIF(SUM(r.amount_ugx), 0), 
        1
    ) AS expense_to_revenue_ratio,

    -- Profit Calculation
    --SUM(r.amount_ugx) - MAX(e.total_expenses) AS net_profit,

    --total bookings_per_month
    COUNT(r.visit_id) AS total_bookings,

    --Average booking duration per month
    -- NEW: Average Booking Duration (Days)
    ROUND(AVG(booking_duration ), 1) AS avg_stay_duration
FROM 
    revenue r
LEFT JOIN 
    monthly_expenses e ON r.year = e.exp_year AND r.month = e.exp_month
WHERE 
    -- Logic: Exclude startup months with prepaid rent (Apr, May, Jun 2025)
    NOT (r.year = 2025 AND r.month IN (4, 5, 6,7))
GROUP BY 
    r.year, r.month
ORDER BY 
    r.year, r.month;

/*
  ── RESULTS ──────────────────────────────────────────────────
  Month       Revenue      Expenses   Ratio   Bookings  Avg Stay
  Aug 2025   3,353,000    1,898,000   56.6%     10       2.7 days
  Sep 2025   2,710,000    2,014,500   74.3%      5       5.0 days
  Oct 2025   2,346,000    1,936,100   82.5%     10       2.2 days
  Nov 2025   3,394,000    1,845,000   54.4%      8       3.4 days
  Dec 2025   3,408,000    1,825,000   53.6%      6       4.3 days
  Jan 2026   1,939,700    1,837,500   94.7%      8       2.1 days
  Feb 2026   3,161,300    1,751,500   55.4%      1      28.0 days
  ─────────────────────────────────────────────────────────────


-This conclusion excludes April–Jul 2025, as we begun operations in mid april and had paid rent 3 months ahead
-1,500,000 UGX is the fixed monthly rent

INSIGHT:
-EXPENSE-TO-REVENUE RATIO: The unit operates at an average efficiency of ~67%. 
   Ratios fluctuate between a highly efficient 53.6% (Dec 2025) and a 
   near-break-even 94.7% (Jan 2026), driven largely by stay duration.

-THE "ACTIVITY VS. PROFIT" PARADOX: January 2026 recorded "reasonable activity" 
   (8 bookings), yet yielded the weakest profitability (94.7% ratio). This 
   highlights that booking volume alone does not guarantee efficiency; 
   short stays (2.1-day avg) fail to dilute fixed rent and variable turnover costs.

-The primary inefficiency is "Turnover Friction." 
   Scaling this model would "amplify" the variable costs.
   If the business scales by increasing total bookings rather 
   than stay duration, the operational workload (and variable costs) 
   will grow faster than the net profit, leading to "Burnout scaling."

-- EFFICIENCY VERDICT: The unit is efficient only when stay duration exceeds 
   3.5 days. Scaling should prioritize "Anchor Guests" (Long-Stays) 
   to maintain margins above the 50% threshold.
*/



-- ============================================================
-- D. RISK / STRESS TEST
--    Can the business survive its worst-case month?
-- ============================================================

/*
  Lowest full-operation revenue month: January 2026 — 1,939,700 UGX
  Total expenses that month: 1,837,500 UGX (variable + 1.5M rent)
  Net profit: 102,200 UGX
  Breakeven at 130,000 UGX/night: 14.4 days required
  Actual days occupied in January: ~17 days

  ── INSIGHT ──────────────────────────────────────────────────
  The unit survived its worst month, but only just. With a net
  profit of 102,200 UGX on 1,939,700 UGX revenue, the January
  stress test produced a 94.7% expense ratio — 2.6 booked days
  away from a net loss.

  The business is self-sustaining at its floor, which confirms a
  low-risk operating model for a single unit. But the stress test
  also reveals that the safety margin is thin. A second unit running
  simultaneously through a slow month — particularly in its early
  operation — would require a cash reserve to absorb the overlap.
  The current model survives a bad month on one unit; it may not
  survive a bad month on two without a liquidity buffer.
*/



-- ============================================================
-- E1. PERFORMANCE & GROWTH — YTD PROFIT TREND
-- ============================================================

WITH monthly_expenses AS (
    SELECT 
        EXTRACT(YEAR FROM expense_date) AS exp_year,
        EXTRACT(MONTH FROM expense_date) AS exp_month,
        SUM(amount_ugx) +1500000 AS total_expenses -- Sum variable costs, then add the 1.5M fixed rent
    FROM expenses
    GROUP BY 1, 2
)
SELECT 
    r.year,
    r.month,
    SUM(r.amount_ugx) AS total_revenue,
    MAX(e.total_expenses) AS total_expenses,
    
    -- Calculation: Expense-to-Revenue Ratio
    ROUND(
        (MAX(e.total_expenses) * 100.0) / NULLIF(SUM(r.amount_ugx), 0), 
        1
    ) AS expense_to_revenue_ratio,

    -- Profit Calculation
    SUM(r.amount_ugx) - MAX(e.total_expenses) AS net_profit

FROM 
    revenue r
LEFT JOIN 
    monthly_expenses e ON r.year = e.exp_year AND r.month = e.exp_month
WHERE 
    -- Logic: Exclude startup months with prepaid rent (Apr, May, Jun 2025)
    NOT (r.year = 2025 AND r.month IN (4, 5, 6,7))
GROUP BY 
    r.year, r.month
ORDER BY 
    r.year, r.month;
/*
  ── RESULTS ──────────────────────────────────────────────────
  Month       Revenue      Expenses    Ratio    Net Profit
  Aug 2025   3,353,000    1,898,000   56.6%    1,455,000
  Sep 2025   2,710,000    2,014,500   74.3%      695,500
  Oct 2025   2,346,000    1,936,100   82.5%      409,900
  Nov 2025   3,394,000    1,845,000   54.4%    1,549,000
  Dec 2025   3,408,000    1,825,000   53.6%    1,583,000
  Jan 2026   1,939,700    1,837,500   94.7%      102,200
  Feb 2026   3,161,300    1,751,500   55.4%    1,409,800
  ─────────────────────────────────────────────────────────────

INSIGHT:
  The profit trend is highly volatile — not because the business is
  weak, but because the 1,500,000 UGX fixed rent acts as a floor
  cost that dominates low-revenue months.

  When stay duration is healthy (Nov–Dec, Feb), profit sits between
  1.4M and 1.6M UGX. When short stays dominate (Oct, Jan), the same
  rent consumes nearly all revenue and profit collapses — most
  dramatically in January, where a 93% drop from December's peak
  (1,583,000 → 102,200 UGX) was caused entirely by booking pattern,
  not by a drop in demand.

  This volatility is manageable for a single unit with low overheads.
  At two units, a synchronised slow month doubles the fixed exposure
  to 3,000,000 UGX before a single booking is made.
*/

-- ============================================================
-- E2. CASH FLOW SUFFICIENCY FOR REINVESTMENT
-- ============================================================
/*
  Unit 1 initial capital:  ~12,588,100 UGX
  Average monthly net profit (Aug 2025 – Feb 2026): ~1,029,000 UGX
  Months to save reinvestment capital at current rate: ~13 months

  INSIGHT:
  At the current average profit of ~1M UGX/month, saving the
  ~12.6M UGX required to replicate Unit 1's setup would take
  approximately 13 months of uninterrupted operation.

  This is achievable — but only under the assumption of zero cash
  shocks and consistent performance. January 2026 demonstrates that
  a single short-stay-heavy month can reduce the month's contribution
  to ~100K UGX, extending the timeline considerably.

  Scaling via external debt is the faster path but introduces a
  monthly debt service obligation on top of the existing rent anchor.
  Unless average stay duration is improved first (target: ≥4.5 days),
  the cash flow is not yet resilient enough to comfortably service debt
  during a slow month.
*/


-- ============================================================
-- E3. BREAKEVEN OCCUPANCY
--    How many days per month must be booked to cover all costs?
-- ============================================================
/*
  Standard daily rate:     130,000 UGX
  Average monthly expenses:  1,870,000 UGX (variable + 1,500,000 rent)
  Breakeven days:           1,870,000 ÷ 130,000 = 14.4 days/month

  INSIGHT
  The breakeven threshold is 14.4 occupied days per month.
  Every full month of available data shows occupancy above this
  floor — even January 2026 (~17 days) cleared it, but by only
  2.6 days.

  This margin is too thin for comfort at scale. If Unit 2 launches
  and spends its early months near the 14–15 day range (likely, as
  a new listing builds its Airbnb ranking), it would operate near
  breakeven while Unit 1 carries the combined overhead.

  The strategic verdict: the business is viable, but not yet
  scaled-ready. Increasing average stay duration to ≥4.5 days
  would raise the profit buffer per month, reduce operational
  friction, and create the cash reserve needed to absorb a slow
  month across two units simultaneously.
*/

