-- ===============================================
-- This query shows the doc types imported by DIPs
-- ===============================================
SELECT
  decode (
    dip.parsefilenum,
      '136', 'NextGen',
      '137', 'SalesForce',
      '138', 'Tax Documents',
      '144', 'HR Benefits Dump',
      '146', 'Financial Aid',
      '147', 'HR Faculty Contracts',
      '148', 'FERPA Disclosure',
      '153', 'K12 CAL',
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
    '136', '137', '138', '144', '146', '147', '148', '153' 
  )
ORDER BY
  dip.parsefilenum,
  dip.itemtypenum
;
