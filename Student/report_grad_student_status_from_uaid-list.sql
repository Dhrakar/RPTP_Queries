WITH
  grads AS (
    SELECT
      b.spriden_pidm as pidm
    FROM
      FNDLB.UAID_COMPARE a
      INNER JOIN SATURN.SPRIDEN b ON (
        b.spriden_change_ind IS NULL
        and b.spriden_id = a.id
      )
  ),
  records AS ( 
  -- buils temp table of all current graduate student records that are 
  -- effective as of or before the current term
  SELECT 
    a.sgbstdn_term_code_eff    AS term_eff,
    a.sgbstdn_camp_code        AS campus,
    a.sgbstdn_pidm             AS pidm,
    a.sgbstdn_degc_code_1      AS prim_degree_code,
    (
      SELECT stvdegc_desc
      FROM SATURN.STVDEGC 
      WHERE stvdegc_code = a.sgbstdn_degc_code_1
    )                          AS prim_degree_desc,
    a.sgbstdn_majr_code_1      AS prim_major_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_1
    )                          AS prim_major_desc,
    (
      SELECT substr(stvmajr_cipc_code, 0,2) || '.' || substr(stvmajr_cipc_code, 3, 4)
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_1
    )                          AS prim_major_cip_code,
    a.sgbstdn_majr_code_conc_1 AS prim_conc_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_conc_1
    )                          AS prim_conc_desc,
    a.sgbstdn_coll_code_1      AS prim_college_code,
    (
      SELECT stvcoll_desc 
      FROM SATURN.STVCOLL
      WHERE stvcoll_code = a.sgbstdn_coll_code_1
    )                          AS prim_college_desc,
    a.sgbstdn_program_1        AS prim_program_code,
    a.sgbstdn_degc_code_2      AS sec_degree_code,
    (
      SELECT stvdegc_desc
      FROM SATURN.STVDEGC 
      WHERE stvdegc_code = a.sgbstdn_degc_code_2
    )                          AS sec_degree_desc,
    a.sgbstdn_majr_code_2      AS sec_major_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_2
    )                          AS sec_major_desc,
    (
      SELECT substr(stvmajr_cipc_code, 0,2) || '.' || substr(stvmajr_cipc_code, 3, 4)
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_2
    )                          AS sec_major_cip_code,
    a.sgbstdn_majr_code_conc_1 AS sec_conc_code,
    (
      SELECT stvmajr_desc  
      FROM SATURN.STVMAJR
      WHERE stvmajr_code = a.sgbstdn_majr_code_conc_2
    )                          AS sec_conc_desc,
    a.sgbstdn_coll_code_2      AS sec_college_code,
    (
      SELECT stvcoll_desc 
      FROM SATURN.STVCOLL
      WHERE stvcoll_code = a.sgbstdn_coll_code_2
    )                          AS sec_college_desc,
    a.sgbstdn_program_2        AS sec_program_code,
    a.sgbstdn_levl_code        AS levl_code,
    a.sgbstdn_resd_code        AS resd_code,
    a.sgbstdn_astd_code        AS astd_code,
    ROW_NUMBER() OVER (
      PARTITION BY a.sgbstdn_pidm
      ORDER BY a.sgbstdn_term_code_eff DESC
    ) as row_no
  FROM 
    SATURN.SGBSTDN a
    INNER JOIN grads ON grads.pidm = a.sgbstdn_pidm
  ),
  reg AS (
  SELECT
    grads.pidm              as pidm,
    a.sfrstca_term_code     as term_code,
    a.sfrstca_crn           as crn,
    a.sfrstca_rsts_code     as rsts_code,
    a.sfrstca_seq_number    as seq_no,
    a.sfrstca_activity_date as activity_date,
    a.sfrstca_credit_hr     as credit_hour,
    b.stvrsts_voice_type    as voice_type,
    ROW_NUMBER() OVER (
      PARTITION BY a.sfrstca_term_code, a.sfrstca_pidm, a.sfrstca_crn
      ORDER BY a.sfrstca_term_code DESC, a.sfrstca_seq_number DESC
    ) as row_no
  FROM
    grads
    LEFT JOIN SATURN.SFRSTCA a ON (
      grads.pidm = a.sfrstca_pidm
      and a.sfrstca_levl_code = 'GF'
    )
    LEFT JOIN SATURN.STVRSTS b ON (
      b.stvrsts_code = a.sfrstca_rsts_code
    )
  ),
  curr AS (
    SELECT 
      reg.*
    FROM   
      reg
    WHERE  
      reg.row_no = 1
    ORDER BY 
      reg.pidm
  ),
  enrolled AS (
    SELECT
      a.pidm,
      a.term_code,
      LISTAGG( 
        a.voice_type, ','
      ) WITHIN GROUP (
        order by a.crn
      )  AS stats
    FROM
      curr a
    GROUP BY
      a.pidm,
      a.term_code
  ),
  sch AS (
    SELECT
      curr.pidm, 
      curr.term_code,
      sum(
        CASE -- only add enrolled courses to sch total
          WHEN curr.voice_type = 'R' THEN curr.credit_hour
          ELSE 0
        END 
      )                          AS total
    FROM 
      curr
    GROUP BY
      curr.pidm, 
      curr.term_code
  ),
  apps AS (
    -- builds a temporary table with student applications for level GF
    -- that have an accepted application decision. Grabs the most recent
    -- decision for each application.
    SELECT
      a.saradap_pidm            AS pidm,
      a.saradap_term_code_entry AS term_code
    FROM
      SATURN.SARADAP a
      INNER JOIN SATURN.SARAPPD b ON (
            b.sarappd_pidm = a.saradap_pidm
        AND b.sarappd_term_code_entry = a.saradap_term_code_entry
        AND b.sarappd_appl_no = a.saradap_appl_no
        AND b.sarappd_apdc_code IN ( 
          SELECT stvapdc_code
          FROM SATURN.STVAPDC
          WHERE stvapdc_inst_acc_ind = 'Y'
        )
        AND b.sarappd_seq_no = (
          SELECT MAX (b2.sarappd_seq_no)
          FROM SATURN.SARAPPD b2
          WHERE b2.sarappd_pidm = b.sarappd_pidm
            AND b2.sarappd_term_code_entry = b.sarappd_term_code_entry
            AND b2.sarappd_appl_no = b.sarappd_appl_no
        )
      )
    WHERE
      a.saradap_levl_code = 'GF'
  ),
  dis_pct AS (
    -- build a temp table of the % completion for grad students for dissertations
    -- this is from the FD codes in sgrsatt. Null if no codes found.  Only 
    -- counts most recent code.
    SELECT
      a.sgrsatt_pidm AS pidm,
      CASE
        WHEN a.sgrsatt_atts_code = 'FD00' THEN '100'
        WHEN a.sgrsatt_atts_code in ( 'FD25', 'FD50', 'FD75', 'FD99' ) THEN substr(a.sgrsatt_atts_code, 3,2)
        ELSE NULL
      END   AS pct
    FROM
      SATURN.SGRSATT a
    WHERE
      a.sgrsatt_atts_code in ( 
        'FD25', 'FD50', 'FD75', 'FD99', 'FD00'
      )
      AND a.sgrsatt_activity_date = (
        SELECT max(a1.sgrsatt_activity_date)
        FROM SATURN.SGRSATT a1
        WHERE a1.sgrsatt_pidm = a.sgrsatt_pidm
          AND a1.sgrsatt_atts_code =  a.sgrsatt_atts_code
      )
  ),
  res_pct AS (
    -- build a temp table of the % completion for grad students for research
    -- this is from the FD codes in sgrsatt. Null if no codes found.  Only 
    -- counts most recent code.
    SELECT
      a.sgrsatt_pidm AS pidm,
      CASE
        WHEN a.sgrsatt_atts_code = 'FR00' THEN '100'
        WHEN a.sgrsatt_atts_code in ( 'FR25', 'FR50', 'FR75' ) THEN substr(a.sgrsatt_atts_code, 3,2)
        ELSE NULL
      END   AS pct
    FROM
      SATURN.SGRSATT a
    WHERE
      a.sgrsatt_atts_code in ( 
        'FR25', 'FR50', 'FR75', 'FR100'
      )
      AND a.sgrsatt_activity_date = (
        SELECT max(a1.sgrsatt_activity_date)
        FROM SATURN.SGRSATT a1
        WHERE a1.sgrsatt_pidm = a.sgrsatt_pidm
          AND a1.sgrsatt_atts_code =  a.sgrsatt_atts_code
      )
  ),
  awd_deg AS (
    -- builds a temp table of student degrees
    SELECT
      a.shrdgmr_pidm AS pidm,
      trim( 
        LISTAGG ( DISTINCT
          (
            SELECT substr(stvcamp_desc,0,3)
            FROM SATURN.STVCAMP
            WHERE stvcamp_code = shrdgmr_camp_code
          ) || ': ' ||
          a.shrdgmr_degc_code || '(' || 
          a.shrdgmr_majr_code_1 || ', ' ||
          to_char( a.shrdgmr_grad_date, 'yyyy') || ')'
          , ', '
        ) WITHIN GROUP (
          ORDER BY a.shrdgmr_grad_date
        )
      ) AS degrees
  FROM
    SATURN.SHRDGMR a
  WHERE
    -- this list may expand to certificates, licenses, etc. based on needs of Grad school
    a.shrdgmr_degc_code NOT IN  ('NDS')
    AND a.shrdgmr_degc_code IS NOT NULL
  GROUP BY
    a.shrdgmr_pidm
  )
SELECT
  enrolled.term_code,
  stu.spriden_id                           AS "UA ID",
  stu.spriden_first_name                   AS "First Name",
  substr (
    stu.spriden_mi, 0, 1
  )                                        AS "Middle Initial",
  stu.spriden_last_name                    AS "Last Name",
  usr.gobtpac_external_user 
   || '@alaska.edu'                        AS "UA Email",
  pe.goremal_email_address                 AS "Preferred Email",
  ma.spraddr_street_line1 
   || ', ' 
   || ma.spraddr_city 
   || ', ' 
   || ma.spraddr_stat_code 
   || ', ' 
   || ma.spraddr_zip                       AS "Mailing Address",
  ma.spraddr_from_date                     AS "Date Mailing Address Updated",
  DECODE (
    records.campus,
    'UAF','UA Fairbanks',
    '1','Rural College',
    '2','Fairbanks',       -- UAF - Correspondence Study
    '3','Fairbanks',       -- UAF - Juneau Fisheries
    '5','Fairbanks',       -- Ilisagvik
    '6','eCampus',
    '7','Bristol Bay',
    '8','Interior Alaska',
    'B','UAF CTC',         -- UAA - Military Program
    'F','Troth Yeddha' || chr(39) || '',
    'L','Kuskokwim',
    'N','Northwest',
    'X','UAF CTC',
    'Y','UAF CTC',         -- UAF - Tanana Valley Campus
    'Z','Chukchi',
     'Other UA Campus (' || records.campus || ')'
  )                                        AS "Home Campus",
  records.prim_college_code                AS "Prim. Prog. College Code",
  records.prim_college_desc                AS "Prim. Prog. College",
  records.prim_program_code                AS "Prim. Curr. Prog. Code",
  records.sec_program_code                 AS "Sec. Curr. Prog. Code",
  records.prim_degree_code                 AS "Prim. Curr. Deg. Code",
  records.sec_degree_code                  AS "Sec. Curr. Deg. Code",
  records.prim_major_code                  AS "Prim. Curr. Maj. Code",
  records.prim_conc_code                   AS "Prim. Curr. Concentration Code",
  records.prim_major_cip_code              AS "Prim. Curr. Major CIP",
  ( -- gets the most recent accepted program term. use subselect so that we don't 
    -- need to group all the other columns
    SELECT
      max(term_code)
    FROM
      apps
    WHERE
      apps.pidm = records.pidm 
      AND apps.term_code <= enrolled.term_code
  )                                        AS "Started Program",
  CASE
    -- checks to see if either the student's biographic record shows they
    -- are a US citizen, or their most recent intl record does
    WHEN bio.spbpers_citz_code = 'Y' OR (
      SELECT
        a.gobintl_natn_code_legal
      FROM 
        GENERAL.GOBINTL a
      WHERE
        a.gobintl_pidm = records.pidm
        AND a.gobintl_activity_date = (
          SELECT MAX(a2.gobintl_activity_date)
          FROM GENERAL.GOBINTL a2
          WHERE a2.gobintl_pidm = a.gobintl_pidm
        )
      ) = 'US'
    THEN 'US Citizen'
    WHEN (
      SELECT 
        a.gorvisa_vtyp_code
      FROM 
        GENERAL.GORVISA a
      WHERE
        a.gorvisa_pidm = records.pidm
        AND a.gorvisa_seq_no = (
          SELECT MAX(a2.gorvisa_seq_no)
          FROM GENERAL.GORVISA a2
          WHERE a2.gorvisa_pidm = a.gorvisa_pidm
        )
      ) = 'PR'
    THEN 'Permanent Resident'
    ELSE 'Non US Citizen'
  END                                      AS "US Student",
  (
    SELECT stvresd_desc
    FROM SATURN.STVRESD
    WHERE stvresd_code = records.resd_code
  )                                        AS "AK Residency",
  CASE
    -- these cases are taken in order and the first one to match wins
    WHEN INSTR(enrolled.stats, 'R') > 0 THEN 'Enrolled'  -- if any course shows a voice type of R
    WHEN INSTR(enrolled.stats, 'W') > 0 THEN 'Withdrawn' -- if no R's but any withdraws
    WHEN INSTR(enrolled.stats, 'D') > 0 THEN 'Dropped'   -- If no Rs or Ws but any drops
    ELSE 'Wait List' -- If only 'L' codes for the registered courses
  END                                      AS "Curr Enroll Status",
  rpad ( -- pad to 10 chars to line things up
    CASE 
      WHEN sch.total >= 9             THEN 'Full Time'
      WHEN sch.total BETWEEN 0 AND 9  THEN 'Part Time'
      ELSE ''
    END,
    10, 
    ' '
  )                                        AS "Status",
  sch.total                                AS "Credit Hours",
  TO_CHAR(
    ROUND(ggpa.shrlgpa_gpa,2), '9D00'
  )                                        AS "Graduate GPA",
  ( 
    SELECT max(pct)
    FROM dis_pct
    WHERE dis_pct.pidm = enrolled.pidm
  )                                        AS "Dissertation %",
  (
    SELECT max(pct)
    FROM res_pct
    WHERE res_pct.pidm = enrolled.pidm
  )                                        AS "Research %",
  records.astd_code                        AS "Acad. Standing",
  awd_deg.degrees                          AS "Degrees Awarded"
FROM
  enrolled
  INNER JOIN records ON (
    records.pidm = enrolled.pidm
    AND records.row_no = 1
  )
  INNER JOIN SATURN.SPRIDEN stu ON (
    stu.spriden_change_ind IS NULL
    and stu.spriden_pidm = enrolled.pidm
  )
  -- get the demographic data
  INNER JOIN SATURN.SPBPERS bio ON (
        bio.spbpers_pidm = enrolled.pidm
    AND bio.spbpers_ssn != 'BAD'
  )
  -- get the UA username
  INNER JOIN GENERAL.GOBTPAC usr ON (
    usr.gobtpac_pidm = enrolled.pidm
  )
  -- get the total SCH for the registered terms
  INNER JOIN sch ON (
        sch.pidm = enrolled.pidm 
    AND sch.term_code = enrolled.term_code
  )
  -- get the preferred email address
  LEFT JOIN GENERAL.GOREMAL pe ON ( 
        pe.goremal_pidm = enrolled.pidm
    AND pe.goremal_status_ind = 'A'
    AND pe.goremal_preferred_ind = 'Y'
  )
  -- get the mailing address
  LEFT JOIN SATURN.SPRADDR ma ON (
        ma.spraddr_pidm = enrolled.pidm
    AND ma.spraddr_atyp_code = 'MA'
  )
  -- get the cumulative GPA for Graduate
  LEFT JOIN SATURN.SHRLGPA ggpa ON (
    ggpa.shrlgpa_pidm = enrolled.pidm
    AND ggpa.shrlgpa_levl_code = 'GF'
    AND ggpa.shrlgpa_gpa_type_ind = 'I'
  )
  -- get the awarded degrees (if any)
  LEFT JOIN awd_deg ON (
    awd_deg.pidm = enrolled.pidm
  )
WHERE
  enrolled.term_code >= '202401'
  AND ( -- get the most recent pref. email address (if exists)
       pe.goremal_pidm IS NULL
    OR pe.goremal_activity_date = (
      SELECT MAX(e2.goremal_activity_date)
      FROM GENERAL.GOREMAL e2
      WHERE e2.goremal_pidm = pe.goremal_pidm
        AND e2.goremal_status_ind = 'A'
        AND e2.goremal_preferred_ind = 'Y'
    )
  )
  AND ( -- get the most recent mailing address (if exists)
       ma.spraddr_seqno IS NULL
    OR ma.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        ma.spraddr_pidm = a2.spraddr_pidm
        AND a2.spraddr_atyp_code = 'MA'
    )
  )
ORDER BY
  stu.spriden_id,
  enrolled.term_code desc
;

select * from sfrstca;