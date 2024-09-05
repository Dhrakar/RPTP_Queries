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
    reg.sfrstcr_pidm
),
labor AS (
SELECT DISTINCT
  a.nbrjlbd_pidm AS pidm,
  a.nbrjlbd_posn AS posn,
  a.nbrjlbd_suff AS suff,
  b.ftvfund_ftyp_code AS fund_typ,
  a.nbrjlbd_fund_code AS fund,
  a.nbrjlbd_orgn_code AS orgn,
  a.nbrjlbd_percent AS pct
FROM
  POSNCTL.NBRJLBD a
  JOIN FIMSMGR.FTVFUND b ON
    b.ftvfund_fund_code = a.nbrjlbd_fund_code
WHERE
  a.nbrjlbd_effective_date = (     
    SELECT MAX (a2.nbrjlbd_effective_date)
    FROM POSNCTL.NBRJLBD a2
    WHERE (
          a.nbrjlbd_pidm = a2.nbrjlbd_pidm
      AND a.nbrjlbd_posn = a2.nbrjlbd_posn
      AND a.nbrjlbd_suff = a2.nbrjlbd_suff
    )
  )
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
  records.prim_degree_desc    AS "Primary Degree",
  records.prim_major_desc     AS "Primary Major",
  records.sec_degree_desc     AS "Secondary Degree",
  records.sec_major_desc      AS "Secondary Major",
  DSDUAF.f_decode$home_campus (
    records.campus
  )                           AS "Home Campus",
  students.sch                AS "Registered SCH",
  DECODE (
    ua.pebempl_empl_status,
    'A', 'Active',
    'T', 'Terminated',
    'Not Employee'
  )                           AS "UA Status",
  CASE
    WHEN ua.pebempl_empl_status = 'A' THEN ua.pebempl_ecls_code
    ELSE NULL
  END                         AS "Employee Class",
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
  '(' || job.nbrbjob_contract_type || ') '
    || job.nbrbjob_posn 
    || '/' 
    || job.nbrbjob_suff       AS "Position",
  LISTAGG (
    labor.fund_typ || ' => ' || labor.fund || '/' || labor.orgn || '(' || labor.pct || '%)', ','
  ) WITHIN GROUP (
    ORDER BY labor.fund_typ , labor.pct DESC
  )                           AS "Labor Dist." 
FROM
  records
  INNER JOIN students ON 
    records.pidm = students.pidm
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
    -- AND job.nbrbjob_contract_type = 'P'
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
  LEFT JOIN labor ON (
    labor.pidm = records.pidm
    AND labor.posn = job.nbrbjob_posn
    AND labor.suff = job.nbrbjob_suff
  )
WHERE
  iden.spriden_change_ind IS NULL
  AND (
    pos.nbrjobs_ecls_code IS NULL 
    OR pos.nbrjobs_ecls_code NOT IN ('XT', 'NR')
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
GROUP BY
  :the_term,
  iden.spriden_id,
  iden.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        iden.spriden_first_name 
       )
    || ' ' 
    || substr ( iden.spriden_mi,1,1),
  records.prim_college_desc,
  records.prim_major_desc,
  records.prim_degree_desc,
  records.sec_major_desc,
  records.sec_degree_desc, 
  DSDUAF.f_decode$home_campus (
    records.campus
  ),
  students.sch,
  DECODE (
    ua.pebempl_empl_status,
    'A', 'Active',
    'T', 'Terminated',
    'Not Employee'
  ),
  CASE
    WHEN ua.pebempl_empl_status = 'A' THEN ua.pebempl_ecls_code
    ELSE NULL
  END,
  CASE
    WHEN ua.pebempl_empl_status = 'A' THEN org.title3
    ELSE  NULL
  END,
  CASE 
    WHEN ua.pebempl_empl_status = 'A' THEN org.title   
    ELSE NULL
  END,
  pos.nbrjobs_desc,
  pos.nbrjobs_ecls_code,
  '(' || job.nbrbjob_contract_type || ') '
    || job.nbrbjob_posn 
    || '/' 
    || job.nbrbjob_suff
ORDER BY
  iden.spriden_id
;
  