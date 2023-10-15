-- =============================================================================
--      Staff Longevity report
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
  /*
   * Build temporary table of employees and position durations
   * - only include primary, eligible positions that start before the end of
   *   the longevity year
   * - for positions that end after the Dec 31 cutoff, or that have no end date,
   *   use Dec 31 of the longevity year to calculate number of days in position
   */
  worked AS (
    SELECT
      pos.nbrbjob_pidm      AS pidm,
      -- get a sum of the total days for all eligible positions
      SUM (
        CASE
          -- if there is no poition end date, use the end of the longevity year
          WHEN pos.nbrbjob_end_date IS NULL 
            THEN to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - pos.nbrbjob_begin_date
          -- otherwise get the number of days for this position
          ELSE pos.nbrbjob_end_date - pos.nbrbjob_begin_date
        END 
      )                     AS span 
    FROM
      POSNCTL.NBRBJOB pos
      -- add a filter for getting just the full-time, benefitted positions
      JOIN POSNCTL.NBRJOBS rec ON (
            pos.nbrbjob_pidm = rec.nbrjobs_pidm
        AND pos.nbrbjob_posn = rec.nbrjobs_posn
        AND pos.nbrbjob_suff = rec.nbrjobs_suff
        AND rec.nbrjobs_ecls_code IN ('CR', 'NR', 'XR', 'EX')
      )
    WHERE
      -- only include the Primary positions
      pos.nbrbjob_contract_type = 'P'
      -- grab only the positions that have already started
      AND pos.nbrbjob_begin_date < to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy')
      -- only grab the most recent jobs record
      AND rec.nbrjobs_effective_date = (     
        SELECT MAX (pos2.nbrjobs_effective_date)
        FROM POSNCTL.NBRJOBS pos2
        WHERE (
              rec.nbrjobs_pidm = pos2.nbrjobs_pidm
          AND rec.nbrjobs_posn = pos2.nbrjobs_posn
          AND rec.nbrjobs_suff = pos2.nbrjobs_suff
        -- just position changes that are before the end of the longevity year
          AND pos2.nbrjobs_effective_date < to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy')
        )
      )
    GROUP BY
      pos.nbrbjob_pidm
  )
SELECT
  -- this col has a 'Y' if this employee's longevity is a milestone year
  CASE 
    WHEN 
      CASE -- if the employee's longevity using the adj service date is greater than that using the calculated days, the use the adj service date
        WHEN (trunc(worked.span / 365.25)) > trunc(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25)) THEN trunc(worked.span / 365.25) 
        ELSE trunc(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25))
      END  IN (1,5,10,15,20,25,30,35,40,45,50) THEN 'Y'
    ELSE 'N'
  END                            AS "Milestone Year",
  -- show the total longevity years (from adj service date is higher, or calulated days otherwise)
  CASE 
    WHEN (trunc(worked.span / 365.25)) > trunc(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25)) THEN trunc(worked.span / 365.25) 
    ELSE trunc(( (to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date) / 365.25))
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
   || coalesce (
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
  emp.pebempl_first_hire_date    AS "Original Hire Date",
  CASE -- set the flag for folks hired prior to 1996
    WHEN to_date('01/01/1996', 'mm/dd/yyyy') > emp.pebempl_first_hire_date THEN 'Y'
    ELSE 'N'
  END                            AS "Pre-Banner",
  emp.nbrjobs_ecls_code          AS "Curr. Position ECLS",
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
  trunc (
    worked.span / 365.25
  )                              AS "Calc. Service Years",
  trunc (
    ( to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy') - emp.pebempl_adj_service_date ) / 365.25
  )                              AS "Adj. Service Years"
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
  -- pull in the position records/summaries temporary table
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
  -- get the name, id, etc for the supervisor (if one is assigned)
  LEFT JOIN SPRIDEN boss ON (
    boss.spriden_pidm = sup.ner2sup_sup_pidm
    AND boss.spriden_change_ind IS NULL
  )
  -- get the UA username (for email) of the supervisor (if one is assigned)
  LEFT JOIN GOBTPAC busr ON 
    boss.spriden_pidm = busr.gobtpac_pidm
WHERE
  -- only primary positions
  emp.nbrbjob_contract_type = 'P'
  -- only the eligible staffers
  AND emp.nbrjobs_ecls_code IN ('CR', 'NR', 'XR', 'EX')
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
  trunc(worked.span / 365.25) DESC,   -- then by longevity years (descending)
  org.title2,                         -- cabinet
  org.title3,                         -- unit
  org.title,                          -- department
  emp.spriden_id                      -- employee
;

