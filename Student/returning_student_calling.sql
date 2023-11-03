-- ===========================================================
--  Returning Student Query
--
-- This query is used to build a list of students for the 
-- admissions folks to include in a calling campaign.  It was
-- developed for Joel Stone and Mary Buchanen.
-- ===========================================================
WITH 
  students AS (  -- create the core cohort of student pidms
                 -- from students registered and enrolled in
                 -- the term provided.  Only include UAF
                 -- undergrads in the set of pidms
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
      AND reg.sfrstcr_levl_code = 'UF'
    GROUP BY
      reg.sfrstcr_pidm, a.ssbsect_camp_code
  ),
  advisors AS ( -- this pulls in the primary advisor record for the students
               -- it only does primary so that we return one record per 
               -- student.
    SELECT
      sgradvr_pidm AS pidm,
      b.spriden_first_name || ' ' || b.spriden_last_name  AS advisor
    FROM 
      SATURN.SGRADVR a
      INNER JOIN SATURN.SPRIDEN b ON (
            b.spriden_pidm = a.sgradvr_advr_pidm
        AND b.spriden_change_ind IS NULL
      )
    WHERE
      a.sgradvr_prim_ind = 'Y'
      and a.sgradvr_term_code_eff = (
        select max( c.sgradvr_term_code_eff )
        from saturn.sgradvr c
        where c.sgradvr_pidm = a.sgradvr_pidm
          and c.sgradvr_prim_ind = 'Y'
     )
  ),
  records AS ( -- builds a table of current SGBSTDN records 
               -- that only include UF and non exchange
    SELECT 
      a.sgbstdn_camp_code   AS campus,
      a.sgbstdn_pidm        AS pidm,
      a.sgbstdn_majr_code_1 AS major,
      a.sgbstdn_term_code_eff AS term,
      b.stvmajr_desc        AS major_desc,
      a.sgbstdn_coll_code_1 AS coll,
      c.stvcoll_desc        AS coll_desc
    FROM 
      SATURN.SGBSTDN a
      INNER JOIN SATURN.STVMAJR b ON (
        b.stvmajr_code = a.sgbstdn_majr_code_1
      )
      INNER JOIN SATURN.STVCOLL c ON (
        c.stvcoll_code = a.sgbstdn_coll_code_1
      )
    WHERE
      a.sgbstdn_levl_code = 'UF'
      AND a.sgbstdn_majr_code_1 <> 'EXCH'
      -- AND a.sgbstdn_camp_code IN ('X', 'F')
      AND (
        a.sgbstdn_term_code_eff = (
          SELECT MAX(b.sgbstdn_term_code_eff)
          FROM SATURN.SGBSTDN b
          WHERE b.sgbstdn_pidm = a.sgbstdn_pidm
          AND b.sgbstdn_term_code_eff <= :the_term
        )
      )
  ),
  records_2 AS ( -- builds a table of current SGBSTDN records 
               -- that only include UF and non exchange
    SELECT 
      a.sgbstdn_camp_code_2 AS campus,
      a.sgbstdn_pidm        AS pidm,
      a.sgbstdn_majr_code_2 AS major,
      b.stvmajr_desc        AS major_desc,
      a.sgbstdn_coll_code_2 AS coll,
      c.stvcoll_desc        AS coll_desc
    FROM 
      SATURN.SGBSTDN a
      INNER JOIN SATURN.STVMAJR b ON (
        b.stvmajr_code = a.sgbstdn_majr_code_2
      )
      INNER JOIN SATURN.STVCOLL c ON (
        c.stvcoll_code = a.sgbstdn_coll_code_2
      )
    WHERE
      a.sgbstdn_levl_code_2 = 'UF'
      AND a.sgbstdn_majr_code_2 <> 'EXCH'
      -- AND a.sgbstdn_camp_code_2 IN ('X', 'F')
      AND (
        a.sgbstdn_term_code_eff = (
          SELECT MAX(b.sgbstdn_term_code_eff)
          FROM SATURN.SGBSTDN b
          WHERE b.sgbstdn_pidm = a.sgbstdn_pidm
          AND b.sgbstdn_term_code_eff <= :the_term
        )
      )
  ),
  holds AS ( -- build a table of all current holds with any
             -- cases of multiple holds per student done as
             -- a listagg
    SELECT
      a.sprhold_pidm AS pidm,
      count(a.sprhold_hldd_code) AS total,
      listagg ( 
        '[' || a.sprhold_hldd_code || '] "' || a.sprhold_reason || '" - ' || b.stvhldd_desc || ' ', ','
      ) WITHIN GROUP (
        ORDER BY a.sprhold_hldd_code
      ) AS codes
    FROM
      SATURN.SPRHOLD a
      JOIN SATURN.STVHLDD b ON a.sprhold_hldd_code = b.stvhldd_code
    WHERE
      a.sprhold_to_date >= SYSDATE
      AND a.sprhold_hldd_code NOT IN ('AT', 'IX', 'AA')
      AND b.stvhldd_reg_hold_ind = 'Y'
    GROUP BY
      a.sprhold_pidm
  )
SELECT DISTINCT
  CASE
    WHEN records.major_desc IS NULL THEN records_2.campus
    ELSE records.campus
  END                                                                             AS "Campus",
  stu.spriden_id                                                                  AS "Student ID",
  stu.spriden_last_name                                                           AS "Last Name",
  nvl( -- get the preferred name if it is set
    bio.spbpers_pref_first_name,
    stu.spriden_first_name
  )                                                                               AS "Preferred or First Name",
  addr.spraddr_city || ', ' || addr.spraddr_stat_code                             AS "Address",
  NVL2( -- only show the formatting if there is a number 
    cell.sprtele_phone_number,
    '(' || cell.sprtele_phone_area || ') '
      || substr(cell.sprtele_phone_number,1,3)
      || '-'
      || substr(cell.sprtele_phone_number,4),
    ' '
  )                                                                               AS "Mobile Number",
  NVL2( -- only show the formatting if there is a number
    day.sprtele_phone_number,
    '(' || day.sprtele_phone_area || ') '
      || substr(day.sprtele_phone_number,1,3)
      || '-'
      || substr(day.sprtele_phone_number,4),
    ' '
  )                                                                               AS "Daytime Number",
  NVL2( -- only show the formatting if there is a number
    eve.sprtele_phone_number,
    '(' || eve.sprtele_phone_area || ') '
      || substr(eve.sprtele_phone_number,1,3)
      || '-'
      || substr(eve.sprtele_phone_number,4),
    ' '
  )                                                                               AS "Evening Number",
  email.goremal_email_address                                                     AS "Preferred Email",
  advisors.advisor                                                                AS "Primary Advisor",
  CASE
    WHEN records.major_desc IS NOT NULL THEN '[1] ' || records.major_desc
    ELSE '[2] ' || records_2.major_desc
  END                                                                             AS "UAF Major",
  CASE
    WHEN records.coll_desc IS NOT NULL THEN '[1] ' || records.coll_desc
    ELSE '[2] ' || records_2.coll_desc
  END                                                                             AS "UAF College",
  nvl2(ath.sgrsprt_actc_code,'Y','N')                                             AS "Athlete Active?",
  nvl2(rss.sgrsatt_atts_code,'Y','N')                                             AS "RSS Active?",
  nvl2(sss.sgrchrt_chrt_code,'Y','N')                                             AS "SSS Active?",
  nvl2(hon.sgrchrt_chrt_code,'Y','N')                                             AS "Honors?",
  vet.sgrvetn_vetc_code                                                           AS "Veteran Code",
  trim(vtc.stvvetc_desc)                                                          AS "Veteran Code Description",
  (
    select sum(sch) 
    from students 
    where students.pidm = stu.spriden_pidm 
      and students.campus = '6'
  )                                                                               AS "eCampus SCH",
  CASE
    WHEN holds.total IS NULL THEN 'None'
    ELSE holds.codes
  END                                                                             AS "Current Holds"  
FROM
  SATURN.SPRIDEN stu
  INNER JOIN students ON (
    students.pidm = stu.spriden_pidm
    AND stu.spriden_change_ind IS NULL
  )
  INNER JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = stu.spriden_pidm
    AND (
      bio.spbpers_ssn NOT LIKE 'BAD%' 
      OR bio.spbpers_ssn IS NULL
    )
    AND bio.spbpers_dead_ind IS NULL
  )
  LEFT JOIN records ON (
    records.pidm = stu.spriden_pidm
  )
  LEFT JOIN records_2 ON (
    records_2.pidm = stu.spriden_pidm
  )
  LEFT JOIN advisors ON (
    advisors.pidm = stu.spriden_pidm
  )
  LEFT JOIN SATURN.SHRDGMR deg ON (
    deg.shrdgmr_pidm = stu.spriden_pidm
    AND deg.shrdgmr_levl_code = 'UF'
    AND deg.shrdgmr_term_code_grad >= :the_term
  )
  LEFT JOIN SATURN.SPRADDR addr ON (
    addr.spraddr_pidm = stu.spriden_pidm
    AND addr.spraddr_atyp_code = 'OE'
  ) 
  LEFT JOIN SATURN.SPRTELE cell ON (
        cell.sprtele_pidm = stu.spriden_pidm
    AND cell.sprtele_tele_code = 'CELL'
  ) 
  LEFT JOIN SATURN.SPRTELE day ON (
        day.sprtele_pidm = stu.spriden_pidm
    AND day.sprtele_tele_code = 'DAY'
  ) 
  LEFT JOIN SATURN.SPRTELE eve ON (
        eve.sprtele_pidm = stu.spriden_pidm
    AND eve.sprtele_tele_code = 'EVES'
  )
  LEFT JOIN SATURN.SGRSPRT ath ON (
        ath.sgrsprt_pidm = stu.spriden_pidm
    AND ath.sgrsprt_term_code = :the_term
    AND ath.sgrsprt_spst_code = 'A'
  )
  LEFT JOIN SATURN.SGRVETN vet ON (
    vet.sgrvetn_pidm = stu.spriden_pidm
    AND vet.sgrvetn_term_code_va = :the_term
  )
  LEFT JOIN SATURN.STVVETC vtc ON 
    vet.sgrvetn_vetc_code = vtc.stvvetc_code
  LEFT JOIN GENERAL.GOREMAL email ON ( 
    email.goremal_pidm = stu.spriden_pidm
    AND email.goremal_status_ind = 'A'
    AND email.goremal_preferred_ind = 'Y'
  )
  LEFT JOIN holds ON (
    holds.pidm = stu.spriden_pidm
  )
  LEFT JOIN SATURN.SGRSATT rss ON (
    rss.sgrsatt_pidm = stu.spriden_pidm
    AND rss.sgrsatt_atts_code = 'FRSS'
  )
  LEFT JOIN SATURN.SGRCHRT sss ON (
    sss.sgrchrt_pidm = stu.spriden_pidm
    AND sss.sgrchrt_chrt_code = 'FSSSPC'
  )
  LEFT JOIN SATURN.SGRCHRT hon ON (
    hon.sgrchrt_pidm = stu.spriden_pidm
    AND hon.sgrchrt_chrt_code LIKE 'FHNRC'
  )
WHERE 
  deg.shrdgmr_pidm IS NULL
  AND (
    records.major_desc IS NOT NULL OR records_2.major_desc IS NOT NULL
  )
  AND ( -- get the most recent main address for city/state
    addr.spraddr_seqno IS NULL
    OR addr.spraddr_seqno = (
     SELECT MAX(a2.spraddr_seqno) 
     FROM SPRADDR a2
      WHERE 
        addr.spraddr_pidm = a2.spraddr_pidm
        AND a2.spraddr_atyp_code = 'OE'
    ) 
  )
  AND ( -- get the most recent Cell record (if it exists)
    cell.sprtele_seqno IS NULL
    OR cell.sprtele_seqno = (
        SELECT max(i.sprtele_seqno)
        FROM saturn.sprtele i
        WHERE i.sprtele_pidm = cell.sprtele_pidm
          AND i.sprtele_tele_code = 'CELL'
      )
  )
  AND ( -- get the most recent Daytime record (if it exists)
    day.sprtele_seqno IS NULL
    OR day.sprtele_seqno = (
        SELECT max(i.sprtele_seqno)
        FROM saturn.sprtele i
        WHERE i.sprtele_pidm = day.sprtele_pidm
          AND i.sprtele_tele_code = 'DAY'
      )
  )
  AND ( -- get the most recent Evening record (if it exists)
    eve.sprtele_seqno IS NULL
    OR eve.sprtele_seqno = (
        SELECT max(i.sprtele_seqno)
        FROM saturn.sprtele i
        WHERE i.sprtele_pidm = eve.sprtele_pidm
          AND i.sprtele_tele_code = 'EVES'
      )
  )
  -- make sure that at least one type of ph number exists
  AND (
       cell.sprtele_pidm IS NOT NULL
    OR day.sprtele_pidm IS NOT NULL
    OR eve.sprtele_pidm IS NOT NULL
  )
  AND ( -- get the most recent preferred email record
    email.goremal_pidm IS NULL
    OR email.goremal_activity_date = (
      SELECT MAX (b.goremal_activity_date)
      FROM GENERAL.GOREMAL b
      WHERE (
        b.goremal_pidm = email.goremal_pidm
        AND b.goremal_status_ind = 'A'
        AND b.goremal_preferred_ind = 'Y'
      )
    )
  )
;
