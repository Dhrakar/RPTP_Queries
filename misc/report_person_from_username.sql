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
    -- to get all UAF students, change to LIKE '%F'
        a.sgbstdn_levl_code LIKE '%'
    -- uncomment to exclude exchange students
    -- AND a.sgbstdn_majr_code_1 <> 'EXCH'
    -- uncomment to limit to just specific home campuses
    -- AND a.sgbstdn_camp_code IN ('X', 'F')
    AND (
      a.sgbstdn_term_code_eff = (
        SELECT MAX(i.sgbstdn_term_code_eff)
        FROM SATURN.SGBSTDN i
        WHERE i.sgbstdn_pidm = a.sgbstdn_pidm
        AND i.sgbstdn_term_code_eff <= :the_term
      )
    )
)
SELECT
  my.username                 AS "Console User",
  emp.spriden_id              AS "UA ID",
  emp.spriden_pidm            AS "Banner PIDM",
  emp.spriden_last_name
    || ', '
    || coalesce (
        bio.spbpers_pref_first_name,
        emp.spriden_first_name 
       )
    || ' ' 
    || substr ( emp.spriden_mi,1,1)                      
                              AS "Full Name",
  decode (
    ua.pebempl_empl_status,
    'A', 'Active: ' || to_char( ua.pebempl_current_hire_date, 'DD-MON-yy'),
    'T', '  Term: ' || to_char( ua.pebempl_term_date, 'DD-MON-yy'),
    NUll, 'No Employee Records',
    ''
  )                           AS "UA Job Status",
  CASE
    WHEN ua.pebempl_empl_status IS NULL THEN NULL
    ELSE 
      dsduaf.f_decode$orgn_campus(
        org.level1
      )
  END                         AS "UA Job Campus",
  org.title3                  AS "UA Job Unit",
  org.title                   AS "UA Job Department",
  CASE
    WHEN emp.spriden_pidm IS NULL THEN NULL
    WHEN ua.pebempl_empl_status IS NULL AND records.pidm IS NULL THEN 'No Student Records'
    WHEN ua.pebempl_empl_status IS NULL THEN
      dsduaf.f_decode$home_campus(
        records.campus
      )
    ELSE ' - ' 
  END                         AS "UA Student Campus",
  CASE
    WHEN emp.spriden_pidm IS NULL THEN NULL
    WHEN ua.pebempl_empl_status IS NULL THEN records.prim_college_desc
    ELSE ' - ' 
  END                         AS "UA Student College"
FROM
  FNDLB.UA_USERS my
  LEFT JOIN GENERAL.GOBTPAC usr ON (
    usr.gobtpac_external_user = my.username
  )
  LEFT JOIN SATURN.SPRIDEN emp ON (
    emp.spriden_pidm = usr.gobtpac_pidm
    AND emp.spriden_change_ind IS NULL
  )
  LEFT JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = usr.gobtpac_pidm
  )
  LEFT JOIN PAYROLL.PEBEMPL ua  ON (
    emp.spriden_pidm = ua.pebempl_pidm
  )
  LEFT JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = ua.pebempl_orgn_code_home
  )
  LEFT JOIN records ON (
    records.pidm = usr.gobtpac_pidm
  )
ORDER BY 
  my.username
;
