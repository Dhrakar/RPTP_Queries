SELECT DISTINCT
  emp.spriden_id               AS "Employee ID",
  CASE
      WHEN emp.nbrjobs_ecls_code IS NOT NULL THEN emp.nbrjobs_ecls_code
      ELSE emp.pebempl_ecls_code 
  END                          AS "Employee eClass",
  emp.spriden_last_name        AS "Last Name",
  emp.spriden_first_name       AS "First Name",
  org.title3                   AS "Unit",
  org.title                    AS "Department",
  emp.nbrbjob_posn 
    || '/' 
    || emp.nbrbjob_suff       AS "Position",
  dist.nbrjlbd_percent        AS "Labor %",
  dist.nbrjlbd_fund_code 
    || '/'
    || dist.nbrjlbd_orgn_code AS "Labor Fund/Org",
  jorg.title3                 AS "Labor Unit",
  CASE
    WHEN jorg.level7 LIKE 'D%' THEN jorg.title7
    WHEN jorg.level6 LIKE 'D%' THEN jorg.title6
    WHEN jorg.level5 LIKE 'D%' THEN jorg.title5
    WHEN jorg.level4 LIKE 'D%' THEN jorg.title4   
    WHEN jorg.level3 LIKE 'D%' THEN jorg.title3 
    ELSE 'D?'
  END                         AS "Labor Department",
  (
    -- inline query to get the faculty rank
    SELECT DISTINCT
      DECODE (
        first_value(perrank_rank_code) over(ORDER BY perrank_action_date desc),
        '1',    'Professor',
        '2',    'Associate Professor',
        '3',    'Assistant Professor',
        '4',    'Instructor',
        '5',    'Lecturer',
        '9',    'Non-standard academic ranking',
        ''
      )
    FROM PAYROLL.PERRANK
    WHERE perrank_pidm = emp.pebempl_pidm
  )                            AS "Faculty Rank",
  DECODE (
    fac.perbfac_primary_activity,
    'I', 'Instruction',
    'R', 'Research',
    'A', 'Administration',
    ''  
  )                            AS "Faculty Primary Type"
FROM
  REPORTS.N_ACTIVE_JOBS emp
-- organization info
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = emp.pebempl_orgn_code_home
    -- uncomment to just get UAF
    AND org.level1 = 'UAFTOT'
  )
  -- join with the labor distributions for thie persons positions (if any exist)
  LEFT JOIN POSNCTL.NBRJLBD dist ON ( 
        emp.nbrbjob_pidm = dist.nbrjlbd_pidm
    AND emp.nbrbjob_posn = dist.nbrjlbd_posn
    AND emp.nbrbjob_suff = dist.nbrjlbd_suff
  )
  -- join to find org hierarchy for the labor funds (if any)
  LEFT JOIN REPORTS.FTVORGN_LEVELS jorg ON (
    jorg.level8 = dist.nbrjlbd_orgn_code
  )
  -- join for details about the labor funds (if any)
  LEFT JOIN FIMSMGR.FTVFUND ftyp ON (
    dist.nbrjlbd_fund_code = ftyp.ftvfund_fund_code
  )
-- get Faculty type/title
  LEFT OUTER JOIN PAYROLL.PERBFAC fac ON (
    emp.pebempl_pidm = fac.perbfac_pidm
  )
WHERE
  emp.nbrbjob_contract_type = 'P'
  AND  
    CASE
      WHEN emp.nbrjobs_ecls_code IS NOT NULL THEN emp.nbrjobs_ecls_code
      ELSE emp.pebempl_ecls_code 
    END IN (
    -- 'A9',	-- 	No longer used - UAFT Regular
    -- 'AR',	-- 	No longer used - UAFT 12 mo
--    'CR',	-- 	L6070 Union - Regular
--    'CT',	-- 	L6070 Union - Temporary
--    'EX',	-- 	Executive Management
    'F9',	-- 	Faculty - Regular - <12 month
    'FN',	-- 	Faculty - Non-represented
    'FR',	-- 	Academic Leadership (nonrep)
    'FT',	-- 	Faculty - Temporary
    'FW',	-- 	Non-Represented Temp Faculty
--    'GN',	-- 	Grad Stdt FICA non-tax Stipend
--    'GT',	-- 	Grad Stdt FICA tax - Stipend
--    'NR',	-- 	NonExempt Staff - Regular
--    'NT',	-- 	NonExempt Staff - Temporary
--    'NX',	-- 	NonExempt Staff - Extended
    -- 'SN',	-- 	Student-non FICA taxable
    -- 'ST',	-- 	Students-FICA taxable
--    'XR',	-- 	Exempt Staff - Regular
--    'XT',	--  Exempt Staff - Temporary
--    'XX'	--  Exempt Staff - Extended
    'ZZ' -- dummy value
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
ORDER BY
  emp.spriden_id
;