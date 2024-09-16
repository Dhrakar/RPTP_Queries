SELECT 
  extract(month from slog.logdate) AS "Month",
  slog.usernum AS "ID#",
  lower(trim(usr.username)) || '@alaska.edu' AS "Email",
  trim(usr.realname) AS "Name",
--  decode (
--    slog.actionnum,
--    1, 'Logon',
--    3, 'Logout',
--    'Other'
--  )  AS "Action",
  slog.messagetext,
  decode (
    slog.subactionnum,
     1, 'Thick Client',
     2, 'Configuration',
     9, 'Core Workflow',
    10, 'DS Client',
    12, 'Web Client',
    14, 'OnBase Studio',
    15, 'Unity Client',
    16, 'Unity Console',
    20, 'POP Client',
    'Other: ' || slog.subactionnum
  ) AS "Details"
FROM
  HSI.SECURITYLOG slog
  INNER JOIN HSI.USERACCOUNT usr ON 
    usr.usernum = slog.usernum
WHERE
  slog.logdate > to_date('01-JAN-2024', 'DD-MON-YYYY')
  -- don't include system accts
  AND slog.usernum > 1000
  -- Don't include the Unity Scheduler
  AND slog.usernum != 3096
  -- comment out to include logouts
  AND slog.actionnum = 1
  -- don't include passwd failures
  AND slog.subactionnum != 7
ORDER BY slog.usernum
;