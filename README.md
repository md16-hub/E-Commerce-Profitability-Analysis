# E-Commerce-Profitability-Analysis
In this notebook, we will analyze BrightCart’s e-commerce profitability across product categories, sales channels, returns, and marketing platforms to identify key drivers of profit and declining margins.

**Summary of Findings
**Category: Electronics is the strongest category, highest profit and best margin (31.1%). Books is the weakest at 11.9% margin, a cost/pricing issue rather than a demand issue.
Channel: Marketplace is unprofitable per order after platform fees. Social Commerce is close behind, dragged down by a 7.4% fee and the highest return rate of any channel (9.1%).
Returns: Returns cost roughly 7.4% of gross revenue over the period.
Marketing: Every platform technically returns more than it costs, but Email Marketing is far less efficient (5.4x ROAS, $26 CPA) than top performers like TikTok Ads (24.4x ROAS, $4 CPA).
Recommendations
Renegotiate the Marketplace fee structure, or cap acquisition spend into that channel until the economics improve.
Investigate Books and Beauty at the unit-cost level rather than the demand level.
Reallocate underperforming marketing spend toward higher-ROAS platforms instead of cutting a flat percentage across the board.
Track return rate alongside revenue and profit in standard reporting, not just when margins raise questions.
**Tech Stack
**
SQL (PostgreSQL syntax) for the analysis, with data quality validation run upfront on all three source tables.
