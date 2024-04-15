-- =============================================================================
--  Staff Longevity report
-- This report calculates llongevity using the sum of all eligible positions for
-- currently active employees.  Notes:
--  - only includes primary positions
--  - only includes benefited, full-time ( NR,NX,XR,XX,EX )
--  - has a flag for pre-banner employees (eg, adj service date < 1Jan1996)
--  - longevity years are the > of calculated time or the adj. service date
--  - The :srdd_year variable refers to the year of the longevity ceremony, so
--    it returns Dec 31 of the prior year in the date calculations.
--  ============================================================================
WITH
  -- build temporary table of employees with total service time from positions
  worked AS (
  SELECT
    pos.nbrbjob_pidm AS pidm,
    -- build sum of all days working in an eligible position
    SUM (
      -- get the number of days that this position lasted
      CASE
        WHEN pos.nbrbjob_end_date IS NULL THEN to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - pos.nbrbjob_begin_date
        ELSE pos.nbrbjob_end_date - pos.nbrbjob_begin_date
      END 
    ) AS span 
  FROM
    POSNCTL.NBRBJOB pos
    -- add the position info for ecls
    JOIN POSNCTL.NBBPOSN rec ON (
      pos.nbrbjob_posn = rec.nbbposn_posn
      -- just get the pos that are eligible for longevity recognition
      AND rec.nbbposn_ecls_code IN (
--      'A9', --'Faculty'
--      'AR', --'Faculty'
      'EX', --'Officers/Sr. Administrators'
--      'F9', --'Faculty'
--      'FN', --'Faculty'
--      'FR', --'Officers/Sr. Administrators'
--      'FT', --'Adjunct Faculty'
--      'FW', --'Adjunct Faculty'
      'CR', --'Staff'
--      'CT', --'Staff'
      'NR', --'Staff'
--      'NT', --'Staff'
      'NX', --'Staff'
      'XR', --'Staff'
--      'XT', --'Staff'
      'XX', --'Staff'
      'GN', --'Student'
      'GT', --'Student'
      'SN', --'Student'
      'ST', --'Student'
    '00' -- dummy value to keep from futzing with the trailing comma when commenting/uncommenting
  )
    )
  WHERE
    -- only include the Primary positions
    pos.nbrbjob_contract_type = 'P'
    -- grab all the positions that have no end date, or are have already started
    AND (
      pos.nbrbjob_end_date IS NULL
      OR pos.nbrbjob_begin_date < to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy')
    )
  GROUP BY
    pos.nbrbjob_pidm
  )
SELECT
  CASE -- determine if the calculated longevity is longer or if the adjusted date logevity is longer to determine max years
    WHEN 
      CASE 
        WHEN (round(worked.span / 365.25)) > round(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25)) 
          THEN round(worked.span / 365.25) 
        ELSE round(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25))
      END  IN (1,5,10,15,20,25,30,35,40,45,50) THEN 'Y'
    ELSE 'N'
  END                            AS "Milestone Year",
  CASE -- if thie person started working pre-banner, flag in case HR needs to check the files
    WHEN (round(worked.span / 365.25)) > round(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25)) 
      THEN round(worked.span / 365.25) 
    ELSE round(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25))
  END                            AS "Longevity",
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                              AS "Campus",
  org.title2                     AS "Cabinet",
  org.title3                     AS "Unit",
  org.title                      AS "Department",
  emp.pebempl_orgn_code_dist     AS "TKL",
  emp.spriden_id                 AS "UA ID",
  emp.spriden_last_name
   || ', ' 
   || NVL2( bio.spbpers_pref_first_name,
            bio.spbpers_pref_first_name,
            emp.spriden_first_name
          ) 
   || ' ' 
   || SUBSTR(emp.spriden_mi,0,1) AS "Full Name",
  usr.gobtpac_external_user 
    || '@alaska.edu'             AS "UA Email",
  a.spraddr_street_line1 
    || ', ' || a.spraddr_city 
    || ', ' || a.spraddr_stat_code 
    || ', ' || a.spraddr_zip     AS "Mailing Address",
  emp.nbrjobs_ecls_code          AS "ECLS",
  emp.pebempl_first_hire_date    AS "Original Hire Date",
  emp.nbrbjob_begin_date         AS "Curr. Position Start Date",
  emp.nbrbjob_end_date           AS "Curr. Position End Date",
  boss.spriden_id                AS "Supervisor UA ID",
  boss.spriden_last_name 
   || ', '
   || boss.spriden_first_name
   || ' '
   || SUBSTR(boss.spriden_mi,0,1)AS "Supervisor Name",
  busr.gobtpac_external_user
    || '@alaska.edu'             AS "Supervisor Email",
  round(worked.span / 365.25)    AS "Calc. Service Years",
  round (
    (
      (
        to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date
      ) / 365.25
    )
  )                              AS "Adj. Service Years",
  CASE -- set the flag for folks hired prior to 1996
    WHEN to_date('01/01/1996', 'mm/dd/yyyy') > emp.pebempl_first_hire_date THEN 'Y'
    ELSE 'N'
  END                            AS "Pre-Banner"
FROM
  -- start with the currently active jobs/employees report
  REPORTS.N_ACTIVE_JOBS emp
  -- get the demographic data
  JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = emp.spriden_pidm
  )
  -- grab the UA username (for email address)
  JOIN GENERAL.GOBTPAC usr  ON (
    usr.gobtpac_pidm = emp.pebempl_pidm
  )
  -- pull in the position records/summaries
  JOIN worked ON ( 
    worked.pidm = emp.spriden_pidm
  )
  -- pull in the employee's organization hierarchy (if home dlevel is set)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = emp.pebempl_orgn_code_home
  )
  -- get the mailing address if there is one
  LEFT JOIN SATURN.SPRADDR a ON (
    -- get just the mailing address
        a.spraddr_pidm = emp.pebempl_pidm
    AND a.spraddr_atyp_code = 'MA'
  )
  -- find the supervisor for the current position (if one is assigned)
  LEFT JOIN NER2SUP sup ON (
        emp.nbrbjob_pidm = sup.ner2sup_pidm
    AND emp.nbrbjob_posn = sup.ner2sup_posn
    AND emp.nbrbjob_suff = sup.ner2sup_suff
    AND sup.ner2sup_sup_ind = 'Y'
  )
  -- get the name, id, etc for the supervisor
  LEFT JOIN SPRIDEN boss ON (
    boss.spriden_pidm = sup.ner2sup_sup_pidm
    AND boss.spriden_change_ind IS NULL
  )
  -- get the UA username (for email) of the supervisor
  LEFT JOIN GOBTPAC busr ON 
    boss.spriden_pidm = busr.gobtpac_pidm
WHERE
  -- only primary positions
  emp.nbrbjob_contract_type = 'P'
  -- only the eligible staffers
  AND emp.nbrjobs_ecls_code IN ('NR','NX','XR','XX','EX')
  -- limit to the most current supervisor record (if there is one)
  AND (
       sup.ner2sup_pidm IS NULL 
    OR sup.ner2sup_effective_date = (
      SELECT MAX (sup2.ner2sup_effective_date)
      FROM NER2SUP sup2
      WHERE (
            sup2.ner2sup_sup_ind = 'Y'
        AND sup.ner2sup_pidm = sup2.ner2sup_pidm
        AND sup.ner2sup_posn = sup2.ner2sup_posn
        AND sup.ner2sup_suff = sup2.ner2sup_suff
      )
    )
  )
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
  1 DESC,                             -- sort the folks with milestones first
  dsduaf.f_decode$orgn_campus(
    org.level1
  ),                                  -- then by campus
  round(worked.span / 365.25) DESC,   -- then by longevity years (descending)
  org.title2,                         -- cabinet
  org.title3,                         -- unit
  org.title,                          -- department
  emp.spriden_id                      -- employee
;
