-- ========================================================================================================
--  Position Report for current, active positions from NBBPOSN
--
-- Includes the name, title, grade of the person either currently in that position or most recently in 
-- that position.  The end date is the last date of the employee most recently in a vacated position or
-- when the person in the current position finishes their contract.  Both the PCN TItle & Grade (NBBPOSN)
-- and the Position Title & Grade (NBRJOBS) are included in case they are different.
--
--   @param :fiscal_year  -- 2 digit year to query 
-- ========================================================================================================
WITH
  pcn_count AS (
    SELECT
      job.nbrbjob_posn          AS posn,
      COUNT( job.nbrbjob_posn ) AS total
    FROM
      POSNCTL.NBRBJOB job 
    WHERE 
      job.nbrbjob_begin_date < SYSDATE
      AND (
        job.nbrbjob_end_date IS NULL
        OR job.nbrbjob_end_date > SYSDATE
      )
    GROUP BY
      job.nbrbjob_posn
  ),
  pcn_budget AS (
    SELECT 
      trn.fgbtrnh_doc_ref_num AS doc,
      SUM(
        DECODE(
          trn.fgbtrnh_dr_cr_ind,
          '+', trn.fgbtrnh_trans_amt,
          '-', - trn.fgbtrnh_trans_amt,
          '0'
        )
      )                       AS budget
    FROM
      FIMSMGR.FGBTRNH trn
      JOIN REPORTS.FTVORGN_LEVELS org ON ( 
        trn.fgbtrnh_orgn_code = org.orgn_code
        AND org.level1 = 'UAFTOT'
      )
    WHERE
      trn.fgbtrnh_fsyr_code = :fiscal_year
      AND trn.fgbtrnh_rucl_code IN ('BD11', 'BD14')
      AND trn.fgbtrnh_acct_code < '1971'
    GROUP BY 
      trn.fgbtrnh_doc_ref_num
  ),
  last_assign AS (
    SELECT  
      job.nbrbjob_posn               AS posn,
      spriden_last_name 
        || ', ' 
        || spriden_first_name        AS assigned,
      LPAD ( EXTRACT(MONTH FROM job.nbrbjob_end_date), 2, '0')
        || '/' || LPAD(EXTRACT(DAY FROM job.nbrbjob_end_date),2,'0')
        || '/' || EXTRACT(YEAR FROM job.nbrbjob_end_date)
                                     AS end_date,
      cur.nbrjobs_desc               AS title,
      cur.nbrjobs_sal_grade          AS grade    
    FROM 
      POSNCTL.NBRBJOB job 
      JOIN SATURN.SPRIDEN on ( 
        job.nbrbjob_pidm = spriden_pidm 
        AND spriden_change_ind IS NULL 
      )
      LEFT JOIN POSNCTL.NBRJOBS cur ON (
        job.nbrbjob_posn = cur.nbrjobs_posn
        AND job.nbrbjob_suff = cur.nbrjobs_suff
      )
    WHERE
      job.nbrbjob_activity_date = (
        SELECT MAX( job2.nbrbjob_activity_date )
        FROM POSNCTL.NBRBJOB job2
        WHERE
          job2.nbrbjob_posn = job.nbrbjob_posn
      )
      AND cur.nbrjobs_effective_date = (
        SELECT MAX( cur2.nbrjobs_effective_date)
        FROM POSNCTL.NBRJOBS cur2
        WHERE cur.nbrjobs_posn = cur2.nbrjobs_posn
          AND cur.nbrjobs_suff = cur2.nbrjobs_suff
      )
  )
SELECT DISTINCT
  pos.nbbposn_bpro_code    AS "BPRO",
  pos.nbbposn_posn         AS "PCN",
  pos.nbbposn_auth_number  AS "Auth #",
  pos.nbbposn_ecls_code    AS "ECLS",
  pos.nbbposn_pcls_code    AS "PCLS",
  pos.nbbposn_title        AS "PCN Title",
  pos.nbbposn_grade        AS "PCN Grade",
  DECODE(
    pcn_count.total,
    '1', 'Current', 
    NULL, 'Vacant',
    'Multiple'
  )                        AS "PCN Status",
  last_assign.assigned     AS "Employee Name",
  last_assign.end_date     AS "Position End",
  last_assign.title        AS "Position Title",
  last_assign.grade        AS "Position Grade",
  pcn_budget.budget        AS "Budget",
  org.title2               AS "Cabinet",
  org.title3               AS "Unit",
  org.title                AS "Department"
FROM
  POSNCTL.NBBPOSN pos 
  JOIN POSNCTL.NBRPTOT tot ON pos.nbbposn_posn = tot.nbrptot_posn
  JOIN REPORTS.FTVORGN_LEVELS org ON (
    tot.nbrptot_orgn_code = org.orgn_code
    AND org.level1 = 'UAFTOT'
  )
  LEFT JOIN pcn_count ON pos.nbbposn_posn = pcn_count.posn
  LEFT JOIN pcn_budget ON pos.nbbposn_posn = pcn_budget.doc
  LEFT JOIN last_assign ON pos.nbbposn_posn = last_assign.posn
  LEFT JOIN POSNCTL.NBRBJOB job ON (
    pcn_count.posn = job.nbrbjob_posn
    AND ( 
      job.nbrbjob_begin_date < SYSDATE
      OR job.nbrbjob_begin_date IS NULL
    )
    AND ( 
      job.nbrbjob_end_date > SYSDATE
      OR job.nbrbjob_end_date IS NULL
    )
  )
  LEFT JOIN SATURN.SPRIDEN emp ON (
    job.nbrbjob_pidm = emp.spriden_pidm
    AND emp.spriden_change_ind IS NULL
  )
WHERE
  pos.nbbposn_status = 'A'
  AND (
    pos.nbbposn_end_date > SYSDATE
    OR pos.nbbposn_end_date IS NULL
  )
  AND SUBSTR(pos.nbbposn_posn,1,1) IN ('2', '4', '9' )
  AND tot.nbrptot_fisc_code = '20' || :fiscal_year
  AND tot.nbrptot_status = 'A'
ORDER BY 
  org.title2, org.title3, org.title, pos.nbbposn_posn
;

