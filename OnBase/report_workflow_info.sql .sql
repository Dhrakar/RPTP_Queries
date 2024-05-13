select 
  a.lcnum AS lifecycle_id,
  rpad(trim(a.lifecyclename),35) AS lifecyle_name,
  case
    when a.flags = 0 then 'CLASSIC' 
    else 'UNITY'
  end AS lifecycle_type 
from 
  hsi.lifecycle a
order by 1
;

select 
  a.usernum AS user_num,
  a.logdate,
  CASE
    when a.messagetext LIKE '%Management Console%' then 'UNITY_SCHED'
    when a.messagetext LIKE '%Studio%' then 'STUDIO'
    when a.messagetext LIKE '%Config 20.3.33%' then 'CONFIG'
    when a.messagetext LIKE '%HTML Web Client%' then 'WEB'
    when a.messagetext LIKE '%Web Server Pop%' then 'POP'
    when a.messagetext LIKE '%Unity Client%' then 'UNITY'
    when a.messagetext LIKE '%Client 20.3.33%' then 'THICK'
    when a.messagetext LIKE '%Disconnected Scanning%' then 'DIS_SCAN'
    when a.messagetext LIKE '%Core Services%' then 'CORE'
    else '?'
  END  AS client
from
  hsi.securitylog a
where
  a.logdate >= SYSDATE - 90
  AND usernum not in (294, 3096)
  AND a.messagetext LIKE '%logon%'
;