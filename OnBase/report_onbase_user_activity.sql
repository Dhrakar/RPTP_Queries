SELECT
  trim(usr.username) AS username,
  tlog.logdate       AS date_stamp,
  trim(tlog.tmessage) AS action
FROM
  HSI.USERACCOUNT usr
  INNER JOIN HSI.TRANSACTIONXLOG tlog ON (
    usr.usernum = tlog.usernum
  )
WHERE
  usr.usernum = 4504 
  AND tlog.tmessage LIKE '%Termed%'
  AND tlog.logdate >= to_date('01-JAN-2025', 'DD-MON-YYYY')
ORDER BY 
  tlog.logdate DESC
;