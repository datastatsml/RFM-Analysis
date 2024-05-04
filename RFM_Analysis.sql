-- RFM ANALYSIS (https://www.youtube.com/watch?v=O2hlHzehZb0)

-- Creating a database
CREATE DATABASE portfolio_project;

-- log into the database
USE portfolio_projects;

-- importing the csv file
SELECT * FROM sales_data;



-- EXPLORATORY DATA ANALYSIS

-- Checking all the unique values in relevant columns
SELECT DISTINCT status 
FROM sales_data; 
-- there are 6 different status. this could be used to plot a bar chart

SELECT DISTINCT year_id
FROM sales_data; 
-- data for three years is present - 2003, 2004, 2005

SELECT DISTINCT productline
FROM sales_data; 
-- 7 products are present

SELECT DISTINCT country
FROM sales_data; 
-- data for 19 countries is present

SELECT DISTINCT dealsize
FROM sales_data; 
-- three different deal size are present - Small, Medium and Large

SELECT DISTINCT territory
FROM sales_data; 
-- 4 regions present - NA, EMEA, APAC and Japan

------------------------------------------------------------------------------------------------------------------------------------------

-- Breakdown the sales by product line
SELECT productline, ROUND(SUM(sales),2) AS revenue
FROM sales_data
GROUP BY productline
ORDER BY 2 DESC;
-- Insight: Classic cars, vintage cars and Motorcycles are the top 3 product lines

-- Breakdown sales by year
SELECT year_id, ROUND(SUM(sales),2) AS revenue
FROM sales_data
GROUP BY year_id
ORDER BY 2 DESC;
-- Insight: sales peaked in 2004 and suddenly declined in 2005? what might be the reason for this decline?

-- what happened in 2005?
SELECT DISTINCT(month_id)
FROM sales_data
where year_id = 2005
ORDER BY 1;
-- Insight: The reason for decline in sales is because the company only operated for first 5 months 

-- Breakdown sales by dealsize
SELECT dealsize, ROUND(SUM(sales),2) AS revenue
FROM sales_data
GROUP BY dealsize
ORDER BY 2 DESC;
-- Insight: Medium size deals generate disproportionately large sales compared to small and large deal sizes.

-- what was the best month for sales in a specific year? how much was earned that month?
SELECT 
	year_id, 
	month_id, 
    SUM(sales) AS revenue,
    COUNT(ordernumber) AS frequency,
    RANK() OVER(PARTITION BY year_id ORDER BY SUM(sales) DESC) AS sales_rank,
    RANK() OVER(PARTITION BY year_id ORDER BY COUNT(ordernumber) DESC) AS frequency_rank
FROM sales_data
GROUP BY year_id, month_id;
-- Insight: November has the highest sales in 2003 and 2004.

-- why does november has the highest sales? what productline was sold the most in the month of november?

SELECT 
	productline, 
    SUM(quantityordered) AS total_sales,
    SUM(sales) AS total_revenue
FROM sales_data
GROUP BY productline
ORDER BY 2 DESC;
-- Insight: Classic cars has the highest sales. Hence it is possible that Classic cars were sold the highest in the month of nov

SELECT 
	year_id, 
	month_id,
    productline,
    total_sales,
    total_revenue
FROM
	(SELECT 
		year_id,
		month_id,
		productline,
		SUM(quantityordered) as total_sales,
		SUM(sales) as total_revenue,
		RANK() OVER(PARTITION BY year_id ORDER BY SUM(quantityordered) DESC) as top_rank
	FROM sales_data
	GROUP BY year_id, month_id, productline) AS table_1
WHERE top_rank =1;
-- Insight: Classic cars were sold the highest in the month of november because of which the total reveue increased exponentially
-- in the month of november.


-- Who is the best customer? 
-- this could be answered using RFM analysis.

-- What is RFM analysis?
/* It stands for Recency, Frequency and Monetary value
   It is an indexing technique that uses past purchase behaviour to segment customers.
   An RFM report is a way of segmenting the customers using three key metrics:
		1. Recency (how long ago their last purchase was)
        2. Frequency (how often they purchase)
        3. Monetary value (How much did they spent) */

SELECT *
FROM sales_data;

-- creating a duplicate column for orderdat to experiment with changing data type
ALTER TABLE sales_data
ADD new_orderdate TEXT;

UPDATE sales_data
SET new_orderdate = orderdate;


-- This query gives you Recency, Frequency and Monetary values of each customer.
SELECT
	customername,
    ROUND(SUM(sales),2) AS monetary_value,
    ROUND(AVG(sales),2) AS avg_monetary_value,
    COUNT(ordernumber) AS frequency,
    MAX(str_to_date(orderdate, '%m/%d/%Y')) AS latest_order_date,
    (SELECT max(str_to_date(orderdate, '%m/%d/%Y')) FROM sales_data) AS max_order_date,
    DATEDIFF((SELECT max(str_to_date(orderdate, '%m/%d/%Y')) FROM sales_data), MAX(str_to_date(orderdate, '%m/%d/%Y'))) AS Recency
FROM sales_data
GROUP BY customername;


-- Once you have the RFM values, we need to segmemet the cutomers based on RFM values - Customer segmentation

WITH rfm AS
	(SELECT
		customername,
		ROUND(SUM(sales),2) AS monetary_value,
		ROUND(AVG(sales),2) AS avg_monetary_value,
		COUNT(ordernumber) AS frequency,
		MAX(str_to_date(orderdate, '%m/%d/%Y')) AS latest_order_date,
		(SELECT max(str_to_date(orderdate, '%m/%d/%Y')) FROM sales_data) AS max_order_date,
		DATEDIFF((SELECT max(str_to_date(orderdate, '%m/%d/%Y')) FROM sales_data), MAX(str_to_date(orderdate, '%m/%d/%Y'))) AS Recency
	FROM sales_data	
	GROUP BY customername
    ),
rfm_calc AS
(
	SELECT *,
		NTILE(4) OVER(ORDER BY Recency DESC) AS rfm_recency,
		NTILE(4) OVER(ORDER BY frequency) AS rfm_frequency,
		NTILE(4) OVER(ORDER BY monetary_value) AS rfm_monetary
	FROM rfm
)
SELECT *,
	(rfm_recency + rfm_frequency + rfm_monetary) AS rfm_cell,
    CONCAT(CAST(rfm_recency AS CHAR), CAST(rfm_frequency AS CHAR), CAST(rfm_monetary AS CHAR)) AS rfm_cell_string
FROM rfm_calc; 


-- using the above query and then segmenting the customers using a case statement
SELECT 
	customername, rfm_recency, rfm_frequency, rfm_monetary,
    CASE
		WHEN rfm_cell_string IN (111,112,121,122,123,132,211,212,114,141) THEN 'lost customers'
        WHEN rfm_cell_string IN (133,134,143,144,244,334,343,344) THEN 'slipping away-cannot lose'
        WHEN rfm_cell_string IN (311,411,331) THEN 'new customer'
        WHEN rfm_cell_string IN (222,223,233,322) THEN 'potential churner'
        WHEN rfm_cell_string IN (323,333,321,422,332,432) THEN 'active customer'
        WHEN rfm_cell_string IN (433,434,443,444) THEN 'loyal'
    END AS rfm_segment
FROM
(

WITH rfm AS
	(SELECT
		customername,
		ROUND(SUM(sales),2) AS monetary_value,
		ROUND(AVG(sales),2) AS avg_monetary_value,
		COUNT(ordernumber) AS frequency,
		MAX(str_to_date(orderdate, '%m/%d/%Y')) AS latest_order_date,
		(SELECT max(str_to_date(orderdate, '%m/%d/%Y')) FROM sales_data) AS max_order_date,
		DATEDIFF((SELECT max(str_to_date(orderdate, '%m/%d/%Y')) FROM sales_data), 
					MAX(str_to_date(orderdate, '%m/%d/%Y'))) AS Recency
	FROM sales_data	
	GROUP BY customername
    ),
rfm_calc AS
(
	SELECT *,
		NTILE(4) OVER(ORDER BY Recency DESC) AS rfm_recency,
		NTILE(4) OVER(ORDER BY frequency) AS rfm_frequency,
		NTILE(4) OVER(ORDER BY monetary_value) AS rfm_monetary
	FROM rfm
)
SELECT *,
	(rfm_recency + rfm_frequency + rfm_monetary) AS rfm_cell,
    CONCAT(CAST(rfm_recency AS CHAR), CAST(rfm_frequency AS CHAR), CAST(rfm_monetary AS CHAR)) AS rfm_cell_string
FROM rfm_calc

) AS rmf_temp_table;