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
  usr.usernum = 4386 -- jbbutler
  AND tlog.tmessage NOT LIKE '%Viewed%'
ORDER BY 
  tlog.logdate DESC
;