SELECT 
    dc.CustomerKey,
    dc.FirstName,
    dc.LastName,
    dd.FullDateAlternateKey AS OrderDate,
    fis.SalesAmount
FROM dbo.FactInternetSales AS fis
INNER JOIN dbo.DimCustomer AS dc
    ON fis.CustomerKey = dc.CustomerKey
INNER JOIN dbo.DimDate AS dd
    ON fis.OrderDateKey = dd.DateKey
WHERE dd.CalendarYear = 2020;
GO

SELECT 
    org.OrganizationName,
    SUM(ff.Amount) AS TotalFinance,
    (SUM(ff.Amount) * 100.0) / (SELECT SUM(Amount) FROM dbo.FactFinance) AS FinancePercent
FROM dbo.FactFinance AS ff
INNER JOIN dbo.DimOrganization AS org
    ON ff.OrganizationKey = org.OrganizationKey
GROUP BY org.OrganizationName;
GO