-- SQL Project #1: Vehicle Sales Analysis: SQL Data Cleaning and Manipulation
-- By Tanner Earsley
-- Created 6/9/2025
-- 
-- In this project, I will be joining two separate sales tables, combing for duplicate/null values, removing unnecessary columns, and changing data types to prepare for analysis
-- Then I will perform analysis upon the resultant table
-- Queries will outline top buyers, locations with greatest product sales, and compare sales figures against averages and previous dates

-- >>> I begin with a inner join of the customer and info tables, creating one full table for staging and further manipulation
CREATE TABLE sales_project.sales_staging
(SELECT *
FROM sales_project.sales_customer AS salesc
JOIN sales_project.sales_info AS salesi
ON salesc.order_number = salesi.order_num);

-- >>> To begin cleaning, I search for duplicates
SELECT order_number, quantity, price_per, order_line_num, sales, COUNT(*)
FROM sales_project.sales_staging
GROUP BY order_number, quantity, price_per, order_line_num, sales
HAVING COUNT(*) > 1;

-- >>> Now we remove the two affected pairs.
DELETE FROM sales_project.sales_staging
WHERE order_number IN (
    SELECT order_number FROM (
        SELECT order_number,
               ROW_NUMBER() OVER (PARTITION BY order_number ORDER BY order_number) AS dupe_count
        FROM sales_project.sales_staging) AS dupe_temp
    WHERE dupe_count > 1
);


-- >>> Now we standardize the remaining data. The order_date column is a text data type, but could be date instead
UPDATE sales_project.sales_staging
SET order_date = STR_TO_DATE(order_date, '%m/%d/%Y');

ALTER TABLE sales_project.sales_staging
MODIFY order_date DATE;

-- >>> Let's search for null values
SELECT *
FROM  sales_project.sales_staging
WHERE quantity IS NULL OR price_per IS NULL OR address2 IS NULL OR zip_code IS NULL OR state IS NULL
OR quantity = '' OR price_per = '' OR address2  = ''  OR zip_code  = '' OR state = ''
;

-- >>> In this example, I've decided that address-related info (zip, address, state) can be valuable as null values, but quantity and price are not valuable without a value.
-- As such, lets update the address columns to NULL values, and remove the quantity/price columns
UPDATE sales_staging
SET
  address2 = NULLIF(address2, ''),
  zip_code = NULLIF(zip_code, ''),
  state = NULLIF(state, '');
  
-- >>> Now that we know which rows have critical null values, we will remove each row containing them
DELETE FROM sales_project.sales_staging
WHERE quantity IS NULL OR price_per IS NULL;

-- >>> For some final changes, let's change status to order_status, and drop unnecessary tables
ALTER TABLE sales_staging
RENAME COLUMN `status` TO order_status,
DROP COLUMN order_num,
DROP COLUMN quarter_id,
DROP COLUMN month_id,
DROP COLUMN year_id
;

-- >>> We may now view our completed table
SELECT *
FROM sales_staging;

-- >>> Now, let's solve some hypothetical problems by running various queries

-- >>> 1: Which product type (product_name) yielded the highest sales over all time?
-- Let's see which product types are sold
SELECT DISTINCT product_name
FROM sales_staging;
--  We can now rank these products by total sales $ earned
SELECT product_name, ROUND(SUM(sales),2) AS sales_sum, 
RANK () OVER(ORDER BY SUM(sales) DESC) AS sales_ranked
FROM sales_staging
GROUP BY product_name;
-- Classic Cars are our winners, and Trains don't appear to raise as many dollars in sales
-- This dataset does not include a cost of goods sold, so we can cannot perform a similar query for net profit

-- >>> 2: Say management wants to downsize and downscope. What are our worst 2 peforming countries? They will be under consideration for being cut
SELECT country, ROUND(SUM(sales),2) AS total_sales, 
RANK () OVER(ORDER BY SUM(sales) ASC) AS low_performance_rating
FROM sales_staging
GROUP BY country
LIMIT 2;
-- Hopefully they still have horses in Ireland

-- >>> 3: Next, let's compare monthly sales to the monthly average in 2003, finding the difference in each month's sales
WITH average_table as (
	SELECT MONTH(order_date) as month_orders, (SUM(sales)) as total_sales
	FROM sales_staging
    WHERE YEAR(order_date) = 2003
	GROUP BY MONTH(order_date)
)
SELECT month_orders,
  ROUND(total_sales, 2) AS total_sales,
  ROUND((SELECT AVG(total_sales) FROM average_table), 2) AS average_monthly_sales,
  ROUND(total_sales - (SELECT AVG(total_sales) FROM average_table),2) AS sales_variance
FROM average_table
ORDER BY month_orders asc;
--  November was easily the top performance month

-- >>> 4: Which customers are buying above MSRP? If unit price > MSRP, that customer must really want that product
SELECT cust_name, product_name, 
ROUND((price_per - msrp),2) AS seller_net
FROM sales_staging
WHERE (price_per - msrp) > 0
ORDER BY seller_net DESC;
-- Scrolling through this list, we see Vintage and Classic Cars are being purchased well above MSRP
-- But now, who's purchasing above MSRP the most often?
SELECT cust_name,
SUM(CASE WHEN (price_per - msrp) > 0 THEN 1 ELSE 0 END) AS purchased_above
FROM sales_staging
GROUP BY cust_name
ORDER BY purchased_above DESC;
-- Euro Shopping Channel is really desperate for our products, and a good customer to hold on to
-- *Willingness to pay above the MSRP can be interpretted as good or bad, with context.alter

-- >>> 5: What cities account for our top 5 quantity of motorcycle sales?
SELECT city,
count(quantity) as motorcycle_quantity
FROM sales_staging
GROUP BY city
ORDER BY motorcycle_quantity DESC;
-- We have most-successfully penetrated the motorcycle market in Madrid

-- >>> 6: Which products saw a sales increase of over $100,000 from 2003 to 2004
WITH sales0304 AS (
SELECT 
product_name,
SUM(CASE WHEN YEAR(order_date) = 2003 THEN sales ELSE 0 END) AS sales_2003,
SUM(CASE WHEN YEAR(order_date) = 2004 THEN sales ELSE 0 END) AS sales_2004
FROM sales_staging
GROUP BY product_name)
SELECT product_name, 
ROUND(sales_2003,2) AS sales_2003, 
ROUND(sales_2004,2) AS sales_2004,
ROUND(sales_2004 - sales_2003,2) AS sales_increase
FROM sales0304
HAVING sales_increase > 100000
ORDER BY sales_increase DESC;
  -- 5 of 7 products made the cut
  
  
  -- >>> 7: Last One. Who are the top 5 most loyal customers?
SELECT cust_name,
COUNT(DISTINCT order_number) AS order_instances,
ROUND(SUM(sales), 2) AS total_sales,
RANK() OVER (ORDER BY COUNT(DISTINCT order_number) DESC) AS loyalty_rank
FROM sales_staging
GROUP BY cust_name
ORDER BY order_instances DESC
LIMIT 5;
  -- This can help us focus our retention strategy on these 5 companies. 
  -- Interesting to note that Euro Shopping Channel purchased not only the most often over MSRP, but had the most instances of purchase as well!
  
  -- >>> Thank you if you read through this whole thing! This is my first SQL project. I hope it did not disappoint!
