-- ============================================================
--  Query for getting all currently active UAF employees along
-- with details about the labor distribution of their position.
-- - only primary positions are included
-- - hierarchy depends on correct pebemple home dLevel
-- ============================================================
SELECT DISTINCT
  org.title2                   AS "Cabinet",
  org.title3                   AS "Unit",
  org.title                    AS "Department",
  emp.spriden_id               AS "Employee ID",
  emp.spriden_last_name        AS "Last Name",
  emp.spriden_first_name       AS "First Name",
  substr(
    emp.spriden_mi,0,1
  )                            AS "Middle Initial",
  emp.pebempl_ecls_code        AS "Employee ECLS",
  emp.nbrjobs_ecls_code        AS "Position ECLS",
  emp.nbrbjob_posn
   || '/' 
   || emp.nbrbjob_suff         AS "Position",
  emp.nbrbjob_begin_date       AS "Position Start Date",
  emp.nbrbjob_end_date         AS "Position End Date",
  LISTAGG (
    ( 
      dist.nbrjlbd_percent || '%'
      || ' (' 
        || 'Fund/Org: ' || dist.nbrjlbd_fund_code || '/' || dist.nbrjlbd_orgn_code 
        || ' Dept: ' || CASE
                          WHEN jorg.level7 LIKE 'D%' THEN jorg.level7
                          WHEN jorg.level6 LIKE 'D%' THEN jorg.level6
                          WHEN jorg.level5 LIKE 'D%' THEN jorg.level5
                          WHEN jorg.level4 LIKE 'D%' THEN jorg.level4   
                          WHEN jorg.level3 LIKE 'D%' THEN jorg.level3 
                          ELSE 'D?'
                        END 
        || ' Acct: ' || dist.nbrjlbd_acct_code 
        || ' Prog: ' || dist.nbrjlbd_prog_code 
      || ') '
    ),','  
  ) WITHIN GROUP (
      ORDER BY dist.nbrjlbd_percent DESC
  )                            AS "Labor"
FROM
  REPORTS.N_ACTIVE_JOBS emp
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    emp.pebempl_orgn_code_home = org.orgn_code
  )
  LEFT JOIN POSNCTL.NBRJLBD dist ON ( 
        emp.nbrbjob_pidm = dist.nbrjlbd_pidm
    AND emp.nbrbjob_posn = dist.nbrjlbd_posn
    AND emp.nbrbjob_suff = dist.nbrjlbd_suff
  )
  LEFT JOIN REPORTS.FTVORGN_LEVELS jorg ON (
    jorg.level8 = dist.nbrjlbd_orgn_code
  )
WHERE
  emp.nbrbjob_contract_type = 'P'
  AND org.level1 = 'UAFTOT'
  AND (
    dist.nbrjlbd_effective_date IS NULL
    OR dist.nbrjlbd_effective_date = (
      SELECT max(i.nbrjlbd_effective_date)
      FROM POSNCTL.NBRJLBD i
      WHERE i.nbrjlbd_pidm = dist.nbrjlbd_pidm
        AND i.nbrjlbd_posn = dist.nbrjlbd_posn
        AND i.nbrjlbd_suff = dist.nbrjlbd_suff
    )
  )
GROUP BY
  org.title2,
  org.title3,
  org.title,
  emp.spriden_id,
  emp.spriden_last_name,
  emp.spriden_first_name,
  substr(emp.spriden_mi,0,1),
  emp.pebempl_ecls_code,
  emp.nbrjobs_ecls_code,
  emp.nbrbjob_posn, 
  emp.nbrbjob_suff,
  emp.nbrbjob_begin_date, 
  emp.nbrbjob_end_date
ORDER BY
  org.title2,
  org.title3,
  org.title,
  emp.spriden_id
;

