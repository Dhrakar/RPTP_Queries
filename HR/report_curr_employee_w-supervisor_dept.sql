SELECT
  emp.spriden_id                       AS "UA ID",
  -- emp.spriden_pidm                     AS "Banner PIDM",
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
  org.title3                           AS "UAF Unit",
  emp.pebempl_orgn_code_home           AS "dLevel",
  org.title                            AS "Department",
  emp.pebempl_orgn_code_dist           AS "TKL",
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
  )                           AS "Supervisor Email",
  nvl2(
    tsappr.spriden_pidm,
    tsappr.spriden_last_name 
    || ', '
    || tsappr.spriden_first_name,
    ' '
  )                           AS "TimeSheet Approver"
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
  -- get supervisor's employee record
  LEFT JOIN PAYROLL.PEBEMPL bemp ON (
    bemp.pebempl_pidm = emp.nbrjobs_supervisor_pidm
  )
  -- get the timesheet approver (if any)
  LEFT JOIN POSNCTL.NBRRJQE tsa ON (
    tsa.nbrrjqe_pidm = emp.pebempl_pidm
    AND tsa.nbrrjqe_posn = emp.nbrjobs_posn
    AND tsa.nbrrjqe_suff = emp.nbrjobs_suff
    AND tsa.nbrrjqe_appr_action_ind = 'A'
  )
  -- name of ts approver (if any)
  LEFT JOIN SATURN.SPRIDEN tsappr ON (
    tsappr.spriden_pidm = tsa.nbrrjqe_appr_pidm
    AND tsappr.spriden_change_ind IS NULL
  )
WHERE
  -- just primary positions
  emp.nbrbjob_contract_type = 'P'
  -- limit to just UAF folks
  AND org.level1 = 'UAFTOT'
  -- uncomment this to limit to those without a supervisor
  -- AND emp.nbrjobs_supervisor_pidm IS NULL
ORDER BY
  emp.spriden_id
;  