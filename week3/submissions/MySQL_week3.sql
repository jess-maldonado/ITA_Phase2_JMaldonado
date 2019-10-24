-- 24. How many cost changes do products generally have?
-- We've worked on many problems based on the ProductCostHistory table. We know that the cost for some products has changed more than for other products.
-- Write a query that shows how many cost changes that products have, in general.
-- For this query, you can ignore the fact that in ProductCostHistory, sometimes there's an additional record for a product where the cost didn't actually change.

with Products as (
  SELECT
  productID
  , count(ProductID) as Changed
  FROM ProductCostHistory
  group by ProductID
) SELECT
distinct p.Changed
, COUNT(DISTINCT p.ProductID) as TotalProducts
from Products p
group by p.Changed


-- 25. Size and base ProductNumber for products
-- The ProductNumber field in the Product table comes from the vendor of the product. The size is sometimes a part of this field.
-- We need to get the base ProductNumber (without the size), and then the size separately. Some products do not have a size. For those products, the base ProductNumber will be the same as the ProductNumber, and the size field will be null.
--  Limit the results to those ProductIDs that are greater than 533. Sort by ProductID.

select ProductID
, ProductNumber
, instr(ProductNumber,"-") as HyphenLocation
, substring_index(ProductNumber,"-",1) as BaseProductNumber
, if(instr(ProductNumber,"-")=0,Null,substr(ProductNumber, instr(ProductNumber,"-")+1)) as Size
FROM Product

WHERE ProductID > 533
ORDER BY ProductID

-- 26. Number of sizes for each base product number
-- Now we'd like to get all the base ProductNumbers, and the number of sizes that they have.
-- Use the output of the previous problem to get the results. However, do not use the filter from the previous problem (ProductIDs that are greater than 533). Instead of that filter, select only those products that are clothing (ProductCategory = 3).
-- Order by the base ProductNumber.

select
substring_index(ProductNumber, "-", 1)                                                        as BaseProductNumber
  , count(distinct(if(instr(ProductNumber, "-") = 0, Null,substr(ProductNumber, instr(ProductNumber, "-") + 1))    ))                                  as Size
FROM Product p
left join ProductSubCategory ps on ps.ProductSubcategoryID = p.ProductSubcategoryID
left join ProductCategory pc on pc.ProductCategoryID = ps.ProductCategoryID
WHERE pc.ProductCategoryID = 3
group by
substring_index(ProductNumber, "-", 1)
order by BaseProductNumber

-- 27. How many cost changes has each product really had?
-- A sharp-eyed analyst has pointed out that the total number of product cost changes (from the problem “Cost changes for each product” is not right. Why? Because sometimes, even when there's a new record in the ProductCostHistory table, the cost is not actually different from the previous record!
-- This eventually will require a fix to the database, to make sure that we do not allow a record like this to be entered. This could be done as a table constraint, or a change to the code used to insert the row.
-- However, for now, let's just get an accurate count of cost changes per product, where the cost has actually changed. Also include the initial row for a product, even if there's only 1 record.
-- Sort the output by ProductID.

select
ProductID
, COUNT(DISTINCT StandardCost) as TotalCostChanges

FROM ProductCostHistory pch
group by ProductID
order by ProductID


-- 28. Which products had the largest increase in cost?
-- We'd like to show which products have had the largest, one-time increases in cost. Show all of the price increases (and decreases), in decreasing order of difference.
-- Don't show any records for which there is no price difference. For instance, if a product only has 1 record in the cost history table, you would not show it in the output, because there has been no change in the cost history.
-- Order by the price difference, and then the ProductID.


select
ProductID
,StartDate as CostChangeDate
, StandardCost
, lag(StandardCost,1) over (partition by ProductID order by ProductID, StartDate) as PreviousStandardCost
, lag(StandardCost,1) over (partition by ProductID order by ProductID, StartDate) - StandardCost as PriceDifference

FROM ProductCostHistory pch
order by PriceDifference desc, ProductID



-- 29. Fix this SQL! Number 3
-- There's been some problems with fraudulent transactions. The data science team has requested, for a machine learning job, a unusual set of records. It should include data for 11 CustomerIDs that are specifically identified as fraudulent. It should also include a set of 100 random customers. The set of 100 random customers must exclude the 11 customers suspected of fraud.
-- The SQL below solves the problem. However, there's a problem with it, which is that the list of bad customers is repeated twice.
-- Having hard-coded numbers or lists of numbers in SQL is not a good idea in general. But duplicating them is even worse, because of the potential that they will get out of sync.
-- Rewrite this SQL to not repeat the hard-coded list of CustomerIDs that are fraud suspects.
-- with FraudSuspects as (
--     Select *
--     From Customer
--     Where
--         CustomerID in (
--             29401
--             ,11194
--             ,16490
--             ,22698
--             ,26583
--             ,12166
--             ,16036
--             ,25110
--             ,18172
--             ,11997
--             ,26731
-- , SampleCustomers as (
--     Select *
--     From Customer
--     Where
--         CustomerID not in (
--             29401
--             ,11194
--             ,16490
--             ,22698
--             ,26583
--             ,12166
--             ,16036
--             ,25110
--             ,18172
--             ,11997
--             ,26731
--  ) )
-- 31
-- ) Order by
--         Rand()
--     Limit 100
-- )
-- Select * From FraudSuspects Union all
-- Select * From SampleCustomers;

WITH fraud as (
  select *
  from Customer
  WHERE CustomerID IN (29401, 11194, 16490, 22698, 26583, 12166, 16036, 25110, 18172, 11997, 26731)
),
nonFraud as (SELECT *
             FROM Customer
             WHERE CustomerID not in (select CustomerID from fraud)
             limit 100
)

select * from fraud
union all
select * from nonFraud

