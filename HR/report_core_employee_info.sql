-- =============================================================================
--  SQL For getting information about the current positions for employees.  It
--  includes the labor distribution, position details and current supervisor.
--
--  This script will accept any of the following params
--  @param :uaid     -- UA Employee/Student ID
--  @param :uaname   -- UA Username
--  @param :pidm     -- Unique Banner numeric ID
--  @param :uaemail  -- UA email address (eg; username@alaska.edu)
--  @param :uatkl    -- All employees in that time keeping location
--  @param :uadlevel -- All the employees in a particular department
--  @param :bannerid -- UA Banner ID (ex; FNABC)
--
--  Included RPTP tables 
--    FIMSMGR.FTVFUND
--    GENERAL.GOBEACC
--    GENERAL.GOBTPAC
--    POSNCTL.NBRBJOB
--    POSNCTL.NBRJLBD
--    POSNCTL.NBRJOBS
--    PAYROLL.PEBEMPL
--    REPORTS.FTVORGN_LEVELS
--    SATURN.SPBPERS
--    SATURN.SPRADDR
--    SATURN.SPRIDEN
-- =============================================================================
--
WITH
--| ----------------------------
--| Create the temporary tables
--| ----------------------------
employee_base AS (
  --// Core table of the employee information
  SELECT DISTINCT
    emp.spriden_pidm          AS pidm,
    emp.spriden_id            AS uaid,
    usr.gobtpac_external_user AS uaname,
    ban.gobeacc_username      AS bannerid,
    emp.spriden_last_name || ', ' || coalesce(bio.spbpers_pref_first_name, emp.spriden_first_name) AS full_name,
    usr.gobtpac_external_user || '@alaska.edu' AS email,
    ua.pebempl_orgn_code_home AS dlevel,
    ua.pebempl_orgn_code_dist AS tkl,
    decode (
      ua.pebempl_empl_status,
      'A', 'Active: ' || to_char( ua.pebempl_current_hire_date, 'DD-MON-yy'),
      'T', '  Term: ' || to_char( ua.pebempl_term_date, 'DD-MON-yy'),
      '?'
    )                         AS status,
    CASE
      -- Use the preferred Gender if available, otherwise sex
      WHEN bio.spbpers_gndr_code IS NOT NULL THEN
        DECODE (
          bio.spbpers_gndr_code,
          'A',	 'Agender',
          'DNA', 'Does Not Apply',
          'F',	 'Female',
          'GQ',	 'Genderqueer',
          'M',	 'Male',
          'N',	 'Non-Binary',
          'TF',	 'Transgender Female',
          'TM',	 'Transgender Male',
          bio.spbpers_gndr_code
        )
      ELSE 
        DECODE (
          bio.spbpers_sex,
          'F',	'Female',
          'M',	'Male',
          'N',	'Not Disclosed',
          bio.spbpers_sex
        )
      END                     AS gender
    FROM SATURN.SPRIDEN emp
    INNER JOIN SATURN.SPBPERS  bio ON emp.spriden_pidm = bio.spbpers_pidm
    INNER JOIN PAYROLL.PEBEMPL ua  ON emp.spriden_pidm = ua.pebempl_pidm
    INNER JOIN GENERAL.GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
    LEFT JOIN GENERAL.GOBEACC ban  ON emp.spriden_pidm = ban.gobeacc_pidm
    WHERE emp.spriden_change_ind IS NULL
      AND ua.pebempl_empl_status != 'T'
      AND ( 
          emp.spriden_id            = trim(:uaid) 
       OR emp.spriden_pidm          = trim(:pidm)
       OR usr.gobtpac_external_user = lower(trim(:uaname)) 
       OR usr.gobtpac_external_user = lower( substr(:uaemail, 1, instr(:uaemail, '@') - 1 ) )
       OR ban.gobeacc_username      = upper(:bannerid)
       OR ua.pebempl_orgn_code_dist = upper(:uatkl)
       OR ua.pebempl_orgn_code_home = upper(:uadlevel)
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
      -- limit the rows of positions to just the employees in the temp table
      AND a.nbrjobs_pidm IN ( SELECT pidm FROM employee_base )
  ),
  ranked_labor AS (
    --// temp table ranked by effective date 
    SELECT DISTINCT
      a.*,
      b.level7,
      b.level6,
      b.level5,
      b.level4,
      b.level3,
      c.ftvfund_ftyp_code,
      DENSE_RANK() OVER ( -- use dense_rank() so that the row number is reset for each
                          -- pidm/posn/suff touple
        PARTITION BY a.nbrjlbd_pidm, a.nbrjlbd_posn, a.nbrjlbd_suff 
        ORDER BY a.nbrjlbd_effective_date DESC
      ) as row_no
    FROM POSNCTL.NBRJLBD a
      -- get the org for this labor distribution
      INNER JOIN REPORTS.FTVORGN_LEVELS b ON b.level8 = a.nbrjlbd_orgn_code
      -- get the fund type for this labor
      INNER JOIN FIMSMGR.FTVFUND c ON c.ftvfund_fund_code = a.nbrjlbd_fund_code
    WHERE -- limit the rows of labor to just the employees in the temp table 
      a.nbrjlbd_pidm IN (SELECT DISTINCT pidm FROM employee_base )
  ),
  ranked_address AS (
    SELECT
      a.*,
      ROW_NUMBER() OVER (
        PARTITION BY a.spraddr_pidm
        ORDER BY a.spraddr_seqno DESC
      ) as row_no
    FROM SATURN.SPRADDR a
    WHERE a.spraddr_atyp_code = 'HR'
      -- limit the rows of addresses to just the employees in the temp table
      AND a.spraddr_pidm IN ( SELECT pidm FROM employee_base )
  ),
  ranked_supervisor_date AS (
    SELECT
      a.*,
      ROW_NUMBER() OVER (
        PARTITION BY a.nbrjobs_pidm, a.nbrjobs_posn, a.nbrjobs_suff
        ORDER BY a.nbrjobs_effective_date DESC
      ) as row_no
    FROM POSNCTL.NBRJOBS a
    WHERE a.nbrjobs_jcre_code = 'SPCHG'
  ),
  supervisor_info AS (
    SELECT
      a.spriden_pidm AS pidm,
      a.spriden_id   AS uaid,
      a.spriden_last_name || ', ' || COALESCE(b.spbpers_pref_first_name, a.spriden_first_name) AS name,
      c.gobtpac_external_user || '@alaska.edu' AS email
    FROM SATURN.SPRIDEN a
      INNER JOIN SATURN.SPBPERS b ON a.spriden_pidm = b.spbpers_pidm
      INNER JOIN GENERAL.GOBTPAC c ON a.spriden_pidm = c.gobtpac_pidm
    WHERE a.spriden_change_ind IS NULL
  )
SELECT
  CASE
    WHEN org.level1 = 'UATKL' THEN 'TKL!'
    WHEN org.level1 LIKE '%TOT' THEN substr(org.level1, 0, length(org.level1) - 3)
    ELSE 'ERR!'
  END                         AS "Campus",
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit", 
  org.title                   AS "Department",
  core.dlevel                 AS "Home dLevel", 
  core.tkl                    AS "Home TKL", 
  core.uaid                   AS "UA ID",
  core.uaname                 AS "UA Username",
  core.email                  AS "UA Email Address",
  core.pidm                   AS "Banner #",
  core.bannerid               AS "Banner ID",
  core.full_name              AS "Full Name",
  core.gender                 AS "Gender",
  core.status                 AS "UA Job Status",
  DECODE (
    -- show contract type or '-' if terminated 
    job.nbrbjob_contract_type,
    'P', '1 Primary',
    'S', '2 Secondary',
    'O', '3 Overload',
    '-'
  )                           AS "Contract Type",
  job.nbrbjob_begin_date      AS "Contract Start",
  job.nbrbjob_end_date        AS "Contract End",
  job.nbrbjob_posn 
    || '/' 
    || job.nbrbjob_suff       AS "Position",
  pos.nbrjobs_orgn_code_ts    AS "Pos. TKL",
  pos.nbrjobs_desc            AS "Position Title",
  pos.nbrjobs_ecls_code       AS "Pos. Class",
  pos.nbrjobs_sal_table       AS "Pos. Salary Table",
  pos.nbrjobs_fte             AS "Pos. FTE",
  dist.nbrjlbd_percent        AS "Labor %",
  dist.nbrjlbd_fund_code 
    || '/'
    || dist.nbrjlbd_orgn_code AS "Labor Fund/Org",
  CASE
    -- walk the orgs to see where the dlevel is at
    WHEN dist.level7 LIKE 'D%' THEN dist.level7
    WHEN dist.level6 LIKE 'D%' THEN dist.level6
    WHEN dist.level5 LIKE 'D%' THEN dist.level5
    WHEN dist.level4 LIKE 'D%' THEN dist.level4   
    WHEN dist.level3 LIKE 'D%' THEN dist.level3 
    ELSE 'D?'
  END                         AS "Labor dLevel",
  dist.ftvfund_ftyp_code      AS "Labor Fund Type",
  boss.uaid                   AS "Supervisor UA ID",
  nvl( -- if no supervisor change date, use most recent change date
    to_char(schg.nbrjobs_effective_date, 'MM/DD/YYYY'),
    to_char(pos.nbrjobs_effective_date, 'MM/DD/YYYY')
  )                           AS "Supervisor As Of",
  boss.name                   AS "Supervisor Name",
  boss.email                  AS "Supervisor Email",
  adr.spraddr_street_line1 || ', '
    || adr.spraddr_street_line2 || ', '
    || adr.spraddr_city || ', '
    || adr.spraddr_stat_code || ', '
    || adr.spraddr_zip       AS "HR Address"
FROM
  -- start with the core employee info
  employee_base core
  -- join to find the org hierarchy for this person's department (if assigned)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = core.dlevel
  )
  -- get information about this person's current base UA job (if it exists)
  LEFT JOIN POSNCTL.NBRBJOB job  ON (
        job.nbrbjob_pidm = core.pidm
    -- uncomment to limit to just current primary position
    -- AND job.nbrbjob_contract_type = 'P'
    -- -----------------------------------
    AND job.nbrbjob_begin_date <= CURRENT_DATE
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
  -- join in the windowed labor (use ranking to get current one)
  LEFT JOIN ranked_labor dist ON (
        dist.nbrjlbd_pidm = core.pidm
    AND dist.nbrjlbd_posn = pos.nbrjobs_posn
    AND dist.nbrjlbd_suff = pos.nbrjobs_suff
    AND dist.row_no = 1
  ) 
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN supervisor_info boss  ON (
    boss.pidm = pos.nbrjobs_supervisor_pidm
  )
  -- grab the last change date for the supervisor (if any)
  LEFT JOIN ranked_supervisor_date schg ON (
        schg.nbrjobs_pidm = pos.nbrjobs_pidm
    AND schg.nbrjobs_posn = pos.nbrjobs_posn
    AND schg.nbrjobs_suff = pos.nbrjobs_suff
    AND schg.row_no = 1
  )
  -- grap HR address (if any)
  LEFT JOIN ranked_address adr ON (
        adr.spraddr_pidm = core.pidm
    AND adr.row_no = 1
  )
ORDER BY
  core.uaid,
  DECODE (
    job.nbrbjob_contract_type,
    'P', '1 Primary',
    'S', '2 Secondary',
    'O', '3 Overload',
    '-'
  ),
  dist.nbrjlbd_percent DESC
;