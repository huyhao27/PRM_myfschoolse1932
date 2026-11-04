# Grades smoke test (run inside the lock: -Cmd "run.ps1; smoke-grades.ps1; stop.ps1").
# Covers list/view/add/edit/delete as Manager and GV against SQL Server, and removes every row it created.
param([string]$BaseUrl = 'http://localhost:8088', [string]$Password = '123456')
$ErrorActionPreference = 'Continue'
$script:fail = 0
function Result($ok, $msg) { if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green } else { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ } }

function Send-Http($method, $path, $jar, $form) {
  $req = [System.Net.HttpWebRequest]::Create("$BaseUrl/$path")
  $req.Method = $method; $req.AllowAutoRedirect = $false; $req.CookieContainer = $jar; $req.Timeout = 120000
  if ($form) {
    $pairs = $form.GetEnumerator() | ForEach-Object { [Uri]::EscapeDataString($_.Key) + '=' + [Uri]::EscapeDataString([string]$_.Value) }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($pairs -join '&'))
    $req.ContentType = 'application/x-www-form-urlencoded'; $req.ContentLength = $bytes.Length
    $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
  }
  try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
  if (-not $resp) { return @{ Status = 0; Body = 'no response'; Location = $null } }
  $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
  $body = $sr.ReadToEnd(); $sr.Close()
  $r = @{ Status = [int]$resp.StatusCode; Body = $body; Location = $resp.Headers['Location'] }
  $resp.Close()
  return $r
}
function Get-Page($path, $jar) { return Send-Http 'GET' $path $jar $null }
function Field($html, $name) { if ($html -match "name=`"$name`"[^>]*value=`"([^`"]*)`"") { return [System.Net.WebUtility]::HtmlDecode($Matches[1]) } else { return '' } }
function Has-Error($body) { return ($body -match 'Server Error in|Stack Trace|Lỗi máy chủ|Parser Error|Compilation Error|Host error') }
function Txt($r) { return [System.Net.WebUtility]::HtmlDecode($r.Body) }

# Collect every form field of the page the way a browser would submit it (hidden, text, selected option, textarea, checked boxes).
function Get-FormFields($html) {
  $f = [ordered]@{}
  foreach ($m in [regex]::Matches($html, '<input\b[^>]*>', 'IgnoreCase')) {
    $t = $m.Value
    if ($t -notmatch 'name="([^"]*)"') { continue }
    $name = $Matches[1]
    $type = if ($t -match 'type="([^"]*)"') { $Matches[1].ToLower() } else { 'text' }
    $val = if ($t -match 'value="([^"]*)"') { [System.Net.WebUtility]::HtmlDecode($Matches[1]) } else { '' }
    if ($type -in 'submit', 'button', 'image', 'file') { continue }
    if ($type -in 'checkbox', 'radio') { if ($t -match 'checked') { $f[$name] = if ($val) { $val } else { 'on' } }; continue }
    $f[$name] = $val
  }
  foreach ($m in [regex]::Matches($html, '<textarea\b[^>]*name="([^"]*)"[^>]*>(.*?)</textarea>', 'IgnoreCase,Singleline')) { $f[$m.Groups[1].Value] = [System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value) }
  foreach ($m in [regex]::Matches($html, '<select\b[^>]*name="([^"]*)"[^>]*>(.*?)</select>', 'IgnoreCase,Singleline')) {
    $sel = [regex]::Match($m.Groups[2].Value, '<option[^>]*selected="selected"[^>]*value="([^"]*)"|<option[^>]*value="([^"]*)"[^>]*selected="selected"')
    if ($sel.Success) { $v = if ($sel.Groups[1].Success) { $sel.Groups[1].Value } else { $sel.Groups[2].Value }; $f[$m.Groups[1].Value] = [System.Net.WebUtility]::HtmlDecode($v) }
    else { $first = [regex]::Match($m.Groups[2].Value, '<option[^>]*value="([^"]*)"'); if ($first.Success) { $f[$m.Groups[1].Value] = [System.Net.WebUtility]::HtmlDecode($first.Groups[1].Value) } }
  }
  return $f
}
function Name-Of($fields, $suffix) { foreach ($k in $fields.Keys) { if ($k -like "*`$$suffix" -or $k -eq $suffix) { return $k } }; return $null }
function Post-Form($path, $jar, $page, $overrides, $button) {
  $f = Get-FormFields $page.Body
  foreach ($k in $overrides.Keys) { $n = Name-Of $f $k; if (-not $n) { $n = $k }; $f[$n] = $overrides[$k] }
  if ($button) { $b = [regex]::Match($page.Body, ('name="([^"]*' + [regex]::Escape('$' + $button) + ')"[^>]*value="([^"]*)"')); if ($b.Success) { $f[$b.Groups[1].Value] = [System.Net.WebUtility]::HtmlDecode($b.Groups[2].Value) } }
  return Send-Http 'POST' $path $jar $f
}
function Do-Login($identifier) {
  $jar = New-Object System.Net.CookieContainer
  $g = Get-Page 'Login.aspx' $jar
  $form = @{ '__VIEWSTATE' = (Field $g.Body '__VIEWSTATE'); '__VIEWSTATEGENERATOR' = (Field $g.Body '__VIEWSTATEGENERATOR'); '__EVENTVALIDATION' = (Field $g.Body '__EVENTVALIDATION')
    'txtIdentifier' = $identifier; 'txtPassword' = $Password; 'btnLogin' = 'Đăng nhập' }
  $r = Send-Http 'POST' 'Login.aspx' $jar $form
  if ($r.Status -ne 302) { Write-Host "login failed for $identifier" -ForegroundColor Red }
  return $jar
}
function Sql($q) { $o = & sqlcmd -S localhost,1433 -E -C -d FSchoolDB -W -h -1 -f 65001 -Q "SET NOCOUNT ON; $q" 2>&1; return (($o | Out-String).Trim()) }

$mgr = Do-Login 'manager@fschool.vn'
$gv = Do-Login 'gv@fschool.vn'
$gv2 = Do-Login 'gv2@fschool.vn'
$scratch = 'Zz Thu Nghiem'
$baseline = Sql "SELECT COUNT(*) FROM dbo.Grade; SELECT COUNT(*) FROM dbo.GradeRemark"
$q = "ListGrade.aspx?class=10A1&term=HK1"
$subj = [Uri]::EscapeDataString('Toán')

try {
  # --- lists
  $r = Get-Page 'ListGrade.aspx' $mgr
  Result ($r.Status -eq 200 -and -not (Has-Error $r.Body)) 'manager ListGrade renders'
  Result ((Txt $r) -match 'Hoc sinh Demo' -and (Txt $r) -match 'Hoc sinh Mai') 'manager list shows both students'
  $r = Get-Page "$q&subject=$subj" $mgr
  Result ((Txt $r) -match '8\.85') 'manager list: Toán average 8.85 for Hoc sinh Demo'
  Result ((Txt $r) -match 'ViewGrade\.aspx\?studentId=4&subject=To%[0-9a-fA-F]{2}%[0-9a-fA-F]{2}n&term=HK1') 'list links use studentId+subject+term'
  $r = Get-Page "$q&q=Mai" $mgr
  Result ((Txt $r) -match 'Hoc sinh Mai' -and (Txt $r) -notmatch 'Hoc sinh Demo') 'search filter (Mai) works'
  $r = Get-Page 'ListGrade.aspx' $gv
  Result ($r.Status -eq 200 -and -not (Has-Error $r.Body) -and (Txt $r) -match 'Hoc sinh Demo') 'GV ListGrade shows class 10A1 rows'

  # --- view
  $r = Get-Page "ViewGrade.aspx?studentId=4&subject=$subj&term=HK1" $mgr
  Result ($r.Status -eq 200 -and -not (Has-Error $r.Body) -and (Txt $r) -match '8\.85' -and (Txt $r) -match 'Hoc sinh Demo') 'ViewGrade shows Toán 8.85'
  Result ((Txt $r) -match 'Em tiếp thu tốt') 'ViewGrade shows teacher remark'
  $r = Get-Page "ViewGrade.aspx?studentId=4&subject=$subj&term=HK1" $gv
  Result ($r.Status -eq 200 -and (Txt $r) -match '8\.85') 'GV can view grade of own class'
  $r = Get-Page 'ViewGrade.aspx?studentId=4&subject=KhongCo&term=HK1' $mgr
  Result ($r.Status -eq 200 -and -not (Has-Error $r.Body) -and (Txt $r) -match 'Không tìm thấy') 'ViewGrade unknown subject -> friendly message'
  $r = Get-Page 'ViewGrade.aspx?studentId=abc' $mgr
  Result ($r.Status -eq 200 -and -not (Has-Error $r.Body) -and (Txt $r) -match 'Thiếu thông tin') 'ViewGrade bad id -> friendly message'

  # --- GV permission on edit
  $en = [Uri]::EscapeDataString('Tiếng Anh')
  $r = Get-Page "EditGrade.aspx?studentId=4&subject=$en&term=HK1" $gv
  Result ($r.Status -eq 200 -and -not (Has-Error $r.Body) -and (Txt $r) -match 'chỉ được sửa') 'GV cannot edit a subject they do not teach (Tiếng Anh)'
  $r = Get-Page "EditGrade.aspx?studentId=4&subject=$subj&term=HK1" $gv
  Result ($r.Status -eq 200 -and (Txt $r) -match 'Lưu Thay Đổi') 'GV can open edit form for own subject (Toán)'
  $r = Get-Page "EditGrade.aspx?studentId=4&subject=$subj&term=HK1" $gv2
  Result ((Txt $r) -match 'chỉ được sửa') 'gv2 cannot edit Toán'

  # --- manager: add a scratch subject
  $add = Get-Page 'AddGrade.aspx' $mgr
  Result ($add.Status -eq 200 -and -not (Has-Error $add.Body) -and $add.Body -match 'liveDtb') 'AddGrade renders with live preview'
  $p = Post-Form 'AddGrade.aspx' $mgr $add @{ ddlClass = '10A1'; ddlStudent = '4'; txtSubjectOther = $scratch; ddlTerm = 'HK1'; txtOral = '10'; txt15a = '8'; txt15b = ''; txt1t = '6'; txtGk = '7'; txtCk = '9'; txtComment = 'Ghi chu thu nghiem' } 'btnSave'
  Result ($p.Status -eq 302 -and "$($p.Location)" -match 'ListGrade') "manager add -> redirect ($($p.Status) $($p.Location))"
  if ($p.Status -ne 302) { Write-Host ((Txt $p) -replace '<[^>]+>', ' ' -replace '\s+', ' ').Substring(0, [Math]::Min(400, $p.Body.Length)) }
  $cnt = Sql "SELECT COUNT(*) FROM dbo.Grade WHERE studentId=4 AND subject=N'$scratch' AND term='HK1'"
  Result ($cnt -eq '5') "SQL: 5 grade rows inserted (got $cnt)"
  # weighted: (10*1 + 8*1 + 6*2 + 7*2 + 9*3) / 9 = 71/9 = 7.89
  $avg = Sql "SELECT CAST(ROUND(SUM(score*weight)/SUM(weight),2) AS decimal(4,2)) FROM dbo.Grade WHERE studentId=4 AND subject=N'$scratch'"
  Result ($avg -eq '7.89') "SQL weighted average 7.89 (got $avg)"
  $rem = Sql "SELECT COUNT(*) FROM dbo.GradeRemark WHERE studentId=4 AND subject=N'$scratch'"
  Result ($rem -eq '1') 'SQL: remark row created'
  $r = Get-Page "$q&subject=$([Uri]::EscapeDataString($scratch))" $mgr
  Result ((Txt $r) -match '7\.89') 'list shows the new average 7.89'
  # duplicate add is refused
  $add2 = Get-Page 'AddGrade.aspx' $mgr
  $p = Post-Form 'AddGrade.aspx' $mgr $add2 @{ ddlClass = '10A1'; ddlStudent = '4'; txtSubjectOther = $scratch; ddlTerm = 'HK1'; txtCk = '5' } 'btnSave'
  Result ($p.Status -eq 200 -and (Txt $p) -match 'đã có điểm') 'duplicate add refused with message'
  # invalid score
  $add3 = Get-Page 'AddGrade.aspx' $mgr
  $p = Post-Form 'AddGrade.aspx' $mgr $add3 @{ ddlClass = '10A1'; ddlStudent = '4'; txtSubjectOther = $scratch + '2'; ddlTerm = 'HK1'; txtCk = '11' } 'btnSave'
  Result ($p.Status -eq 200 -and (Txt $p) -match 'từ 0 đến 10') 'score 11 rejected'

  # --- edit
  $en2 = "EditGrade.aspx?studentId=4&subject=$([Uri]::EscapeDataString($scratch))&term=HK1"
  $ed = Get-Page $en2 $mgr
  Result ($ed.Status -eq 200 -and -not (Has-Error $ed.Body) -and $ed.Body -match 'rptRows') 'EditGrade renders rows'
  $f = Get-FormFields $ed.Body
  $scoreNames = @($f.Keys | Where-Object { $_ -like '*txtScore' })
  Result ($scoreNames.Count -eq 5) "EditGrade has 5 score rows (got $($scoreNames.Count))"
  $ov = @{}; $ov[$scoreNames[4]] = '10'   # final 9 -> 10
  $p = Post-Form $en2 $mgr $ed $ov 'btnUpdate'
  Result ($p.Status -eq 302) "EditGrade save -> redirect ($($p.Status))"
  # (10 + 8 + 12 + 14 + 30) / 9 = 74/9 = 8.22
  $avg = Sql "SELECT CAST(ROUND(SUM(score*weight)/SUM(weight),2) AS decimal(4,2)) FROM dbo.Grade WHERE studentId=4 AND subject=N'$scratch'"
  Result ($avg -eq '8.22') "SQL average after edit 8.22 (got $avg)"
  # add a row then delete one
  $ed = Get-Page $en2 $mgr
  $p = Post-Form $en2 $mgr $ed @{} 'btnAddRow'
  Result ($p.Status -eq 200 -and ([regex]::Matches($p.Body, 'txtScore')).Count -ge 6) 'EditGrade add-row shows 6 rows'

  # --- delete through the list (postback)
  $r = Get-Page "$q&subject=$([Uri]::EscapeDataString($scratch))" $mgr
  $t = [regex]::Match($r.Body, "__doPostBack\(&#39;([^&]*btnDelete)&#39;|__doPostBack\('([^']*btnDelete)'")
  if ($t.Success) {
    $target = if ($t.Groups[1].Success) { $t.Groups[1].Value } else { $t.Groups[2].Value }
    $f = Get-FormFields $r.Body; $f['__EVENTTARGET'] = $target; $f['__EVENTARGUMENT'] = ''
    $d = Send-Http 'POST' $q $mgr $f
    $cnt = Sql "SELECT COUNT(*) FROM dbo.Grade WHERE studentId=4 AND subject=N'$scratch'"
    Result ($d.Status -eq 200 -and $cnt -eq '0') "delete from list removes the rows (left $cnt)"
  } else { Result $false 'delete link found in list' }

  # --- GV adds a new set for a subject they teach (Thể dục, HK2) and the remark gets teacherId = GV
  $add = Get-Page 'AddGrade.aspx' $gv
  Result ($add.Status -eq 200 -and $add.Body -match 'Thể dục' -and $add.Body -notmatch 'value="Tiếng Anh"') 'GV AddGrade subject list = own subjects only'
  $p = Post-Form 'AddGrade.aspx' $gv $add @{ ddlClass = '10A1'; ddlStudent = '4'; ddlSubject = 'Thể dục'; ddlTerm = 'HK2'; txtGk = '8'; txtCk = '9'; txtComment = 'GV test' } 'btnSave'
  Result ($p.Status -eq 302) "GV add (Thể dục HK2) -> redirect ($($p.Status))"
  $tid = Sql "SELECT teacherId FROM dbo.GradeRemark WHERE studentId=4 AND subject=N'Thể dục' AND term='HK2'"
  $gid = Sql "SELECT id FROM dbo.Users WHERE email='gv@fschool.vn'"
  Result ($tid -eq $gid) "remark teacherId is the logged-in GV ($tid)"
  # service-level rule: GV cannot save an unrelated subject (tamper test through the manager-only free text is blocked for GV)
  $add = Get-Page 'AddGrade.aspx' $gv
  $p = Post-Form 'AddGrade.aspx' $gv $add @{ ddlClass = '10A1'; ddlStudent = '4'; txtSubjectOther = 'Tiếng Anh'; ddlSubject = 'Thể dục'; ddlTerm = 'HK2'; txtCk = '1' } 'btnSave'
  Result ((Txt $p) -match 'đã có điểm|Thể dục') 'GV free-text subject field ignored (no Tiếng Anh write)'
  $ea = Sql "SELECT COUNT(*) FROM dbo.Grade WHERE studentId=4 AND subject=N'Tiếng Anh' AND term='HK2'"
  Result ($ea -eq '0') 'no Tiếng Anh HK2 rows created by GV'

  # --- API (session cookie of the portal login)
  function Send-Json($method, $path, $jar, $obj) {
    $req = [System.Net.HttpWebRequest]::Create("$BaseUrl/$path"); $req.Method = $method; $req.CookieContainer = $jar; $req.AllowAutoRedirect = $false
    if ($obj) { $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Depth 5)); $req.ContentType = 'application/json; charset=utf-8'; $req.ContentLength = $bytes.Length; $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close() }
    try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
    if (-not $resp) { return @{ Status = 0; Body = '' } }
    $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8); $b = $sr.ReadToEnd(); $sr.Close(); $st = [int]$resp.StatusCode; $resp.Close()
    return @{ Status = $st; Body = $b }
  }
  $a2 = Get-Page 'api/grades' (New-Object System.Net.CookieContainer)
  Result ($a2.Status -eq 401) "api/grades anonymous -> $($a2.Status)"
  $a = Get-Page 'api/grades?className=10A1&term=HK1' $mgr
  Result ($a.Status -eq 200 -and $a.Body -match '"average": 8\.85') "api/grades as manager lists grades with average 8.85 ($($a.Status))"
  $a = Get-Page "api/grades/4?subject=$subj&term=HK1" $gv
  Result ($a.Status -eq 200 -and $a.Body -match '"average": 8\.85' -and $a.Body -match '"evaluation": "T') "api/grades/4?subject=Toán as GV -> 200 average 8.85"
  $a = Send-Json 'POST' 'api/grades' $gv @{ studentId = 4; subject = 'Tiếng Anh'; term = 'HK2'; entries = @(@{ type = 'Cuối kỳ'; score = 5 }) }
  Result ($a.Status -eq 403) "api POST by GV for a subject they do not teach -> $($a.Status)"
  $a = Send-Json 'POST' 'api/grades' $mgr @{ studentId = 4; subject = $scratch; term = 'HK1'; comment = 'api'; entries = @(@{ type = 'Giữa kỳ'; score = 6 }, @{ type = 'Cuối kỳ'; score = 9 }) }
  Result ($a.Status -eq 200 -and $a.Body -match '"average": 7\.8') "api POST by manager creates scratch grades (avg (6*2+9*3)/5=7.8) -> $($a.Status)"
  $a = Send-Json 'POST' 'api/grades' $mgr @{ studentId = 4; subject = $scratch; term = 'HK1'; entries = @(@{ type = 'Cuối kỳ'; score = 9 }) }
  Result ($a.Status -eq 409) "api POST duplicate -> $($a.Status)"
  $a = Send-Json 'PUT' "api/grades/4?subject=$([Uri]::EscapeDataString($scratch))&term=HK1" $mgr @{ entries = @(@{ type = 'Cuối kỳ'; score = 10 }) }
  Result ($a.Status -eq 200 -and $a.Body -match '"average": 10') "api PUT replaces rows -> $($a.Status)"
  $a = Send-Json 'POST' 'api/grades' $mgr @{ studentId = 4; subject = $scratch + '3'; term = 'HK1'; entries = @(@{ type = 'Cuối kỳ'; score = 12 }) }
  Result ($a.Status -eq 400) "api POST score 12 -> $($a.Status)"
  $a = Send-Json 'DELETE' "api/grades/4?subject=$([Uri]::EscapeDataString($scratch))&term=HK1" $mgr $null
  Result ($a.Status -eq 200) "api DELETE -> $($a.Status)"
}
finally {
  # cleanup: remove only rows created by this script
  Sql "DELETE FROM dbo.Grade WHERE subject LIKE N'$scratch%'; DELETE FROM dbo.GradeRemark WHERE subject LIKE N'$scratch%'; DELETE FROM dbo.Grade WHERE studentId=4 AND subject=N'Thể dục' AND term='HK2'; DELETE FROM dbo.GradeRemark WHERE studentId=4 AND subject=N'Thể dục' AND term='HK2'; DELETE FROM dbo.Grade WHERE studentId=4 AND subject=N'Tiếng Anh' AND term='HK2'" | Out-Null
  $after = Sql "SELECT COUNT(*) FROM dbo.Grade; SELECT COUNT(*) FROM dbo.GradeRemark"
  Result ($after -eq $baseline) "seed data unchanged after test (Grade/GradeRemark counts: $(($after -split '\s+') -join '/'))"
}
if ($script:fail -eq 0) { Write-Host "SMOKE-GRADES OK" -ForegroundColor Green; exit 0 } else { Write-Host "SMOKE-GRADES: $($script:fail) check(s) failed" -ForegroundColor Red; exit 1 }
