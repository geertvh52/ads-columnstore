-- Run this script to follow along with the demo.
USE [ABCCompany];
GO
SELECT * INTO [ABCCompany].[Sales].[SalesOrder_RS] FROM [ABCCompany].[Sales].[SalesOrder]
SELECT * INTO [ABCCompany].[Sales].[SalesOrder_CS] FROM [ABCCompany].[Sales].[SalesOrder]

CREATE UNIQUE CLUSTERED INDEX ci1 ON [ABCCompany].[Sales].[SalesOrder_RS] ([Id]);  
GO

CREATE CLUSTERED COLUMNSTORE INDEX cci1 ON [ABCCompany].[Sales].[SalesOrder_CS] WITH (MAXDOP = 1); 
GO

-- Let's look at the deleted buffer.
SELECT  object_name(i.object_id) AS TableName,
		i.[name] AS IndexName, 
		p.[internal_object_type_desc] AS [Description],
		p.[rows] AS [RowCount], 
		p.[data_compression_desc] AS [CompressionType]
FROM [sys].[internal_partitions] AS p
INNER JOIN [sys].[indexes] AS i ON p.[object_id] = i.[object_id] 
	AND p.[index_id] = i.[index_id]
WHERE i.[name] = 'cci1';
GO




-- Let's checkout our rowgroups.
SELECT  object_name(i.object_id) AS TableName,   
		i.name AS IndexName,   
		i.type_desc AS IndexType,   
		rg.state_desc AS StateDescription,
		rg.total_rows AS TotalRows,
		rg.deleted_rows AS DeletedRows,
		100*(ISNULL(deleted_rows,0))/NULLIF(total_rows,0) AS Fragmented,
		rg.trim_reason_desc AS TrimReason
FROM [sys].[indexes] AS i  
JOIN [sys].[dm_db_column_store_row_group_physical_stats] AS rg  
    ON i.object_id = rg.object_id AND i.index_id = rg.index_id
	WHERE i.name = 'cci1';
GO


ALTER INDEX cci1 ON [ABCCompany].[Sales].[SalesOrder_CS] REORGANIZE;
GO



-- This option will compress even tiny delta stores.
ALTER INDEX cci1 ON [ABCCompany].[Sales].[SalesOrder_CS] REORGANIZE
WITH (COMPRESS_ALL_ROW_GROUPS = ON);
GO




-- I don't want a bunch of small compressed rowgroups.
ALTER INDEX cci1 ON [ABCCompany].[Sales].[SalesOrder_CS] REBUILD
WITH (MAXDOP = 1);
GO

set rowcount 1100000
update [ABCCompany].[Sales].[SalesOrder_CS]
set [SalesAmount] = [SalesAmount] + 1;