SELECT 
  id.itemnum AS dochandle, 
  trim(id.itemname) AS docname
FROM
  HSI.ITEMDATA id
  -- filter by the Calendar Year
  INNER JOIN HSI.KEYITEM196 kw_date ON 
    kw_date.itemnum = id.itemnum
  -- filter by the UAID
  INNER JOIN HSI.KEYXITEM116 kxi_uaid ON kxi_uaid.itemnum = id.itemnum
  INNER JOIN HSI.KEYTABLE116 kw_uaid ON kw_uaid.keywordnum = kxi_uaid.keywordnum
WHERE
  -- W2 doc type
  id.itemtypenum = 521
  -- filter by calendar year
  AND kw_date.keyvaluesmall = 2023
  -- limit to these UAIDs
  AND kw_uaid.keyvaluechar IN ('30039100', '30057090', '30057518', '30058124', 
                               '30065314', '30067686', '30084556', '30095313', 
                               '30097069', '30103579', '30108803', '30136713', 
                               '30143555', '30188195', '30190758', '30215011', 
                               '30218226', '30234816', '30287119', '30333446', 
                               '30337858', '30515847', '30700587', '30761188', 
                               '30809881', '30832396', '30847624', '30934438', 
                               '30958804', '30963821', '31000964', '31054364', 
                               '31097182', '31140447', '31160575', '31219136')
ORDER BY
  id.itemnum