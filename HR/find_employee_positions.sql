-- =============================================================================
--  SQL For getting information about the current positions for employees.  It
--  includes the labor distribution, position details and current supervisor.
--
--  This script will accept any of the following params
--  @param :uaid     -- UA Employee/Student ID
--  @param :username -- UA Username
--  @param :pidm     -- Unique Banner numeric ID
--  @param :uaemail  -- UA email address (eg; username@alaska.edu)
--  @param :uatkl    -- All employees in that time keeping location
--  @param :uadlevel -- All the employees in a particular department
--  @param :bannerid -- UA Banner ID (ex; FNABC)
--
--  Included RPTP tables
--   SPRIDEN, GOBTPAC, GOBEACC, NBRBJOB, NBRJOBS, NBRJLBD, FTVFUND, 
--   FTVORGN_LEVELS
-- =============================================================================
SELECT DISTINCT
  CASE
    WHEN org.level1 = 'UATKL' THEN 'TKL'
    WHEN org.level1 LIKE '%TOT' THEN substr(org.level1, 0, length(org.level1) - 3)
    ELSE 'ZZZ'
  END                         AS "Campus",
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit", org.level4,
  org.title                   AS "Department",
  ua.pebempl_orgn_code_home   AS "Home dLevel", 
  ua.pebempl_orgn_code_dist   AS "Home TKL", 
  dsduaf.f_sc_units(
    org.level3
  )                           AS "SC Unit",
  emp.spriden_id              AS "UA ID",
  usr.gobtpac_external_user   AS "UA Username",
  emp.spriden_pidm            AS "Banner #",
  ban.gobeacc_username        AS "Banner ID",
  emp.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.spriden_first_name 
       )
    || ' ' 
    || substr ( emp.spriden_mi,1,1)                      
                              AS "Full Name",
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
    END                       AS "Gender",
  decode (
    ua.pebempl_empl_status,
    'A', 'Active: ' || to_char( ua.pebempl_current_hire_date, 'DD-MON-yy'),
    'T', '  Term: ' || to_char( ua.pebempl_term_date, 'DD-MON-yy'),
    '?'
  )                           AS "UA Status",
  -- ua.pebempl_first_hire_date  AS "First Hired",
  -- ua.pebempl_adj_service_date AS "Adj Service Start",
  DECODE (
    -- show contract type or '-' if terminated 
    job.nbrbjob_contract_type,
    'P', 'Primary',
    'S', 'Secondary',
    'O', 'Overload',
    '-'
  )                           AS "Contract Type",
  job.nbrbjob_begin_date      AS "Contract Start",
  job.nbrbjob_end_date        AS "Contract End",
  job.nbrbjob_posn 
    || '/' 
    || job.nbrbjob_suff       AS "Position",
  dist.nbrjlbd_percent        AS "Labor %",
  dist.nbrjlbd_fund_code 
    || '/'
    || dist.nbrjlbd_orgn_code AS "Labor Fund/Org",
  CASE
    WHEN jorg.level7 LIKE 'D%' THEN jorg.level7
    WHEN jorg.level6 LIKE 'D%' THEN jorg.level6
    WHEN jorg.level5 LIKE 'D%' THEN jorg.level5
    WHEN jorg.level4 LIKE 'D%' THEN jorg.level4   
    WHEN jorg.level3 LIKE 'D%' THEN jorg.level3 
    ELSE 'D?'
  END                         AS "Labor dLevel",
  ftyp.ftvfund_ftyp_code      AS "Labor Fund Type",
  pos.nbrjobs_orgn_code_ts    AS "Pos. TKL",
  pos.nbrjobs_desc            AS "Position Title",
  pos.nbrjobs_ecls_code       AS "Pos. Class",
  pos.nbrjobs_sal_table       AS "Pos. Salary Table",
  pos.nbrjobs_fte             AS "Pos. FTE",
  nvl( -- if no supervisor change date, use most recent change date
    to_char(chg.nbrjobs_effective_date, 'MM/DD/YYYY'),
    to_char(pos.nbrjobs_effective_date, 'MM/DD/YYYY')
  )                           AS "Supervisor As Of",
  boss.spriden_id             AS "Supervisor UA ID",
  boss.spriden_last_name 
    || ', ' 
    || coalesce (
        bbio.spbpers_pref_first_name,
        boss.spriden_first_name 
       )                     AS "Supervisor Name",
  busr.gobtpac_external_user
    || '@alaska.edu'         AS "Supervisor Email",
  adr.spraddr_street_line1 || ', '
    || adr.spraddr_street_line2 || ', '
    || adr.spraddr_city || ', '
    || adr.spraddr_stat_code || ', '
    || adr.spraddr_zip       AS "HR Address"
FROM
  -- start with the identity table
  SATURN.SPRIDEN emp
  -- join with biographical info for each person
  INNER JOIN SATURN.SPBPERS bio  ON emp.spriden_pidm = bio.spbpers_pidm
  -- join with core employee information (and limit to just UA employees)
  INNER JOIN PAYROLL.PEBEMPL ua  ON emp.spriden_pidm = ua.pebempl_pidm
  -- join with SSO username informaiton (eg; Google username)
  INNER JOIN GENERAL.GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
  -- join with the Banner login information (if exists)
  LEFT JOIN GENERAL.GOBEACC ban  ON emp.spriden_pidm = ban.gobeacc_pidm
  -- get information about this person's current base UA job (if it exists)
  LEFT JOIN POSNCTL.NBRBJOB job  ON (
        emp.spriden_pidm = job.nbrbjob_pidm
    -- uncomment to limit to just current primary position
    -- AND job.nbrbjob_contract_type = 'P'
    -- -----------------------------------
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    AND ( 
         job.nbrbjob_end_date >= CURRENT_DATE 
      OR job.nbrbjob_end_date IS NULL
    )
  )
  -- get information about this person's current UA position(s) (if any exist)
  LEFT JOIN POSNCTL.NBRJOBS pos  ON ( 
    job.nbrbjob_pidm = pos.nbrjobs_pidm
    AND job.nbrbjob_posn = pos.nbrjobs_posn
    AND job.nbrbjob_suff = pos.nbrjobs_suff
  )
  -- get the effective date of the supervisor change (if any)
  LEFT JOIN POSNCTL.NBRJOBS chg ON (
        chg.nbrjobs_pidm = pos.nbrjobs_pidm
    AND chg.nbrjobs_posn = pos.nbrjobs_posn
    AND chg.nbrjobs_suff = pos.nbrjobs_suff
    AND chg.nbrjobs_jcre_code = 'SPCHG'
  )
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN SATURN.SPRIDEN boss  ON (
    boss.spriden_pidm = pos.nbrjobs_supervisor_pidm
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
  -- join with the labor distributions for thie persons positions (if any exist)
  LEFT JOIN POSNCTL.NBRJLBD dist ON ( 
        job.nbrbjob_pidm = dist.nbrjlbd_pidm
    AND job.nbrbjob_posn = dist.nbrjlbd_posn
    AND job.nbrbjob_suff = dist.nbrjlbd_suff
  )
  -- join to find the org hierarchy for this person's department (if assigned)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = ua.pebempl_orgn_code_home
  )
  -- join to find org hierarchy for the labor funds (if any)
  LEFT JOIN REPORTS.FTVORGN_LEVELS jorg ON (
    jorg.level8 = dist.nbrjlbd_orgn_code
  )
  -- join for details about the labor funds (if any)
  LEFT JOIN FIMSMGR.FTVFUND ftyp ON (
    dist.nbrjlbd_fund_code = ftyp.ftvfund_fund_code
  )
  -- join to grab the most recent HR address for this person (if any)
  LEFT JOIN SATURN.SPRADDR adr ON (
        adr.spraddr_pidm = emp.spriden_pidm
    AND adr.spraddr_atyp_code = 'HR'
  )
WHERE
  ( 
    -- various filter options
    emp.spriden_id = trim(:uaid) 
 OR emp.spriden_pidm = trim(:pidm)
 OR usr.gobtpac_external_user = lower(trim(:uaname)) 
 OR usr.gobtpac_external_user = lower( substr(:uaemail, 1, instr(:uaemail, '@') - 1 ) )
 OR ua.pebempl_orgn_code_dist = upper(:uatkl)
 OR ua.pebempl_orgn_code_home = upper(:uadlevel)
 OR ban.gobeacc_username = upper(:bannerid)
  )
  -- uncomment to only include currently active employees
   AND ua.pebempl_empl_status != 'T'
  -- only include the current person records for the employee
  AND emp.spriden_change_ind IS NULL
  -- limit to the most current position (if exists)
  AND (
       pos.nbrjobs_pidm IS NULL 
    OR pos.nbrjobs_effective_date = (     
      SELECT MAX (pos2.nbrjobs_effective_date)
      FROM POSNCTL.NBRJOBS pos2
      WHERE (
            pos.nbrjobs_pidm = pos2.nbrjobs_pidm
        AND pos.nbrjobs_posn = pos2.nbrjobs_posn
        AND pos.nbrjobs_suff = pos2.nbrjobs_suff
      )
    )
  )
  -- find the most recent supervisor change (if any)
  AND (
    chg.nbrjobs_effective_date IS NULL 
    OR chg.nbrjobs_effective_date = (
    SELECT MAX(i.nbrjobs_effective_date)
    FROM POSNCTL.NBRJOBS i
    WHERE i.nbrjobs_pidm = pos.nbrjobs_pidm
      AND i.nbrjobs_posn = pos.nbrjobs_posn
      AND i.nbrjobs_suff = pos.nbrjobs_suff
      AND i.nbrjobs_effective_date <= SYSDATE
    )
  )
  -- limit to the most current labor dist for this job (if exists)
  AND (
       dist.nbrjlbd_pidm IS NULL 
    OR dist.nbrjlbd_effective_date = (     
      SELECT MAX (dist2.nbrjlbd_effective_date)
      FROM POSNCTL.NBRJLBD dist2
      WHERE (
            dist.nbrjlbd_pidm = dist2.nbrjlbd_pidm
        AND dist.nbrjlbd_posn = dist2.nbrjlbd_posn
        AND dist.nbrjlbd_suff = dist2.nbrjlbd_suff
      )
    )
  )
  -- Get the most recent mailing address (if exists)
  AND (
       adr.spraddr_seqno IS NULL
    OR adr.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        a2.spraddr_pidm = adr.spraddr_pidm
        AND a2.spraddr_atyp_code = 'HR'
    )
  )
ORDER BY
  emp.spriden_id,
  dist.nbrjlbd_percent DESC
;