-- =============================================================
-- Staff Council membership by election unit
--
-- This query uses the F_SC_UNITS() function in DSDUAF to map  
-- each employee's home unit (level 3) to an SC election
-- unit.  Only currently active and on-contract employees are
-- included in the results.
-- ==============================================================

SELECT
  dsduaf.f_sc_units(org.level3)     AS "Election Unit",
  emp.spriden_id                    AS "UA ID",
  usr.gobtpac_external_user 
    || '@alaska.edu'                AS "UA Email",
  emp.spriden_last_name
    || ', '
    || nvl(
         bio.spbpers_pref_first_name,
         emp.spriden_first_name
       )
    || ' '
    || substr(
         emp.spriden_mi,1,1
       )                            AS "Full Name", 
  emp.nbrjobs_desc                  AS "Position Title",
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                                 AS "Campus",
  org.title2                        AS "Cabinet",
  org.title3                        AS "Unit",
  org.level3                        AS "Unit Code",
  org.title                         AS "Department",
  org.orgn_code                     AS "Dept Code",
  emp.nbrbjob_end_date              AS "Contract End"
FROM
  -- start with all of the currently active & on-contract employees
  REPORTS.N_ACTIVE_JOBS emp
  -- Get bio info
  INNER JOIN SATURN.SPBPERS bio ON (
    emp.spriden_pidm = bio.spbpers_pidm
  )
  -- get the UA org hierarchy
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON (
       emp.pebempl_orgn_code_home = org.orgn_code
    -- filter to just UAF 
    AND org.level1 = 'UAFTOT' 
  )
  -- get the UA username
  INNER JOIN GENERAL.GOBTPAC usr ON (
    emp.spriden_pidm = usr.gobtpac_pidm
  )
  -- get the mailing address to determine local/remote
  LEFT JOIN SATURN.SPRADDR adr ON (
    adr.spraddr_pidm = emp.spriden_pidm
    AND adr.spraddr_atyp_code = 'MA'
  )
WHERE
    -- filter to just primary positions
  emp.nbrbjob_contract_type = 'P'
    -- filter to just employee classes covered by the staff council
  AND emp.nbrjobs_ecls_code IN (
--    'A9', --'Faculty',
--    'AR', --'Faculty',
--    'EX', --'Officers/Sr. Administrators',
--    'F9', --'Faculty',
--    'FN', --'Faculty',
--    'FR', --'Officers/Sr. Administrators',
--    'FT', --'Adjunct Faculty',
--    'FW', --'Adjunct Faculty',
--    'CR', --'Staff',
--    'CT', --'Staff',
    'NR', --'Staff',
--    'NT', --'Staff',
    'NX', --'Staff',
    'XR', --'Staff',
--    'XT', --'Staff',
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
ORDER BY
  "Election Unit", "UA ID"
;