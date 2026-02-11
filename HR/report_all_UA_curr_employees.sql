-- =============================================================================
-- = Returns details for all current (Active in PEBEML) employees.  Does not
-- = include student employees.  Derived from Airtable employee query.
-- =
-- = Banner Tables Used
-- = ~~~~~~~~~~~~~~~~~~
-- = FIMSMGR.FTVORGN
-- = GENERAL.GOBTPAC
-- = PAYROLL.PEBEMPL
-- = PAYROLL.PERAPPT
-- = PAYROLL.PERBFAC
-- = PAYROLL.PERRANK
-- = PAYROLL.PHREARN
-- = POSNCTL.NBRBJOB
-- = POSNCTL.NBRJOBS
-- = SATURN.SIRNIST
-- = SATURN.SORDEGR
-- = SATURN.SPBPERS
-- = SATURN.SPRIDEN
-- = SATURN.STVDEGC
-- = 
-- =============================================================================
SELECT DISTINCT
  emp.spriden_id               AS "Employee ID",
  CASE
      WHEN pos.nbrjobs_ecls_code IS NOT NULL THEN pos.nbrjobs_ecls_code
      ELSE rec.pebempl_ecls_code 
  END                          AS "Employee eClass",
  emp.spriden_last_name        AS "Last Name",
  emp.spriden_first_name       AS "First Name",
  bio.spbpers_pref_first_name  AS "Preferred Name",
  substr(
    emp.spriden_mi,0,1
  )                            AS "Middle Initial",
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
    END                        AS "Gender",
  bio.spbpers_pprn_code        AS "Preferred Pronoun",
  (
    SELECT stvethn_desc
    FROM SATURN.STVETHN 
    WHERE stvethn_code = bio.spbpers_ethn_code
  )                            AS "Ethnicity",
  usr.gobtpac_external_user
    || '@alaska.edu'           AS "UA Email",
  org.title1                   AS "Campus Title",
  org.title2                   AS "Cabinet",
  org.title3                   AS "Unit/School",
  org.title                    AS "Department",
  job.nbrbjob_posn             AS "Position PCN",
  job.nbrbjob_suff             AS "PCN Suffix",
  pos.nbrjobs_desc             AS "Position Title",
  pos.nbrjobs_sal_grade        AS "Position Grade",
  pos.nbrjobs_sal_step         AS "Position Step",
  pos.nbrjobs_per_pay_salary   AS "Position Pay Sal.",
  pos.nbrjobs_ann_salary       AS "Position Annual Sal.",
  (
    SELECT sum(pe.phrearn_amt)
    FROM PAYROLL.PHREARN pe
    WHERE pe.phrearn_year = extract(year from SYSDATE)
      AND pe.phrearn_pidm = rec.pebempl_pidm
      AND pe.phrearn_earn_code IN ( 
       '200', -- Credit Biweekly Overload
       '250', -- Non-Credit Biweekly Overload
       '255', -- Non-Credit Hourly Overload
       -- '290' -- Former other-than-contract pay code 
       '360', -- Department Chair
       '425'  -- Faculty Time Off
       -- '653' -- Off Contract
      )
  )                            AS "Position Other Pay",
  (
    SELECT sum(pe.phrearn_hrs)
    FROM PAYROLL.PHREARN pe
    WHERE pe.phrearn_year = extract(year from SYSDATE)
      AND pe.phrearn_pidm = rec.pebempl_pidm
      AND pe.phrearn_earn_code IN ( 
       '200', -- Credit Biweekly Overload
       '250', -- Non-Credit Biweekly Overload
       '255'  -- Non-Credit Hourly Overload
      )
  )                            AS "Overload Hours",
  (
    SELECT sum(pe.phrearn_amt)
    FROM PAYROLL.PHREARN pe
    WHERE pe.phrearn_year = extract(year from SYSDATE)
      AND pe.phrearn_pidm = rec.pebempl_pidm
      AND pe.phrearn_earn_code IN ( 
       '200', -- Credit Biweekly Overload
       '250', -- Non-Credit Biweekly Overload
       '255'  -- Non-Credit Hourly Overload
      )
  )                            AS "Overload Earned Amount",  
  rec.pebempl_orgn_code_dist   AS "Position TKL",
  NVL2 (
    emp_sup.spriden_pidm,
    emp_sup.spriden_last_name
      || ', ' ||
      emp_sup.spriden_first_name,
    ''
  )                            AS "Supervisor Name",
  to_char(
    rec.pebempl_first_hire_date, 'MM/DD/YYYY'
  )                            AS "Hire Date",
  rec.pebempl_empl_status      AS "Employee Status",
  to_char(
    rec.pebempl_term_date, 'MM/DD/YYYY'
  )                            AS "Termination Date", 
  DECODE (
    pos.nbrjobs_status,
    'A', 'Active',
    'B', 'LWOP - With Benefits',
    'F', 'AL',
    'L', 'LWOP - No Benefits',
    'P', 'AL - Partial Benefits',
    'Off Contract'
  )                            AS "Contract Status",
  pos.nbrjobs_jcre_code        AS "Job Change Code", 
  (
    SELECT stvdegc_desc
    FROM SATURN.STVDEGC 
    WHERE stvdegc_code = tdeg.sordegr_degc_code
  )                            AS "Terminal Degree",
  -- faculty specific information after this --
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
    WHERE perrank_pidm = rec.pebempl_pidm
  )                            AS "Faculty Rank",
  DECODE (
    apt.perappt_tenure_code,
    'T', 'Tenured',
    'N', 'Non-Tenured',
    'I','Ineligible',
    apt.perappt_tenure_code
  )                            AS "Faculty Tenure",
  CASE
    WHEN apt.perappt_tenure_code = 'T' THEN 'Tenured Asof: ' || to_char(apt.perappt_tenure_eff_date, 'DD/MM/YYYY')
    WHEN apt.perappt_tenure_trac_begin_date IS NULL THEN ''
    WHEN apt.perappt_tenure_code = 'N' THEN  'TT Asof: ' || to_char(apt.perappt_tenure_trac_begin_date, 'DD/MM/YYYY')
    ELSE 'Non-TT'
  END                          AS "Tenure Track",
  (
    -- inline query to get the faculty CIP
    SELECT DISTINCT
      first_value(sirnist_tops_code) over(ORDER BY sirnist_term_code desc)
    FROM SATURN.SIRNIST
    WHERE sirnist_pidm = rec.pebempl_pidm
      AND sirnist_nist_code = 'CIP'
  )                            AS "Faculty CIP",
  DECODE (
    fac.perbfac_primary_activity,
    'I', 'Instruction',
    'R', 'Research',
    'A', 'Administration',
    ''  
  )                            AS "Faculty Primary Type",
  ( -- inline query for faculty Instructional workload
    -- Codes: ILRC, INCA, INCL, INS
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code LIKE 'I%'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Ins. Wrk.",
  ( -- inline query for faculty Research workload
    -- Codes: RES, RESN, RESS
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code LIKE 'R%'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Res. Wrk.",
  ( -- inline query for faculty Service workload
    -- Codes: SPRO, SPUB, SUNV
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code LIKE 'S%'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Serv. Wrk.",
  ( -- inline query for faculty Admin workload
    -- Codes: ACH, ACO, ADM
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code LIKE 'A%'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Admin Wrk.",
  ( -- inline query for faculty Sabbatical workload
    -- Code: OSB
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code = 'OSB'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Sabb. Wrk.",
  ( -- inline query for faculty Other workload
    -- Code: OSA
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code = 'OSA'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Other Wrk.",
  ( -- inline query for faculty workload total
    -- Code: All except CIP
    SELECT sum(a.sirnist_nist_workload)
    FROM SATURN.SIRNIST a
    WHERE a.sirnist_pidm = rec.pebempl_pidm
      AND a.sirnist_nist_code != 'CIP'
      AND a.sirnist_term_code = (
        SELECT max(aa.sirnist_term_code)
        FROM SATURN.SIRNIST aa
        WHERE aa.sirnist_pidm = a.sirnist_pidm
      )
  )                            AS "Faculty Total Wrk.",
  fac.perbfac_academic_title   AS "Faculty Acad. Title"
FROM  
  PAYROLL.PEBEMPL rec
-- organization info
  LEFT OUTER JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = rec.pebempl_orgn_code_home
    -- uncomment to just get UAF
    -- AND org.level1 = 'UAFTOT'
  )
-- basic person info
  INNER JOIN SATURN.SPRIDEN emp ON (
        rec.pebempl_pidm = emp.spriden_pidm
    AND emp.spriden_change_ind IS NULL
    AND emp.spriden_id NOT LIKE 'BAD%'
  )
-- biographic info
  INNER JOIN SATURN.SPBPERS bio ON (
    rec.pebempl_pidm = bio.spbpers_pidm
    -- Do not include deceased
    AND bio.spbpers_dead_ind IS NULL
    -- Filter out bad records
    AND (bio.spbpers_ssn NOT LIKE 'BAD%' OR bio.spbpers_ssn IS NULL)
  )
-- Get User info
  INNER JOIN GENERAL.GOBTPAC usr ON (
    rec.pebempl_pidm = usr.gobtpac_pidm
  )
-- get Faculty type/title
  LEFT OUTER JOIN PAYROLL.PERBFAC fac ON (
    rec.pebempl_pidm = fac.perbfac_pidm
  )
-- get faculty tenure info
  LEFT OUTER JOIN PAYROLL.PERAPPT apt ON (
    rec.pebempl_pidm = apt.perappt_pidm
    AND apt.perappt_appt_eff_date = (
      SELECT MAX(apt_i.perappt_appt_eff_date)
      FROM PAYROLL.PERAPPT apt_i
      WHERE apt_i.perappt_pidm = apt.perappt_pidm
    )
  )
-- get highest (terminal) degree
  LEFT OUTER JOIN SATURN.SORDEGR tdeg ON (
    rec.pebempl_pidm = tdeg.sordegr_pidm
    AND tdeg.sordegr_term_degree = 'Y'
    AND tdeg.sordegr_degc_date = (
      SELECT MAX(tdeg_i.sordegr_degc_date)
      FROM SATURN.SORDEGR tdeg_i
      WHERE tdeg_i.sordegr_pidm = tdeg.sordegr_pidm
        AND tdeg_i.sordegr_term_degree = 'Y'
    )
  )
-- Get current base job
  LEFT OUTER JOIN POSNCTL.NBRBJOB job ON (
        rec.pebempl_pidm = job.nbrbjob_pidm 
    -- Just the primary position
    AND job.nbrbjob_contract_type = 'P'
    -- just current contracts
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    AND (job.nbrbjob_end_date >= CURRENT_DATE OR job.nbrbjob_end_date IS NULL)
  )
-- Get current position
  LEFT OUTER JOIN POSNCTL.NBRJOBS pos ON (
        rec.pebempl_pidm = pos.nbrjobs_pidm
    AND job.nbrbjob_posn = pos.nbrjobs_posn
    AND job.nbrbjob_suff = pos.nbrjobs_suff
    AND pos.nbrjobs_status <> 'T'
    AND pos.nbrjobs_effective_date = (
      SELECT MAX(pos_i.nbrjobs_effective_date)
      FROM POSNCTL.NBRJOBS pos_i
      WHERE pos.nbrjobs_pidm = pos_i.nbrjobs_pidm
        AND pos_i.nbrjobs_status <> 'T'
        AND pos_i.nbrjobs_effective_date <= sysdate
        AND pos_i.nbrjobs_posn = pos.nbrjobs_posn
        AND pos_i.nbrjobs_suff = pos.nbrjobs_suff
    )
  )
-- get supervisor name
  LEFT OUTER JOIN SATURN.SPRIDEN emp_sup ON (
        pos.nbrjobs_supervisor_pidm = emp_sup.spriden_pidm
    AND emp_sup.spriden_change_ind IS NULL
  )
WHERE
  -- just currently Active employees
  rec.pebempl_empl_status = 'A'
  -- Filter to the needed classes using the primary position eclass unless it does
  -- not exist, then use the employee position
  AND 
    CASE
      WHEN pos.nbrjobs_ecls_code IS NOT NULL THEN pos.nbrjobs_ecls_code
      ELSE rec.pebempl_ecls_code 
    END IN (
    -- 'A9',	-- 	No longer used - UAFT Regular
    -- 'AR',	-- 	No longer used - UAFT 12 mo
    'CR',	-- 	L6070 Union - Regular
    'CT',	-- 	L6070 Union - Temporary
    'EX',	-- 	Executive Management
    'F9',	-- 	Faculty - Regular - <12 month
    'FN',	-- 	Faculty - Non-represented
    'FR',	-- 	Academic Leadership (nonrep)
    'FT',	-- 	Faculty - Temporary
    'FW',	-- 	Non-Represented Temp Faculty
    'GN',	-- 	Grad Stdt FICA non-tax Stipend
    'GT',	-- 	Grad Stdt FICA tax - Stipend
    'NR',	-- 	NonExempt Staff - Regular
    'NT',	-- 	NonExempt Staff - Temporary
    'NX',	-- 	NonExempt Staff - Extended
    -- 'SN',	-- 	Student-non FICA taxable
    -- 'ST',	-- 	Students-FICA taxable
    'XR',	-- 	Exempt Staff - Regular
    'XT',	--  Exempt Staff - Temporary
    'XX'	--  Exempt Staff - Extended
  )
ORDER BY
  emp.spriden_id
;
