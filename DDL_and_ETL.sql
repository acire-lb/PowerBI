
USE EricaFinDW

/*
		1). Create the Dimension and Fact Tables
		2).	Extract from the FinanceDB
*/

	-- Create DimRegion Table
	IF EXISTS (SELECT 1 FROM EricaFinDW.sys.tables where name = 'DimRegion')
	DROP TABLE DimRegion;
	GO

	CREATE TABLE DimRegion (
	Location_SKID tinyint IDENTITY NOT NULL, 
	RegionID tinyint NOT NULL, 
	SegmentID tinyint NOT NULL, 
	CountryID tinyint NOT NULL, 
	SalesRegionID tinyint NOT NULL,
	CountryName nvarchar(28) NOT NULL, 
	SegmentName nvarchar(24) NOT NULL, PRIMARY KEY (Location_SKID));


	-- Create DimSalesPerson Table
	IF EXISTS (SELECT 1 FROM EricaFinDW.sys.tables where name = 'DimSalesPerson')
	DROP TABLE DimSalesPerson;
	GO

	CREATE TABLE DimSalesPerson (SalesPersonID tinyint IDENTITY NOT NULL, 
	FirstName nvarchar(32) NOT NULL, 
	LastName nvarchar(32) NOT NULL, PRIMARY KEY (SalesPersonID));

	-- Create DimProduct Table
	IF EXISTS (SELECT 1 FROM EricaFinDW.sys.tables where name = 'DimProduct')
	DROP TABLE DimProduct;
	GO
	CREATE TABLE DimProduct (Product_SKID int IDENTITY NOT NULL, 
	ProductID tinyint NOT NULL, 
	ProductCostID smallint NOT NULL, 
	ProductName nvarchar(12) NOT NULL, PRIMARY KEY (Product_SKID));

	-- Create FactKPI Table
	IF EXISTS (SELECT 1 FROM EricaFinDW.sys.tables where name = 'FactKPI')
	DROP TABLE FactKPI;
	GO
	CREATE TABLE FactKPI (KPI_ID smallint IDENTITY NOT NULL, 
	KPI float(10) NOT NULL, 
	SalesYear int NOT NULL, 
	SalesPersonID tinyint NOT NULL, 
	Location_SKID tinyint NOT NULL, 
	PRIMARY KEY (KPI_ID),
	FOREIGN KEY (SalesPersonID) REFERENCES DimSalesPerson (SalesPersonID),
	FOREIGN KEY (Location_SKID) REFERENCES DimRegion (Location_SKID));

	-- Create FactSales Table
	IF EXISTS (SELECT 1 FROM EricaFinDW.sys.tables where name = 'FactSales')
	DROP TABLE FactSales;
	GO

	CREATE TABLE FactSales (
	Sales_SKID int IDENTITY NOT NULL, 
	SalesOrderID bigint  NULL, 
	SalesOrderNumber nvarchar(24)  NULL, 
	ManufactoringPrice float(10)  NULL, 
	SalePrice float(10)  NULL, 
	UnitsSold smallint  NULL, 
	SalesOrderDate datetime  NULL, 
	SalesMonth date  NULL, 
	Product_SKID int  NULL, 
	Location_SKID tinyint  NULL, 
	PRIMARY KEY (Sales_SKID),
	FOREIGN KEY (Product_SKID) REFERENCES DimProduct (Product_SKID),
	FOREIGN KEY (Location_SKID) REFERENCES DimRegion (Location_SKID));


-- 2) Extracting from the FinanceDB 
	USE FinanceDB
	GO

	/* EXTRACT */
	-- extract region Table
	IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'etl_extract_region' AND TYPE = 'P')
	DROP PROCEDURE etl_extract_region;
	GO

	CREATE PROCEDURE etl_extract_region
	AS
	BEGIN
	-- Extract into Region  table
	SET IDENTITY_INSERT [EricaFinDW].[dbo].[DimRegion] off
	INSERT INTO EricaFinDW.dbo.DimRegion (CountryID, RegionID, SegmentID, SalesRegionID, CountryName, SegmentName)
		SELECT
		c.CountryID,
		r.RegionID,
		s.SegmentID,
		sr.SalesRegionID,
		c.CountryName,
		s.SegmentName
		FROM Region as r
		INNER JOIN SalesRegion as sr on r.RegionID = sr.RegionID
		INNER JOIN Country as c on r.CountryID = c.CountryID
		INNER JOIN Segment as s on r.SegmentID = s.SegmentID
	END
	GO

	/* EXTRACT product */
	-- extract Product Table

	USE FinanceDB
	
	IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'etl_extract_product' AND TYPE = 'P')
	DROP PROCEDURE etl_extract_product;
	GO
	CREATE PROCEDURE etl_extract_product
	AS
	BEGIN
		-- Extract into Product table
		SET IDENTITY_INSERT [EricaFinDW].[dbo].[DimProduct] off

		INSERT INTO EricaFinDW.dbo.DimProduct (ProductID, ProductCostID, ProductName)
		SELECT DISTINCT
			p.ProductID,
			pc.ProductCostID,
			p.ProductName
		FROM Product as p
		INNER JOIN ProductCost AS pc on pc.ProductID = p.ProductID
	END
	GO

	
	/* EXTRACT sales person */
	-- extract SalesPerson Table
	IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'etl_extract_SalesPerson' AND TYPE = 'P')
	DROP PROCEDURE etl_extract_SalesPerson;
	GO
	CREATE PROCEDURE etl_extract_SalesPerson
	AS
	BEGIN
		SET IDENTITY_INSERT [EricaFinDW].[dbo].[DimSalesPerson] ON
		-- Extract into Sales Person  table
		INSERT INTO EricaFinDW.dbo.DimSalesPerson (SalesPersonID, FirstName, LastName)
		SELECT
			sp.SalesPersonID,
			sp.FirstName,
			sp.LastName
		FROM SalesPerson as sp
		SET IDENTITY_INSERT [EricaFinDW].[dbo].[DimSalesPerson] off
	END
	GO


	/* extract fact kpi */
	IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'etl_extract_factkpi' AND TYPE = 'P')
	DROP PROCEDURE etl_extract_factkpi;
	GO
	CREATE PROCEDURE etl_extract_factkpi
	AS
	BEGIN
		SET IDENTITY_INSERT [EricaFinDW].[dbo].[FactKPI] OFF
		-- Extract into fact kpi Stage table
		INSERT INTO [EricaFinDW].[dbo].[FactKPI] (KPI, SalesYear, SalesPersonID, Location_SKID)
		SELECT
			KPI.KPI,
			KPI.SalesYear,
			SP.SalesPersonID,
			R.Location_SKID
		FROM FinanceDB.dbo.SalesKPI AS KPI
		INNER JOIN EricaFinDW.dbo.DimSalesPerson as SP on SP.SalesPersonID = KPI.SalesPersonID
		INNER JOIN EricaFinDW.dbo.DimRegion as R on R.SalesRegionID = KPI.SalesRegionID
	END
	GO

	-- When extracting and inserting into the talos fact sales table - there was a lot of information to load
	-- therefore the local database was implemnted for all the table inserts/views

	/* extract fact sales */
	IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'etl_extract_factsales' AND TYPE = 'P')
	DROP PROCEDURE etl_extract_factsales;
	GO

	CREATE PROCEDURE etl_extract_factsales
	AS
	BEGIN

		INSERT INTO EricaFinDW.dbo.FactSales
			(
			SalesOrderID,
			SalesOrderNumber,
			ManufacturingPrice,
			SalePrice, 
			UnitsSold,  
			SalesOrderDate,
			SalesMonth,
			Product_SKID,
			Location_SKID
			)
		SELECT distinct
			SO.SalesOrderID,
			SO.SalesOrderNumber,
			PC.ManufacturingPrice,
			SOL.SalePrice,
			SOL.UnitsSold,
			SO.SalesOrderDate,
			SO.SalesMonth,
			P.Product_SKID,
			R.Location_SKID
			FROM SalesOrderLineItem AS SOL
			INNER JOIN SalesOrder AS SO ON SO.SalesOrderID = SOL.SalesOrderID
			INNER JOIN EricaFinDW.dbo.DimProduct AS P ON P.ProductID = SOL.ProductID
			INNER JOIN ProductCost AS PC ON pc.ProductCostID = P.ProductCostID
			INNER JOIN EricaFinDW.dbo.DimRegion AS R ON R.SalesRegionID = SO.SalesRegionID

	END

	GO
			
-- Execute the Procedures once created.
	USE FinanceDB
	GO
	IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'etl_extract_from_financedb' AND TYPE = 'P')
	DROP PROCEDURE etl_extract_from_financedb;
	go
	CREATE PROCEDURE etl_extract_from_financedb
	AS
	BEGIN
		EXECUTE etl_extract_region
		EXECUTE etl_extract_product
		EXECUTE etl_extract_SalesOrder
		EXECUTE etl_extract_SalesPerson
		EXECUTE etl_extract_factkpi
		EXECUTE etl_extract_factsales
	END
	GO

