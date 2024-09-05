-- =============================================================================
-- Performance Evaluation Report
--
--  This query returns all of the uploaded performance evaluations along with
-- metadata for reporting.  Pulls only the most recent evaluation per employee
--
--    Doc ID # 560 -- HR Performance Evaluation
--           # 116 -- UAID KW (dual table, required)
--           # 117 -- ReceivingCampus KW (dual table, required)
--           # 308 -- Evaluation Date KW (single table)
--
-- =============================================================================
SELECT DISTINCT
  trim(campus.keyvaluechar)                  AS "Campus",
  to_char(edate.keyvaluedate, 'DD MON YYYY') AS "Date Evaluated",
  trim(uaid.keyvaluechar)                    AS "Employee ID"
FROM
  HSI.DOCTYPE doc
  -- find all the documents of this type
  INNER JOIN HSI.ITEMDATA itm ON 
    doc.itemtypenum = itm.itemtypenum
  -- get UAID KW
  INNER JOIN HSI.KEYXITEM116 kw_uaid  ON 
    itm.itemnum = kw_uaid.itemnum
  INNER JOIN HSI.KEYTABLE116 uaid ON 
    kw_uaid.keywordnum = uaid.keywordnum
  -- get ReceivingCampus KW
  INNER JOIN HSI.KEYXITEM117 kw_campus  ON 
    itm.itemnum = kw_campus.itemnum
  INNER JOIN HSI.KEYTABLE117 campus ON 
    kw_campus.keywordnum = campus.keywordnum
  -- get the evaluation date (if any)
  LEFT JOIN HSI.KEYITEM308 edate ON 
    itm.itemnum = edate.itemnum
WHERE
  doc.itemtypenum = 560
--  AND ( -- if there is a date, get the max for this uaid
--    edate.keyvaluedate IS NULL
--    OR edate.keyvaluedate = (
--      SELECT max(edate2.keyvaluedate)
--      FROM HSI.KEYITEM308 edate2
--        INNER JOIN HSI.KEYXITEM116 kwuaid2 ON 
--          edate2.itemnum = kwuaid2.itemnum
--        INNER JOIN HSI.KEYTABLE116 uaid2 ON 
--          kwuaid2.keywordnum = uaid2.keywordnum
--      WHERE uaid2.keyvaluechar = uaid.keyvaluechar
--    )
--  )
ORDER BY
  trim(campus.keyvaluechar),
  trim(uaid.keyvaluechar)
;