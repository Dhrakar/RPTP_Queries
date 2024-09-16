-- =============================================================================
--    Gets a list of all current OnBase users from OnBase USERACCOUNT table
-- 
--  Only include non-deactivated accounts ( OnBase marks deleted users with 
--  "(deactivated)") and non-system accounts that have an ID > 100
-- 
-- Includes license flag field (16 bit ) which decodes to:
-- 65536 == service account
--  4096 == Administrator 
--   512 == User Group Admin
--    64 == Workflow Named User
--     1 == Named User
-- =============================================================================
SELECT
  *
FROM (
SELECT
--  emp.usernum                     AS "OnBase User #",
  trim(emp.username)              AS "Username",
  trim(emp.realname)              AS "Full Name",
  emp.lastlogon                   AS "Last Login",
  decode( 
    emp.disablelogin, 
    0, 'Unlocked', 
    'Locked'
  )                               AS "Status",
  DECODE ( 
    BITAND(emp.licenseflag, 1), 
    1, '*',
    ' '  
  )                               AS "Named User",
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
  useraccount emp
  -- account for folks with no groups
  LEFT JOIN userxusergroup uxg ON uxg.usernum = emp.usernum
  JOIN usergroup grp ON (
    uxg.usergroupnum = grp.usergroupnum
   -- uncomment to add any group filters
   -- AND grp.usergroupname LIKE 'ua_onbase.doctype.hr%'
  )
WHERE
   -- don't get the system accounts
  emp.usernum > 100
   -- only current users (
  AND emp.username NOT LIKE '%(de%'
GROUP BY
--  emp.usernum,
  trim(emp.username), emp.username, 
  trim(emp.realname), emp.realname, 
  emp.lastlogon, 
  decode(emp.disablelogin, 0, 'Unlocked', 'Locked'),  
  DECODE (BITAND(emp.licenseflag, 1), 1, '*',' ' )
ORDER BY
  "Status", "Username" ASC
)
WHERE 
       instr(groups,'doctype.uaf.mou_moa') > 0 
   AND instr(groups,'user.doc.upload') > 0
   --AND instr(groups,'user.doc.print') > 0
;