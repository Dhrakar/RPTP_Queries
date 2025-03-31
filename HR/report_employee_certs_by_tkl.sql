SELECT
  emp.spriden_id                                AS "UA ID",
  usr.gobtpac_external_user 
    || '@alaska.edu'                            AS "UA Email",
  emp.spriden_last_name
    || ', '
    || coalesce (
         bio.spbpers_pref_first_name,
         emp.spriden_first_name
       )
    || ' '
    || substr(
         emp.spriden_mi,1,1
       )                                         AS "Full Name",
  emp.nbrjobs_ecls_code                          AS "Job Class",
  sup.ner2sup_effective_date                     AS "Supervisor As Of",
  boss.spriden_id                                AS "Supervisor UA ID",
  boss.spriden_last_name 
    || ', ' 
    || boss.spriden_first_name 
    || ' '
    || substr(
         boss.spriden_mi,1,1
       )                                         AS "Supervisor Name",
  busr.gobtpac_external_user
    || '@alaska.edu'                             AS "Supervisor Email",
  crt.pprcert_cert_code                          AS "Certification",
  to_char(crt.pprcert_cert_date, 'MM/DD/YYYY')   AS "Certification Date",
  to_char(crt.pprcert_expire_date, 'MM/DD/YYYY') AS "Expiration Date"
FROM 
  -- start with the view that has one row per active employee and position
  REPORTS.N_ACTIVE_JOBS emp
  -- get the biographic data
  INNER JOIN SATURN.SPBPERS bio ON 
    emp.spriden_pidm = bio.spbpers_pidm
  -- get teh UA username (for email)
  INNER JOIN GENERAL.GOBTPAC usr ON 
    emp.spriden_pidm = usr.gobtpac_pidm
  -- get thesupervisor records
  LEFT JOIN POSNCTL.NER2SUP sup  ON (
        emp.nbrbjob_pidm = sup.ner2sup_pidm
    AND emp.nbrbjob_posn = sup.ner2sup_posn
    AND emp.nbrbjob_suff = sup.ner2sup_suff
    AND sup.ner2sup_sup_ind = 'Y'
  )
  -- identity info for supervisor
  LEFT JOIN SATURN.SPRIDEN boss  ON (
    boss.spriden_pidm = sup.ner2sup_sup_pidm
    AND boss.spriden_change_ind IS NULL
  )
  -- UA username for supervisor (for email)
  LEFT JOIN GENERAL.GOBTPAC busr ON 
    boss.spriden_pidm = busr.gobtpac_pidm
  -- get the certification records
  LEFT JOIN PAYROLL.PPRCERT crt ON (
    emp.spriden_pidm = crt.pprcert_pidm
    AND UPPER(crt.pprcert_cert_code) LIKE UPPER(:cert_code)
  )
WHERE
  -- only include Primary positions
  emp.nbrbjob_contract_type = 'P'
  AND (
    -- filter to just the desired TKL
    UPPER(emp.pebempl_orgn_code_dist) LIKE UPPER(:the_tkl)
    -- or filter by employee
    OR emp.spriden_id = :uaid
  )
  -- limit to just the most recent certification of the desired type (if exists)
  AND (
    crt.pprcert_pidm IS NULL
    OR crt.pprcert_cert_date = (
      SELECT max(crt2.pprcert_cert_date)
      FROM PAYROLL.PPRCERT crt2
      WHERE crt2.pprcert_pidm = crt.pprcert_pidm
        AND crt2.pprcert_cert_code = crt.pprcert_cert_code
    )
  )
  -- limit to the most current supervisor record (if exists)
  AND (
       sup.ner2sup_pidm IS NULL 
    OR sup.ner2sup_effective_date = (
      SELECT MAX (sup2.ner2sup_effective_date)
      FROM POSNCTL.NER2SUP sup2
      WHERE (
            sup2.ner2sup_sup_ind = 'Y'
        AND sup.ner2sup_pidm = sup2.ner2sup_pidm
        AND sup.ner2sup_posn = sup2.ner2sup_posn
        AND sup.ner2sup_suff = sup2.ner2sup_suff
      )
    )
  )
ORDER BY
  emp.spriden_id,
  crt.pprcert_cert_code
;
