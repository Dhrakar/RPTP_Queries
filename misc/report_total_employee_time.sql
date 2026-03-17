SELECT
  to_date(
    '31-DEC-' || :milestone_year, 
    'DD-MON-YYYY')                     AS "Milestone Cut-Off Date",
  SYSDATE                              AS "As Of Date",
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                                    AS "Campus",
  org.title2                           AS "Cabinet",
  org.title3                           AS "Unit",
  org.title                            AS "Department",
  emp.pebempl_orgn_code_dist           AS "TKL",
  emp.spriden_id                       AS "UAID",
  emp.pebempl_pidm                     AS "Banner PIDM",
  usr.gobtpac_external_user 
    || '@alaska.edu'                   AS "UA Email",
  emp.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.spriden_first_name 
       )
    || ' ' 
    || substr ( emp.spriden_mi,1,1)                      
                                       AS "Full Name",
  nvl2(
    a.spraddr_pidm,
    a.spraddr_street_line1 
    || ', ' || a.spraddr_city 
    || ', ' || a.spraddr_stat_code 
    || ', ' || a.spraddr_zip,
    null
  )                                    AS "Mailing Address",
  emp.nbrjobs_ecls_code                AS "ECLS",
  boss.spriden_id                      AS "Supervisor UA ID",
  nvl2(
    boss.spriden_pidm,
    boss.spriden_last_name 
      || ', '
      || coalesce (
         bbio.spbpers_pref_first_name,
         boss.spriden_first_name 
        ) 
      || ' '
      || SUBSTR(boss.spriden_mi,0,1),
    null
  )                                    AS "Supervisor Name",
  nvl2(
    busr.gobtpac_pidm,
    busr.gobtpac_external_user || '@alaska.edu',
    null 
  )                                    AS "Supervisor Email",
  emp.pebempl_adj_service_date         AS "HR Adj. Service Date",
  floor(
    ( to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy') 
    - emp.pebempl_adj_service_date
    ) / 365.25
  )                                    AS "HR Adj. Serv. Years",
  emp.pebempl_first_hire_date          AS "Original Hire Date",
  floor(
    ( to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy') 
    - emp.pebempl_first_hire_date
    ) / 365.25
  )                                    AS "Total Years",
  CASE
    WHEN mod(floor(
    ( to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy') 
    - emp.pebempl_first_hire_date
    ) / 365.25), 5) = 0 THEN 'Y'
    ELSE 'N'
  END                                  AS "Milestone?"
FROM
  REPORTS.N_ACTIVE_JOBS emp
  -- get the demographic data
  INNER JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = emp.pebempl_pidm
  )
  -- get the UA username (for email address)
  INNER JOIN GENERAL.GOBTPAC usr  ON (
    usr.gobtpac_pidm = emp.pebempl_pidm
  )
  -- pull in the employee's organization hierarchy (if home dlevel is set)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = emp.pebempl_orgn_code_home
  )
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN SATURN.SPRIDEN boss  ON (
    boss.spriden_pidm = emp.nbrjobs_supervisor_pidm
    AND boss.spriden_change_ind IS NULL
  )
  -- grab any preferred name for the supervisor (if any)
  LEFT JOIN SATURN.SPBPERS bbio ON (
    bbio.spbpers_pidm = boss.spriden_pidm
  )
  -- grab the username info for the supervisor (also for email) (if any assigned)
  LEFT JOIN GENERAL.GOBTPAC busr ON (
    busr.gobtpac_pidm = boss.spriden_pidm
  )
  -- get the mailing address if there is one
  LEFT JOIN SATURN.SPRADDR a ON (
    -- get just the mailing address
        a.spraddr_pidm = emp.pebempl_pidm
    AND a.spraddr_atyp_code = 'MA'
  )
WHERE
  emp.nbrbjob_contract_type = 'P'
  AND emp.nbrjobs_ecls_code IN ('NR','NX','XR','XX', 'CR', 'EX')
  -- only the most current mailing address (if there is one)
  AND (
    a.spraddr_seqno IS NULL
    OR a.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        a.spraddr_pidm = a2.spraddr_pidm
        AND a2.spraddr_atyp_code = 'MA'
    )
  )
ORDER BY 
  -- first by campus
  dsduaf.f_decode$orgn_campus( org.level1 ),
  org.title2,                         -- cabinet
  org.title3,                         -- unit
  org.title,                          -- department
  emp.spriden_id                      -- employee
  
