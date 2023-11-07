-- ==========================================================================
--  Title IX Report
--
-- This query pulls the most recent title IX completion for each employee in
-- a supplied TKL.  Shows NULL if a person has never done Title IX. 
-- ==========================================================================
SELECT
  emp.spriden_id             AS uaid,
  emp.spriden_first_name     AS first_name,
  emp.spriden_last_name      AS last_name,
  emp.pebempl_orgn_code_dist AS tkl,
  typ.ptrcert_desc           AS certification,
  to_char(
    crt.pprcert_cert_date,
    'mm/dd/yyyy'
  )                          AS certification_date
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
WHERE
  emp.nbrbjob_contract_type = 'P' -- only grab primary positions
  AND emp.pebempl_orgn_code_dist = :tkl -- filter for TKL
  AND (
    -- check for null in case this person does not have any T9 certs
    -- otherwise, find the most recent
    crt.pprcert_cert_date IS NULL
    OR crt.pprcert_cert_date = (
      SELECT max(crt2.pprcert_cert_date)
      FROM PAYROLL.PPRCERT crt2
      WHERE crt2.pprcert_pidm = crt.pprcert_pidm
        AND crt2.pprcert_cert_code = crt.pprcert_cert_code
    )
  )
;
