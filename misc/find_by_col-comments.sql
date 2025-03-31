-- =====================================================================
--   This query is used to find Banner tables, columns from parts of the
--  table name, owner, col title or col comments.  Since the behavior of
--  this query can get weird if you try to search on more than one area
--  at a time, it is best to uncomment only the table/col/comment that
--  you need to search by.  The final filter in the WHERE clause can be
--  uncommented if you need to filter out the Data Warehouse tables.
-- =====================================================================

SELECT DISTINCT 
  search.owner,
  search.table_name,
  search.column_name,
  search.comments
FROM 
  SYS.ALL_COL_COMMENTS search
WHERE 
 -- UPPER(search.owner)       LIKE '%' || UPPER(:owner_needle) || '%'
 UPPER(search.table_name)  LIKE '%' || UPPER(:table_needle) || '%'
 -- UPPER(search.column_name) LIKE '%' || UPPER(:col_needle) || '%'
 -- UPPER(search.comments)    LIKE '%' || UPPER(:comment_needle) || '%'
 -- AND search.owner != 'DSDMGR'  
ORDER BY 
  search.owner,
  search.table_name
;

-- =====================================================================
-- This query finds any comments for the requested table.  It uses the
-- same parameters as the col comment query so that you don't have to
-- reenter things
-- =====================================================================
SELECT DISTINCT 
  search.owner,
  search.table_name,
  search.table_type,
  search.comments
FROM 
  SYS.ALL_TAB_COMMENTS search
WHERE 
 -- UPPER(search.owner)       LIKE '%' || UPPER(:owner_needle) || '%'
 UPPER(search.table_name)  LIKE '%' || UPPER(:table_needle) || '%'
 -- AND search.owner != 'DSDMGR'   
ORDER BY 
  search.owner,
  search.table_name
;

