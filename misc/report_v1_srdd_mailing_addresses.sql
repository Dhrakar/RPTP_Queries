-- =============================================================================
-- SQL for getting the mailing addresses of all current, UAF regular employees 
-- and execs.  This can be used to also do random drawings as long as Execs are
-- skipped.
-- =============================================================================
SELECT
  emp.spriden_id  AS "UA ID",
  emp.spriden_last_name
  || ', '
  || nvl(bio.spbpers_pref_first_name,emp.spriden_first_name)
  || ' '
  || substr(emp.spriden_mi,1,1)  AS "Full Name",
  gobtpac_external_user || '@alaska.edu' as "Email",
  ma.spraddr_city                AS "Mailing City",
  ma.spraddr_zip                 AS "Mailing Zip",
  org.title2                     AS "Cabinet",
  org.title3                     AS "Unit",
  org.title                      AS "Department",
  ma.spraddr_street_line1 || ', ' || ma.spraddr_city || ', ' || ma.spraddr_stat_code || ', ' || ma.spraddr_zip AS "Address",
  emp.pebempl_ecls_code          AS "eClass",
  emp.nbrbjob_posn
   || '/' 
   || emp.nbrbjob_suff           AS "Position",
  emp.nbrbjob_begin_date         AS "Position Start Date",
  emp.nbrbjob_end_date           AS "Position End Date"
FROM
  REPORTS.N_ACTIVE_JOBS emp
  JOIN SPBPERS bio ON emp.spriden_pidm = bio.spbpers_pidm
  JOIN ftvorgn_levels org ON emp.pebempl_orgn_code_home = org.orgn_code
  JOIN GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
  LEFT JOIN SPRADDR ma ON (
    spriden_pidm = ma.spraddr_pidm
    AND ma.spraddr_atyp_code = 'MA'
  )
WHERE
  emp.nbrbjob_contract_type = 'P'
  AND ( 
      org.level1 = 'UAFTOT' 
    OR org.level3 IN ('8APPS', '8CITO', '8INFR', '8SECU', '8SPMO', '8TOS', '8USRV')
  )
  AND emp.pebempl_ecls_code IN (
      'EX',            -- Executive
      'CR', 'CT',      -- craft/trade
      'NR', 'NT', 'NX',-- non exempt (regular, temp, extended)
      'XR', 'XT', 'XX' -- Exempt from overtime (regular, temp, extended)
  )
  AND (
      ma.spraddr_seqno IS NULL
      OR ma.spraddr_seqno = (
        SELECT MAX(a2.spraddr_seqno) 
        FROM SPRADDR a2
        WHERE 
          ma.spraddr_pidm = a2.spraddr_pidm
          AND a2.spraddr_atyp_code = 'MA'
      )
    )
  ;
