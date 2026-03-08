MERGE INTO users u USING staging s ON u.id = s.id WHEN MATCHED THEN UPDATE SET name = s.name;
SELECT * FROM sales QUALIFY ROW_NUMBER() OVER (PARTITION BY region ORDER BY amount DESC) = 1;
SELECT * FROM monthly_sales PIVOT (SUM(amount) FOR month IN ('JAN', 'FEB'));
SELECT * FROM monthly_sales UNPIVOT (amount FOR month IN (jan_amount, feb_amount));
SELECT * FROM events MATCH_RECOGNIZE (PARTITION BY user_id ORDER BY ts PATTERN (A B+));
