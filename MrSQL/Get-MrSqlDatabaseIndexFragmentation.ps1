function Get-MrSqlDatabaseIndexFragmentation {
    param (
        $ComputerName,
        $DatabaseName,
        $Percentage
    )

    Invoke-Sqlcmd -ServerInstance $ComputerName -Database $DatabaseName -Query "
    SELECT DB_NAME(database_id) AS database_name,
           so.[name] AS table_name,
           dmv.index_id,
           si.[name],
           dmv.index_type_desc,
           dmv.alloc_unit_type_desc,
           dmv.index_depth,
           dmv.index_level,
           avg_fragmentation_in_percent,
           page_count
    FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, 'LIMITED') dmv
        INNER JOIN sysobjects so
        ON dmv.[object_id] = so.id
        INNER JOIN sys.indexes si
        ON dmv.object_id = si.object_id
        AND dmv.index_id = si.index_id
    WHERE dmv.avg_fragmentation_in_percent >= $Percentage
    ORDER BY table_name, si.name"
}