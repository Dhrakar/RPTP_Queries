SELECT
  org.title2                  AS "Cabinet",
  org.title3                  AS "Unit",
  org.title                   AS "Department",
  -- rec.pebempl_orgn_code_home  AS "Home dLevel", 
  emp.spriden_id              AS "UA ID",
  usr.gobtpac_external_user || '@alaska.edu'   AS "UA Email",
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
    WHEN rem.pprcert_cert_code IS NULL THEN 'None' 
    ELSE (
      SELECT  ptrcert_desc
      FROM PAYROLL.PTRCERT
      WHERE ptrcert_code = rem.pprcert_cert_code
    )
  END                         AS "Remote Agreement?",
  adr.spraddr_city            
   || ', ' 
   || adr.spraddr_stat_code 
   || ' ' 
   || adr.spraddr_zip        AS "Mailing Address",
  CASE
    WHEN substr(adr.spraddr_zip,1,5) IN (
      '99702',  -- Eielson AFB
      '99703',  -- Ft Wainwright
      -- '99704', -- Clear 
      '99705',  -- North Pole
      '99706',  -- Fairbanks PO
      '99707',  -- Fairbanks PO
      '99708',  -- Fairbanks PO
      '99709',  -- Fairbanks 
      '99710',  -- Fairbanks PO
      '99711',  -- Fairbanks PO
      '99712',  -- Two Rivers, Fox
      -- '99713',  -- ?
      '99714',  -- Salcha
      -- '99715',  -- ?
      '99716',  -- Fairbanks PO (Two Rivers)
      '99725',  -- Fairbanks PO (Ester)
      '99775',  -- UAF
      -- '99790',  -- Interior Alaska (Ft Greely, etc)
      -- General Fairbanks
      '99701'
    ) THEN 'Local'
    ELSE 'Remote'
  END                            AS "MA ZIP Location"
FROM
  -- start with the identity table
  SATURN.SPRIDEN emp
  -- join with biographical info for each person
  INNER JOIN SATURN.SPBPERS bio  ON emp.spriden_pidm = bio.spbpers_pidm
  -- join with core employee information (and limit to just UA employees)
  INNER JOIN PAYROLL.PEBEMPL rec  ON emp.spriden_pidm = rec.pebempl_pidm
  -- join with SSO username informaiton (eg; Google username)
  INNER JOIN GENERAL.GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
  -- get information about this person's current base UA job (if it exists)
  LEFT JOIN POSNCTL.NBRBJOB job  ON (
        emp.spriden_pidm = job.nbrbjob_pidm
    AND job.nbrbjob_contract_type = 'P'
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
  -- join to find the org hierarchy for this person's department (if assigned)
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = rec.pebempl_orgn_code_home
  )
  -- join to get any remote access agreements
  LEFT JOIN PAYROLL.PPRCERT rem ON (
        rem.pprcert_pidm = emp.spriden_pidm
    AND rem.pprcert_cert_code LIKE 'REM_'
    -- Filter to just current agreements
    AND (
         rem.pprcert_expire_date >= SYSDATE
      OR rem.pprcert_expire_date IS NULL
    )
  )
  -- get the mailing address information
  LEFT JOIN SATURN.SPRADDR adr ON (
    adr.spraddr_pidm = emp.spriden_pidm
    AND adr.spraddr_atyp_code = 'MA'
  )
WHERE
  -- limit to just UAF employees
      org.level1 = 'UAFTOT'
  -- limit to only current employees (on or off contract)
  AND rec.pebempl_empl_status != 'T'
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
  -- limit to non-students
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
    'XT',	-- Exempt Staff - Temporary
    'XX'	-- Exempt Staff - Extended
  )
  AND (
    -- Get the most recent mailing address (if exists)
    adr.spraddr_seqno IS NULL
    OR adr.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        a2.spraddr_pidm = adr.spraddr_pidm
        AND a2.spraddr_atyp_code = 'MA'
    )
  )
  AND (
    -- get the most recent remote agreement (if any)
    rem.pprcert_cert_date IS NULL
    OR rem.pprcert_cert_date = (
      SELECT MAX(rem2.pprcert_cert_date)
      FROM PAYROLL.PPRCERT rem2
      WHERE rem2.pprcert_pidm = rem.pprcert_pidm
    )
  )
ORDER BY
  org.title2, org.title3, org.title,
  emp.spriden_id
;