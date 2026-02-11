SELECT
  emp.spriden_id,
  emp.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.spriden_first_name 
       )
    || ' ' 
    || substr ( emp.spriden_mi,1,1)                      
                                       AS "Full Name",
  dsduaf.f_decode$benefits_category(
    emp.nbrjobs_ecls_code
  )                                    AS "Employee Type",
  emp.pebempl_orgn_code_home           AS "dLevel",
  org.title                            AS "Department",
  boss.spriden_id                      AS "Supervisor UA ID",
  nvl2(
    boss.spriden_pidm,
    boss.spriden_last_name 
    || ', ' 
    || coalesce (
        bbio.spbpers_pref_first_name,
        boss.spriden_first_name 
       ),
    ' '
  )                           AS "Supervisor Name",
  bemp.pebempl_orgn_code_home AS "Supervisor dLevel",
  (
    SELECT ftvorgn_title
    FROM FIMSMGR.FTVORGN 
    WHERE ftvorgn_orgn_code = bemp.pebempl_orgn_code_home
    FETCH FIRST 1 ROW ONLY
  )                           AS "Supervisor Department",
  nvl2( 
    busr.gobtpac_pidm,
    busr.gobtpac_external_user || '@alaska.edu',
    ' '
  )                           AS "Supervisor Email"
FROM
  REPORTS.N_ACTIVE_JOBS emp
  INNER JOIN SATURN.SPBPERS bio ON emp.pebempl_pidm = bio.spbpers_pidm
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON org.orgn_code = emp.pebempl_orgn_code_home
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN SATURN.SPRIDEN boss  ON (
    boss.spriden_pidm = emp.nbrjobs_supervisor_pidm
    AND boss.spriden_change_ind IS NULL
  )
  -- grab any preferred name for the supervisor (if any)
  LEFT JOIN SATURN.SPBPERS bbio ON (
    bbio.spbpers_pidm = boss.spriden_pidm
  )
  -- grab the username info for the supervisor (also for email) (if any assigned)
  LEFT JOIN GENERAL.GOBTPAC busr ON (
    busr.gobtpac_pidm = boss.spriden_pidm
  )
  LEFT JOIN PAYROLL.PEBEMPL bemp ON (
    bemp.pebempl_pidm = emp.nbrjobs_supervisor_pidm
  )
WHERE
  emp.nbrbjob_contract_type = 'P'
  AND org.level1 = 'UAFTOT'
ORDER BY
  emp.spriden_id
;  