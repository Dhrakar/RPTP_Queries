-- ======================================================================
--  This query returns all of the Keywords associated with a particular
--  Document Type
-- ======================================================================
SELECT
  '[' || a.itemtypenum || '] '
  || trim(c.itemtypename)     AS "Document Type",
  '[' || a.keytypenum || '] '
  || trim(b.keytype)          AS "Keyword",
  trim(a.defaultkeywordvalue) AS "Default Value"
FROM
  HSI.ITEMTYPEXKEYWORD a
  INNER JOIN HSI.KEYTYPETABLE b ON (
    b.keytypenum = a.keytypenum
  )
  INNER JOIN HSI.DOCTYPE c ON (
    c.itemtypenum = a.itemtypenum
  )
WHERE
  a.itemtypenum = :docID
ORDER BY
  1,
  a.seqnum
;