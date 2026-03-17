-- ====================================================
-- Shows all activity for the requested user
-- ====================================================
-- 2279 - Derek
-- 4504 - Shiva
SELECT
  to_char(tlog.logdate, 'MON/YYYY') AS "Log Date",
  trim(usr.realname) 
    || ' [' 
    || trim(usr.username)
    || '] '                AS "OnBase User",
  CASE
    WHEN tlog.actionnum = 1 THEN 'Document: '
     || DECODE (
          tlog.subactionnum,
          1, 'Created',
          2, 'Created',
          3, 'Deleted',
          ' '
        )
    WHEN tlog.actionnum = 2 THEN 'Folder: ' || tlog.subactionnum
    WHEN tlog.actionnum = 3 THEN 'Note: '
     || DECODE (
          tlog.subactionnum,
           1, 'Created',
           2, 'Viewed',
           3, 'Deleted',
           4, 'Modified',
          tlog.subactionnum
        )
    WHEN tlog.actionnum = 4 THEN 'Document: '
     || DECODE (
          tlog.subactionnum,
           1, 'Viewed',
           2, 'Printed',
           3, 'Mailed',
           4, 'Re-Indexed',
           8, 'Revised',
          16, 'Added Pages',
          tlog.subactionnum
        )
    WHEN tlog.actionnum = 5 THEN 'Keywords: '
     || DECODE (
          tlog.subactionnum,
           1, 'Viewed',
           'Updated'
        )
    WHEN tlog.actionnum = 6 THEN 'Misc: ' || tlog.subactionnum
    ELSE 'Unknown'
  END                    AS "Actions", 
  trim(dtyp.itemtypename)  AS "Document Type",
  count(dtyp.itemtypename)          AS "# Affected"
FROM
  HSI.TRANSACTIONXLOG tlog
  INNER JOIN HSI.USERACCOUNT usr ON (
    usr.usernum = tlog.usernum
  )
  INNER JOIN HSI.ITEMDATA item ON (
    item.itemnum = tlog.num
  )
  INNER JOIN HSI.DOCTYPE dtyp ON (
    dtyp.itemtypenum = item.itemtypenum
  )
WHERE
  tlog.logdate >= to_date('01-JAN-2025', 'DD-MON-YYYY')
  AND (
       usr.usernum = :usernum
    OR UPPER(usr.username) = UPPER(:username)
  )
GROUP BY
  to_char(tlog.logdate, 'MON/YYYY'),
  trim(usr.realname) 
    || ' [' 
    || trim(usr.username)
    || '] ',
  CASE
    WHEN tlog.actionnum = 1 THEN 'Document: '
     || DECODE (
          tlog.subactionnum,
          1, 'Created',
          2, 'Created',
          3, 'Deleted',
          ' '
        )
    WHEN tlog.actionnum = 2 THEN 'Folder: ' || tlog.subactionnum
    WHEN tlog.actionnum = 3 THEN 'Note: '
     || DECODE (
          tlog.subactionnum,
           1, 'Created',
           2, 'Viewed',
           3, 'Deleted',
           4, 'Modified',
          tlog.subactionnum
        )
    WHEN tlog.actionnum = 4 THEN 'Document: '
     || DECODE (
          tlog.subactionnum,
           1, 'Viewed',
           2, 'Printed',
           3, 'Mailed',
           4, 'Re-Indexed',
           8, 'Revised',
          16, 'Added Pages',
          tlog.subactionnum
        )
    WHEN tlog.actionnum = 5 THEN 'Keywords: '
     || DECODE (
          tlog.subactionnum,
           1, 'Viewed',
           'Updated'
        )
    WHEN tlog.actionnum = 6 THEN 'Misc: ' || tlog.subactionnum
    ELSE 'Unknown'
  END,
  trim(dtyp.itemtypename)
ORDER BY
  to_char(tlog.logdate, 'MON/YYYY') DESC,
  trim(dtyp.itemtypename)
;