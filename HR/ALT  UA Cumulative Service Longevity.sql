WITH
  emp AS (
    -- Uses the daily view of all current job positions to build a temp 
    -- table of current employees.  Only primary positions and folks 
    -- eligible for staff recognition
    SELECT
      a.spriden_pidm               AS pidm,
      a.spriden_id                 AS uaid,
      a.spriden_last_name          AS last_name,
      a.spriden_first_name         AS first_name,
      substr (a.spriden_mi,1,1)    AS middle_init,
      a.nbrjobs_ecls_code          AS ecls,
      a.pebempl_first_hire_date    AS orig_hire,
      a.pebempl_adj_service_date   AS adj_service,
      a.nbrbjob_begin_date         AS pos_start,
      a.nbrbjob_end_date           AS pos_end,
      a.nbrjobs_supervisor_pidm    AS boss_pidm,
      a.pebempl_orgn_code_home     AS dlevel,
      a.pebempl_orgn_code_dist     AS tkl
    FROM
      REPORTS.N_ACTIVE_JOBS a
    WHERE
      -- only primary positions
      a.nbrbjob_contract_type = 'P'
      -- only the eligible staffers
      AND a.nbrjobs_ecls_code IN ('NR','XR','CR','EX')
  ),
  primary_jobs AS (
    -- creates a temp table of all of the primary positions that have 
    -- been held by the current employees.  
        SELECT
      job.nbrbjob_pidm pidm,
      job.nbrbjob_posn posn,
      job.nbrbjob_suff suff,
      job.nbrbjob_contract_type contract_type,
      pos.nbrjobs_ecls_code ecls,
      job.nbrbjob_begin_date                          AS begin_date,
      -- if the job is ongoing, pick the last day of the CY as the end
      CASE
        WHEN (job.nbrbjob_end_date IS NULL) 
          or (job.nbrbjob_end_date > to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy'))
        THEN to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy')
        ELSE job.nbrbjob_end_date
      END AS end_date
    FROM
      -- start with table of all base job position
      POSNCTL.NBRBJOB job
      -- limit to just the current employees to keep the table size sane
      INNER JOIN emp ON emp.pidm = job.nbrbjob_pidm
      -- find the corresponding, current positions
      INNER JOIN POSNCTL.NBRJOBS pos ON (
            pos.nbrjobs_pidm = job.nbrbjob_pidm
        AND pos.nbrjobs_posn = job.nbrbjob_posn
        AND pos.nbrjobs_suff = job.nbrbjob_suff
        AND pos.nbrjobs_effective_date = (
          SELECT max(pos2.nbrjobs_effective_date)
          FROM POSNCTL.NBRJOBS pos2
          WHERE pos2.nbrjobs_pidm = job.nbrbjob_pidm
            AND pos2.nbrjobs_posn = job.nbrbjob_posn
            AND pos2.nbrjobs_suff = job.nbrbjob_suff
            -- filter out any updates from past the milestone date
            AND pos2.nbrjobs_effective_date <= to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy')
        )
      )
    WHERE
      -- limit to just primary jobs
      job.nbrbjob_contract_type = 'P'
      -- limit by ECLS type of previous positions
      AND ( 
          -- include full-time benefitted positions
          pos.nbrjobs_ecls_code IN ( 'EX', 'CR', 'NR', 'NX', 'XR', 'XX' )
          -- uncomment to include student positions
          OR pos.nbrjobs_ecls_code IN ('SN','ST','GN','GT')
          -- uncomment to include faculty positions
          OR pos.nbrjobs_ecls_code IN ('A9','AR','F9','FN','FR','FW') 
          -- uncomment out to include temporary positions
          OR pos.nbrjobs_ecls_code IN ('CT','FT','NT','XT')
      )
  ),
  prim_days AS (
    -- build a temp table of the day spans for each job. A temp table saves
    -- needing to do a bunch of groups for the final select
    SELECT
      a.pidm      AS pidm,
      -- total days of the eligible positions
      sum(
        (a.end_date - a.begin_date)
      )           AS days
    FROM 
      primary_jobs a
    GROUP BY
      a.pidm
  )
SELECT DISTINCT
  to_date(
    '31-DEC-' || :milestone_year, 
    'DD-MON-YYYY')                     AS "Milestone Cut-Off Date",
  -- flag if this is a milestone year (eg; div by 5)
  CASE
    WHEN mod(
           floor(
             (  prim_days.days 
              + greatest( 
                  (to_date('01/01/1996', 'mm/dd/yyyy') - emp.orig_hire)
                  ,0
                )
             ) / 365.25
           ), 5
            
         ) = 0 THEN 'Y'
    ELSE 'N'
  END                                  AS "Milestone?",
  SYSDATE                              AS "As Of Date",
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                                    AS "Campus",
  org.title2                           AS "Cabinet",
  org.title3                           AS "Unit",
  org.title                            AS "Department",
  emp.tkl                              AS "TKL",
  emp.pidm,
  emp.uaid                             AS "UAID",
  usr.gobtpac_external_user 
    || '@alaska.edu'                   AS "UA Email",
  emp.last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.first_name 
       )
    || ' ' 
    || substr ( emp.middle_init,1,1)                      
                                       AS "Full Name",
  nvl2(
    adr.spraddr_pidm,
    adr.spraddr_street_line1 
    || ', ' || adr.spraddr_city 
    || ', ' || adr.spraddr_stat_code 
    || ', ' || adr.spraddr_zip,
    null
  )                                    AS "Mailing Address",
  nvl2(rem.pprcert_pidm,'Yes',' ')     AS "Remote  Agreement",
  emp.ecls                             AS "ECLS",
  emp.orig_hire                        AS "Original Hire Date",
  emp.adj_service                      AS "Curr. Adj. Service Date",
  emp.pos_start                        AS "Curr. Position Start Date",
  emp.pos_end                          AS "Curr. Position End Date",
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
  floor(
    ( to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy') 
    - emp.adj_service
    ) / 365.25
  )                                    AS "HR Adj. Years",                                    AS "Sec. Posn Serv. Years", 
  round( 
    greatest( 
      (to_date('01/01/1996', 'mm/dd/yyyy') - emp.orig_hire),0
    ) / 365.25, 1
  )                                    AS "Pre-Banner Serv. Years",
  round(
    (prim_days.days / 365.25), 1
  )                                    AS "Elig. Service Years",
  -- add together the days of pre-banner (if any) and the total elig primary days
  -- do the division last to minimize rounding errors
  floor(
    (prim_days.days + greatest( (to_date('01/01/1996', 'mm/dd/yyyy') - emp.orig_hire),0)) / 365.25
  )                                    AS "Total Service Years",
  floor(
    ( to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy') 
    - emp.orig_hire
    ) / 365.25
  )                                    AS "Total Years at UA"
FROM
  -- start with curr employees
  emp
  -- collect the primary position timespans (for testing)
  INNER JOIN primary_jobs ON (
    primary_jobs.pidm = emp.pidm
  )
  -- get the totals for the primary eligible positions
  INNER JOIN prim_days ON (
    prim_days.pidm = emp.pidm
  )
  -- get the demographic data
  INNER JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = emp.pidm
  )
  -- get the UA username (for email address)
  INNER JOIN GENERAL.GOBTPAC usr  ON (
    usr.gobtpac_pidm = emp.pidm
  )
  -- pull in the employee's organization hierarchy (if home dlevel is set)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = emp.dlevel
  )
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN SATURN.SPRIDEN boss  ON (
    boss.spriden_pidm = emp.boss_pidm
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
  LEFT JOIN SATURN.SPRADDR adr ON (
    -- get just the mailing address
        adr.spraddr_pidm = emp.pidm
    AND adr.spraddr_atyp_code = 'MA'
  )
  -- get the local/remote status
  LEFT JOIN PAYROLL.PPRCERT rem ON (
        rem.pprcert_pidm = emp.pidm
    AND rem.pprcert_cert_code LIKE 'REM%'
    AND rem.pprcert_expire_date IS NULL
  )
WHERE
  -- only the most current mailing address (if there is one)
  (
    adr.spraddr_pidm IS NULL
    OR adr.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        adr.spraddr_pidm = a2.spraddr_pidm
        AND a2.spraddr_atyp_code = 'MA'
    )
  )
ORDER BY
  dsduaf.f_decode$orgn_campus(org.level1), -- campus
  2, -- milestone flag         
  org.title2, -- cabinet
  org.title3, -- unit
  org.title, -- department
  emp.uaid
;
      