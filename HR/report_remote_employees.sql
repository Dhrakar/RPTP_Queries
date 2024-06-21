SELECT DISTINCT
  emp.spriden_id              AS "UA ID",
  emp.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.spriden_first_name 
       )
    || ' ' 
    || substr ( emp.spriden_mi,1,1)                      
                              AS "Full Name",
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit",
  org.title                   AS "Department",
  DECODE (
    a.pprcert_cert_code,
    'REMH', 'Hybrid',
    'REMR', 'Full Remote',
    'General Remote'
  )                           AS "Remote Type"
FROM 
  PAYROLL.PPRCERT a
  INNER JOIN REPORTS.N_ACTIVE_JOBS emp ON 
    emp.spriden_pidm = a.pprcert_pidm
  INNER JOIN SATURN.SPBPERS bio ON 
    bio.spbpers_pidm = a.pprcert_pidm
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON 
    emp.pebempl_orgn_code_home = org.orgn_code
WHERE
  -- Filter to just those with work agreements
  a.pprcert_cert_code LIKE 'REM_'
  -- Filter to just current agreements
  AND (
    a.pprcert_expire_date >= SYSDATE
    OR a.pprcert_expire_date IS NULL
  )
  -- Filter to just the primary job
  AND emp.nbrbjob_contract_type = 'P'
  -- Filter to just UAF
  AND org.level1 = 'UAFTOT'
ORDER BY
  emp.spriden_id
;