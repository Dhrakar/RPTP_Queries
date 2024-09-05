-- ==========================================================================
--  Title IX Report
--
-- This query pulls the most recent title IX completion for each employee in
-- a supplied TKL.  Shows NULL if a person has never done Title IX. 
-- ==========================================================================
SELECT
  emp.spriden_id                AS uaid,
  emp.spriden_first_name        AS first_name,
  emp.spriden_last_name         AS last_name,
  to_char(
    emp.pebempl_current_hire_date,
    'mm/dd/yyyy'
  )                             AS hired_on,
  to_char(
    emp.nbrbjob_begin_date,
    'mm/dd/yyyy'
  )                             AS position_start,
  to_char(
    emp.nbrbjob_end_date,
    'mm/dd/yyyy'
  )                             AS position_end,
  emp.nbrjobs_ecls_code
    || ':' || (
      SELECT a.ptrecls_long_desc 
      FROM PAYROLL.PTRECLS a 
      WHERE a.ptrecls_code = emp.nbrjobs_ecls_code 
    )                           AS employee_class,
  -- emp.pebempl_orgn_code_dist    AS tkl,
  -- org.level1                    AS campus,
  org.title2                    AS cabinet,
  org.title                     AS title,
  typ.ptrcert_desc              AS certification,
  to_char(
    crt.pprcert_cert_date,
    'mm/dd/yyyy'
  )                             AS certification_date,
  CASE 
    WHEN to_char( crt.pprcert_cert_date, 'mm/dd/yyyy' ) = '06/20/2024' AND emp.pebempl_current_hire_date < to_date ('11/01/2023', 'mm/dd/yyyy') THEN 'ERROR'
    WHEN SYSDATE - crt.pprcert_cert_date > 365 THEN 'EXPIRED'
    WHEN typ.ptrcert_desc IS NULL THEN 'NOT DONE'
    ELSE 'OK'
  END    AS status
FROM
  -- get the currently active employees
  REPORTS.N_ACTIVE_JOBS emp
  -- find if they have any T9 certs
  LEFT OUTER JOIN PAYROLL.PPRCERT crt ON (
    crt.pprcert_pidm = emp.spriden_pidm
    AND crt.pprcert_cert_code IN (
      -- Title IX training codes
      'XT9T', 'XT9H', 'XT9', 'XT9I', 'XT9R', 'ZT9R', 'ZT9' 
    )
  )
  -- get actual name of cert
  LEFT OUTER JOIN PAYROLL.PTRCERT typ ON (
    typ.ptrcert_code = crt.pprcert_cert_code
  )
  -- get this person's home dept and hierarchy
  LEFT OUTER JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = emp.pebempl_orgn_code_home 
  )
WHERE
  emp.nbrbjob_contract_type = 'P' -- only grab primary positions
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
  -- uncomment to get a specific TKL
  -- AND emp.pebempl_orgn_code_dist = :tkl -- filter for TKL
  -- ----------------------------------
--    -- just UAF TKLs
--  AND emp.pebempl_orgn_code_dist IN (
--    SELECT
--      ntr2tkl_orgn_code
--    FROM
--      POSNCTL.NTR2TKL
--    WHERE 
--      ntr2tkl_mau_code = 'F'
--  )
    -- just folks that roll up to UAFTOT
  AND org.level1 = 'UAFTOT'
  AND (
    -- check for null in case this person does not have any T9 certs
    -- otherwise, find the most recent
    crt.pprcert_cert_date IS NULL
    OR crt.pprcert_cert_date = (
      SELECT max(crt2.pprcert_cert_date)
      FROM PAYROLL.PPRCERT crt2
      WHERE crt2.pprcert_pidm = crt.pprcert_pidm
        -- AND crt2.pprcert_cert_code = crt.pprcert_cert_code
    )
  )
ORDER BY
  org.title2, org.title,
  emp.spriden_id
;