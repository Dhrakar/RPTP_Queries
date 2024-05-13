-- =============================================================================
-- =  SQL Query for extracting current student data for EAB
-- =  
-- =============================================================================

-- set to create a CSV file
set markup csv on quote on

-- output CSV file (overwritten each run)
spool &&home./data/eab_extract.csv

WITH
  terms AS (
    -- get the current regular spring/summer/fall term code
    SELECT
    max(a.stvterm_code) AS curr_term
    -- '202203' AS curr_term
    FROM SATURN.STVTERM a
    WHERE substr(a.stvterm_code,6,1) = '3' -- IN ('1','2','3') -- only do fall for now 
      AND a.stvterm_start_date <= SYSDATE
  ),
  curr_apps AS (
    SELECT
      a.saradap_pidm AS pidm,
      a.saradap_term_code_entry AS term_code,
      a.saradap_appl_no  AS appl_no,
      a.saradap_appl_date AS appl_date,
      b.sarappd_seq_no  AS seq_no
    FROM
      SATURN.SARADAP a
      -- include the matching decisions 
      INNER JOIN SATURN.SARAPPD b ON (
            b.sarappd_pidm = a.saradap_pidm
        AND b.sarappd_term_code_entry = a.saradap_term_code_entry
        AND b.sarappd_appl_no = a.saradap_appl_no
      )
      -- limit results to just accepted or withdrawn
      INNER JOIN SATURN.STVAPDC c ON (
            c.stvapdc_code = b.sarappd_apdc_code
        AND (
             b.sarappd_apdc_code IN ('WA', 'PA')
          OR c.stvapdc_inst_acc_ind = 'Y'
        )
      )
    WHERE
      -- only include undergrad UAF
          a.saradap_levl_code = 'UF'
      -- only first time or transfer
      AND a.saradap_styp_code in ('F', 'T')
      -- only bachelor-type degrees
      AND a.saradap_degc_code_1 in ( 
        SELECT a1.stvdegc_code
        FROM SATURN.STVDEGC a1
        JOIN SATURN.STVDLEV a2 ON (
              a2.stvdlev_code = a1.stvdegc_dlev_code
          AND a2.stvdlev_code in ('02', 'B')
        )
      )
      -- get the highest sequence number from the current decision record info
      AND b.sarappd_seq_no = (
        SELECT MAX(b1.sarappd_seq_no)
        FROM SATURN.SARAPPD b1
        WHERE b1.sarappd_pidm = b.sarappd_pidm
          AND b1.sarappd_appl_no = b.sarappd_appl_no
          AND b1.sarappd_term_code_entry = b.sarappd_term_code_entry
      )
  ),
  enroll AS (  
    SELECT 
      reg.sfrstcr_pidm           AS pidm,
      min(reg.sfrstcr_rsts_date) AS rsts_date,
      sum(reg.sfrstcr_credit_hr) AS sch
    FROM
      SATURN.SFRSTCR reg
      INNER JOIN SATURN.STVRSTS enr ON (
            reg.sfrstcr_rsts_code = enr.stvrsts_code
        --  limit to just enrolled
        AND enr.stvrsts_voice_type = 'R'
      ) 
      LEFT JOIN SATURN.SSBSECT a ON (
            a.ssbsect_term_code = reg.sfrstcr_term_code
        AND a.ssbsect_crn = reg.sfrstcr_crn
      )
    WHERE
          reg.sfrstcr_term_code = (
            SELECT curr_term
            FROM terms
          )
      -- Gets all enrolled UAF students for this term
      AND reg.sfrstcr_levl_code LIKE '%F'
    GROUP BY
      reg.sfrstcr_pidm
  ),
  race AS (  -- temp table with a count of race codes per person
             -- this allows getting the total race codes without 
             -- needing to group everything
    SELECT
      a.gorprac_pidm            AS pidm,
      count(a.gorprac_race_cde) AS count
    FROM 
      GENERAL.GORPRAC a
    GROUP BY
      a.gorprac_pidm
  ),
  citiz AS ( -- build a temp table of the most recent citizenships
    SELECT
      a.gobintl_pidm            AS pidm,
      a.gobintl_natn_code_legal AS country
    FROM GENERAL.GOBINTL a
    WHERE
      a.gobintl_activity_date = (
        SELECT MAX(a2.gobintl_activity_date)
        FROM GENERAL.GOBINTL a2
        WHERE a2.gobintl_pidm = a.gobintl_pidm
      )
  ),
  tests AS ( -- builds a table with the most current score
             -- for each student for each test
    SELECT
      a.sortest_pidm        AS pidm,
      a.sortest_tesc_code  AS test_code,
      a.sortest_test_score AS test_score
    FROM 
      SATURN.SORTEST a
    WHERE
      -- limit this to just the tests we need
      a.sortest_tesc_code IN (
        'EACO', -- ACT Composite
        'SATT', -- SAT Composite
        'SATC', -- SAT Reading
        'SATM', -- SAT Mathematics
        'SATW', -- SAT Writing
        'S12',  -- SATR Mathematics
        'S11',  -- SATR Reading
        'S10'   -- SATR Composite
      )
      -- get the most recent test with the highest score
      AND a.sortest_test_date = (
        SELECT MAX(a2.sortest_test_date)
        FROM SATURN.SORTEST a2
        WHERE a2.sortest_pidm = a.sortest_pidm
          AND a2.sortest_tesc_code = a.sortest_tesc_code
          AND a.sortest_test_score = (
            SELECT MAX(a3.sortest_test_score)
            FROM SATURN.SORTEST a3
              WHERE a3.sortest_pidm = a2.sortest_pidm
                AND a3.sortest_tesc_code = a2.sortest_tesc_code
          )
      )
  ),
  military AS ( -- builds a table of the most recent UAF mil statuses by pidm
                -- needed to collapse multiple attributes into one list
    SELECT 
      a.sgrsatt_pidm AS pidm,
      LISTAGG (
        a.sgrsatt_atts_code, ','
      ) WITHIN GROUP (
        ORDER BY a.sgrsatt_atts_code
      )  AS satt
    FROM
      SATURN.SGRSATT a
      JOIN SATURN.STVATTS b ON (
        b.stvatts_code = a.sgrsatt_atts_code
      )
    WHERE a.sgrsatt_atts_code IN ( 
         'ADA',-- active duty - Army
        'ADAF',-- actove duty - AF
        'ADNG',-- active duty - NG
        'FCTM',-- active duty - GoArmyEd code
        'FGAR',-- active duty - GoArmyEd code
        'FMCH',-- Active duty child
        'FMDP',-- Active duty dependent (old code and superceeded by FMCH, FMSP)
        'FMIL',-- Active duty
        'FMNG',-- National guard
        'FNGC',-- National guard child
        'FMSP',-- Active duty spouse
        'FNGS',-- National guard spouse
        'FRCH',-- Reservist child
        'FRSP',-- Reservist spouse
        'FRSV',-- Reservist
        'FRTC',-- ROTC cadet
        'FVCH',-- Veteran child
        'FVDP',-- Veteran dependent (old code and superceeded by FVCH, FVSP)
        'FVET',-- Military veteran
        'FVSP' -- Veteran spouse
      ) 
      -- get the most recent military status (if any)
      AND (
        a.sgrsatt_term_code_eff = (
          SELECT MAX(a2.sgrsatt_term_code_eff)
          FROM SATURN.SGRSATT a2
          WHERE a2.sgrsatt_pidm = a.sgrsatt_pidm
            AND a2.sgrsatt_atts_code = a.sgrsatt_atts_code
        )
      )
      GROUP BY 
        a.sgrsatt_pidm
  ),
  cgpa AS (
    SELECT DISTINCT
      a.sordegr_pidm AS pidm,
      a.sordegr_hours_transferred AS hrs,
      a.sordegr_gpa_transferred AS gpa
    FROM
      SATURN.SORDEGR a
    WHERE
      a.sordegr_hours_transferred IS NOT NULL
      AND a.sordegr_hours_transferred = (
        SELECT MAX(a2.sordegr_hours_transferred)
        FROM SATURN.SORDEGR a2
        WHERE a2.sordegr_pidm = a.sordegr_pidm
          AND a2.sordegr_hours_transferred > 0
      )
  ),
  transfer AS (
    SELECT 
      a.shrtrce_pidm              AS pidm,
      sum(a.shrtrce_credit_hours) AS sch
    FROM
      SATURN.SHRTRCE a
    WHERE
      a.shrtrce_term_code_eff <= (
          SELECT curr_term
          FROM terms
        )
      AND a.shrtrce_levl_code = 'UF'
    GROUP BY
      a.shrtrce_pidm
  )
SELECT DISTINCT
  curr_apps.pidm                        AS "StudentPIDM",
  stu.spriden_ID                        AS "StudentID",
  ( -- get the salesforce ID
    SELECT sfxgpid_sfid
    FROM SATURN.SFXGPID 
    WHERE sfxgpid_pidm = curr_apps.pidm
      AND sfxgpid_status = 'Active'
  )                                     AS "CRMStudentID",
  stu.spriden_ID                        AS "ERPStudentID",
  stu.spriden_ID                        AS "FinAidID",
  CASE
    WHEN substr(app.saradap_term_code_entry, 5, 2) = '01' THEN 'Spring'
    WHEN substr(app.saradap_term_code_entry, 5, 2) = '02' THEN 'Summer' 
    ELSE 'Fall'
  END                                   AS "EntryTerm",
  SUBSTR (
    app.saradap_term_code_entry,0,4
  )                                     AS "EntryYear",
  app.saradap_styp_code                 AS "EntryStatus",
  dsn.sarappd_apdc_code                 AS "AdmitStatus",
  pr.spraddr_street_line1               AS "PermanentAdress1",
  pr.spraddr_street_line2               AS "PermanentAdress2",
  pr.spraddr_city                       AS "PermanentCity",
  pr.spraddr_stat_code                  AS "PermanentState",
  pr.spraddr_zip                        AS "PermanentZip",
  nvl (
    pr.spraddr_natn_code,
    'US'
  )                                     AS "PermanentCountry",
  ROUND(hs.sorhsch_gpa,2)               AS "HSGPA",
  (
    SELECT ROUND(MAX(cgpa.gpa), 2) 
    FROM cgpa 
    WHERE cgpa.pidm = curr_apps.pidm
  )                                     AS "CollegeGPA",
  -- '' AS "RecalcGPA", -- N/A
  app.saradap_appl_date                 AS "AppDate",
  DECODE (
    dsn.sarappd_apdc_code,
    'WA', '',
    'PA', '', 
    to_char(dsn.sarappd_apdc_date, 'DD/MM/YYYY')
  )                                     AS "AdmitDate",
  enroll.rsts_date                      AS "EnrollDate",
  DECODE (
    dsn.sarappd_apdc_code,
    'WA', to_char(dsn.sarappd_apdc_date, 'DD/MM/YYYY'),
    'PA', to_char(dsn.sarappd_apdc_date, 'DD/MM/YYYY'),
    '' 
  )                                     AS "WithdrawDate",
  -- '' AS "CancelDate", -- N/A
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'EAC0'
  )                                     AS "ACTComposite",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'SATT'
  )                                     AS "SATComposite",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'S10'
  )                                     AS "SATRComposite",
  hs.sorhsch_class_rank                 AS "ClassRank",
  hs.sorhsch_class_size                 AS "ClassSize",
  CASE
    -- if this person is not a US citizen or has a visa, then they are international
    WHEN bio.spbpers_citz_code = 'N' THEN 'Y'
    WHEN bio.spbpers_citz_code IS NULL AND v.gorvisa_pidm IS NOT NULL THEN 'Y'
    WHEN bio.spbpers_citz_code = 'Y' THEN 'N'
    ELSE NULL
  END                                   AS "Intl",
  nvl2 ( -- if any registration records exist for this student/term
          -- then set enrolled to 'Y'
    enroll.pidm, 'Y', 'N'
  )                                     AS "Enrolled",
  CASE 
    WHEN enroll.sch >= 12            THEN 'Full Time'
    WHEN enroll.sch BETWEEN 9 AND 11 THEN '3/4 Time'
    WHEN enroll.sch BETWEEN 6 AND 8  THEN '1/2 Time'
    WHEN enroll.sch < 6              THEN 'Part Time'
    ELSE ''
  END                                   AS "AcadLoadStatus",
  app.saradap_majr_code_1               AS "Major",
  -- '' AS "CEEBCode", -- N/A
  CASE -- this is a summary for when a student declares multiple 
       -- races/ethnicities
    WHEN race.count < 1 OR race.count IS NULL THEN 'UN'
    WHEN race.count = 1 THEN (
      SELECT 
        gorprac_race_cde 
      FROM 
        general.gorprac 
      WHERE 
        gorprac_pidm = curr_apps.pidm
    )
    ELSE '>1'
  END                                   AS "Race",
  ( -- if there is a record for this term/student then they live in the dorm
    SELECT 
      CASE 
        WHEN count(slr2thc_room_assignment) > 0 THEN 'Dorm'
        ELSE 'Commuter'
      END
    FROM SATURN.SLR2THC 
    WHERE slr2thc_pidm = curr_apps.pidm
      AND slr2thc_term_code = terms.curr_term
      AND slr2thc_camp_code ='F'
  )                                     AS "Commuter",
  nvl( -- if there is a Gender code, use that.  else sbppers_sex
    bio.spbpers_gndr_code,
    bio.spbpers_sex
  )                                     AS "Gender",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'SATC'
  )                                     AS "SATReading",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'SATM'
  )                                     AS "SATMath",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'SATW'
  )                                     AS "SATWriting",
  ''                                    AS "WLAdmit",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'S12'
  )                                     AS "SATRMath",
  ( SELECT test_score
    FROM tests
    WHERE tests.pidm = curr_apps.pidm 
      AND test_code = 'S11'
  )                                     AS "SATRReading",
  -- '' AS "NumberOfVisits", -- N/A
  -- '' AS "RecruitedAthelete", -- N/A
  -- Commented out for now since EAB wants this to be other institutions (not HS)
  -- They don't need it for now
  -- hs.sorhsch_sbgi_code                  AS "TransferringInstCode", 
  app.saradap_coll_code_1               AS "SchoolApplied",
  -- '' AS "Religion", -- N/A
  CASE
    WHEN bio.spbpers_citz_code = 'N' OR bio.spbpers_citz_code IS NULL
      THEN ( -- if the spbpers does not list as a citizen, grab the country
             -- from the most recent gobintl entry
             SELECT citiz.country
             FROM citiz 
             WHERE citiz.pidm = curr_apps.pidm
      )
    WHEN bio.spbpers_citz_code = 'Y' THEN 'US'
    ELSE NULL
  END                                   AS "Citizenship",
  nvl2(
    fgn.sgrsatt_pidm, 'Y', 'N'
  )                                     AS "FirstGen",
  -- '' AS "AppType", -- N/A
  -- '' AS "AppFormat", -- N/A
  -- '' AS "FAIntent", -- N/A
  -- '' AS "Legacy", -- N/A
  -- output the military codes in order of priority. first match wins
  CASE
    -- student is veteran
    WHEN instr(military.satt,'FVET', 1) > 0 THEN 'Veteran'
    -- student is active duty
    WHEN instr(military.satt, 'ADA', 1) > 0 THEN 'Active Duty'
    WHEN instr(military.satt,'ADAF', 1) > 0 THEN 'Active Duty' 
    WHEN instr(military.satt,'FCTM', 1) > 0 THEN 'Active Duty' 
    WHEN instr(military.satt,'FGAR', 1) > 0 THEN 'Active Duty' 
    WHEN instr(military.satt,'FMIL', 1) > 0 THEN 'Active Duty'
    -- student is in other miltary 
    WHEN instr(military.satt,'FRSV', 1) > 0 THEN 'Reservist'
    WHEN instr(military.satt,'ADNG', 1) > 0 THEN 'National Guard'
    WHEN instr(military.satt,'FNMG', 1) > 0 THEN 'National Guard'
    WHEN instr(military.satt,'FVSP', 1) > 0 THEN 'ROTC'
    -- student is the spouse of a military member
    WHEN instr(military.satt,'FMSP', 1) > 0 THEN 'Military Spouse'
    WHEN instr(military.satt,'FNGS', 1) > 0 THEN 'Military Spouse' 
    WHEN instr(military.satt,'FRSP', 1) > 0 THEN 'Military Spouse' 
    WHEN instr(military.satt,'FVSP', 1) > 0 THEN 'Military Spouse'
    -- student is the child of a military member
    WHEN instr(military.satt,'FMCH', 1) > 0 THEN 'Military Child'  
    WHEN instr(military.satt,'FNGC', 1) > 0 THEN 'Military Child'  
    WHEN instr(military.satt,'FRCH', 1) > 0 THEN 'Military Child'  
    WHEN instr(military.satt,'FVCH', 1) > 0 THEN 'Military Child' 
    ELSE 'Non-Military'
  END                                   AS "MilitaryStatus",
  transfer.sch                          AS "TransferCredits"
  -- '' AS "GovtPell", -- N/A
  -- '' AS "GovtFedOther", -- N/A
  -- '' AS "GovtState", -- N/A
  -- '' AS "InstNeed", -- N/A
  -- '' AS "InstMerit", -- N/A
  -- '' AS "InstAthl", -- N/A
  -- '' AS "InstWaiv", -- N/A
  -- '' AS "OutsideGift", -- N/A
  -- '' AS "TotalLoad", -- N/A
  -- '' AS "totalWork", -- N/A
FROM
  -- start with the current applications and decisiosn on those applications
   curr_apps
  -- limit to just the applications from the current term
  INNER JOIN terms ON (
    terms.curr_term = curr_apps.term_code
  )
  -- now get the corresponding full application record
  INNER JOIN SATURN.SARADAP app ON (
        app.saradap_pidm = curr_apps.pidm
    AND app.saradap_term_code_entry = curr_apps.term_code
    AND app.saradap_appl_no = curr_apps.appl_no
  )
  -- next, the corresponding full decision record
  INNER JOIN SATURN.SARAPPD dsn ON (
    dsn.sarappd_pidm = curr_apps.pidm
    AND dsn.sarappd_appl_no = curr_apps.appl_no
    AND dsn.sarappd_seq_no = curr_apps.seq_no
  )
  -- add in basic person identity information
  INNER JOIN SATURN.SPRIDEN stu ON (
    stu.spriden_pidm = curr_apps.pidm
    AND stu.spriden_change_ind IS NULL
  )
  -- add in student biographics
  INNER JOIN SATURN.SPBPERS bio ON (
    bio.spbpers_pidm = curr_apps.pidm
  )
  -- get the list of self-selected race codes
  LEFT JOIN race ON (
    race.pidm = curr_apps.pidm
  )
  -- add in any course enrollments for this term
  LEFT JOIN enroll ON (
    enroll.pidm = curr_apps.pidm
  )
  -- grab the permanent address (if any)
  LEFT JOIN SATURN.SPRADDR pr ON (
    pr.spraddr_pidm = curr_apps.pidm
    AND pr.spraddr_atyp_code = 'PR'
  )
  -- get any high school data (like the GPA)
  LEFT JOIN SATURN.SORHSCH hs ON (
    hs.sorhsch_pidm = curr_apps.pidm
  )
  -- check to see if the student is flagged as First Gen
  LEFT JOIN SATURN.SGRSATT fgn ON (
    fgn.sgrsatt_pidm = curr_apps.pidm
    AND fgn.sgrsatt_atts_code = 'FFGN'
  )
  -- get any visa informaiton for the international students
  LEFT JOIN GENERAL.GORVISA v ON (
    v.gorvisa_pidm = curr_apps.pidm
  )
  -- collect the current military flags for students (if any)
  LEFT JOIN military ON (
    military.pidm = curr_apps.pidm
  )
  -- get any transfer credits
  LEFT JOIN transfer ON (
    transfer.pidm = curr_apps.pidm
  )
WHERE
  -- limit the applications from cur_apps to just one record per student (max)
  curr_apps.appl_no = (
    SELECT MAX(apps2.appl_no)
    FROM curr_apps apps2
    WHERE apps2.pidm = curr_apps.pidm
      AND apps2.term_code = curr_apps.term_code
  )
  -- get the most current permanent address (if any)
  AND (
    pr.spraddr_seqno IS NULL
    OR pr.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        pr.spraddr_pidm = a2.spraddr_pidm
        AND a2.spraddr_atyp_code = 'PR'
    )
  )
  -- get the most current HS record (if any)
  AND (
    hs.sorhsch_pidm IS NULL
    OR hs.sorhsch_activity_date = (
      SELECT MAX(hs2.sorhsch_activity_date)
      FROM SATURN.SORHSCH hs2
      WHERE hs2.sorhsch_pidm = hs.sorhsch_pidm
    )
  )
ORDER BY
  stu.spriden_id
;



SPOOL off;

EXIT;
