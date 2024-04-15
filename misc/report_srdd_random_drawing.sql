-- =============================================================================
-- = SRDD Employees Eligibility                                                
-- =  - This query returns a list of UAF employees that are eligible for the   
-- =   prize drawing.  It only includes regular, current UAF employees         
-- =                                                                           
-- =  - 2017 dlb - initial version                                             
-- =  - 201805   - slightly rearranged to put filters in JOINs & made NBRBJOB
-- =              a regular join instead of LEFT (since we _do_ want to filter)
-- =  - 202005 dlb - Rewritten completely to use N_ACTIVE_JOBS as the base & to
-- =              include the mailing city/zip for filtering local folks
-- =============================================================================

SELECT
  emp.spriden_id                 AS "UA ID",
  emp.spriden_last_name
   || ', ' 
   || emp.spriden_first_name 
   || ' ' 
   || SUBSTR(emp.spriden_mi,0,1) AS "Full Name",
  ua.gobtpac_external_user 
   || '@alaska.edu'              AS "UA Email",
  ma.spraddr_city                AS "Mailing City",
  ma.spraddr_zip                 AS "Mailing Zip",
  org.title2                     AS "Cabinet",
  org.title3                     AS "Unit",
  org.title                      AS "Department",
  emp.nbrbjob_posn
   || '/' 
   || emp.nbrbjob_suff           AS "Position",
  emp.nbrbjob_begin_date         AS "Position Start Date",
  emp.nbrbjob_end_date           AS "Position End Date",
  emp.pebempl_ecls_code          AS "Position eClass"
FROM
  REPORTS.N_ACTIVE_JOBS emp 
  JOIN REPORTS.FTVORGN_LEVELS org ON (
    emp.pebempl_orgn_code_home = org.orgn_code
    AND org.level1 = 'UAFTOT'
  )
  JOIN GOBTPAC ua ON emp.spriden_pidm = ua.gobtpac_pidm
  LEFT JOIN SPRADDR ma ON (
    emp.spriden_pidm = ma.spraddr_pidm
    AND ma.spraddr_atyp_code = 'MA'
  )
WHERE 
  emp.pebempl_empl_status <> 'T'      -- only active employees 
  AND emp.nbrbjob_contract_type = 'P' -- only primary jobs
  AND emp.pebempl_ecls_code IN (
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
ORDER BY
  org.title2,
  org.title3,
  org.title, 
  emp.spriden_id
;
