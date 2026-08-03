-- =============================================================================
--  SQL for pulling in core informaiton for all UA employees.  It is intended to 
-- be used for filling a HR Employee Profile (eform) document.  These pages will
-- then be used to build employee folders and Exception Reports for any missing
-- record documents.  
--  It is not intended for any autofills.
--
--  Included RPTP tables 
--    GENERAL.GOBTPAC
--    POSNCTL.NBRBJOB
--    POSNCTL.NBRJOBS
--    PAYROLL.PEBEMPL
--    REPORTS.FTVORGN_LEVELS
--    SATURN.SPBPERS
--    SATURN.SPRADDR
--    SATURN.SPRIDEN
-- =============================================================================
--
WITH
 -- |++++++++++++++++++++++++++++|
 -- | Create the CTEs and Ranked |
 -- | temporary tables           |
 -- |++++++++++++++++++++++++++++|
 employee_base AS (
  --// Core table of the employee information
  SELECT DISTINCT
    emp.spriden_pidm            AS pidm,
    emp.spriden_id              AS uaid,
    usr.gobtpac_external_user   AS ua_name,
    emp.spriden_last_name       AS l_name, 
    emp.spriden_first_name      AS f_name,
    substr(
      emp.spriden_mi,1,1
    )                           AS m_name,
    bio.spbpers_pref_first_name AS p_name,
    usr.gobtpac_external_user || '@alaska.edu' AS email,
    ua.pebempl_orgn_code_home   AS dlevel,
    ua.pebempl_orgn_code_dist   AS tkl,
    ua.pebempl_empl_status      AS status,
    to_char( 
      ua.pebempl_current_hire_date, 'mm/dd/yyyy'
    )                           AS hire_date, 
    to_char( 
      ua.pebempl_term_date, 'mm/dd/yyyy'
    )                           AS term_date,
    bio.spbpers_dead_ind        AS deceased
    FROM SATURN.SPRIDEN emp
    INNER JOIN SATURN.SPBPERS  bio ON emp.spriden_pidm = bio.spbpers_pidm
    INNER JOIN PAYROLL.PEBEMPL ua  ON emp.spriden_pidm = ua.pebempl_pidm
    INNER JOIN GENERAL.GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
    WHERE 
      -- only the current, valid spriden record
          emp.spriden_change_ind IS NULL
      AND emp.spriden_id NOT LIKE '%BAD%'
      -- only Active employees or those terminated in the last year
      AND (
           ua.pebempl_empl_status = 'A'
        OR ua.pebempl_term_date >= SYSDATE - 365
      )
  ),
  ranked_positions AS (
    --// Temp table ranked by effective date of active positions
    SELECT 
      a.*, 
      DENSE_RANK() OVER (
        PARTITION BY a.nbrjobs_pidm, a.nbrjobs_posn, a.nbrjobs_suff 
        ORDER BY a.nbrjobs_effective_date DESC
      ) as row_no
    FROM POSNCTL.NBRJOBS a
    WHERE 
      -- only include currently active positions
      a.nbrjobs_status = 'A'
      -- only consider position changes that are before today
      AND a.nbrjobs_effective_date <= SYSDATE
      -- limit the rows of positions to just the employees in the temp table
      AND a.nbrjobs_pidm IN ( SELECT pidm FROM employee_base )
  ),
  ranked_address AS (
    --// Temp table of HR address (or MA fallback) for each employee.
    SELECT
      a.*,
      ROW_NUMBER() OVER (
        PARTITION BY a.spraddr_pidm
        ORDER BY 
          -- Force HR to rank #1, MA to rank #2
          CASE WHEN a.spraddr_atyp_code = 'HR' THEN 1 ELSE 2 END ASC,
          -- Tie-breaker: get the most recent sequence number
          a.spraddr_seqno DESC
      ) as row_no
    FROM SATURN.SPRADDR a
    WHERE a.spraddr_atyp_code IN ('HR', 'MA')
      -- limit the rows of addresses to just the employees in the temp table
      AND a.spraddr_pidm IN ( SELECT pidm FROM employee_base )
  )
  SELECT
  -- Demographics
  core.uaid                   AS "UAID",
  core.ua_name                AS "UA Username",
  core.f_name                 AS "First Name",
  core.m_name                 AS "Middle Initial",
  core.l_name                 AS "Last Name",
  core.p_name                 AS "Preferred Name",
  core.deceased               AS "Is Deceased",
  -- Organization
  DECODE (
    substr(org.level1, 0, length(org.level1) - 3),
    'UAA', 'A',
    'UAF', 'F',
    'UAS', 'J',
    'SW',  'SW',
    'UAT', 'TKL!',  -- this is actually an error and indicates 
    '??'            -- putting a TKL in pebempl_orgn_code_home
  )                           AS "Campus",
  core.tkl                    AS "TKL",
  core.dlevel                 AS "dLevel",
  org.title3                  AS "Unit",
  org.title                   AS "Department",
  -- Employment
  core.status                 AS "Status",
  core.hire_date              AS "Current Hire Date",
  core.term_date              AS "Termination Date",
  pos.nbrjobs_ecls_code       AS "Position ECLS",
  pos.nbrjobs_posn            AS "Position Code",
  pos.nbrjobs_suff            AS "Position SUffix",
  (
    SELECT 
      DECODE (
        nbbposn_barg_code,
        'AC', 'UNAC - Rep Faculty',
        'AD', 'UNAD - Rep Adjuncts', 
        'AG', 'AGWA - Rep Grad Workers',
        'CS', 'CAUSE - Rep Staff',
        'FF', 'IAFF - Rep Firefighters',
        'L6', 'L6070 - Rep Crafts/Trades', 
        'NB', 'Non-Represented',
        '?? - ' || nbbposn_barg_code
      ) AS unit
    FROM POSNCTL.NBBPOSN
    WHERE nbbposn_posn = job.nbrbjob_posn
  )                           AS "Bargaining Unit",
  to_char( 
    job.nbrbjob_begin_date, 'mm/dd/yyyy'
  )                           AS "Contract Start",
  to_char( 
    job.nbrbjob_end_date, 'mm/dd/yyyy'
  )                           AS "Contract End",
  pos.nbrjobs_desc            AS "Position Title",
  adr.spraddr_street_line1    AS "Address Line 1", 
  adr.spraddr_street_line2    AS "Address Line 2",
  adr.spraddr_city            AS "Address City",
  adr.spraddr_stat_code       AS "Address State",
  adr.spraddr_zip             AS "Address ZIP"
FROM
  employee_base core
  -- get the organizational information (if any)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = core.dlevel
  )
  -- get information about this person's current base UA job (if it exists)
  LEFT JOIN POSNCTL.NBRBJOB job  ON (
        job.nbrbjob_pidm = core.pidm
    -- only get the primary position
    AND job.nbrbjob_contract_type = 'P'
    -- only get positions that started prior to today    
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    -- only positions that have no end date or end after today
    AND ( 
         job.nbrbjob_end_date >= CURRENT_DATE 
      OR job.nbrbjob_end_date IS NULL
    )
  )
  -- join in the windowed positions (use ranking to get current one)
  LEFT JOIN ranked_positions pos ON (
        pos.nbrjobs_pidm = core.pidm
    AND pos.nbrjobs_posn = job.nbrbjob_posn
    AND pos.nbrjobs_suff = job.nbrbjob_suff
    AND pos.row_no = 1
  )
  -- grap HR address (if any)
  LEFT JOIN ranked_address adr ON (
        adr.spraddr_pidm = core.pidm
    AND adr.row_no = 1
  )
ORDER BY 
  
;
