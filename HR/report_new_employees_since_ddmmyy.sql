-- ========================================================================================================
--  New UAF Employee Orientation query
--
-- This query finds all of the staff who have been hired recently.  It does not include students 
-- or temp / adjunct faculty.  The 'local' flag is used for sending invites for folks to come to the 
-- meetings in person. 
-- ========================================================================================================
SELECT
  emp.spriden_id                 AS "UA ID",
  emp.spriden_last_name
    || ', '
    || nvl(
         bio.spbpers_pref_first_name,
         emp.spriden_first_name
       )
    || ' '
    || substr(
         emp.spriden_mi,1,1
       )                         AS "Full Name",
  usr.gobtpac_external_user 
    || '@alaska.edu'             AS "UA Email",
  pe.goremal_email_address       AS "Preferred Email",
  adr.spraddr_city               AS "Mailing Address City", adr.spraddr_zip,
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
  END                            AS "Location",
  DSDUAF.f_decode$orgn_campus(
    org.level1
  )                              AS "Campus",
  org.title2                     AS "Cabinet",
  org.title3                     AS "Unit",
  org.title                      AS "Department",
  emp.nbrjobs_ecls_code
    || '-' || (
      SELECT a.ptrecls_long_desc 
      FROM PAYROLL.PTRECLS a 
      WHERE a.ptrecls_code = emp.nbrjobs_ecls_code 
    )                            AS "Employee Class",
  CASE 
    WHEN emp.pebempl_first_hire_date < emp.pebempl_current_hire_date THEN 'Re-Hire'
    ELSE 'New-Hire'
  END                            AS "Prev. Hired?",
  emp.pebempl_first_hire_date    AS "Original Hire Date",
  -- emp.pebempl_current_hire_date  AS "Current Hire Date",
  emp.nbrbjob_begin_date         AS "Position Start Date",
  emp.nbrbjob_end_date           AS "Position End Date"
FROM 
  REPORTS.N_ACTIVE_JOBS emp
  INNER JOIN SATURN.SPBPERS bio ON 
    emp.spriden_pidm = bio.spbpers_pidm
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON 
    emp.pebempl_orgn_code_home = org.orgn_code
  INNER JOIN GENERAL.GOBTPAC usr ON 
    usr.gobtpac_pidm = emp.spriden_pidm
  INNER JOIN SATURN.SPRADDR adr ON (
    adr.spraddr_pidm = emp.spriden_pidm
    AND adr.spraddr_atyp_code = 'MA'
  )
  LEFT JOIN GENERAL.GOREMAL pe ON (
    pe.goremal_pidm = emp.spriden_pidm
    AND pe.goremal_preferred_ind = 'Y'
    AND pe.goremal_status_ind = 'A'
  )
WHERE 
  -- only include Primary positions
  emp.nbrbjob_contract_type = 'P'
  -- comment out to do all of UA
  AND org.level1 = 'UAFTOT'
  -- Only count folks hired inthe last 4 months
  AND emp.pebempl_current_hire_date BETWEEN SYSDATE - 120 AND SYSDATE 
  -- do not include student employees or the old Adjunct categories
  AND emp.nbrjobs_ecls_code IN (
--    'A9', --'Faculty',
--    'AR', --'Faculty',
    'EX', --'Officers/Sr. Administrators',
    'F9', --'Faculty',
    'FN', --'Faculty',
    'FR', --'Officers/Sr. Administrators',
    'FT', --'Adjunct Faculty',
    'FW', --'Adjunct Faculty',
    'CR', --'Staff',
    'CT', --'Staff',
    'NR', --'Staff',
    'NT', --'Staff',
    'NX', --'Staff',
    'XR', --'Staff',
    'XT', --'Staff',
    'XX', --'Staff',
--    'GN', --'Student',
--    'GT', --'Student',
--    'SN', --'Student',
--    'ST' --'Student',
    '00' -- dummy value to keep from futzing with the trailing ','
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
    -- get the most recent, preferred email address (if exists)
    pe.goremal_pidm IS NULL
    OR pe.goremal_activity_date = (
      SELECT MAX(pe2.goremal_activity_date)
      FROM GENERAL.GOREMAL pe2
      WHERE 
        pe2.goremal_pidm = pe.goremal_pidm
        AND pe2.goremal_preferred_ind = 'Y'
        AND pe2.goremal_status_ind = 'A'
    )
  )
order by
  DSDUAF.f_decode$orgn_campus(
    org.level1
  ), 
  org.title2, 
  org.title3, 
  org.title, 
  emp.spriden_id
;
