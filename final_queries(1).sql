--I. Overall Business 
--1. When are the peak & lowest selling months in a 2023?  

SELECT 
	TO_CHAR(sale_date, 'MM') AS month,
	sum(total_amount) as total_amount
FROM Sales
WHERE EXTRACT(YEAR FROM sale_date) = 2023
GROUP BY TO_CHAR(sale_date, 'MM')
ORDER BY total_amount DESC;

--2. Which customer loyalty level generate the most revenue?
SELECT 
	CASE
        WHEN points >= 1000 THEN 'Platinum'
        WHEN points >= 500 THEN 'Gold'
        WHEN points >= 200 THEN 'Silver'
        ELSE 'Bronze'
    END AS loyalty,
	sum (quantity_sold*unit_price) as revenue
FROM (
	SELECT   
		a.customer_id,
		a.card_id,
		a.points,
		b.sale_id
	FROM customer_loyalty a 
	LEFT JOIN Sales b 
	ON a.customer_id=b. customer_id
)aa
LEFT JOIN products_sold bb 
ON aa.sale_id =bb.sale_id
GROUP BY loyalty
ORDER BY revenue DESC;

--3. Rank stores by sales
SELECT
    s.store_id,
    s.store_name,
    SUM(sa.total_amount) AS total_sales,
    RANK() OVER (ORDER BY SUM(sa.total_amount) DESC) AS rank
FROM
    Stores s
JOIN
    Sales sa ON s.store_id = sa.store_id
GROUP BY
    s.store_id, s.store_name
ORDER BY
    rank;

--II. Each store insights
--4. What are the 5 least selling products in each store? 
WITH ranked_sales AS (
	SELECT 
		store_id,
		product_id,
		quantity_sold,
		row_number()over(partition by store_id order by quantity_sold) AS ranking 
	FROM (
		SELECT 
				a.store_id, 
				b.product_id,
				sum(b.quantity_sold) as quantity_sold
		FROM sales a 
		LEFT JOIN products_sold b 
		ON a.sale_id=b.sale_id
		GROUP BY a.store_id, b.product_id
		)x 
)
SELECT
store_name, 
product_name,
quantity_sold
FROM ranked_sales rs
LEFT JOIN products p ON rs.product_id = p.product_id
LEFT JOIN stores s ON rs.store_id = s.store_id
WHERE ranking <=5 
;


-- 5. Top 5 products in terms of sales from each store by month:
WITH ranked_products_sold_store_month AS (
       SELECT st.store_id, st.store_name, p.product_id, p.product_name, 
       TO_CHAR(DATE_TRUNC('month', sa.sale_date), 'Month YYYY') AS sale_month,
       SUM(ps.quantity_sold) AS total_sold,
       RANK() OVER(PARTITION BY st.store_id, DATE_TRUNC('month', sa.sale_date) ORDER BY SUM(ps.quantity_sold) DESC) as rank
       FROM sales sa
       JOIN products_sold ps ON sa.sale_id = ps.sale_id
       JOIN products p ON ps.product_id = p.product_id
       JOIN stores st ON sa.store_id = st.store_id
       GROUP BY st.store_id, st.store_name, p.product_id, p.product_name, DATE_TRUNC('month', sa.sale_date)
)
SELECT * FROM ranked_products_sold_store_month WHERE rank <= 5

--III. Products
--6. Which products have had the most significant price changes?
WITH ranked_price_change AS (
       SELECT ph.product_id, p.product_name, MAX(ph.unit_price) - MIN(ph.unit_price) AS price_change,
       RANK() OVER(ORDER BY ABS(MAX(ph.unit_price) - MIN(ph.unit_price)) DESC) AS rank
       FROM product_history ph
       JOIN products p ON ph.product_id = p.product_id
       GROUP BY ph.product_id, p.product_name
)
SELECT * FROM ranked_price_change WHERE rank <= 7;

--7. Which product sold the most?
SELECT 
    p.product_name, 
    ps.unit_price, 
    SUM(ps.quantity_sold) as total_quantity_sold
FROM 
    Products_Sold ps
INNER JOIN 
    Products p ON p.product_id = ps.product_id
GROUP BY 
    p.product_name, ps.unit_price
ORDER BY 
    total_quantity_sold DESC
LIMIT 1;

--8. What are the 10 best-selling products along with their total quantities sold
SELECT p.product_id, p.product_name, SUM(ps.quantity_sold) AS total_quantity_sold
FROM Products p
JOIN Products_Sold ps ON p.product_id = ps.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_quantity_sold DESC
LIMIT 10;

--9.At which price which product is sold the most?
WITH Product_Sales AS (
    SELECT
        p.product_id,
        p.product_name,
        ps.unit_price AS unit_price,
        RANK() OVER(PARTITION BY p.product_id ORDER BY COUNT(*) DESC) AS rank
    FROM
        Products p
    JOIN
        Products_Sold ps ON p.product_id = ps.product_id
    GROUP BY
        p.product_id, p.product_name, ps.unit_price
)
SELECT
    product_id,
    product_name,
    unit_price
FROM
    Product_Sales
WHERE
    rank = 1;


--IV. Vendors and deliveries
--10 Top Vendors based on the number of orders placed
SELECT v.vendor_name, COUNT(*) AS order_count
FROM vendors v
JOIN deliveries d ON v.vendor_id = d.vendor_id
GROUP BY v.vendor_name
ORDER BY order_count DESC;

--11 Top Vendors based on the number of products delivered
SELECT v.vendor_name, SUM(pd.quantity) AS deliveries_count
FROM vendors v
JOIN products p ON v.vendor_id = p.vendor_id
JOIN products_in_deliveries pd ON p.product_id = pd.product_id
GROUP BY v.vendor_name
ORDER BY deliveries_count DESC;

--12 Vendors that supply the most popular products (in terms of quantity sold in stores):
WITH ranked_vendors_product_sold AS (
  SELECT v.vendor_id, v.vendor_name, p.product_id, p.product_name, SUM(ps.quantity_sold) AS total_sold,
    RANK() OVER(ORDER BY SUM(ps.quantity_sold) DESC) as "rank"
  FROM Vendors v
  JOIN Products p ON v.vendor_id = p.vendor_id
  JOIN Products_Sold ps ON p.product_id = ps.product_id
  GROUP BY v.vendor_id, v.vendor_name, p.product_id, p.product_name
)
SELECT * FROM ranked_vendors_product_sold WHERE "rank" <= 5;

--13 By month: Vendors that supply the most popular products (in terms of quantity sold in stores):
WITH ranked_vendors_product_sold AS (
  SELECT 
    v.vendor_id, 
    v.vendor_name, 
    p.product_id, 
    p.product_name, 
    TO_CHAR(DATE_TRUNC('month', s.sale_date), 'Month YYYY') AS sale_month,
    SUM(ps.quantity_sold) AS total_sold,
    RANK() OVER(PARTITION BY DATE_TRUNC('month', s.sale_date) ORDER BY SUM(ps.quantity_sold) DESC) as rank
  FROM 
    Vendors v
  JOIN 
    Products p ON v.vendor_id = p.vendor_id
  JOIN 
    Products_Sold ps ON p.product_id = ps.product_id
  JOIN 
    Sales s ON ps.sale_id = s.sale_id
  GROUP BY 
    v.vendor_id, v.vendor_name, p.product_id, p.product_name, DATE_TRUNC('month', s.sale_date)
)
SELECT * FROM ranked_vendors_product_sold WHERE rank <= 5;

--14 which delivery company deliver the most?
SELECT dc.company_name
FROM Delivery_Company dc
WHERE dc.company_id = (
  SELECT d.company_id
  FROM Deliveries d
  GROUP BY d.company_id
  ORDER BY COUNT(*) DESC
  LIMIT 1
);

--V. Employees
--15. What is the average performance rating of employees in each department?
SELECT department_id, AVG(performance_rating) AS avg_performance_rating
FROM Staff
GROUP BY department_id
ORDER BY avg_performance_rating DESC;

--16. Rank stores by the highest to lowest staff rating for people in the "Sales" department

SELECT
    st.store_id,
    s.store_name,
    AVG(st.performance_rating) AS avg_rating,
    RANK() OVER(ORDER BY AVG(st.performance_rating) DESC) AS rank
FROM
    stores s
JOIN
    staff st ON s.store_id = st.store_id
JOIN
    departments d ON st.department_id = d.department_id
WHERE
    d.dept_name = 'Sales'
GROUP BY
    st.store_id, s.store_name
ORDER BY
    rank;



-----------------------------------
-- Other queries for visualization:
-- Proportion of sales amount based on category
WITH total_sales AS (
    SELECT SUM(ps.quantity_sold * ps.unit_price) AS total_sales_amount
    FROM products_sold ps
    JOIN products p ON ps.product_id = p.product_id
),
category_sales AS (
    SELECT p.product_category, SUM(ps.quantity_sold * ps.unit_price) AS category_sales_amount
    FROM products_sold ps
    JOIN products p ON ps.product_id = p.product_id
    GROUP BY p.product_category
)
SELECT cs.product_category, cs.category_sales_amount, 
       (cs.category_sales_amount / ts.total_sales_amount) * 100 AS percentage_of_total_sales
FROM category_sales cs, total_sales ts;



-- Proportion of sales quantity based on category
WITH total_quantity_sold AS (
    SELECT SUM(ps.quantity_sold) AS total_quantity_sold
    FROM products_sold ps
    JOIN products p ON ps.product_id = p.product_id
),
category_quantity_sold AS (
    SELECT p.product_category, SUM(ps.quantity_sold) AS category_quantity_sold
    FROM products_sold ps
    JOIN products p ON ps.product_id = p.product_id
    GROUP BY p.product_category
)
SELECT cqs.product_category, cqs.category_quantity_sold, 
       (cqs.category_quantity_sold::decimal / tqs.total_quantity_sold) * 100 AS percentage_of_total_quantity_sold
FROM category_quantity_sold cqs, total_quantity_sold tqs;

-- the average price for the selected product(s) during each month and the total number of units sold in the same period
WITH Monthly_Average_Price AS (
  SELECT 
    ph.product_id,
    TO_CHAR(ph.effective_date, 'Month YYYY') AS price_month,
    AVG(ph.unit_price) AS avg_price
  FROM product_history ph
  GROUP BY ph.product_id, price_month
)

SELECT 
  st.store_name,
  p.product_name,
  TO_CHAR(s.sale_date, 'Month YYYY') AS sale_month,
  COALESCE(map.avg_price, AVG(ps.unit_price)) AS avg_price_per_month,
  AVG(ps.unit_price) AS avg_price,
  SUM(ps.quantity_sold) AS total_sold
FROM sales s
JOIN products_sold ps ON s.sale_id = ps.sale_id
JOIN products p ON ps.product_id = p.product_id
JOIN stores st ON s.store_id = st.store_id
LEFT JOIN Monthly_Average_Price map ON map.product_id = p.product_id AND map.price_month = TO_CHAR(s.sale_date, 'Month YYYY')
GROUP BY st.store_name, p.product_name, map.avg_price, TO_CHAR(s.sale_date, 'Month YYYY')
ORDER BY st.store_name, TO_DATE(TO_CHAR(s.sale_date, 'Month YYYY'), 'Month YYYY');

-- the trend of revenue for different products over the months for each store
WITH total_revenue_product_month_store AS (
  SELECT
    st.store_name,
    p.product_name,
    TO_CHAR(sa.sale_date, 'YYYY-MM') AS sale_month,
    SUM(sa.total_amount) AS total_revenue
  FROM
    sales sa
  JOIN
    products_Sold ps ON sa.sale_id = ps.sale_id
  JOIN
    products p ON ps.product_id = p.product_id
  JOIN
    stores st ON sa.store_id = st.store_id
  GROUP BY
    st.store_name, p.product_name, sale_month
)
SELECT 
  store_name,
  product_name, 
  sale_month, 
  total_revenue
FROM 
  total_revenue_product_month_store
ORDER BY
  sale_month ASC, total_revenue DESC;

--  Top 5 delivery companies by quantity of products delivered each month
WITH monthly_deliveries AS (
    SELECT 
        d.company_id, 
        dc.company_name, 
        TO_CHAR(d.delivery_date), 'Month YYYY') as delivery_month, 
        SUM(pid.quantity) as total_quantity
    FROM deliveries d
    JOIN delivery_company dc ON d.company_id = dc.company_id
    JOIN products_in_deliveries pid ON d.order_id = pid.order_id
    GROUP BY d.company_id, dc.company_name, delivery_month
),
ranked_deliveries AS (
    SELECT 
        delivery_month,
        company_id, 
        company_name, 
        total_quantity, 
        RANK() OVER (PARTITION BY delivery_month ORDER BY total_quantity DESC) AS delivery_rank
    FROM monthly_deliveries
)
SELECT *
FROM ranked_deliveries
WHERE delivery_rank <= 5;


