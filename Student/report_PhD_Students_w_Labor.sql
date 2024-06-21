WITH
  records AS (
  SELECT 
    a.sgbstdn_term_code_eff AS term_eff,
    a.sgbstdn_camp_code     AS campus,
    a.sgbstdn_pidm          AS pidm,
    a.sgbstdn_levl_code     AS student_levl_code,
    h.stvlevl_desc          AS student_levl_desc,
    a.sgbstdn_degc_code_1   AS prim_degree_code,
    b.stvdegc_desc          AS prim_degree_desc,
    a.sgbstdn_majr_code_1   AS prim_major_code,
    c.stvmajr_desc          AS prim_major_desc,
    a.sgbstdn_degc_code_2   AS sec_degree_code,
    d.stvdegc_desc          AS sec_degree_desc,
    a.sgbstdn_majr_code_2   AS sec_major_code,
    e.stvmajr_desc          AS sec_major_desc,
    a.sgbstdn_coll_code_1   AS prim_college_code,
    f.stvcoll_desc          AS prim_college_desc,
    a.sgbstdn_coll_code_2   AS sec_college_code,
    g.stvcoll_desc          AS sec_college_desc
  FROM 
    SATURN.SGBSTDN a
    LEFT JOIN SATURN.STVDEGC b ON (
      b.stvdegc_code = a.sgbstdn_degc_code_1
    )
    LEFT JOIN SATURN.STVMAJR c ON (
      c.stvmajr_code = a.sgbstdn_majr_code_1
    )
    LEFT JOIN SATURN.STVDEGC d ON (
      d.stvdegc_code = a.sgbstdn_degc_code_2
    )
    LEFT JOIN SATURN.STVMAJR e ON (
      e.stvmajr_code = a.sgbstdn_majr_code_2
    )
    LEFT JOIN SATURN.STVCOLL f ON (
      f.stvcoll_code = a.sgbstdn_coll_code_1
    )
    LEFT JOIN SATURN.STVCOLL g ON (
      g.stvcoll_code = a.sgbstdn_coll_code_2
    )
    LEFT JOIN SATURN.STVLEVL h ON (
      h.stvlevl_code = a.sgbstdn_levl_code
    )
  WHERE
        a.sgbstdn_levl_code LIKE '%F'
    AND (
      a.sgbstdn_degc_code_1 = 'PHD'
      OR a.sgbstdn_degc_code_2 = 'PHD'
    )
    AND (
      a.sgbstdn_term_code_eff = (
        SELECT MAX(i.sgbstdn_term_code_eff)
        FROM SATURN.SGBSTDN i
        WHERE i.sgbstdn_pidm = a.sgbstdn_pidm
        AND i.sgbstdn_term_code_eff <= :the_term
      )
    )
  ),
students AS (  
  SELECT 
    reg.sfrstcr_pidm    AS pidm,
    a.ssbsect_camp_code AS campus,
    sum(reg.sfrstcr_credit_hr) AS sch
  FROM
    SATURN.SFRSTCR reg
    INNER JOIN SATURN.STVRSTS enr ON (
          reg.sfrstcr_rsts_code = enr.stvrsts_code
      --  limit to just enrolled
      AND enr.stvrsts_incl_sect_enrl = 'Y'
      AND enr.stvrsts_withdraw_ind = 'N'
      AND enr.stvrsts_code NOT IN ('AU')
    ) 
    LEFT JOIN SATURN.SSBSECT a ON (
          a.ssbsect_term_code = reg.sfrstcr_term_code
      AND a.ssbsect_crn = reg.sfrstcr_crn
    )
  WHERE
        reg.sfrstcr_term_code = :the_term
    AND reg.sfrstcr_levl_code LIKE '%F'
  GROUP BY
    reg.sfrstcr_pidm, 
    a.ssbsect_camp_code
)
SELECT DISTINCT
  :the_term                   AS "Term Code",
  iden.spriden_id             AS "UA ID",
  iden.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        iden.spriden_first_name 
       )
    || ' ' 
    || substr ( iden.spriden_mi,1,1)                      
                              AS "Full Name",
  records.prim_college_desc   AS "Primary College",
  records.prim_major_desc     AS "Primary Major",
  DSDUAF.f_decode$home_campus (
    students.campus
  )                           AS "Home Campus",
  students.sch                AS "Registered SCH",
  DECODE (
    ua.pebempl_empl_status,
    'A', 'Active',
    'T', 'Terminated',
    'Not Employee'
  )                           AS "UA Status",
  CASE 
    WHEN ua.pebempl_empl_status = 'A' THEN org.title3
    ELSE  NULL
  END                         AS "Position Unit",
  CASE 
    WHEN ua.pebempl_empl_status = 'A' THEN org.title   
    ELSE NULL
  END                         AS "Position Department",
  pos.nbrjobs_desc            AS "Position Title",
  pos.nbrjobs_ecls_code       AS "Position Class",
  job.nbrbjob_posn 
    || '/' 
    || job.nbrbjob_suff       AS "Position",
  dist.nbrjlbd_percent        AS "Labor %",
  dist.nbrjlbd_fund_code 
    || '/'
    || dist.nbrjlbd_orgn_code AS "Labor Fund/Org",
  ftyp.ftvfund_ftyp_code      AS "Labor Fund Type"
FROM
  records
  INNER JOIN students ON records.pidm = students.pidm
  INNER JOIN SATURN.SPRIDEN iden ON 
    iden.spriden_pidm = records.pidm
  INNER JOIN SATURN.SPBPERS bio ON 
    records.pidm = bio.spbpers_pidm
  LEFT JOIN PAYROLL.PEBEMPL ua ON ua.pebempl_pidm = records.pidm
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = ua.pebempl_orgn_code_home
  )
  LEFT JOIN POSNCTL.NBRBJOB job ON (
        records.pidm = job.nbrbjob_pidm
    -- uncomment to limit to just current positions
    AND job.nbrbjob_contract_type = 'P'
    -- -----------------------------------
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    AND ( 
         job.nbrbjob_end_date >= CURRENT_DATE 
      OR job.nbrbjob_end_date IS NULL
    )
  )
  LEFT JOIN POSNCTL.NBRJOBS pos ON ( 
    job.nbrbjob_pidm = pos.nbrjobs_pidm
    AND job.nbrbjob_posn = pos.nbrjobs_posn
    AND job.nbrbjob_suff = pos.nbrjobs_suff
  )
  LEFT JOIN POSNCTL.NBRJLBD dist ON ( 
        job.nbrbjob_pidm = dist.nbrjlbd_pidm
    AND job.nbrbjob_posn = dist.nbrjlbd_posn
    AND job.nbrbjob_suff = dist.nbrjlbd_suff
  )
  LEFT JOIN FIMSMGR.FTVFUND ftyp ON 
    dist.nbrjlbd_fund_code = ftyp.ftvfund_fund_code
WHERE
  iden.spriden_change_ind IS NULL
  AND (
    pos.nbrjobs_ecls_code IS NULL 
    OR pos.nbrjobs_ecls_code NOT IN ('EX', 'XR', 'XT', 'NR', 'NT')
  )
  -- limit to the most current position (if exists)
  AND (
       pos.nbrjobs_pidm IS NULL 
    OR pos.nbrjobs_effective_date = (     
      SELECT MAX (pos2.nbrjobs_effective_date)
      FROM POSNCTL.NBRJOBS pos2
      WHERE (
            pos.nbrjobs_pidm = pos2.nbrjobs_pidm
        AND pos.nbrjobs_posn = pos2.nbrjobs_posn
        AND pos.nbrjobs_suff = pos2.nbrjobs_suff
      )
    )
  )
  -- limit to the most current labor dist for this job (if exists)
  AND (
       dist.nbrjlbd_pidm IS NULL 
    OR dist.nbrjlbd_effective_date = (     
      SELECT MAX (dist2.nbrjlbd_effective_date)
      FROM POSNCTL.NBRJLBD dist2
      WHERE (
            dist.nbrjlbd_pidm = dist2.nbrjlbd_pidm
        AND dist.nbrjlbd_posn = dist2.nbrjlbd_posn
        AND dist.nbrjlbd_suff = dist2.nbrjlbd_suff
      )
    )
  )
ORDER BY
  iden.spriden_id
;
  