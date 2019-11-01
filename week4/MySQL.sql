-- 30. History table with start/end date overlap
-- There is a product that has an overlapping date ranges in the ProductListPriceHistory table. Find the products with overlapping records, and show the dates that overlap.

-- also answer for #31

With Overlap as (
  select ProductID
    , EndDate
    ,lead (StartDate) over (partition by ProductID order by StartDate) as NextStartDate
  FROM ProductListPriceHistory
  )
SELECT o.ProductID, c.CalendarDate
       from Overlap o
left join Calendar c on c.CalendarDate >= o.NextStartDate and c.CalendarDate <= o.EndDate
WHERE NextStartDate < EndDate

-- 32. Running total of orders in last year
-- For the company dashboard we'd like to calculate the total number of orders, by month, as well as the running total of orders.
-- Limit the rows to the last year of orders. Sort by calendar month.

With total as (
  select c.CalendarMonth
       , count(o.SalesOrderID) as TotalOrders

  from SalesOrderHeader o
         left join Calendar c on c.CalendarDate = cast(o.OrderDate as date)


  where CalendarMonth >= '2013/06 - Ju'
    group by c.CalendarMonth
    Order by CalendarMonth
)
select * , sum(TotalOrders) over (order by CalendarMonth) as RunningTotal

from total


-- 33. Total late orders by territory
-- Show the number of total orders, and the number of orders that are late. For this problem, an order is late when the DueDate is before the ShipDate. Group and sort the rows by Territory.


SELECT
o.TerritoryID
, st.TerritoryName
, st.CountryCode
, count(o.SalesOrderID) as TotalOrders
, count(if (DueDate<ShipDate,o.SalesOrderID, null)) as TotalLateOrders

FROM SalesOrderHeader o
left join SalesTerritory st on st.TerritoryID = o.TerritoryID

group by o.TerritoryID
, st.TerritoryName
, st.CountryCode
order by o.TerritoryID


-- 35. Customer's last purchase—what was the product subcategory?
-- For a limited list of customers, we need to show the product subcategory of their last purchase. If they made more than one purchase on a particular day, then show the one that cost the most.
-- Limit the customers to these customer IDs:

With Total as (
  select c.CustomerID
       , concat(c.FirstName, " ", c.LastName)                                 as CustomerName
       , sc.ProductSubCategoryName
       , p.ListPrice
       , row_number() over(partition by c.CustomerID order by ListPrice desc) as RowNum


  from SalesOrderHeader o
         left join Customer c on c.CustomerID = o.CustomerID
         left join SalesOrderDetail sd on sd.SalesOrderID = o.SalesOrderID
         left join Product p on p.ProductID = sd.ProductID
         left join ProductSubCategory sc on sc.ProductSubcategoryID = p.ProductSubcategoryID

  where o.CustomerID in (19500,
                         19792,
                         24409,
                         26785)
    group by CustomerID
      , sd.ProductID
    order by c.CustomerID
      , p.ListPrice desc
)
select CustomerID
, CustomerName
, ProductSubCategoryName
FROM Total
where RowNum = 1


-- 36. Order processing: time in each stage
-- When an order is placed, it goes through different stages, such as processed, readied for pick up, in transit, delivered, etc.
-- How much time does each order spend in the different stages?
-- To figure out which tables to use, take a look at the list of tables in the database. You should be able to figure out the tables to use from the table names.
-- Limit the orders to these SalesOrderIDs:
-- 68857
-- 70531
-- 70421
-- Sort by the SalesOrderID, and then the date/time.

  select o.SalesOrderID
       , t.EventName
       , ot.EventDateTime                                                                as TrackingEventDate
       , lead(ot.EventDateTime) over(partition by o.SalesOrderID order by EventDateTime) as NextTrackingEventDate
,HOUR(timediff(ot.EventDateTime,lead(ot.EventDateTime) over(partition by o.SalesOrderID order by EventDateTime)))
  from SalesOrderHeader o

         left join OrderTracking ot on ot.SalesOrderID = o.SalesOrderID
         left join TrackingEvent t on t.TrackingEventID = ot.TrackingEventID

  where o.SalesOrderID in (68857,
                           70531,
                           70421)
    order by o.SalesOrderID
      , ot.EventDateTime


-- 37. Order processing: time in each stage, part 2
-- Now we want to show the time spent in each stage of order processing, but instead of showing information for specific orders, we want to show aggregate data, by online vs offline orders.
-- Sort first by OnlineOfflineStatus, and then TrackingEventID.



With Total as (
  select
     o.SalesOrderID
       , case when o.OnlineOrderFlag = 1 then 'Online' else 'Offline' end as OnlineOfflineStatus
       , t.EventName
       , ot.EventDateTime                                                                as TrackingEventDate
       , lead(ot.EventDateTime) over(partition by o.SalesOrderID order by EventDateTime) as NextTrackingEventDate
       , HOUR(
      timediff(ot.EventDateTime, lead(ot.EventDateTime) over(partition by o.SalesOrderID order by EventDateTime))) as TimeInStage
  from SalesOrderHeader o

         left join OrderTracking ot on ot.SalesOrderID = o.SalesOrderID
         left join TrackingEvent t on t.TrackingEventID = ot.TrackingEventID

    order by o.SalesOrderID
      , ot.EventDateTime
)
select

OnlineOfflineStatus
, EventName
, avg(TimeInStage) as AverageHoursSpentInStage

from Total
group by OnlineOfflineStatus, EventName




-- 38. Order processing: time in each stage, part 3
-- The previous query was very helpful to the operations manager, to help her get an overview of differences in order processing between online and offline orders.
-- Now she has another request, which is to have the averages for online/offline status on the same line, to make it easier to compare.

With Total as (
  select
     o.SalesOrderID
       , case when o.OnlineOrderFlag = 1 then 'Online' else 'Offline' end as OnlineOfflineStatus
       , t.EventName
       , ot.EventDateTime                                                                as TrackingEventDate
       , lead(ot.EventDateTime) over(partition by o.SalesOrderID order by EventDateTime) as NextTrackingEventDate
       , HOUR(
      timediff(ot.EventDateTime, lead(ot.EventDateTime) over(partition by o.SalesOrderID order by EventDateTime))) as TimeInStage
  from SalesOrderHeader o

         left join OrderTracking ot on ot.SalesOrderID = o.SalesOrderID
         left join TrackingEvent t on t.TrackingEventID = ot.TrackingEventID

    order by o.SalesOrderID
      , ot.EventDateTime
)

select

EventName
   , avg(if(OnlineOfflineStatus='Online',TimeInStage,null)) as OnlineAvgHoursInStage
 , avg(if(OnlineOfflineStatus='Offline',TimeInStage,null)) as OfflineAvgHoursInStage

from Total
group by EventName


-- 39. Top three product subcategories per customer
-- The marketing department would like to have a listing of customers, with the top 3 product subcategories that they've purchased.
-- To define “top 3 product subcategories”, we'll order by the total amount purchased for those subcategories (i.e. the line total).
-- Normally we'd run the query for all customers, but to make it easier to view the results, please limit to just the following customers:
-- 13763
-- 13836
-- 20331
-- 21113
-- 26313
-- Sort the results by CustomerID


with Total as (
  select o.CustomerID
       , concat(c.FirstName, " ", c.LastName)                                        as CustomerName
       , sc.ProductSubCategoryName
       , sum(p.ListPrice)                                                               TotalSpent
       , row_number() over(partition by o.CustomerID order by sum(p.ListPrice) desc) as SCRank


  from SalesOrderHeader o
         left join SalesOrderDetail sd on sd.SalesOrderID = o.SalesOrderID
         left join Product p on p.ProductID = sd.ProductID
         left join ProductSubCategory sc on sc.ProductSubcategoryID = p.ProductSubcategoryID
         left join Customer c on c.CustomerID = o.CustomerId

  where o.CustomerID in (13763,
13836,
20331,
21113,
26313)

  group by o.CustomerID
         , concat(c.FirstName, " ", c.LastName)
         , sc.ProductSubCategoryName
)
select
CustomerID, CustomerName
, max(case when SCRank = 1 then ProductSubCategoryName end) as TopProdSubCat1
, max(case when SCRank = 2 then ProductSubCategoryName end) as TopProdSubCat2
, max(case when SCRank = 3 then ProductSubCategoryName end) as TopProdSubCat3

FROM Total
group by CustomerID, CustomerName
order by CustomerID



-- 40. History table with date gaps
-- It turns out that, in addition to overlaps, there are also some gaps in the ProductListPriceHistory table. That is, there are some date ranges for which there are no list prices. We need to find the products and the dates for which there are no list prices.
-- This is one of the most challenging and fun problems in this book, so take your time and enjoy it! Try doing it first without any hints, because even if you don't manage to solve the problem, you will have learned much more.


