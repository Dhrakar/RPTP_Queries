SELECT
  -- ua.pebempl_pidm                      AS "Banner PIDM",
  emp.spriden_id                       AS "UA ID",
  emp.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.spriden_first_name 
       )
    || ' ' 
    || substr ( emp.spriden_mi,1,1)                      
                                       AS "Full Name",
  ua.pebempl_orgn_code_home            AS "Home dLevel",
  ua.pebempl_orgn_code_dist            AS "TKL",
  decode (
    ua.pebempl_empl_status,
    'A', 'Active: ' || to_char( ua.pebempl_current_hire_date, 'DD-MON-yy'),
    'T', '  Term: ' || to_char( ua.pebempl_term_date, 'DD-MON-yy'),
    '?'
  )                           AS "UA Status",
  DECODE (
    -- show contract type or '-' if terminated 
    job.nbrbjob_contract_type,
    'P', 'Primary',
    'S', 'Secondary',
    'O', 'Overload',
    '-'
  )                           AS "Contract Type",
  job.nbrbjob_begin_date      AS "Contract Start",
  job.nbrbjob_end_date        AS "Contract End",
  job.nbrbjob_posn 
    || '/' 
    || job.nbrbjob_suff       AS "Position",
  psn.nbbposn_status          AS "Position Status",
  pos.nbrjobs_effective_date  AS "Position Date",
  pos.nbrjobs_orgn_code_ts    AS "Pos. TKL",
  pos.nbrjobs_desc            AS "Position Title",
  pos.nbrjobs_ecls_code       AS "Pos. Class",
  pos.nbrjobs_sal_table       AS "Pos. Salary Table",
  pos.nbrjobs_fte             AS "Pos. FTE",
  psn.nbbposn_posn_reports    AS "Reports to Position",
  nvl2(
    rboss.spriden_pidm,
    rboss.spriden_last_name 
    || ', ' 
    || coalesce (
        rbio.spbpers_pref_first_name,
        rboss.spriden_first_name 
       ),
    ' '
  )                           AS "Reports to Person",
  nvl2(
    old_emp_sup.spriden_pidm,
    old_emp_sup.spriden_id
    || ' ' 
    || old_emp_sup.spriden_last_name
    || ', ' 
    || old_emp_sup.spriden_first_name,
    ' '
  )                           AS "[NER2SUP] Supervisor",
  nvl( -- if no supervisor change date, use most recent change date
    to_char(chg.nbrjobs_effective_date, 'MM/DD/YYYY'),
    to_char(pos.nbrjobs_effective_date, 'MM/DD/YYYY')
  )                           AS "Supervisor As of Date",
  boss.spriden_id             AS "Supervisor UA ID",
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
  nvl2( 
    busr.gobtpac_pidm,
    busr.gobtpac_external_user || '@alaska.edu',
    ' '
  )                           AS "Supervisor Email",
  approver.spriden_id         AS "TS Approver ID",
  nvl2(
    approver.spriden_pidm,
    approver.spriden_last_name || ', ' || approver.spriden_first_name 
      || ' ' || substr ( approver.spriden_mi,1,1),
    ' '
  )                           AS "Approver Name"
FROM
  -- start with the core UA employee table
  PAYROLL.PEBEMPL ua 
  -- join with identity info for each employee
  INNER JOIN SATURN.SPRIDEN emp ON (
    emp.spriden_pidm = ua.pebempl_pidm
    AND emp.spriden_change_ind IS NULL
  )
  -- join with biographical info for each person
  INNER JOIN SATURN.SPBPERS bio ON ua.pebempl_pidm = bio.spbpers_pidm 
  -- get information about this person's current base UA job
  INNER JOIN POSNCTL.NBRBJOB job  ON (
        ua.pebempl_pidm = job.nbrbjob_pidm
    AND job.nbrbjob_contract_type = 'P'
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    AND ( 
         job.nbrbjob_end_date >= CURRENT_DATE 
      OR job.nbrbjob_end_date IS NULL
    )
  )
  -- get information about this person's current UA position(s)
  INNER JOIN POSNCTL.NBRJOBS pos  ON ( 
    job.nbrbjob_pidm = pos.nbrjobs_pidm
    AND job.nbrbjob_posn = pos.nbrjobs_posn
    AND job.nbrbjob_suff = pos.nbrjobs_suff
    AND pos.nbrjobs_effective_date <= SYSDATE
  )
  -- get information about the position
  INNER JOIN POSNCTL.NBBPOSN psn ON (
    psn.nbbposn_posn = job.nbrbjob_posn
  )
  -- -----------------------------------------------------
  -- temp refer to the NER2SUP table
  -- -----------------------------------------------------
  LEFT OUTER JOIN POSNCTL.NER2SUP old_sup ON (
        ua.pebempl_pidm = old_sup.ner2sup_pidm
    AND job.nbrbjob_posn = old_sup.ner2sup_posn
    AND job.nbrbjob_suff = old_sup.ner2sup_suff
    AND old_sup.ner2sup_sup_ind = 'Y'
    AND old_sup.ner2sup_effective_date = (
      SELECT MAX(sup_i.ner2sup_effective_date)
      FROM POSNCTL.NER2SUP sup_i
      WHERE 
            sup_i.ner2sup_sup_ind = 'Y'
        AND sup_i.ner2sup_pidm = old_sup.ner2sup_pidm
        AND sup_i.ner2sup_posn = old_sup.ner2sup_posn
        AND sup_i.ner2sup_suff = old_sup.ner2sup_suff
    )
  )
-- get supervisor name from ner2sup
  LEFT OUTER JOIN SATURN.SPRIDEN old_emp_sup ON (
        old_sup.ner2sup_sup_pidm = old_emp_sup.spriden_pidm
    AND old_emp_sup.spriden_change_ind IS NULL
  )
  -- ------------------------------------------------------
  -- get the current person in the 'reports to' (if any)
  LEFT JOIN POSNCTL.NBRBJOB rjob ON (
    rjob.nbrbjob_posn = psn.nbbposn_posn_reports
    AND rjob.nbrbjob_contract_type = 'P'
    AND rjob.nbrbjob_begin_date <= CURRENT_DATE
    AND ( 
         rjob.nbrbjob_end_date >= CURRENT_DATE 
      OR rjob.nbrbjob_end_date IS NULL
    )
  )
  -- grab identity info for the reports to (if assigned)
  LEFT JOIN SATURN.SPRIDEN rboss  ON (
    rboss.spriden_pidm = pos.nbrjobs_supervisor_pidm
    AND rboss.spriden_change_ind IS NULL
  )
  -- grab any preferred name for the reports to (if any)
  LEFT JOIN SATURN.SPBPERS rbio ON (
    rbio.spbpers_pidm = rboss.spriden_pidm
  )
  -- get the effective date of the supervisor change (if any)
  LEFT JOIN POSNCTL.NBRJOBS chg ON (
        chg.nbrjobs_pidm = pos.nbrjobs_pidm
    AND chg.nbrjobs_posn = pos.nbrjobs_posn
    AND chg.nbrjobs_suff = pos.nbrjobs_suff
    AND chg.nbrjobs_jcre_code = 'SPCHG'
  )
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN SATURN.SPRIDEN boss  ON (
    boss.spriden_pidm = pos.nbrjobs_supervisor_pidm
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
  -- get info about the timesheet approver (if any)
  LEFT JOIN POSNCTL.NBRRJQE tsa ON (
    tsa.nbrrjqe_pidm = ua.pebempl_pidm
    AND tsa.nbrrjqe_posn = job.nbrbjob_posn
    AND tsa.nbrrjqe_suff = job.nbrbjob_suff
    AND tsa.nbrrjqe_acat_code = 'TIME'
  )
  -- get the approver identity (if any)
  LEFT JOIN SATURN.SPRIDEN approver ON (
    approver.spriden_pidm = tsa.nbrrjqe_appr_pidm
    AND approver.spriden_change_ind IS NULL
  )
WHERE
  ua.pebempl_empl_status != 'T'
  AND ( 
    ua.pebempl_orgn_code_dist = :tkl
    OR ua.pebempl_orgn_code_home = upper(:home_dlevel)
    OR emp.spriden_id = :uaid
  )
  -- limit to the most current position
  AND (
    pos.nbrjobs_effective_date = (     
      SELECT MAX (pos2.nbrjobs_effective_date)
      FROM POSNCTL.NBRJOBS pos2
      WHERE (
            pos.nbrjobs_pidm = pos2.nbrjobs_pidm
        AND pos.nbrjobs_posn = pos2.nbrjobs_posn
        AND pos.nbrjobs_suff = pos2.nbrjobs_suff
        AND pos2.nbrjobs_effective_date <= SYSDATE
      )
    )
  )
  -- limit to the most recent approver update (if any)
  AND (
    tsa.nbrrjqe_pidm IS NULL
    or tsa.nbrrjqe_appr_seq_no = (
      SELECT max(tsa2.nbrrjqe_appr_seq_no)
      FROM POSNCTL.NBRRJQE tsa2
      WHERE tsa2.nbrrjqe_pidm = tsa.nbrrjqe_pidm
        AND tsa2.nbrrjqe_posn = tsa.nbrrjqe_posn
        AND tsa2.nbrrjqe_suff = tsa.nbrrjqe_suff
        AND tsa2.nbrrjqe_acat_code = 'TIME'
    )
  )
  -- find the most recent supervisor change (if any)
  AND (
    chg.nbrjobs_effective_date IS NULL 
    OR chg.nbrjobs_effective_date = (
    SELECT MAX(chg2.nbrjobs_effective_date)
    FROM POSNCTL.NBRJOBS chg2
    WHERE chg2.nbrjobs_pidm = pos.nbrjobs_pidm
      AND chg2.nbrjobs_posn = pos.nbrjobs_posn
      AND chg2.nbrjobs_suff = pos.nbrjobs_suff
      AND chg2.nbrjobs_effective_date <= SYSDATE
    )
  )
ORDER BY
  1
;

select * from nbrrjqe;