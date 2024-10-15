SELECT
  --itm.datestored          AS "Date Uploaded",
  nvl(
    trim(usr.realname), 
    'NextGen'
  )                       AS "Uploader",
  trim(doc.itemtypename)  AS "Document Type",
  count(doc.itemtypename) AS "# Uploaded"
FROM
  HSI.USERACCOUNT usr
  INNER JOIN HSI.ITEMDATA itm ON
    itm.usernum = usr.usernum
  INNER JOIN HSI.DOCTYPE doc ON 
    doc.itemtypenum = itm.itemtypenum
WHERE
  itm.datestored BETWEEN to_date('01/01/2024', 'MM/DD/YYYY') AND SYSDATE
  AND usr.usernum = 4123  -- ejhoward
GROUP BY
  --itm.datestored,
  nvl(trim(usr.realname), 'NextGen'),
  trim(doc.itemtypename)
ORDER BY
  trim(doc.itemtypename)
;