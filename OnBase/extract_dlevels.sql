-- This query builds the data value entries for the "Department (dlevel|title)" keyword
-- Use teh 'Replace' option for importing the values
-- Use RPTP connection and not DDIT or DDIL

SELECT 
  rpad(ftvorgn_orgn_code, 7, ' ') || '| ' || trim(upper(ftvorgn_title)) AS dept
FROM 
  FIMSMGR.FTVORGN 
WHERE 
  ftvorgn_orgn_code LIKE 'D%'
  AND upper(ftvorgn_title) NOT LIKE '%DELETE%'
  AND ftvorgn_nchg_date = to_date('31-DEC-2099', 'DD-MON-YYYY')
ORDER BY
  ftvorgn_orgn_code
;