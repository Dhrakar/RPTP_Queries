WITH
  all_positions AS (
    SELECT
      job.nbrbjob_pidm                                AS pidm,
      job.nbrbjob_posn                                AS posn,
      job.nbrbjob_suff                                AS suff,
      job.nbrbjob_contract_type                       AS contract_type,
      job.nbrbjob_begin_date                          AS begin_date,
      -- if the job is ongoing or extends past the milestone cut-off, 
      -- pick the last day of the CY as the end
      CASE
        WHEN (job.nbrbjob_end_date IS NULL) 
          or (job.nbrbjob_end_date > to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy'))
        THEN to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy')
        ELSE job.nbrbjob_end_date
      END                                             AS end_date
    FROM
      -- start with table of all base job position
      POSNCTL.NBRBJOB job
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
      job.nbrbjob_contract_type in ('P')
      -- limit the eligible previous positions
      AND pos.nbrjobs_ecls_code IN (
  --    'A9', --'Faculty'
  --    'AR', --'Faculty'
      'EX', --'Officers/Sr. Administrators'
  --    'F9', --'Faculty'
  --    'FN', --'Faculty'
  --    'FR', --'Officers/Sr. Administrators'
  --    'FT', --'Adjunct Faculty'
  --    'FW', --'Adjunct Faculty'
      'CR', --'Staff'
  --    'CT', --'Staff'
      'NR', --'Staff'
  --    'NT', --'Staff'
      'NX', --'Staff'
      'XR', --'Staff'
  --    'XT', --'Staff'
      'XX', --'Staff'
--      'GN', --'Student'
--      'GT', --'Student'
--      'SN', --'Student'
--      'ST', --'Student'
      '00' -- dummy value to keep from futzing with the trailing comma when commenting/uncommenting
      )
  ),
  posn_days AS (
    SELECT
      ap.pidm      AS pidm,
      -- total days of the eligible positions
      (ap.end_date - ap.begin_date) AS days
    FROM 
      all_positions ap
  ),
  total_days AS (
    SELECT
      pd.pidm AS pidm,
      -- add togethere the days from all positions
      sum(pd.days) as pos_days,
      -- get any days of pre-banner time
      greatest(
        (-- get the person's orig hire date
          SELECT (to_date('01/01/1996', 'mm/dd/yyyy') - pebempl_first_hire_date)
          FROM PAYROLL.PEBEMPL
          WHERE pebempl_pidm = pd.pidm 
        ),0
      ) AS pre_banner_days
    FROM
      posn_days pd
    GROUP BY 
      pd.pidm
  )
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
--  emp.pebempl_pidm                     AS "Banner PIDM",
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
    adr.spraddr_pidm,
    adr.spraddr_street_line1 
    || ', ' || adr.spraddr_city 
    || ', ' || adr.spraddr_stat_code 
    || ', ' || adr.spraddr_zip,
    null
  )                                    AS "Mailing Address",
  nvl2(rem.pprcert_pidm,'Yes',' ')     AS "Remote  Agreement",
  emp.nbrjobs_ecls_code                AS "ECLS",
  emp.pebempl_first_hire_date          AS "Original Hire Date",
  emp.pebempl_adj_service_date         AS "Curr. Adj. Service Date",
  emp.nbrbjob_begin_date               AS "Curr. Position Start Date",
  emp.nbrbjob_end_date                 AS "Curr. Position End Date",
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
    - emp.pebempl_adj_service_date
    ) / 365.25
  )                                    AS "HR Adj. Years", 
  round(
    (td.pre_banner_days / 365.25), 1
  )                                    AS "Pre-Banner Years",
  round(
    (td.pos_days / 365.25), 1
  )                                    AS "Elig. Service Years",
  -- note that this sum adds the raw days and not years to avoid rounding errors
  floor(
    (td.pos_days + td.pre_banner_days) / 365.25
  )                                    AS "Cumulative Serv. Years",
  floor(
    ( to_date('12/31/' || (:milestone_year), 'mm/dd/yyyy') 
    - emp.pebempl_first_hire_date
    ) / 365.25
  )                                    AS "Years UA Employee",
  -- flag if this is a milestone year
  CASE
    WHEN mod(floor((td.pos_days + td.pre_banner_days) / 365.25), 5) = 0 THEN 'Y'
    ELSE 'N'
  END                                  AS "Milestone?"
FROM
  -- start with the set of current employees
  REPORTS.N_ACTIVE_JOBS emp
  -- get the demographic data
  INNER JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = emp.pebempl_pidm
  )
  -- get the UA username (for email address)
  INNER JOIN GENERAL.GOBTPAC usr  ON (
    usr.gobtpac_pidm = emp.pebempl_pidm
  )
  -- get the cumulative position days and any banner days
  INNER JOIN total_days td ON (
    td.pidm = emp.pebempl_pidm
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
  LEFT JOIN SATURN.SPRADDR adr ON (
    -- get just the mailing address
        adr.spraddr_pidm = emp.pebempl_pidm
    AND adr.spraddr_atyp_code = 'MA'
  )
  LEFT JOIN PAYROLL.PPRCERT rem ON (
        rem.pprcert_pidm = emp.pebempl_pidm
    AND rem.pprcert_cert_code LIKE 'REM%'
    AND rem.pprcert_expire_date IS NULL
  )
WHERE
  -- only primary positions
  emp.nbrbjob_contract_type = 'P'
  -- only the eligible staffers
  AND emp.nbrjobs_ecls_code IN ('NR','NX','XR','XX', 'CR', 'EX')
  -- only the most current mailing address (if there is one)
  AND (
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
  -- first by campus
  dsduaf.f_decode$orgn_campus( org.level1 ),
  -- then sort the folks with milestones first
  CASE WHEN mod(floor((td.pos_days + td.pre_banner_days) / 365.25), 5) = 0 THEN 'Y' ELSE 'N' END DESC,   
  -- then by longevity years (descending)
  floor( (td.pos_days + td.pre_banner_days) / 365.25 ) DESC, 
  org.title2,                         -- cabinet
  org.title3,                         -- unit
  org.title,                          -- department
  emp.spriden_id                      -- employee
;

select 
  floor((SYSDATE - to_date('07/27/1994', 'mm/dd/yyyy')) / 365.25) as years, 
  (to_date('01/01/1996', 'mm/dd/yyyy') - to_date('07/27/1994', 'mm/dd/yyyy')) as days,
  floor((to_date('01/01/1996', 'mm/dd/yyyy') - to_date('07/27/1994', 'mm/dd/yyyy')) / 365.25) as yos
from dual;