SELECT
  ftd.fgbtrnd_orgn_code    AS "Org Code",
  ftd.fgbtrnd_fund_code    AS "Fund Code",
  ftd.fgbtrnd_acct_code    AS "Acct Code",
  ftd.fgbtrnd_prog_code    AS "Program Code",
  ftd.fgbtrnd_doc_code     AS "Document #",
  fth.fgbtrnh_actv_code    AS "Activity Code",
  NVL(
    fth.fgbtrnh_doc_ref_num, ' '
  )                        AS "Reference Num",
  fth.fgbtrnh_trans_desc   AS "Transaction Description",
  ftd.fgbtrnd_trans_amt    AS "Transaction Amount",
  fth.fgbtrnh_trans_date   AS "Transaction Date",
  ftd.fgbtrnd_seq_num      AS "Sequence #",
  org.title3               AS "Unit",
  org.title4               AS "Division",
  org.title5               AS "Cluster",
  org.title6               AS "Department",
  org.title7               AS "Program (lvl 7)",
  org.title8               AS "Data Entry (lvl 8)"
FROM
  FIMSMGR.FGBTRND ftd
  -- inner join the org hierarchy, since we want to limit to just specific acct codes
  INNER JOIN REPORTS.FTVORGN_LEVELS org ON (
    org.orgn_code = ftd.fgbtrnd_orgn_code
  )
  LEFT JOIN FIMSMGR.FGBTRNH fth ON (
    fth.fgbtrnh_doc_code = ftd.fgbtrnd_doc_code
    AND fth.fgbtrnh_submission_number = ftd.fgbtrnd_submission_number
    AND fth.fgbtrnh_item_num = ftd.fgbtrnd_item_num
    AND fth.fgbtrnh_seq_num = ftd.fgbtrnd_seq_num
  )
WHERE
  ftd.fgbtrnd_coas_code = 'B'
  AND ftd.fgbtrnd_cmt_type = 'U'
  AND ftd.fgbtrnd_ledger_ind = 'O'
  AND ftd.fgbtrnd_field_code = '03'
  -- Use % as the wildcard for eitehr of these variables
  AND ftd.fgbtrnd_fund_code LIKE :fund_code  
  AND org.level8 LIKE :level8_code
ORDER BY
  ftd.fgbtrnd_orgn_code,
  ftd.fgbtrnd_fund_code,
  ftd.fgbtrnd_acct_code,
  ftd.fgbtrnd_prog_code,
  fth.fgbtrnh_trans_date,
  ftd.fgbtrnd_doc_code,
  ftd.fgbtrnd_trans_amt
;
