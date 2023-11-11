-- ===================================================
--  Various short queries for pulling out OnBase data
-- ===================================================

-- List all Scan Queues
SELECT 
  sq.queuenum            AS "ID",
  trim(sq.queuename)     AS "Scan Queue",
  trim(dg.diskgroupname) AS "Disk Group"
FROM
  HSI.SCANQUEUE sq
  JOIN HSI.DISKGROUP dg ON 
    sq.diskgroupnum = dg.diskgroupnum
ORDER BY
  sq.queuenum
;

-- Custom Queries that are based on doc type
SELECT 
  cq.cqname        AS "Custom Query", 
  doc.itemtypename AS "Document Type"
from 
  HSI.CUSTOMIT items
  JOIN HSI.DOCTYPE doc ON 
    items.itemtypenum = doc.itemtypenum
  JOIN HSI.CUSTOMQUERY cq ON
    items.cqnum = cq.cqnum
where
  cq.cqname LIKE 'HR%'
order by 
  cq.cqname,
  items.seqnum
;

-- report for accesses of specific document type[s]
-- Replace the Where clause with the id of the doc type to check
SELECT
  item.itemnum            AS "Document ID",
  trim(item.itemname)     AS "Document Name",
  trim(emp.realname)      AS "UA Employee",
  DECODE (log.action,
      16, 'Created Document',
      32, 'Viewed Document',
      35, 'Viewed Keywords',
    1027, 'Exported Document',
    1034, 'Deleted Keyword',
    1035, 'Add Keyword',
          'unknown: ' || log.action
  )                       AS "Activity",
  log.logdate             AS "Activity Date"
FROM
  ITEMDATA item
  JOIN TRANSACTIONXLOG log ON item.itemnum = log.itemnum
  JOIN USERACCOUNT emp ON log.usernum = emp.usernum
WHERE
  item.itemtypenum = 617
ORDER BY
  log.logdate DESC
;

