-- ==================================================================
--              URSA Veteran Report
--
-- This script generates a report listing all of the students who 
-- enrolled in URSA coded courses for the requested aidyear. The
-- courses are hard-coded since there is not a programmatic way to
-- determine them.
--
-- Params:
--   :aidyr  the YYXX aidyear (like 2324)
-- ==================================================================
WITH
  mil AS (
    SELECT 
      a.sgrsatt_pidm AS pidm,
      a.sgrsatt_term_code_eff as term_eff,
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
      -- only get military affiliations up to the last report term
      AND a.sgrsatt_term_code_eff <= '20' || substr(:aidyr,3,2) || '02'
      -- get the most recent military status (if any)
      AND (
        a.sgrsatt_term_code_eff = (
          SELECT MAX(a2.sgrsatt_term_code_eff)
          FROM SATURN.SGRSATT a2
          WHERE a2.sgrsatt_pidm = a.sgrsatt_pidm
            -- AND a2.sgrsatt_atts_code = a.sgrsatt_atts_code
            AND a2.sgrsatt_term_code_eff <= '20' || substr(:aidyr,3,2) || '02'
        )
      )
      GROUP BY 
        a.sgrsatt_pidm, a.sgrsatt_term_code_eff
  )
SELECT DISTINCT
  dsduaf.f_decode$semester(reg.term_code) AS "Term",
  reg.student_id                          AS "UAID",
  mil.satt                                AS "Mil Affiliation",
  mil.term_eff                            AS "Mil Affil Eff",
  reg.subject_code 
   || reg.course_number                   AS "Course",
  reg.section_number                      AS "Section",
  reg.campus_code                         AS "Campus",
  reg.student_id                          AS "UAID",
  (
    SELECT
      stu.spriden_last_name
        || ', ' 
        || coalesce (
             bio.spbpers_pref_first_name,
             stu.spriden_first_name 
           ) 
        || ' ' 
        || stu.spriden_mi  
    FROM  SATURN.SPRIDEN stu
    WHERE stu.spriden_id = reg.student_id 
      AND stu.spriden_change_ind IS NULL
  )                                       AS "Name",
  (
    SELECT a.stvrsts_desc
    FROM SATURN.STVRSTS a
    WHERE a.stvrsts_code = reg.registration_status
  )                                       AS "Status"
FROM
  -- start with the frozen IR registration records (closing freeze)
  DSDMGR.DSD_REGISTRATION reg
  -- get the preferred name
  INNER JOIN SATURN.SPBPERS bio ON 
    bio.spbpers_pidm = reg.student_pidm
  -- limit to just folks with a military affiliation
  INNER JOIN mil ON mil.pidm = reg.student_pidm
WHERE
  -- build out the terms from the suplied aidyear
  reg.term_code IN (
    '20' || substr(:aidyr,1,2) || '03', -- fall_term
    '20' || substr(:aidyr,3,2) || '01', -- spring_term
    '20' || substr(:aidyr,3,2) || '02'  -- summer_term
  )
  AND ( 
    reg.subject_code || reg.course_number ) IN (
    'ACCTF497',
    'ANLF497',
    'ANSF340','ANSF474','ANSF478','ANSF497',
    'ANTHF270','ANTHF305','ANTHF308','ANTHF336','ANTHF402','ANTHF435','ANTHF445','ANTHF485','ANTHF497',
    'ARTF490','ARTF497','ARTF498','ARTF499',
    'ATMF101','ATMF401','ATMF413','ATMF415','ATMF425','ATMF444','ATMF446','ATMF456','ATMF473','ATMF480','ATMF488','ATMF497',
    'BAF454','BAF455','BAF490','BAF497',
    'BIOLF397','BIOLF434','BIOLF440','BIOLF441','BIOLF472','BIOLF483','BIOLF487','BIOLF490','BIOLF491','BIOLF497','BIOLF498',
    'BMSCF293','BMSCF393',
    'CEF471','CEF472','CEF490','CEF493','CEF497','CEF498',
    'CHEMF488','CHEMF497',
    'COJOF401','COJOF498',
    'COMMF497',
    'CSF472','CSF490','CSF497',
    'ECEF497',
    'ECONF497',
    'EDF497',
    'EDSCF497',
    'EEF488','EEF497',
    'ENGLF497','ENGLF488',
    'ESKF488','ESKF497',
    'ESMF497',
    'FISHF290','FISHF487','FISHF490','FISHF497','FISHF498','FISHF499',
    'FLF497','FLMF497','FLMF498',
    'FLPAF201','FLPAF298','FLPAF401','FLPAF402','FLPAF403','FLPAF498','FLPAF499',
    'FRENF488','FRENF497',
    'FSNF497',
    'GEF480','GEF489','GEF497',
    'GEOGF488','GEOGF489','GEOGF490','GEOGF497',
    'GEOSF488','GEOSF497','GEOSF499',
    'GERF488','GERF497',
    'HISTF476','HISTF490','HISTF497',
    'HONRF497','HONRF498','HONRF499',
    'HSEMF497',
    'INDSF497',
    'JPNF488',
    'JRNF490','JRNF497','JRNF498',
    'JUSTF497','JUSTF498',
    'LASF497',
    'LATF497',
    'LINGF497',
    'LSF487','LSF490',
    'MATHF490','MATHF497','MATHF498',
    'MEF486','MEF487','MEF490','MEF497','MEF498',
    'MILSF497',
    'MINF489','MINF490','MINF497',
    'MRAPF288','MRAPF293','MRAPF488',
    'MSLF497','MSLF499',
    'MUSF490','MUSF496','MUSF497',
    'NORSF497',
    'NRMF300','NRMF403','NRMF483','NRMF484','NRMF487','NRMF488','NRMF489','NRMF490','NRMF497',
    'PETEF487','PETEF489','PETEF490','PETEF497',
    'PHILF487','PHILF488','PHILF490','PHILF497','PHILF499',
    'PHYSF488','PHYSF497',
    'PRTF497',
    'PSF497','PSF499',
    'PSYF250','PSYF275','PSYF475','PSYF480','PSYF488','PSYF497','PSYF498','PSYF499',
    'RDF475','RDF497',
    'RUSSF497','RUSSF488',
    'SOCF490','SOCF497','SOCF498',
    'SPANF488','SPANF497',
    'STATF497','STATF498',
    'SWKF375','SWKF497',
    'THRF497','THRF499',
    'URSAF388','URSAF393','URSAF397','URSAF488','URSAF493',
    'WLFF497',
    'WMSF497' 
  )
ORDER BY
  dsduaf.f_decode$semester(reg.term_code),
  reg.student_id
;