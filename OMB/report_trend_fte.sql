-- =============================================================================
--  UAF Staffing/Employee Trends project 
--
--  Based on DSDMGR tables & RPTP FTVORGN_LEVELS for consistency with PAIR and
-- SW IR reports (like UA in Review).  Grabs the last 10 FYs worth of data.
--  
--  This report is FTE only.  Note that is does include all types of FTE as well
-- as regular, temporary, student, etc.  Thus, when trying to limit to just the
-- regular employees, be sure to limit the FTE Type to 10_FTE along with the 
-- ECLS filtering.
--   
-- History
--  - 20170601 Adapted from general AS Data SQL
--  - 20170602 Added multiple fields from the AS Data FTE section
--  - 20170929 migrate to separate file and included VC/Unit
--  - 20180502 Added new fund type definition for Match
--             added in org section for use with pivot reports 
--             filtered to just the 10_FTE type
--  -          Add in columns for the UA in review definitions
--  - 20180925 Removed the Job Category column (out of date & no longer needed)
--             Removed MAU column (always UAF since filtered to level2 UAFTOT)
--             Moved check for level2 = 'UAFTOT' to be in FTVORGN_LEVELS join
--  - 20181010 Removed the FTE Type filter 
--  - 20181016 Added campus name via DSD.CODE_ACADEMIC_ORGANIZATION
--  - 20181019 UPdate time span calc in WHERE to be much simpler and robust
--  - 20200110 Add titles and levels for 2 - 6 ; sort up to lvl 6
--  - 20200113 Due to the need to pull orgs as they existed in previous years
--             for the FTE report, I have set this up to be just the DB pull &
--             have removed all of the org titles and levels that are not 
--             already in H_DISTRIBUTION
-- =============================================================================

SELECT DISTINCT
  ''                             AS "Row ID",
  dist.employee_id               AS "UAID",
  CASE WHEN dist.term_code LIKE '%1' 
         THEN 'Spring ' || SUBSTR(dist.term_code,0,4)
       WHEN dist.term_code LIKE '%2' 
         THEN 'Summer ' || SUBSTR(dist.term_code,0,4)
       ELSE 'Fall ' || SUBSTR(dist.term_code,0,4)
  END                            AS "TERM",
  dist.fiscal_year               AS "FY", 
  dist.department_code           AS "Dept Code",
  camp.description               AS "Academic Organization",
  dist.name_last 
    || ', ' 
    || dist.name_first           AS "Name",
  dist.position_number           AS "Position",
  dist.position_suffix           AS "Suffix",
  dist.job_class_code            AS "ECLS",
  dist.fund_code                 AS "Fund",
  dist.org_code                  AS "Org",
  dist.account_code              AS "Account",
  dist.program_code              AS "Program",
  dist.employee_group            AS "Employee Group",
  DECODE( -- definitions from H_EMPLOYEE  for FY > 2000
    dist.job_class_code,
      'NX','EXT_TEMP',
      'XX','EXT_TEMP',
      'A9','REGULAR',
      'AR','REGULAR',
      'CR','REGULAR',
      'EX','REGULAR',
      'F9','REGULAR',
      'FN','REGULAR',
      'FR','REGULAR',
      'NR','REGULAR',
      'XR','REGULAR',
      'CT','TEMPORARY',
      'FT','TEMPORARY',
      'FW','TEMPORARY',
      'GN','TEMPORARY',
      'GT','TEMPORARY',
      'NT','TEMPORARY',
      'SN','TEMPORARY',
      'ST','TEMPORARY',
      'XT','TEMPORARY',
      '?'
    )                            AS "Regular/Temporary", 
  dist.fte                       AS "FTE",
  dist.fte_measure               AS "FTE Type",
  DECODE( -- create the benefits categories
    dist.job_class_code,
    'A9', 'Faculty',
    'AR', 'Faculty',
    'EX', 'Officers/Sr. Administrators',
    'F9', 'Faculty',
    'FN', 'Faculty',
    'FR', 'Officers/Sr. Administrators',
    'FT', 'Adjunct Faculty',
    'FW', 'Adjunct Faculty',
    'CR', 'Staff',
    'CT', 'Staff',
    'NR', 'Staff',
    'NT', 'Staff',
    'NX', 'Staff',
    'XR', 'Staff',
    'XT', 'Staff',
    'XX', 'Staff',
    'GN', 'Student',
    'GT', 'Student',
    'SN', 'Student',
    'ST', 'Student',
    'Other'
  )                              AS "ABS Description",
  -- this col matches the ECLS list used to generate UA in Review
  DECODE( 
    dist.job_class_code,
    'A9', 'Faculty',
    'F9', 'Faculty',
    'FN', 'Faculty',
    'FR', 'Faculty',
    'CR', 'Staff',
    'EX', 'Staff',
    'NR', 'Staff',
    'XR', 'Staff',
    'Other'
  )                              AS "UA Review Category",
  eeo.eeo_occupation_desc        AS "EEO Description",
  dist.nchems                    AS "NCHEMS",
  job.job_title                  AS "Job Title",
  CASE WHEN dist.fte > 1 
         THEN job.salary_annual
       ELSE job.salary_annual * dist.fte
  END                            AS "Salary",
  -- caclulate the type of fund code.  This is the UAF definition
  CASE 
    WHEN dist.fund_code BETWEEN 100000 AND 139999 
        OR dist.fund_code BETWEEN 150000 AND 169999
        OR dist.fund_code BETWEEN 180000 AND 189999
      THEN 'UNRESTRICTED'
    WHEN dist.fund_code BETWEEN 140000 AND 149999
      THEN 'MATCH'
    WHEN dist.fund_code BETWEEN 170000 AND 179999
      THEN 'RECHARGE'
    WHEN dist.fund_code BETWEEN 190000 AND 199999
      THEN 'AUXILIARY'
    WHEN dist.fund_code BETWEEN 200000 AND 999999
      THEN 'RESTRICTED'
    ELSE 'ERROR'
  END                            AS "UAF Fund Type",
  -- this is the SW IR definitions for fund type from UA in review
  CASE 
    WHEN dist.fund_code BETWEEN 100000 AND 179999 
      THEN 'UNRESTRICTED'
    ELSE 'OTHER'
  END                            AS "UA Review Fund Type"
  
FROM
  DSDMGR.H_DISTRIBUTION dist
  JOIN dsdmgr.h_assignment job ON (
    dist.employee_id = job.employee_id
    AND dist.term_code = job.term_code
    AND dist.position_number = job.position_number
    AND dist.position_suffix = job.position_suffix
  )
  JOIN DSDMGR.CODE_EEO_OCCUPATION eeo ON 
    job.occupation_eeo_code = eeo.eeo_occupation_code
  LEFT JOIN DSDMGR.CODE_ACADEMIC_ORGANIZATION camp ON 
    dist.academic_org_code = camp.academic_organization_code
WHERE
  -- this section dynamically gets the last 10 fiscal years of freeze data
  -- it uses the fall term and grabs anything between the most recent year's
  --  fall and the 10 years-ago fall term
  dist.term_code BETWEEN BETWEEN  
        (EXTRACT(year FROM CURRENT_DATE) - 10) || '03'
    AND EXTRACT(year FROM CURRENT_DATE) || '03'
  AND dist.mau_code = 'UAF'
ORDER BY
  "TERM",
  dist.department_code,
  dist.employee_id
;