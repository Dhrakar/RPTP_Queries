-- =============================================================================
--  SQL For getting information about the current positions for an employee.
--  includes the labor distribution, position details and current supervisor.
--
--  This script will accept any of the following params
--  @param :uaid     -- UA Employee/Student ID
--  @param :username -- UA Username
--  @param :pidm     -- unique Banner numeric ID
--  @param :uaemail  -- UA email address (eg; username@alaska.edu)
--  @param :uatkl    -- All employees in that time keeping location
--  @param :uadlevel -- All the employees in a particular department
--
--  Included RPTP tables
--   SPRIDEN, GOBTPAC, NBRBJOB, NBRJOBS, NER2SUP, NBRJLBD, FTVFUND, 
--   FTVORGN_LEVELS
-- =============================================================================
SELECT DISTINCT
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit",
  org.title                   AS "Department",
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
  ua.pebempl_empl_status      AS "UA Status",
  ua.pebempl_first_hire_date  AS "First Hired",
  ua.pebempl_adj_service_date AS "Adj Service Start",
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
  pos.nbrjobs_fte             AS "Pos. FTE",
  sup.ner2sup_effective_date  AS "Supervisor As Of",
  boss.spriden_id             AS "Supervisor UA ID",
  boss.spriden_last_name 
    || ', ' 
    || boss.spriden_first_name AS "Supervisor Name",
  busr.gobtpac_external_user
    || '@alaska.edu'          AS "Supervisor Email"
FROM
  SATURN.SPRIDEN emp
  INNER JOIN SATURN.SPBPERS bio ON emp.spriden_pidm = bio.spbpers_pidm
  INNER JOIN PAYROLL.PEBEMPL ua ON emp.spriden_pidm = ua.pebempl_pidm
  INNER JOIN GENERAL.GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
  LEFT JOIN GENERAL.GOBEACC ban ON emp.spriden_pidm = ban.gobeacc_pidm
  LEFT JOIN POSNCTL.NBRBJOB job ON (
        emp.spriden_pidm = job.nbrbjob_pidm
    -- uncomment to limit to just current positions
    -- AND job.nbrbjob_contract_type = 'P'
    -- -----------------------------------
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    AND ( 
         job.nbrbjob_end_date >= CURRENT_DATE 
      OR job.nbrbjob_end_date IS NULL
    )
  )
  LEFT JOIN POSNCTL.NBRJOBS pos ON ( 
    job.nbrbjob_pidm = pos.nbrjobs_pidm
    AND job.nbrbjob_posn = pos.nbrjobs_posn
    AND job.nbrbjob_suff = pos.nbrjobs_suff
  )
  LEFT JOIN POSNCTL.NER2SUP sup ON (
        job.nbrbjob_pidm = sup.ner2sup_pidm
    AND job.nbrbjob_posn = sup.ner2sup_posn
    AND job.nbrbjob_suff = sup.ner2sup_suff
    AND sup.ner2sup_sup_ind = 'Y'
  )
  LEFT JOIN SATURN.SPRIDEN boss ON (
    boss.spriden_pidm = sup.ner2sup_sup_pidm
    AND boss.spriden_change_ind IS NULL
  )
  LEFT JOIN GENERAL.GOBTPAC busr ON 
    boss.spriden_pidm = busr.gobtpac_pidm
  LEFT JOIN POSNCTL.NBRJLBD dist ON ( 
        job.nbrbjob_pidm = dist.nbrjlbd_pidm
    AND job.nbrbjob_posn = dist.nbrjlbd_posn
    AND job.nbrbjob_suff = dist.nbrjlbd_suff
  )
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = ua.pebempl_orgn_code_home
  )
  LEFT JOIN REPORTS.FTVORGN_LEVELS jorg ON (
    jorg.level8 = dist.nbrjlbd_orgn_code
  )
  LEFT JOIN FIMSMGR.FTVFUND ftyp ON dist.nbrjlbd_fund_code = ftyp.ftvfund_fund_code
WHERE
  ( 
    emp.spriden_id = trim(:uaid) 
 OR emp.spriden_pidm = trim(:pidm)
 OR usr.gobtpac_external_user = lower(trim(:uaname)) 
 OR usr.gobtpac_external_user = lower( substr(:uaemail, 1, instr(:uaemail, '@') - 1 ) )
 OR ua.pebempl_orgn_code_dist = upper(:uatkl)
 OR ua.pebempl_orgn_code_home = upper(:uadlevel)
  )
  -- only include currently active employees
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
  -- limit to the most current supervisor record (if exists)
  AND (
       sup.ner2sup_pidm IS NULL 
    OR sup.ner2sup_effective_date = (
      SELECT MAX (sup2.ner2sup_effective_date)
      FROM POSNCTL.NER2SUP sup2
      WHERE (
            sup2.ner2sup_sup_ind = 'Y'
        AND sup.ner2sup_pidm = sup2.ner2sup_pidm
        AND sup.ner2sup_posn = sup2.ner2sup_posn
        AND sup.ner2sup_suff = sup2.ner2sup_suff
      )
    )
  )
ORDER BY
  emp.spriden_id,
  dist.nbrjlbd_percent DESC
;