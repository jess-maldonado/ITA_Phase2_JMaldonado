
--16. We'd like to get more details on when products (that were supposed to be unavailable) were ordered.
-- Create a new column that shows whether the product was ordered before the sell start date, or after the sell end date.
-- Sort the results by ProductID and OrderDate.

select
p.ProductID
, sh.OrderDate
, d.OrderQty as Qty
, p.SellStartDate
, p.SellEndDate
, if(datediff(OrderDate, SellStartDate)<0, 'Sold before start date','Sold after end date') as ProblemType
from Product p
join SalesOrderDetail d on p.ProductID = d.ProductID
join SalesOrderHeader sh on sh.SalesOrderID = d.SalesOrderID
where sh.OrderDate < p.SellStartDate or sh.OrderDate > p.SellEndDate
ORDER BY d.ProductID, sh.OrderDate

-- 17. OrderDate with time component
-- How many OrderDate values in SalesOrderHeader have a time component to them? Show the results as below.

select
count(if(EXTRACT(HOUR_MINUTE from OrderDate)>0,SalesOrderID,null)) as TotalOrderWithTime
  , count(SalesOrderID) as TotalOrders
, count(if(EXTRACT(HOUR_MINUTE from OrderDate)>0,SalesOrderID,null))*1.0 / count(SalesOrderID) as PercentOrdersWithTime

from SalesOrderHeader

-- 18. Fix this SQL! Number 1
-- We want to show details about certain products (name, subcategory, first order date, last order date), similar to what we did in a previous query.
-- This time, we only want to show the data for products that have Silver in the color field. Because you’ve looked at the Color field of the Product table directly, you know that there are many products with that color.
-- A colleague sent you this query, and asked you to look at it. It seems correct, but it returns no rows.
-- What's wrong with it?
Select
    Product.ProductID
    ,ProductName
    ,ProductSubCategoryName
    ,Date(Min(OrderDate)) as FirstOrder
    ,Date(Max(OrderDate)) as LastOrder
From Product
    Left Join SalesOrderDetail  Detail
        on Product.ProductID = Detail.ProductID
    Left Join SalesOrderHeader  Header
        on Header.SalesOrderID = Detail .SalesOrderID
    Left Join ProductSubCategory
 21
on ProductSubCategory .ProductSubCategoryID = Product.ProductSubCategoryID
Where
    'Color' = 'Silver'
Group by
    Product.ProductID
    ,ProductName
    ,ProductSubCategoryName
Order by LastOrder desc;

-- ANSWER

-- You don't use quotes around any field names. Also, you're only capturing products where silver is the only color. If you want to capture all products with a silver color, including where there are other colors, you need to use wildcards.



-- 19. Raw margin quartile for products
-- The product manager would like to show information for all products about the raw margin – that is, the price minus the cost. Create a query that will show this information, as well as the raw margin quartile.
-- For this problem, the quartile should be 1 if the raw margin of the product is in the top 25%, 2 if the product is in the second 25%, etc.
-- Sort the rows by the product name.

select
ProductID
, ProductName
, StandardCost
, ListPrice
, ListPrice - StandardCost as RawMargin
, ntile(4) over (order by ListPrice-StandardCost desc) as Quartile

FROM Product
WHERE StandardCost > 0 and ListPrice > 0
Order by ProductName

-- 20. Customers with purchases from multiple sales people
-- Show all the customers that have made purchases from multiple sales people. Sort the results by the customer name (first name plus last name).


select
c.CustomerID
, concat(c.FirstName," ",c.LastName) as CustomerName
, count(distinct sh.SalesPersonEmployeeID) as TotalDifferentSalesPeople

from SalesOrderHeader sh
left join Customer c on c.CustomerID = sh.CustomerID

group by c.CustomerID, concat(c.FirstName," ",c.LastName)
having (count(distinct sh.SalesPersonEmployeeID)) > 1
order by CustomerName

-- 21. Fix this SQL! Number 2
-- A colleague has sent you the following SQL, which causes an error:
-- Select
--     Customer.CustomerID
--     ,FirstName + ' ' + LastName as CustomerName
--     ,OrderDate
--     ,SalesOrderHeader.SalesOrderID
-- ,SalesOrderDetail.ProductID
--     ,Product.ProductName
--     ,LineTotal
-- From  SalesOrderHeader
--     Join Product
--         on Product.ProductID = SalesOrderDetail .ProductID
--     Join SalesOrderDetail
--         on SalesOrderHeader .SalesOrderID = SalesOrderDetail .SalesOrderID
--     Join Customer
--         on Customer.CustomerID = SalesOrderHeader.CustomerID
-- Order by
-- CustomerID
--     ,OrderDate
-- Limit 100;
-- The error it gives is this:
-- Error Code: 1054. Unknown column 'SalesOrderDetail.ProductID' in 'on clause'
-- Fix the SQL so it returns the correct results without error.

Select
    Customer.CustomerID
    ,FirstName + ' ' + LastName as CustomerName
    ,OrderDate
    ,SalesOrderHeader.SalesOrderID
,SalesOrderDetail.ProductID
    ,Product.ProductName
    ,LineTotal
From  SalesOrderHeader
    Join SalesOrderDetail
        on SalesOrderHeader.SalesOrderID = SalesOrderDetail.SalesOrderID
  Join Product
        on Product.ProductID = SalesOrderDetail.ProductID
    Join Customer
        on Customer.CustomerID = SalesOrderHeader.CustomerID
Order by
CustomerID
    ,OrderDate
Limit 100;


-- 22. Duplicate product
-- It looks like the Product table may have duplicate records. Find the names of the products that have duplicate records (based on having the same ProductName).

SELECT
ProductName
from  Product
group by ProductName
having count(ProductName) > 1

-- 23. Duplicate product: details
-- We'd like to get some details on the duplicate product issue. For each product that has duplicates, show the product name and the specific ProductID that we believe to be the duplicate (the one that's not the first ProductID for the product name).

SELECT
max(ProductID) as PotentialDuplicateProductId
,ProductName
from  Product
group by ProductName
having count(ProductName) > 1


