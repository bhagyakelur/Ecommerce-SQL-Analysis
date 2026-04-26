-- @conn ecommerce_new_db

--Understanding Data:

/*Checking tables of the ecommerce database*/
SELECT name FROM sqlite_master WHERE type='table';

/*Used to know datatypes of columns*/
--PRAGMA table_info(table_name);  

/*Checking the number of rows in tables.*/
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM payments;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM reviews;
SELECT COUNT(*) FROM sellers;
SELECT COUNT(*) FROM geolocation;
SELECT COUNT(*) FROM category_translation;

--Data cleaning:

/*Converts string to date format(if the format is in 
timestamp: yyyy-mm-dd hh:mm:ss format only), to test if the column is in proper date format. */
SELECT 
    order_purchase_timestamp,
    DATE(order_purchase_timestamp) AS order_date
FROM orders
LIMIT 5;

/*Fetches year, month of the order_purchase dates*/
SELECT 
    order_id,
    strftime('%Y', order_purchase_timestamp) AS year,
    strftime('%m', order_purchase_timestamp) AS month
FROM orders
LIMIT 5;

/*This query fetches number of customers in each city (highest to lowest). 
By the observations, sao paulo has the most number of customers and is highest demand region. */
SELECT customer_city, COUNT(customer_id) as noOfcustomers 
from customers
GROUP BY customer_city 
ORDER BY noOfcustomers DESC; 

/*Check NULL values*/
SELECT COUNT(*) 
FROM orders
WHERE order_delivered_customer_date IS NULL;

/*Checking duplicates*/
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

/*Invalid payments*/
/*There are 9 orders that are unpaid(payment_value = 0)*/
SELECT * FROM payments
WHERE payment_value <= 0;

/*Checking canceled orders*/
/*625 orders are canceled*/
SELECT order_status, count(*) FROM orders
GROUP BY order_status;

--Data fetching:

/*Revenue per city*/
/*Sao paulo has both highest number of customers and highest revenue.*/
SELECT c.customer_city, SUM(p.payment_value) as revenue
FROM customers c 
JOIN orders o ON c.customer_id = o.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_city
ORDER BY SUM(p.payment_value) DESC;

/*Orders per city*/
/*Sao paulo also has highest number of orders
indicating it is the area with high demand.*/
SELECT COUNT(DISTINCT ord.order_id) as noOfOrders, c.customer_city
FROM orders ord 
JOIN customers c 
ON ord.customer_id = c.customer_id
GROUP BY c.customer_city
ORDER BY noOfOrders DESC;

/*Total revenue per order*/
/*The highest revenue the company got from a order is 13664.08*/
SELECT SUM(p.payment_value), ord.order_id
FROM payments p 
JOIN orders ord 
ON p.order_id = ord.order_id
GROUP BY ord.order_id
ORDER BY SUM(p.payment_value) DESC;
--OR
SELECT SUM(payment_value), order_id
FROM payments 
GROUP BY order_id
ORDER BY SUM(payment_value) DESC;

/*Top product categories by items sold*/
/*The below query fetches the top product categories based on the no of items sold. 
Bed bath table is on the top with 11115 items sold.*/
SELECT COUNT(*) as No_of_orderItems, ct.product_category_name_english
FROM order_items oi 
JOIN products pr 
ON oi.product_id = pr.product_id
JOIN category_translation ct
ON pr.product_category_name = ct.product_category_name
GROUP BY ct.product_category_name_english
ORDER BY No_of_orderItems DESC;

/*Top product categories by revenue*/
/*The below query calculates the top product categories based on the amount of revenue collected. 
health_beauty products collect the highest revenue i.e. 1441283.824, it is also Top 2nd product category based on number of items sold.*/
WITH order_payment AS (
    SELECT order_id, SUM(payment_value) AS total_payment
    FROM payments
    GROUP BY order_id
),
order_total_price AS (
    SELECT order_id, SUM(price) AS total_order_price
    FROM order_items
    GROUP BY order_id
)
SELECT ct.product_category_name_english AS category,
SUM((oi.price / otp.total_order_price) * op.total_payment) 
AS revenue
FROM order_items oi
JOIN order_payment op ON oi.order_id = op.order_id
JOIN order_total_price otp ON oi.order_id = otp.order_id
JOIN products pr ON oi.product_id = pr.product_id
JOIN category_translation ct ON pr.product_category_name = ct.product_category_name
GROUP BY category
ORDER BY revenue DESC;

/*Top 5 customers by revenue*/
/*This query fetches the top 5 customers based on total revenue the company gets per each customer
The highest revenue per customer equals the highest revenue per order, 
indicating that a single high-value order contributed significantly.*/
SELECT sum(p.payment_value), c.customer_id
FROM payments p
JOIN orders o
ON p.order_id = o.order_id
JOIN customers c 
ON o.customer_id = c.customer_id
GROUP BY c.customer_id
ORDER BY sum(p.payment_value) DESC
LIMIT 5;

/*Average order value*/
/*This query calculates the average revenue collected per each order*/
SELECT AVG(order_value) AS AOV
FROM (
    SELECT SUM(payment_value) AS order_value, order_id
    FROM payments 
    GROUP BY order_id
);

/*Orders per month*/
/*This query fetches the number of orders per month and 
also calculates the increase/decrease in the number of orders, trends monthly.*/
SELECT monthly, noOforders,
noOforders - LAG(noOforders) OVER (ORDER BY monthly) as trends
FROM (
    SELECT COUNT(*) as noOforders, 
    STRFTIME('%Y-%m', order_purchase_timestamp) as monthly
    FROM orders
    GROUP BY monthly
); 

/*Customer that ordered more than once*/
SELECT c.customer_unique_id, count(o.order_id) as noOfOrders
FROM orders o
JOIN customers c 
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING noOfOrders > 1;

/*Delivery performance*/
/*The average delivery time is 12.55 days 
from purchase to delivery.*/ 
SELECT ROUND(AVG(JULIANDAY(order_delivered_customer_date) - JULIANDAY(order_purchase_timestamp)),2) 
AS avg_delivery_days 
FROM orders 
WHERE order_delivered_customer_date IS NOT NULL;

/*Minimum delivery time*/
/*The minimum delivery time is 12.8 hours i.e. 0.53 days. 
This is the fastest delivery time taken.*/
SELECT order_id, JULIANDAY(order_delivered_customer_date) - JULIANDAY(order_purchase_timestamp) AS min_delivery_period,
(JULIANDAY(order_delivered_customer_date) - JULIANDAY(order_purchase_timestamp)) * 24 AS min_delivery_hours
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
ORDER BY min_delivery_hours
LIMIT 1;

/*Maximum delivery time*/
/*The maximum delivery time is 209.63 days, 
this is an outlier as the avg delivery time is approximately 12 to 13 days*/
SELECT order_id, 
JULIANDAY(order_delivered_customer_date) - JULIANDAY(order_purchase_timestamp) AS max_delivery_days
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
ORDER BY max_delivery_days DESC
LIMIT 1;

/*Orders that are delivered and not delivered*/
SELECT 
    CASE
        WHEN order_status = 'delivered' THEN 'delivered'
        ELSE 'not_delivered'
    END AS delivery_status,
    COUNT(*) as total_orders
from orders
GROUP BY delivery_status;

/*Percentage of orders that are delivered and not delivered*/
SELECT delivery_status, total_orders, 
ROUND((total_orders*100.0)/SUM(total_orders) over (),2) AS percentDeliveryStatus
FROM (
    SELECT 
    CASE
        WHEN order_status = 'delivered' THEN 'delivered'
        ELSE 'not_delivered'
    END AS delivery_status,
    COUNT(*) as total_orders
from orders
GROUP BY delivery_status
);

/*Late deliveries*/
SELECT count(*) FROM
(
    SELECT order_id, 
    order_delivered_customer_date - order_estimated_delivery_date 
    as late_deliveries 
    FROM orders
    WHERE late_deliveries > 0
);

/*% of orders delivered late vs on time*/
SELECT delivered_time, total_delivered, ROUND(total_delivered*100.0/SUM(total_delivered) over (),2) AS late_del_percent, total_delivered FROM(
    SELECT 
        CASE 
            WHEN JULIANDAY(order_delivered_customer_date) > JULIANDAY(order_estimated_delivery_date) THEN 'late_deliveries'
            ELSE 'on_time'
        END AS delivered_time, count(*) as total_delivered
    FROM orders 
    WHERE order_status = 'delivered'
    GROUP BY delivered_time
);

/*Lifetime value of each customer*/
SELECT sum(p.payment_value) as revenue_per_customer, 
count(o.order_id) as ordersPercustomer, c.customer_unique_id from 
payments p 
join orders o 
on p.order_id = o.order_id 
join customers c 
on o.customer_id = c.customer_id 
group by customer_unique_id
ORDER BY revenue_per_customer DESC, 
ordersPercustomer DESC;

/*RFM Analysis*/
SELECT c.customer_unique_id, 
(MAX(o.order_purchase_timestamp) OVER ()) - MAX(DATE(o.order_purchase_timestamp)) as recency, 
count(DISTINCT o.order_id) as frequency,
sum(p.payment_value) as monetary
FROM orders o
JOIN customers c
ON c.customer_id = o.customer_id
join payments p
ON p.order_id = o.order_id
GROUP BY c.customer_unique_id
ORDER BY recency, 
frequency DESC, monetary DESC;

/*Seasonality trends*/
SELECT COUNT(*) as noOforders, 
STRFTIME('%m', order_purchase_timestamp) as monthly
FROM orders
GROUP BY monthly;

/*Top selling products*/
SELECT COUNT(oi.order_item_id) 
as no_of_order_items,  
ct.product_category_name_english 
FROM category_translation ct
JOIN products pr ON pr.product_category_name = ct.product_category_name
JOIN order_items oi ON oi.product_id = pr.product_id
GROUP BY ct.product_category_name_english  
ORDER BY no_of_order_items DESC;

/*Customer classification based on RFM*/
SELECT customer_unique_id, 
    CASE 
        WHEN recency = 0 AND frequency > 4 AND monetary > 850 
            THEN 'VIP'
        WHEN recency >= 1 AND frequency >= 5
            THEN 'Loyal'
        WHEN monetary > 2000 
            THEN 'Big Spender'
        WHEN recency >= 2 
            THEN 'At Risk'
        ELSE 'Low Value'
    END AS customer_category FROM (
        SELECT c.customer_unique_id, 
        (MAX(o.order_purchase_timestamp) OVER ()) - MAX(DATE(o.order_purchase_timestamp)) as recency, 
        count(DISTINCT o.order_id) as frequency,
        sum(p.payment_value) as monetary FROM orders o 
        JOIN customers c 
        ON c.customer_id = o.customer_id
        join payments p 
        ON p.order_id = o.order_id
        GROUP BY c.customer_unique_id
        ORDER BY recency, 
        frequency DESC, monetary DESC
);

/*Number of customers in each category*/
SELECT  
    CASE 
        WHEN recency = 0 AND frequency > 4 AND monetary > 850 
            THEN 'VIP'
        WHEN recency >= 1 AND frequency >= 5
            THEN 'Loyal'
        WHEN monetary > 2000 
            THEN 'Big Spender'
        WHEN recency >= 2 
            THEN 'At Risk'
        ELSE 'Low Value'
    END AS customer_category, count(*) as numOfCustomers FROM (
        SELECT c.customer_unique_id, 
        (MAX(o.order_purchase_timestamp) OVER ()) - MAX(DATE(o.order_purchase_timestamp)) as recency, 
        count(DISTINCT o.order_id) as frequency,
        sum(p.payment_value) as monetary FROM orders o 
        JOIN customers c 
        ON c.customer_id = o.customer_id
        join payments p 
        ON p.order_id = o.order_id
        GROUP BY c.customer_unique_id
    )
GROUP BY customer_category
ORDER BY numOfCustomers;
