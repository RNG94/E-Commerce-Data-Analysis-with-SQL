 ----- Analyze the data by finding the answers to the questions below:

 -- 1. Find the top 3 customers who have the maximum count of orders.
 

SELECT	top 3 Cust_ID, COUNT (Ord_ID) CNT_ORDERS
FROM e_commerce_data
GROUP BY Cust_ID
ORDER BY CNT_ORDERS DESC

  -- 2. Find the customer whose order took the maximum time to get shipping.


  SELECT TOP 1 Customer_Name, DaysTakenForShipping
  FROM e_commerce_data
  ORDER BY DaysTakenForShipping DESC


  -- 3. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

  
SELECT	COUNT(DISTINCT Cust_ID) January_cust
FROM	e_commerce_data
WHERE	YEAR (Order_Date) = 2011 AND MONTH(Order_Date) = 1


  WITH cte AS 
(
SELECT	DISTINCT Cust_ID
FROM	e_commerce_data
WHERE	YEAR (Order_Date) = 2011 AND MONTH(Order_Date) = 1
)
SELECT	MONTH(order_date) numb_of_month, COUNT (DISTINCT cte.Cust_ID) count_customer
FROM	e_commerce_data e, cte
WHERE	e.Cust_ID = cte.Cust_ID AND	YEAR (Order_Date) = 2011
GROUP BY MONTH(order_date)
ORDER BY 1

-- 4. Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.

WITH T1 AS (
SELECT	DISTINCT Cust_ID, MIN(Order_Date) OVER(PARTITION BY Cust_ID) First_order_date
FROM e_commerce_data
), T2 AS
(
SELECT	DISTINCT Cust_ID, Order_date, Ord_ID,
		DENSE_RANK() OVER(PARTITION BY Cust_ID ORDER BY order_date, Ord_ID) ord_date_number
FROM e_commerce_data
)
SELECT DISTINCT t1.Cust_ID, First_order_date, Order_Date, DATEDIFF(DAY, t1.First_order_date,t2.Order_Date) DATE_DIFF
FROM T1, T2
WHERE T1.Cust_ID = T2.Cust_ID AND T2.ord_date_number = 3
ORDER BY 1 

-- 5. Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of these products to the total number of products purchased by the customer.

;WITH T1 AS 
(
SELECT Cust_ID, 
	SUM(CASE WHEN Prod_ID = 'Prod_11' THEN Order_Quantity ELSE 0 END ) prod_11 ,
	SUM (CASE WHEN Prod_ID = 'Prod_14' THEN Order_Quantity ELSE 0 END ) prod_14
FROM e_commerce_data
GROUP BY Cust_ID
HAVING
	SUM(CASE WHEN Prod_ID = 'Prod_11' THEN Order_Quantity ELSE 0 END ) > 0
	AND
	SUM (CASE WHEN Prod_ID = 'Prod_14' THEN Order_Quantity ELSE 0 END ) > 0
), T2 AS (
SELECT Cust_ID, SUM (Order_Quantity) Total_prod
FROM	e_commerce_data
GROUP BY Cust_ID
)
SELECT T1.Cust_ID, CAST(1.0*prod_11/Total_prod AS numeric(18,2)) AS prod_11_rate, CAST(1.0*prod_14/Total_prod AS NUMERIC(18,2)) AS  prod_14_rate
FROM	T1, T2
WHERE	T1.Cust_ID = T2.Cust_ID


 ---- Customer Segmentation
-- 1. Create a “view” that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month
-- 2. Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning business)

CREATE VIEW order_month AS
SELECT Cust_ID, YEAR(Order_Date) year, MONTH(Order_Date) real_month_num,
    DENSE_RANK() OVER(ORDER BY YEAR(Order_Date), MONTH(Order_Date)) month_num
FROM e_commerce_data

-- 3. For each visit of customers, create the next month of the visit as a separate column.

CREATE VIEW next_month AS
SELECT DISTINCT *,
    LEAD(month_num) OVER(PARTITION BY Cust_ID ORDER BY month_num) next_month
FROM order_month

-- 4. Calculate the monthly time gap between two consecutive visits by each customer.

CREATE VIEW time_gaps AS 
SELECT *, month_num - LAG(month_num) OVER (PARTITION BY Cust_ID ORDER BY month_num) time_gap
FROM order_month

-- 5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.


;WITH T1 AS 
(
SELECT Cust_ID, AVG(time_gap) AVG_TIME_GAP
FROM time_gaps
GROUP BY Cust_ID
)
SELECT Cust_ID, 
		CASE WHEN AVG_TIME_GAP <= 2 THEN 'regular' 
			WHEN AVG_TIME_GAP >2 THEN 'irregular'
			ELSE 'churn' 
		END AS CUST_LABEL
FROM T1
order by 1

---- Month-Wise Retention Rate
-- 1. Find the number of customers retained month-wise. (You can use time gaps)

SELECT *
FROM time_gaps
WHERE time_gap = 1
ORDER BY Cust_ID

-- 2. Calculate the month-wise retention rate.

WITH t1 AS
(
	SELECT *, COUNT(Cust_ID) OVER(PARTITION BY year, month) total_cust_monthly
	FROM time_gaps
), t2 AS
(
    SELECT DISTINCT year, month, total_cust_monthly, COUNT(Cust_ID) OVER(PARTITION BY year, month) retained_cust_monthly
    FROM t1
    WHERE time_gap = 1
)
SELECT year, month, retained_cust_monthly, total_cust_monthly, CAST((1.0 * retained_cust_monthly/ total_cust_monthly) AS DECIMAL (18, 4)) retention_rate
FROM t2
ORDER BY year, month
