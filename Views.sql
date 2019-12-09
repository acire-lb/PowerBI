
	 -- 1). Runs the Index's
	 -- 2). Creates the View

	 USE EricaFinDW;

	-- Non Clustered Index for Fact Sales Table
	CREATE NONCLUSTERED INDEX [INDX_SalesOrder_NonClustered]
	ON [dbo].[FactSales] ([Location_SKID])
	INCLUDE (SalesOrderDate, SalePrice, UnitsSold, ManufacturingPrice)

	-- Non Clustered Index for Fact KPI Table
	CREATE INDEX [INDX_SalesKPI_NonClustered]
	ON [dbo].[FactKPI] ([Location_SKID], [SalesPersonID])
	INCLUDE (KPI, SalesYear)

-- 2). Create Views 

	-- Profit_per_year   View
	DROP VIEW dbo.Profit_per_year 
	GO
	CREATE VIEW dbo.Profit_per_year  
	AS
		SELECT
			DR.CountryName,
			DR.SegmentName,
			SUM(FS.SalePrice - (FS.ManufacturingPrice * FS.UnitsSold)) AS TotalProfit,
			YEAR(FS.SalesOrderDate) AS SalesYear,
			COUNT(*) AS TotalSales
		FROM FactSales AS FS
		INNER JOIN DimRegion AS DR ON DR.Location_SKID = FS.Location_SKID
		GROUP BY YEAR(FS.SalesOrderDate), DR.CountryName, DR.SegmentName
	GO

	SELECT * FROM Profit_per_year

	-- YearlyKPI  View
	DROP VIEW dbo.YearlyKPI 
	GO

	CREATE VIEW dbo.YearlyKPI  
	AS
		SELECT 
			DSP.FirstName,
			DSP.LastName,
			KPI.SalesYear,
			SUM(KPI.KPI) AS YearlySalesKPI,
			DR.CountryName,
			DR.SegmentName
		FROM FactKPI AS KPI
		INNER JOIN DimRegion AS DR ON KPI.Location_SKID = DR.Location_SKID
		INNER JOIN DimSalesPerson AS DSP ON DSP.SalesPersonID = KPI.SalesPersonID
		GROUP BY DSP.FirstName, DSP.LastName, KPI.SalesYear, DR.CountryName, DR.SegmentName;
		GO

	SELECT * FROM dbo.YearlyKPI

		-- YearlyPerformance View
	DROP VIEW dbo.YearlyPerformance
	GO

	CREATE VIEW dbo.YearlyPerformance
	AS
		SELECT
				DSP.FirstName,
				DSP.LastName,
				KPI.SalesYear,
				SUM(CAST(KPI.KPI AS DECIMAL (18,2))) AS YearlySalesKPI,
				COUNT(*) AS TotalSales,
				SUM(KPI.KPI) / COUNT(*) * 100 AS YearlyPerformance,
				DR.CountryName,
				DR.SegmentName
		FROM FactKPI AS KPI
		INNER JOIN DimRegion AS DR ON DR.Location_SKID = KPI.Location_SKID
		INNER JOIN DimSalesPerson AS DSP ON DSP.SalesPersonID = KPI.SalesPersonID
		GROUP BY KPI.SalesYear, DSP.FirstName, DSP.LastName, DR.CountryName, DR.SegmentName, KPI.KPI
		GO

	SELECT * FROM dbo.YearlyPerformance

	-- Monthly_total_sales View
	DROP VIEW dbo.Monthly_total_sales

	CREATE VIEW dbo.Monthly_total_sales
	AS
		SELECT
			DSP.SalesPersonID,
			DSP.FirstName,
			DSP.LastName,
			DR.CountryName,
			DR.SegmentName,
			KPI.SalesYear,
			SUM(KPI.KPI) AS MonthlySalesKPI,
			COUNT(*) AS TotalSales,
			SUM(KPI.KPI) / COUNT(*) / 12 * 100 AS MonthlyPerformance
		FROM FactKPI AS KPI
		INNER JOIN DimSalesPerson AS DSP ON DSP.SalesPersonID = KPI.SalesPersonID
		INNER JOIN DimRegion AS DR ON DR.Location_SKID = KPI.Location_SKID
		--INNER JOIN Stage_FactSales AS FS ON FS.Location_SKID = DR.Location_SKID
		GROUP BY DSP.SalesPersonID, DSP.FirstName, DSP.LastName, DR.CountryName, DR.SegmentName, KPI.KPI, KPI.SalesYear;

		SELECT * FROM dbo.Monthly_total_sales

	GO

	-- Performance View
	DROP VIEW dbo.Performance
	GO

	CREATE VIEW dbo.Performance
	AS
		SELECT TOP(10)
			DSP.SalesPersonID,
			DSP.FirstName,
			DSP.LastName,
			DR.CountryName,
			DR.SegmentName,
			SUM(KPI.KPI) AS KPI,
			COUNT(FS.SalesOrderNumber) AS TotalSales,
			ROW_NUMBER()
			OVER(ORDER BY COUNT(FS.SalesOrderNumber) DESC) AS Performance
		FROM FactKPI AS KPI
		INNER JOIN DimSalesPerson AS DSP ON DSP.SalesPersonID = KPI.SalesPersonID
		INNER JOIN DimRegion AS DR ON DR.Location_SKID = KPI.Location_SKID
		INNER JOIN FactSales AS FS ON FS.Location_SKID = DR.Location_SKID
		GROUP BY DSP.SalesPersonID, DSP.FirstName, DSP.LastName, DR.CountryName, DR.SegmentName;

	SELECT * FROM Performance


		