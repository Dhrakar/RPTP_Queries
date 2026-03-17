WITH 
  citiz AS ( -- build a temp table of the most recent citizenships
    SELECT
      a.gobintl_pidm            AS pidm,
      a.gobintl_natn_code_legal AS country
    FROM GENERAL.GOBINTL a
    WHERE
      a.gobintl_activity_date = (
        SELECT MAX(a2.gobintl_activity_date)
        FROM GENERAL.GOBINTL a2
        WHERE a2.gobintl_pidm = a.gobintl_pidm
      )
  )
SELECT
  CASE
    WHEN org.level1 = 'UATKL' THEN 'TKL'
    WHEN org.level1 LIKE '%TOT' THEN substr(org.level1, 0, length(org.level1) - 3)
    ELSE 'ZZZ'
  END                         AS "Campus",
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit", 
  org.title                   AS "Department",
  ua.pebempl_orgn_code_home   AS "Home dLevel", 
  ua.pebempl_orgn_code_dist   AS "Home TKL",
  emp.spriden_pidm            AS "Banner PIDM",
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
  ua.pebempl_ecls_code         AS "ECLS",                             
  ua.pebempl_current_hire_date AS "Curr Hire Date",
  nvl2(
    job.nbrbjob_pidm,
    job.nbrbjob_posn || '/' || job.nbrbjob_suff,
    'No posn records'
  )                           AS "Position",
  job.nbrbjob_begin_date      AS "Contract Start",
  job.nbrbjob_end_date        AS "Contract End",
  CASE
    WHEN bio.spbpers_citz_code = 'N' OR bio.spbpers_citz_code IS NULL
      THEN ( -- if the spbpers does not list as a citizen, grab the country
             -- from the most recent gobintl entry
             SELECT citiz.country
             FROM citiz 
             WHERE citiz.pidm = emp.spriden_pidm
      )
    WHEN bio.spbpers_citz_code = 'Y' THEN 'US'
    ELSE NULL
  END                         AS "Citizenship",
  ua2.peb2emp_everify_date    AS "E-Verify Date",
  DECODE (
    v.gorvisa_vtyp_code,
    'NC', 'Naturalized',
    'PR', 'Perm. Resident',
    v.gorvisa_vtyp_code
  )                           AS "Visa Type",
  v.gorvisa_visa_start_date   AS "Visa Start Date",
  v.gorvisa_visa_expire_date  AS "Visa Expire Date", 
  ua.pebempl_i9_form_ind      AS "I9 Form Ind.",
  ua.pebempl_i9_expire_date   AS "I9 Expire Date"
FROM
  -- start with the identity table
  SATURN.SPRIDEN emp
  -- join with biographical info for each person
  INNER JOIN SATURN.SPBPERS bio  ON (
    bio.spbpers_pidm = emp.spriden_pidm
  )
  -- join with core employee information (and limit to just UA employees)
  INNER JOIN PAYROLL.PEBEMPL ua  ON (
    ua.pebempl_pidm = emp.spriden_pidm
  )
  -- get information about this person's current base UA job (if it exists)
  INNER JOIN POSNCTL.NBRBJOB job  ON (
        emp.spriden_pidm = job.nbrbjob_pidm
    -- uncomment to limit to just current primary position
    AND job.nbrbjob_contract_type = 'P'
    -- filter to just jobs starting before today
    AND job.nbrbjob_begin_date <= CURRENT_DATE
  )
  -- join to find the org hierarchy for this person's department (if assigned)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = ua.pebempl_orgn_code_home
  )
  LEFT JOIN PAYROLL.PEB2EMP ua2 ON (
    ua2.peb2emp_pidm = emp.spriden_pidm
  )
  LEFT JOIN GENERAL.GORVISA v ON (
    v.gorvisa_pidm = emp.spriden_pidm
  )
WHERE
  -- only include currently active employees
  ua.pebempl_empl_status != 'T'
  -- only include the current person records for the employee
  AND emp.spriden_change_ind IS NULL
  -- filter to just international folks
  AND ( bio.spbpers_citz_code = 'N' OR bio.spbpers_citz_code IS NULL )
  -- Filter to just folks who are working with an expired auth 
  -- or have not worked in the last year
  AND (
    (
      ua.pebempl_i9_expire_date <= SYSDATE
      AND (
        job.nbrbjob_end_date IS NULL
        OR job.nbrbjob_end_date >= sysdate
      )
    )
    OR (
      job.nbrbjob_end_date BETWEEN (sysdate - 730) AND (sysdate - 365)
      AND job.nbrbjob_end_date = (
        SELECT max(job2.nbrbjob_end_date)
        FROM POSNCTL.NBRBJOB job2
        WHERE job2.nbrbjob_pidm = job.nbrbjob_pidm
          AND job2.nbrbjob_end_date <= sysdate - 365
      )
    )
  )
  -- get the most recent version of the visa data
  AND (
    v.gorvisa_pidm IS NULL 
    OR v.gorvisa_surrogate_id = (
      SELECT max(v2.gorvisa_surrogate_id)
      FROM GENERAL.GORVISA v2
      WHERE v2.gorvisa_pidm = v.gorvisa_pidm
    )
  )
ORDER BY
  CASE
    WHEN org.level1 = 'UATKL' THEN 'TKL'
    WHEN org.level1 LIKE '%TOT' THEN substr(org.level1, 0, length(org.level1) - 3)
    ELSE 'ZZZ'
  END,
  org.title2,
  org.title3, 
  org.title,
  emp.spriden_id 
;

select * from nbrbjob where nbrbjob_pidm = 23250;
select * from nbrjobs where nbrjobs_pidm = 1357892;