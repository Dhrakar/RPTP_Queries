-- ===========================================================
--  Active UAF Employee email and department
--
-- This query pulls out all of the UAFTOT employees from the
-- REPORTS.N_ACTIVE_JOBS view
-- ============================================================
SELECT
  emp.spriden_id           AS "UA ID",
  NVL2(
    bio.spbpers_pref_first_name,
    bio.spbpers_pref_first_name,
    emp.spriden_first_name
  )                        AS "First Name",
  substr(emp.spriden_mi,0,1) AS "MI",
  emp.spriden_last_name    AS "Last Name",
  usr.gobtpac_external_user || '@alaska.edu'   AS "Email",
  dsduaf.f_decode$benefits_category(
    emp.nbrjobs_ecls_code
  )                        AS "Employee Type",
  -- org.title2               AS "Cabinet",
  org.title3               AS "Unit",
  org.title                AS "Department"
FROM
  N_ACTIVE_JOBS emp
  JOIN spbpers bio ON ( 
        emp.spriden_pidm = bio.spbpers_pidm
    AND (bio.spbpers_ssn NOT LIKE 'BAD%' OR bio.spbpers_ssn IS NULL)
    AND bio.spbpers_dead_ind IS NULL
  )
  JOIN ftvorgn_levels org ON emp.pebempl_orgn_code_home = org.orgn_code
  JOIN GOBTPAC usr ON emp.spriden_pidm = usr.gobtpac_pidm
WHERE
  org.level1 = 'UAFTOT'
  -- org.level2 = '5VCAS'
  AND emp.nbrjobs_ecls_code IN ( 
                                 'CR', 'CT', 
                                 'EX', 
                                 --'FR', 
                                 --'F9', 'FN', 'FT', 'FW', 
                                 'NR', 'NT', 'NX', 
                                 'XR', 'XT', 'XX',
                                 'SN', 'ST',
                                 'GN','GT'
                               )
  AND emp.nbrbjob_contract_type = 'P'
ORDER BY
  org.title2,org.title3,org.title,emp.spriden_id
;