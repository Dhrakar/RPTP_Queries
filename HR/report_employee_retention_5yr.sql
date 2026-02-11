SELECT
  emp_hired   as "Hire Year",
  count( distinct emp_pidm ) as "# Hired",
  sum( CASE WHEN emp_termed = '2015' THEN 1 ELSE 0 END ) as "Term 2015",
  sum( CASE WHEN emp_termed = '2016' THEN 1 ELSE 0 END ) as "Term 2016",
  sum( CASE WHEN emp_termed = '2017' THEN 1 ELSE 0 END ) as "Term 2017",
  sum( CASE WHEN emp_termed = '2018' THEN 1 ELSE 0 END ) as "Term 2018",
  sum( CASE WHEN emp_termed = '2019' THEN 1 ELSE 0 END ) as "Term 2019",
  sum( CASE WHEN emp_termed = '2020' THEN 1 ELSE 0 END ) as "Term 2020",
  sum( CASE WHEN emp_termed = '2021' THEN 1 ELSE 0 END ) as "Term 2021",
  sum( CASE WHEN emp_termed = '2022' THEN 1 ELSE 0 END ) as "Term 2022",
  sum( CASE WHEN emp_termed = '2023' THEN 1 ELSE 0 END ) as "Term 2023",
  sum( CASE WHEN emp_termed = '2024' THEN 1 ELSE 0 END ) as "Term 2024",
  sum( CASE WHEN emp_termed = '2025' THEN 1 ELSE 0 END ) as "Term 2025",
  sum( CASE WHEN emp_stat = 'A' THEN 1 ELSE 0 END ) as "Remaining Active"
FROM (
SELECT
  a.pebempl_pidm as emp_pidm,
  to_char(a.pebempl_current_hire_date, 'YYYY') as emp_hired,
  a.pebempl_empl_status as emp_stat,
  CASE
    WHEN a.pebempl_empl_status = 'T' then to_char(a.pebempl_term_date, 'YYYY')
    ELSE null
  END as emp_termed
FROM
  PAYROLL.PEBEMPL a
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON a.pebempl_orgn_code_home = org.orgn_code
WHERE
  a.pebempl_current_hire_date BETWEEN to_date('01/01/2015', 'mm/dd/yyyy') AND SYSDATE 
  AND org.level1 = 'UAFTOT'
  AND a.pebempl_ecls_code IN (
--    'A9', --'No longer used',
--    'AR', --'No longer used',
    'EX', --'Officers/Sr. Administrators',
    'F9', --'Faculty',
    'FN', --'Faculty',
    'FR', --'Officers/Sr. Administrators',
    'FT', --'Adjunct Faculty',
    'FW', --'Adjunct Faculty',
    'CR', --'Staff',
    'CT', --'Staff',
    'NR', --'Staff',
    'NT', --'Staff',
    'NX', --'Staff',
    'XR', --'Staff',
    'XT', --'Staff',
    'XX', --'Staff',
--    'GN', --'Student',
--    'GT', --'Student',
--    'SN', --'Student',
--    'ST' --'Student',
    '00' -- dummy value to keep from futzing with the trailing ','
  )
)
GROUP BY 
  emp_hired
ORDER BY
  1
;
