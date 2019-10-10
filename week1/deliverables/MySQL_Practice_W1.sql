-- 1. There's a table called ProductCostHistory which contains the history of the cost of the product. Using that table, get the total number of times the product cost has changed.
-- Sort the results by ProductID

SELECT
ProductID
, count(ProductID) as TotalPriceChanges

FROM ProductCostHistory

GROUP BY ProductID
ORDER BY ProductID;

-- 2. We want to see a list of all the customers that have made orders, and the total number of orders the customer has made.
-- Sort by the total number of orders, in descending order

SELECT
CustomerID
, count(distinct SalesOrderID) as TotalOrders
FROM SalesOrderHeader
GROUP BY CustomerID
ORDER BY TotalOrders desc;

-- 3. For each product that was ordered, show the first and last date that it was ordered.
-- Sort the results by ProductID.

SELECT
d.ProductID
, cast(min(h.OrderDate) as date) as FirstOrder
, cast(max(h.OrderDate) as date) as LastOrder

from SalesOrderDetail d
LEFT JOIN SalesOrderHeader h on h.SalesOrderID = d.SalesOrderID

GROUP BY d.ProductID
ORDER BY d.ProductID

-- 4. For each product that was ordered, show the first and last date that it was ordered. This time, include the name of the product in the output, to make it easier to understand.
-- Sort the results by ProductID.

SELECT
d.ProductID
, p.ProductName
, cast(min(h.OrderDate) as date) as FirstOrder
, cast(max(h.OrderDate) as date) as LastOrder

from SalesOrderDetail d
LEFT JOIN SalesOrderHeader h on h.SalesOrderID = d.SalesOrderID
LEFT JOIN Product p on p.ProductID = d.ProductID

GROUP BY d.ProductID
ORDER BY d.ProductID

-- 5. We'd like to get a list of the cost of products, as of a certain date, 2012-04-15. Use the ProductCostHistory to get the results.
-- Sort the output by ProductID.

SELECT
ProductID
, StandardCost

FROM ProductCostHistory
WHERE StartDate <= '2012-04-15' and EndDate >= '2012-04-15'
ORDER BY ProductID

-- 6. It turns out that the answer to the above problem has a problem. Change the date to 2014-04-15. What are your results?
-- If you use the SQL from the answer above, and just change the date, you won't get the results you want.
-- Fix the SQL so it gives the correct results with the new date. Note that when the EndDate is null, that means that price is applicable into the future.

SELECT
ProductID
, StandardCost

FROM ProductCostHistory
WHERE StartDate <= '2014-04-15' and (EndDate >= '2014-04-15' or EndDate is null)
ORDER BY ProductID

-- 7. Show the months from the ProductListPriceHistory table, and the total number of changes made in that month.

SELECT
extract(YEAR_MONTH from StartDate) as ProductListPriceMonth
, count(*) as TotalRows

FROM ProductListPriceHistory
GROUP BY extract(YEAR_MONth from StartDate)

-- 8. After reviewing the results of the previous query, it looks like price changes are made only in one month of the year.
-- We want a query that makes this pattern very clear. Show all months (within the range of StartDate values in ProductListPriceHistory). This includes the months during which no prices were changed.

SELECT
c.CalendarMonth
, count(if(p.StartDate = c.CalendarDate, p.StartDate,null)) as TotalChanges

FROM ProductListPriceHistory p
LEFT JOIN Calendar c on c.CalendarDate >= p.StartDate and (c.CalendarDate <= p.EndDate or p.EndDate is null)
WHERE c.CalendarDate < '2013-06-01'
GROUP BY c.CalendarMonth;

-- 9. What is the current list price of every product, using the ProductListPrice history? Order the results by ProductID

SELECT
ProductID
, ListPrice
FROM ProductListPriceHistory
WHERE EndDate is null

-- 10. Show a list of all products that do not have any entries in the list price history table. Sort the results by ProductID

SELECT ProductID, ProductName
FROM Product p
WHERE ProductID not in (SELECT ProductID from ProductListPriceHistory);

-- 11. In the earlier problem “Product cost on a specific date, part 2”, this answer was given:
-- Select
--     ProductID
--     ,StandardCost
-- From ProductCostHistory
-- Where
-- '2014-04-15' Between StartDate and IfNull(EndDate, Now()) Order By ProductID;
-- However, there are many ProductIDs that exist in the ProductCostHistory table that don’t show up in this list.
--  16
-- Show every ProductID in the ProductCostHistory table that does not appear when you run the above SQL.

SELECT p.ProductID
from ProductCostHistory p
left join (
Select
    ProductID
    ,StandardCost
From ProductCostHistory
Where
'2014-04-15' Between StartDate and IfNull(EndDate, Now())) p2 on p.ProductID = p2.ProductID
WHERE p2.ProductID is null
ORDER BY p.ProductID

-- 12. There should only be one current price for each product in the ProductListPriceHistory table, but unfortunately some products have multiple current records.
-- Find all these, and sort by ProductID

SELECT 
       ProductID
FROM
     ProductListPriceHistory
WHERE EndDate is null
GROUP BY ProductID
HAVING count(StartDate)>1
ORDER BY ProductID


-- 13. In the problem “Products with their first and last order date, including name", we looked only at product that have been ordered.
-- It turns out that there are many products that have never been ordered.
-- This time, show all the products, and the first and last order date. Include the product subcategory as well.
-- Sort by the ProductName field.

SELECT
p.ProductID
, p.ProductName
, cast(min(h.OrderDate) as date) as FirstOrder
, cast(max(h.OrderDate) as date) as LastOrder

from Product p
LEFT JOIN SalesOrderDetail d on p.ProductID = d.ProductID
LEFT JOIN SalesOrderHeader h on h.SalesOrderID = d.SalesOrderID

GROUP BY p.ProductID
ORDER BY p.ProductName

-- 14. It's astonishing how much work with SQL and data is in finding and resolving discrepancies in data. Some of the salespeople have told us that the current price in the price list history doesn't seem to match the actual list price in the Product table.
-- Find all these discrepancies. Sort the results by ProductID.


select
p.ProductID
, p.ProductName
, p.ListPrice as Prod_ListPrice
, pl.ListPrice as PriceHist_LatestListPRice
, p.ListPrice - pl.ListPrice as Diff
FROM Product p
join ProductListPriceHistory pl on pl.ProductID = p.ProductID and pl.EndDate is null
where pl.ListPrice != p.ListPrice

-- 15. It looks like some products were sold before or after they were supposed to be sold, based on the SellStartDate and SellEndDate in the Product table. Show a list of these orders, with details.
-- Sort the results by ProductID, then OrderDate.

select
p.ProductID
, sh.OrderDate
, p.ProductName
, d.OrderQty as Qty
, p.SellStartDate
, p.SellEndDate
from Product p
join SalesOrderDetail d on p.ProductID = d.ProductID
join SalesOrderHeader sh on sh.SalesOrderID = d.SalesOrderID
where sh.OrderDate < p.SellStartDate or sh.OrderDate > p.SellEndDate
ORDER BY d.ProductID, sh.OrderDate