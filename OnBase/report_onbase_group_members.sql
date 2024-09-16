-- ================================================
-- Get's all of the members of an AD group and then
-- lists out all of those users' groups
-- 
-- param: grp ( like doctype.hr )
-- =================================================

--WITH
--  users AS (
--    -- buils a list of user accounts that belong
--    -- to the requested group
--    SELECT 
--      lower(trim(emp.username)) AS username
--    FROM
--      HSI.USERGROUP grp
--      JOIN HSI.userxusergroup uxg ON (
--        uxg.usergroupnum = grp.usergroupnum
--      )
--      JOIN HSI.USERACCOUNT emp ON (
--            emp.usernum = uxg.usernum
--        AND emp.usernum > 100
--        AND emp.username NOT LIKE '%(de%'
--      )
--    WHERE
--      grp.usergroupname = 'ua_onbase.' || 'doctype.uaf.mou_moa'
--  )

SELECT 
  rpad(username,15,' ') AS username,
  rpad(full_name,25, ' ') AS "Full Name",
  last_login
FROM (
SELECT
  trim(lower(emp.username))       AS username,
  trim(emp.realname)              AS full_name,
  emp.lastlogon                   AS last_login,
  decode( 
    emp.disablelogin, 
    0, 'Unlocked', 
    'Locked'
  )                               AS login_status,
  DECODE ( 
    BITAND(emp.licenseflag, 1), 
    1, '*',
    ' '  
  )                               AS named_user,
  LISTAGG (
    replace(
      trim(grp.usergroupname), 
      'ua_onbase.',
      ''
    ), ','
  ) WITHIN GROUP (
    ORDER BY grp.usergroupname
  )                               AS groups
FROM
  HSI.USERACCOUNT emp
  -- limit to just the members of the group we want
  -- INNER JOIN users on users.username = lower(trim(emp.username))
  -- account for folks with no groups
  LEFT JOIN HSI.USERXUSERGROUP uxg ON (
    uxg.usernum = emp.usernum
  )
  JOIN HSI.USERGROUP grp ON (
    uxg.usergroupnum = grp.usergroupnum
  )
WHERE
   -- don't get the system accounts
  emp.usernum > 100
   -- only current users (
  AND emp.username NOT LIKE '%(de%'
GROUP BY
  trim(lower(emp.username)), 
  trim(emp.realname), 
  emp.lastlogon, 
  decode(emp.disablelogin, 0, 'Unlocked', 'Locked'),  
  DECODE (BITAND(emp.licenseflag, 1), 1, '*',' ' )
ORDER BY
  login_status, username ASC
)
WHERE
  instr(groups,'doctype.uaf.mou_moa') > 0
  AND instr(groups,'user.doc.create') > 0
ORDER BY
  username
;