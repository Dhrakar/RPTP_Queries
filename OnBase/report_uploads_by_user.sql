SELECT
  to_char(itm.datestored, 'YYYY')          AS "Year Uploaded",
  to_char(itm.datestored, 'MM')          AS "Month Uploaded",
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
  AND usr.usernum = 4135
  -- AND usr.username = 'wmason3'
GROUP BY
  to_char(itm.datestored, 'YYYY'),
  to_char(itm.datestored, 'MM'),
  nvl(trim(usr.realname), 'NextGen'),
  trim(doc.itemtypename)
ORDER BY
  to_char(itm.datestored, 'YYYY') DESC,
  to_char(itm.datestored, 'MM') DESC,
  trim(doc.itemtypename)
;

select * from hsi.itemdata;