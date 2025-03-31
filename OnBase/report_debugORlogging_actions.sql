-- Shows Actions that include debugging or logging
SELECT 
  action.actionnum        AS "Action #",
  trim(action.actionname) AS "Action Name",
  DECODE (
    action.flags,
    '4096',      'Debug',
   '1073741824', 'Logging',
   '1073745920', 'Both',
   'None'
  )                       AS "Action Flags"
FROM
  HSI.ACTION action
WHERE
  action.flags IN (
   '4096',
   '1073741824',
   '1073745920'
  )
;

select * from hsi.lifecycle ;
select * from HSI.DOCCHECKOUT;