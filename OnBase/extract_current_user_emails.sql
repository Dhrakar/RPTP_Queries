-- builds a VCSV file of email addresses for ingestion into Google Groups
SELECT
  '"' || trim(usr.realname) || '" <' || trim(usr.emailaddress) || '>' AS contact
FROM
  HSI.USERACCOUNT usr
WHERE
   -- don't get the system accounts
   usr.usernum > 100 
   AND usr.licenseflag < 4096
   -- no admin accounts
   AND usr.username NOT LIKE '%ADMIN%'
   -- no special accounts
   AND usr.username NOT LIKE '%UAF-%'
   AND usr.username NOT LIKE '%UA-%'
   AND usr.username NOT LIKE '%OIT-%'
   -- only current users (
  AND usr.username NOT LIKE '%(de%'
  -- only valid UA emails
  AND usr.emailaddress LIKE '%@alaska.edu%'
ORDER BY
  usr.username
;