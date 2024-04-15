-- ===========================================================
--  Employee Engagement Survey Data
-- ===========================================================
SELECT
  emp.spriden_id               AS "UA ID",
  emp.spriden_last_name
  || ', '
  || nvl(bio.spbpers_pref_first_name,emp.spriden_first_name)
  || ' '
  || substr(emp.spriden_mi,1,1) AS "Full Name",
  addr.gobtpac_external_user 
    || '@alaska.edu'           AS "UA Email",
  (
    SELECT stvethn_desc
    FROM SATURN.STVETHN
    WHERE stvethn_code = bio.spbpers_ethn_code 
  )                            AS "Primary Ethnicity",
  ( 
    SELECT listagg ( b.gorrace_desc, ', '  ) 
           within group ( order by a.gorprac_race_cde ) AS codes
    FROM GENERAL.GORPRAC a
      JOIN GENERAL.GORRACE b ON b.gorrace_race_cde = a.gorprac_race_cde
    WHERE gorprac_pidm = emp.spriden_pidm
  )                            AS "Race Codes",
  CASE
    -- Use the preferred Gender if available, otherwise sex
    WHEN bio.spbpers_gndr_code IS NOT NULL THEN
      DECODE (
        bio.spbpers_gndr_code,
        'A',	'Agender',
        'DNA', 'Does Not Apply',
        'F',	'Female',
        'GQ',	'Genderqueer',
        'M',	'Male',
        'N',	'Non-Binary',
        'TF',	'Transgender Female',
        'TM',	'Transgender Male',
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
  nvl2( -- if there is a birth date calc the age, else null
    bio.spbpers_birth_date,
    trunc((SYSDATE - bio.spbpers_birth_date)/365.25),
    null
  )                            AS "Age",
  (
    SELECT stvmrtl_desc
    FROM SATURN.STVMRTL
    WHERE stvmrtl_code = bio.spbpers_mrtl_code
  )                            AS "Marital Status",
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                            AS "Campus",
  org.title2                   AS "Cabinet",
  org.title3                   AS "Unit",
  org.title                    AS "Department",
  orgn_code                    AS "dLevel",
  emp.pebempl_orgn_code_dist   AS "TKL",
  emp.nbrbjob_posn
   || '/' 
   || emp.nbrbjob_suff         AS "Position",
  emp.nbrjobs_desc             AS "Position Title",
  emp.nbrbjob_begin_date       AS "Position Start Date",
  emp.nbrbjob_end_date         AS "Position End Date",
  emp.nbrjobs_ecls_code        AS "Position eClass",
  DSDUAF.F_DECODE$BENEFITS_CATEGORY( 
    emp.nbrjobs_ecls_code
  )                            AS "Position Category",
  emp.pebempl_first_hire_date  AS "Original Hire Date",
  boss.spriden_id              AS "Supervisor UA ID",
  boss.spriden_last_name
   || ', ' 
   || boss.spriden_first_name 
   || ' ' 
   || substr(boss.spriden_mi,1,1) AS "Supervisor Name"
FROM
  REPORTS.N_ACTIVE_JOBS emp
  JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = emp.spriden_pidm
  )
  JOIN GENERAL.GOBTPAC addr  ON (
    -- grab the UA username
	    emp.pebempl_pidm = addr.gobtpac_pidm
  )
  JOIN REPORTS.FTVORGN_LEVELS org ON (
    emp.pebempl_orgn_code_home = org.orgn_code
  )
  LEFT JOIN POSNCTL.NER2SUP sup   ON (
     -- join to the supervisor table
        emp.nbrbjob_pidm = sup.ner2sup_pidm
    AND emp.nbrbjob_posn = sup.ner2sup_posn
    AND emp.nbrbjob_suff = sup.ner2sup_suff
     -- just get the management supervisor
    AND sup.ner2sup_sup_ind = 'Y'
  )
  LEFT JOIN SATURN.SPRIDEN boss ON (
    sup.ner2sup_sup_pidm = boss.spriden_pidm
    AND boss.spriden_change_ind IS NULL
  )
WHERE
  -- only primary jobs
  emp.nbrbjob_contract_type ='P'
  -- only folks hired prior to October 31
  AND emp.pebempl_first_hire_date <= to_date('31-OCT-2023', 'DD-MON-YYYY')
  -- only specific ecls
  AND emp.nbrjobs_ecls_code IN (
--    'A9', --'Faculty',
--    'AR', --'Faculty',
    'EX', --'Officers/Sr. Administrators',
    'F9', --'Faculty',
    'FN', --'Faculty',
    'FR', --'Officers/Sr. Administrators',
--    'FT', --'Adjunct Faculty',
--    'FW', --'Adjunct Faculty',
    'CR', --'Staff',
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
    '00' -- dummy value to keep from futzing with the trailing comma
  )
  AND ( 
    sup.ner2sup_pidm IS NULL 
    OR sup.ner2sup_effective_date = (
      SELECT MAX (sup2.ner2sup_effective_date)
      FROM POSNCTL.NER2SUP sup2
      WHERE (
            sup.ner2sup_pidm = sup2.ner2sup_pidm
        AND sup.ner2sup_posn = sup2.ner2sup_posn
        AND sup.ner2sup_suff = sup2.ner2sup_suff
        AND sup2.ner2sup_sup_ind = 'Y'
      )
    )
  )
ORDER BY
  "Campus", 
  "Cabinet", 
  "Unit", 
  "Department", 
  emp.spriden_id
;