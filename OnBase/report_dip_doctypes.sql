-- ===============================================
-- This query shows the doc types imported by DIPs
-- ===============================================
SELECT
  decode (
    dip.parsefilenum,
      '136', 'NextGen',
      '137', 'SalesForce',
      dip.parsefilenum
    )                   AS "DIP Name",
  dip.itemtypenum       AS "DocType ID",
  trim(it.itemtypename) AS "DocType"
FROM
  HSI.PARSEFILEXITMTYP dip
  LEFT JOIN HSI.DOCTYPE it ON 
    it.itemtypenum = dip.itemtypenum
WHERE
  dip.parsefilenum IN  (
    '136', -- NextGen DIP
    '137'  -- SalesFOrce DIP
  )
ORDER BY
  dip.parsefilenum,
  dip.itemtypenum
;
