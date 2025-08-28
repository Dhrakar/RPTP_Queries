-- ===============================
--  Full List
-- ===============================
SELECT DISTINCT
  to_char(slog.logdate, 'YYYY') AS "Year",
  to_char(slog.logdate, '[MM]MON')  AS "Month",
  -- slog.usernum AS "ID#",
  lower(trim(usr.username))     AS "UA Username",
  trim(usr.realname)            AS "Name",
  decode (
    slog.actionnum,
    1, 'Logon',
    3, 'Logout',
    'Other'
  )                             AS "Action",
  -- slog.messagetext,
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
  )                             AS "Client Details"
FROM
  HSI.SECURITYLOG slog
  INNER JOIN HSI.USERACCOUNT usr ON 
    usr.usernum = slog.usernum
WHERE
  slog.logdate > to_date('01-JUN-2024', 'DD-MON-YYYY')
  -- don't include system accts
  AND slog.usernum > 1000
  -- don't include disabled accounts
  AND usr.username NOT LIKE '%(deactivated)%'
  -- Don't include the Unity Scheduler
  AND slog.usernum != 3096
  -- comment out to include logouts
  AND slog.actionnum = 1
  -- don't include passwd failures
  AND slog.subactionnum != 7
ORDER BY 
  1 DESC, 2, 3, 6
--  slog.usernum
;

-- ===============================
--  Compact view
-- ===============================
SELECT
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
  )                            AS "OnBase Client",
  LISTAGG ( DISTINCT
    trim(usr.username), ', '
  ) WITHIN GROUP (
    ORDER BY usr.username
  )                            AS "UA Users"
FROM
  HSI.SECURITYLOG slog
  INNER JOIN HSI.USERACCOUNT usr ON 
    usr.usernum = slog.usernum
WHERE
  slog.logdate > to_date('01-JAN-2025', 'DD-MON-YYYY')
  -- don't include system accts
  AND slog.usernum > 1000
  -- don't include disabled accounts
  AND usr.username NOT LIKE '%(deactivated)%'
  -- Don't include the Unity Scheduler
  AND slog.usernum != 3096
  -- comment out to include logouts
  AND slog.actionnum = 1
  -- don't include passwd failures
  AND slog.subactionnum != 7
  -- only include Classic clients
  AND slog.subactionnum IN ( 1,2,10)
GROUP BY
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
  )
ORDER BY
  1
;