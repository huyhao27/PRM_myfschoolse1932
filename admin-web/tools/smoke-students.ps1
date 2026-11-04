# Detailed test of ListStudent / ListSchedule / ImportData and /api/students, /api/schedules, /api/import (site must be running).
# Creates scratch data (phones 0977000xxx, class ZZ9, emails *@smoke.test) and removes it at the end.
# Run inside the lock:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\locked.ps1 -Cmd "run.ps1; smoke-students.ps1; stop.ps1"
param([string]$BaseUrl = 'http://localhost:8088', [string]$Password = '123456', [string]$NodeApi = 'http://localhost:3000')
$ErrorActionPreference = 'Continue'
$script:fail = 0
function Result($ok, $msg) { if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green } else { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ } }

function Send-Http($method, $path, $jar, $form, $headers) {
  $req = [System.Net.HttpWebRequest]::Create("$BaseUrl/$path")
  $req.Method = $method; $req.AllowAutoRedirect = $false; $req.CookieContainer = $jar; $req.Timeout = 120000
  if ($headers) { foreach ($k in $headers.Keys) { $req.Headers[$k] = $headers[$k] } }
  if ($form) {
    $pairs = $form.GetEnumerator() | ForEach-Object { [Uri]::EscapeDataString($_.Key) + '=' + [Uri]::EscapeDataString([string]$_.Value) }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($pairs -join '&'))
    $req.ContentType = 'application/x-www-form-urlencoded'; $req.ContentLength = $bytes.Length
    $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
  } elseif ($method -ne 'GET') { $req.ContentLength = 0 }
  try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
  if (-not $resp) { return @{ Status = 0; Body = 'no response'; Location = $null } }
  $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
  $body = $sr.ReadToEnd(); $sr.Close()
  $r = @{ Status = [int]$resp.StatusCode; Body = $body; Location = $resp.Headers['Location'] }
  $resp.Close()
  return $r
}
function Get-Page($path, $jar) { return Send-Http 'GET' $path $jar $null $null }
function Dec($s) { return [System.Net.WebUtility]::HtmlDecode($s) }
function Has-Error($body) { return ($body -match 'Server Error in|Stack Trace|Lỗi máy chủ|Parser Error|Compilation Error|Host error') }

# All inputs/textareas/selects of the page as they would be posted (hidden, text, password, textarea, selected option). Submit buttons excluded.
function Get-Fields($html) {
  $f = [ordered]@{}
  foreach ($m in [regex]::Matches($html, '<input\b[^>]*>')) {
    $t = $m.Value
    if ($t -notmatch 'name="([^"]+)"') { continue }
    $name = $Matches[1]
    $type = 'text'; if ($t -match 'type="([^"]+)"') { $type = $Matches[1].ToLower() }
    if ($type -in 'submit', 'button', 'file', 'image') { continue }
    if ($type -in 'checkbox', 'radio') { if ($t -notmatch 'checked') { continue } }
    $val = ''; if ($t -match 'value="([^"]*)"') { $val = Dec $Matches[1] }
    $f[$name] = $val
  }
  foreach ($m in [regex]::Matches($html, '<textarea\b[^>]*name="([^"]+)"[^>]*>(.*?)</textarea>', 'Singleline')) { $f[$m.Groups[1].Value] = (Dec $m.Groups[2].Value).TrimStart("`r", "`n") }
  foreach ($m in [regex]::Matches($html, '<select\b[^>]*name="([^"]+)"[^>]*>(.*?)</select>', 'Singleline')) {
    $name = $m.Groups[1].Value; $opts = $m.Groups[2].Value
    $sel = [regex]::Match($opts, '<option\b[^>]*selected[^>]*value="([^"]*)"')
    if (-not $sel.Success) { $sel = [regex]::Match($opts, '<option\b[^>]*value="([^"]*)"[^>]*selected') }
    if (-not $sel.Success) { $sel = [regex]::Match($opts, '<option\b[^>]*value="([^"]*)"') }
    $f[$name] = if ($sel.Success) { Dec $sel.Groups[1].Value } else { '' }
  }
  return $f
}

# Post back the page $html: all its fields, then $over (hashtable) on top. $target = __EVENTTARGET (control UniqueID) or $null; $button = submit button name.
function Post-Page($path, $jar, $html, $over, $target, $button) {
  $f = Get-Fields $html
  $form = @{}
  foreach ($k in $f.Keys) { $form[$k] = $f[$k] }
  $form['__EVENTTARGET'] = if ($target) { $target } else { '' }
  $form['__EVENTARGUMENT'] = ''
  if ($button) { $form[$button] = 'x' }
  foreach ($k in $over.Keys) { $form[$k] = $over[$k] }
  return Send-Http 'POST' $path $jar $form $null
}

# Real UniqueID of a control from its short id (e.g. txtName -> ctl00$MainContent$txtName)
function UID($html, $short) {
  $m = [regex]::Match($html, 'name="([^"]*\$)?' + [regex]::Escape($short) + '"')
  if ($m.Success) { return $m.Value.Substring(6, $m.Value.Length - 7) }
  $m = [regex]::Match($html, "__doPostBack\(&#39;([^&]*\$)?" + [regex]::Escape($short) + "&#39;")
  if ($m.Success) { return $m.Value.Substring(18, $m.Value.Length - 23) }
  return $short
}

# __doPostBack target of the LinkButton with the given title inside the <tr> that contains $marker
function Row-Target($html, $marker, $title) {
  foreach ($row in [regex]::Matches($html, '<tr\b.*?</tr>', 'Singleline')) {
    if ($row.Value.Contains($marker)) {
      foreach ($a in [regex]::Matches($row.Value, '<a\b[^>]*>')) {
        $tag = Dec $a.Value
        if ($tag -match ('title="' + [regex]::Escape($title) + '"')) {
          $m = [regex]::Match($tag, "__doPostBack\('([^']+)',''\)")
          if ($m.Success) { return $m.Groups[1].Value }
        }
      }
    }
  }
  return $null
}

function Do-Login($identifier, $pass) {
  $jar = New-Object System.Net.CookieContainer
  $g = Get-Page 'Login.aspx' $jar
  $form = @{ '__VIEWSTATE' = ((Get-Fields $g.Body)['__VIEWSTATE']); '__VIEWSTATEGENERATOR' = ((Get-Fields $g.Body)['__VIEWSTATEGENERATOR']); '__EVENTVALIDATION' = ((Get-Fields $g.Body)['__EVENTVALIDATION'])
            'txtIdentifier' = $identifier; 'txtPassword' = $pass; 'btnLogin' = 'Đăng nhập' }
  $r = Send-Http 'POST' 'Login.aspx' $jar $form $null
  $r.Session = $jar
  return $r
}
function Sql($q) { $o = & sqlcmd -S localhost,1433 -E -C -I -d FSchoolDB -h -1 -W -Q "SET NOCOUNT ON; $q" 2>&1; return ($o | Out-String).Trim() }

$mgr = (Do-Login 'manager@fschool.vn' $Password).Session
$gv = (Do-Login 'gv@fschool.vn' $Password).Session
$gv2 = (Do-Login 'gv2@fschool.vn' $Password).Session
$anon = New-Object System.Net.CookieContainer

$seedUsers = [int](Sql 'SELECT COUNT(*) FROM dbo.Users'); $seedSched = [int](Sql 'SELECT COUNT(*) FROM dbo.Schedule'); $seedLinks = [int](Sql 'SELECT COUNT(*) FROM dbo.ParentStudent')
Write-Host "Seed counts before: users=$seedUsers schedule=$seedSched parentLinks=$seedLinks"

try {
  # ---------------------------------------------------------------- pages render per role
  foreach ($pg in 'ListStudent.aspx', 'ListSchedule.aspx', 'ImportData.aspx') {
    $r = Get-Page $pg $mgr
    Result ($r.Status -eq 200 -and -not (Has-Error $r.Body)) "Manager GET $pg -> $($r.Status)"
    $r = Get-Page $pg $anon
    Result ($r.Status -eq 302) "anonymous GET $pg -> redirect ($($r.Status))"
  }
  $r = Get-Page 'ImportData.aspx' $gv
  Result ($r.Status -eq 302 -and "$($r.Location)" -match 'ListStudent') "GV GET ImportData.aspx -> redirected to ListStudent ($($r.Status) $($r.Location))"

  # ---------------------------------------------------------------- ListStudent: read
  $ls = Get-Page 'ListStudent.aspx' $mgr
  $t = Dec $ls.Body
  Result ($t -match '0901000003' -and $t -match '0901234567' -and $t -match '0901000001') "Manager list shows HS, PH and GV accounts"
  Result ($t -match 'Phu huynh Demo' -and $t -match '10A1') "list shows names and class"
  Result ($t -match 'Phu huynh Demo \(0901234567\)') "student row shows parent name+phone"
  $lg = Get-Page 'ListStudent.aspx' $gv
  $tg = Dec $lg.Body
  Result ($tg -match '0901000003' -and $tg -notmatch '0901000002' -and $tg -notmatch 'title="Sửa"') "GV list: students of own classes only, no manager rows, no edit buttons"
  $lg2 = Get-Page 'ListStudent.aspx' $gv2
  Result ($lg2.Status -eq 200 -and -not (Has-Error $lg2.Body)) "GV2 list renders"
  # search
  $p = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{ (UID $ls.Body 'txtSearch') = 'hs2@fschool' } $null (UID $ls.Body 'btnSearch')
  $tp = Dec $p.Body
  Result ($tp -match 'hs2' -or $tp -match 'Hoc sinh Mai') "search by email finds hs2"
  Result ($tp -notmatch '0901000001') "search by email excludes others"

  # ---------------------------------------------------------------- ListStudent: create scratch student with validation
  $ls = Get-Page 'ListStudent.aspx' $mgr
  $a = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{} (UID $ls.Body 'btnShowAdd') $null
  Result ($a.Body -match 'Thêm tài khoản mới') "Add form opens"
  $u = { param($s) UID $a.Body $s }
  $bad = Post-Page 'ListStudent.aspx' $mgr $a.Body @{ (& $u 'txtName') = 'Smoke Scratch'; (& $u 'txtClass') = 'ZZ9'; (& $u 'txtPhone') = '12ab'; (& $u 'txtEmail') = 'x@smoke.test' } $null (& $u 'btnSaveUser')
  Result ((Dec $bad.Body) -match 'Số điện thoại không hợp lệ') "invalid phone rejected with message"
  $dup = Post-Page 'ListStudent.aspx' $mgr $a.Body @{ (& $u 'txtName') = 'Smoke Dup'; (& $u 'txtClass') = 'ZZ9'; (& $u 'txtPhone') = '0901000003'; (& $u 'txtEmail') = '' } $null (& $u 'btnSaveUser')
  Result ((Dec $dup.Body) -match 'đã được đăng ký') "duplicate phone -> friendly message"
  $dupE = Post-Page 'ListStudent.aspx' $mgr $a.Body @{ (& $u 'txtName') = 'Smoke Dup'; (& $u 'txtClass') = 'ZZ9'; (& $u 'txtPhone') = ''; (& $u 'txtEmail') = 'HS@fschool.vn' } $null (& $u 'btnSaveUser')
  Result ((Dec $dupE.Body) -match 'đã tồn tại') "duplicate email -> friendly message"
  $ok = Post-Page 'ListStudent.aspx' $mgr $a.Body @{ (& $u 'txtName') = 'Smoke Scratch'; (& $u 'txtClass') = 'ZZ9'; (& $u 'txtPhone') = '0977000111'; (& $u 'txtEmail') = 'scratch1@smoke.test'; (& $u 'txtPassword') = 'Scratch1!' } $null (& $u 'btnSaveUser')
  Result ((Dec $ok.Body) -match 'Đã tạo tài khoản Smoke Scratch') "scratch student created"
  Result ((Sql "SELECT COUNT(*) FROM dbo.Users WHERE phone='0977000111' AND role='HS' AND className='ZZ9'") -eq '1') "row in dbo.Users (HS, class ZZ9)"
  $hash = Sql "SELECT passwordHash FROM dbo.Users WHERE phone='0977000111'"
  Result ($hash -match '^\$2[aby]\$10\$') "password stored as bcrypt cost 10"

  # ---------------------------------------------------------------- edit
  $ls = Get-Page 'ListStudent.aspx' $mgr
  $tgt = Row-Target $ls.Body '0977000111' 'Sửa'
  Result ($tgt -ne $null) "found Sửa button of scratch row"
  $e1 = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{} $tgt $null
  Result ((Dec $e1.Body) -match 'Sửa tài khoản: Smoke Scratch') "edit form opens"
  $e2 = Post-Page 'ListStudent.aspx' $mgr $e1.Body @{ (UID $e1.Body 'txtName') = 'Smoke Scratch Edited'; (UID $e1.Body 'txtClass') = 'ZZ9'; (UID $e1.Body 'txtPhone') = '0977000111'; (UID $e1.Body 'txtEmail') = 'scratch1@smoke.test' } $null (UID $e1.Body 'btnSaveUser')
  Result ((Dec $e2.Body) -match 'Đã cập nhật tài khoản Smoke Scratch Edited') "edit saved"
  $e3 = Post-Page 'ListStudent.aspx' $mgr $e1.Body @{ (UID $e1.Body 'txtName') = 'Smoke Scratch Edited'; (UID $e1.Body 'txtPhone') = '0901000003' } $null (UID $e1.Body 'btnSaveUser')
  Result ((Dec $e3.Body) -match 'đã được dùng bởi tài khoản khác') "edit to a taken phone -> friendly message"
  Result ((Sql "SELECT name FROM dbo.Users WHERE phone='0977000111'") -eq 'Smoke Scratch Edited') "name changed in DB"

  # ---------------------------------------------------------------- reset password + login with it
  $ls = Get-Page 'ListStudent.aspx' $mgr
  $tgt = Row-Target $ls.Body '0977000111' 'Đặt lại mật khẩu'
  $w1 = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{} $tgt $null
  $w2 = Post-Page 'ListStudent.aspx' $mgr $w1.Body @{ (UID $w1.Body 'txtResetPwd') = '123' } $null (UID $w1.Body 'btnDoReset')
  Result ((Dec $w2.Body) -match 'ít nhất 6 ký tự') "short password rejected"
  $w3 = Post-Page 'ListStudent.aspx' $mgr $w1.Body @{ (UID $w1.Body 'txtResetPwd') = 'NewPass#9' } $null (UID $w1.Body 'btnDoReset')
  Result ((Dec $w3.Body) -match 'Đã đặt lại mật khẩu') "password reset"
  $hash2 = Sql "SELECT passwordHash FROM dbo.Users WHERE phone='0977000111'"
  Result ($hash2 -ne $hash -and $hash2 -match '^\$2[aby]\$10\$') "hash changed (bcrypt cost 10)"
  # the account is HS so the portal refuses it with the access message (proves the new password is accepted)
  $lp = Do-Login '0977000111' 'NewPass#9'
  Result ((Dec $lp.Body) -match 'không có quyền truy cập') "login with new password accepted by auth (HS then denied portal access)"
  $lo = Do-Login '0977000111' 'Scratch1!'
  Result ((Dec $lo.Body) -match 'không đúng') "old password no longer works"
  try {
    $b = [Text.Encoding]::UTF8.GetBytes('{"identifier":"0977000111","password":"NewPass#9"}')
    $nr = Invoke-WebRequest "$NodeApi/api/login" -Method Post -ContentType 'application/json' -Body $b -UseBasicParsing -TimeoutSec 10
    Result ($nr.StatusCode -eq 200) "Node API /api/login accepts the reset password (cross-check of the bcrypt hash)"
  } catch {
    if ($_.Exception.Response) { Result $false "Node API login failed: $($_.Exception.Message)" } else { Write-Host "[SKIP] Node backend not running on $NodeApi" -ForegroundColor Yellow }
  }

  # ---------------------------------------------------------------- parent link / unlink
  $ls = Get-Page 'ListStudent.aspx' $mgr
  $tgt = Row-Target $ls.Body '0977000111' 'Liên kết phụ huynh / con'
  $k1 = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{} $tgt $null
  Result ((Dec $k1.Body) -match 'Phụ huynh của Smoke Scratch Edited') "parent panel opens for the student"
  $k2 = Post-Page 'ListStudent.aspx' $mgr $k1.Body @{ (UID $k1.Body 'txtLinkWho') = 'nobody@nowhere.test' } $null (UID $k1.Body 'btnAddLink')
  Result ((Dec $k2.Body) -match 'Không tìm thấy tài khoản') "unknown parent -> message"
  $k2b = Post-Page 'ListStudent.aspx' $mgr $k1.Body @{ (UID $k1.Body 'txtLinkWho') = '0901000001' } $null (UID $k1.Body 'btnAddLink')
  Result ((Dec $k2b.Body) -match 'Tài khoản phụ huynh không hợp lệ') "linking a non-PH account refused"
  $k3 = Post-Page 'ListStudent.aspx' $mgr $k1.Body @{ (UID $k1.Body 'txtLinkWho') = '0901234567' } $null (UID $k1.Body 'btnAddLink')
  Result ((Dec $k3.Body) -match 'Đã liên kết phụ huynh') "parent linked by phone"
  Result ((Sql "SELECT COUNT(*) FROM dbo.ParentStudent WHERE studentId=(SELECT id FROM dbo.Users WHERE phone='0977000111')") -eq '1') "ParentStudent row exists"
  $ls = Get-Page 'ListStudent.aspx' $mgr
  Result ((Dec $ls.Body) -match 'Smoke Scratch Edited' -and (Dec $ls.Body) -match 'Phu huynh Demo \(0901234567\)') "list shows parent phone for the scratch student"
  $m = [regex]::Match($k3.Body, "__doPostBack\(&#39;([^&]*gvLinks[^&]*)&#39;,&#39;&#39;\)")
  Result ($m.Success) "unlink button present"
  $k4 = Post-Page 'ListStudent.aspx' $mgr $k3.Body @{} $m.Groups[1].Value $null
  Result ((Dec $k4.Body) -match 'Đã gỡ liên kết') "parent unlinked"
  Result ((Sql "SELECT COUNT(*) FROM dbo.ParentStudent") -eq "$seedLinks") "ParentStudent back to seed count"

  # ---------------------------------------------------------------- permission: GV cannot create (server side)
  $gvPage = Get-Page 'ListStudent.aspx' $gv
  $att = Post-Page 'ListStudent.aspx' $gv $gvPage.Body @{ (UID $a.Body 'txtName') = 'Hacker'; (UID $a.Body 'txtPhone') = '0977000999'; (UID $a.Body 'txtClass') = 'ZZ9' } $null (UID $a.Body 'btnSaveUser')
  Result ((Sql "SELECT COUNT(*) FROM dbo.Users WHERE phone='0977000999'") -eq '0') "GV cannot create accounts (forged postback ignored)"

  # ---------------------------------------------------------------- delete-safe
  $ls = Get-Page 'ListStudent.aspx' $mgr
  $tgt = Row-Target $ls.Body '0901000003' 'Xóa'
  $d1 = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{} $tgt $null
  Result ((Dec $d1.Body) -match 'Không thể xóa Hoc sinh Demo vì còn dữ liệu liên quan') "deleting a student with grades is refused with a friendly message"
  Result ((Sql "SELECT COUNT(*) FROM dbo.Users WHERE phone='0901000003'") -eq '1') "seed student still exists"
  $tgt = Row-Target $ls.Body '0901000001' 'Xóa'
  $d1 = Post-Page 'ListStudent.aspx' $mgr $ls.Body @{} $tgt $null
  Result ((Dec $d1.Body) -match 'Không thể xóa Giao vien Demo') "deleting a teacher with lessons is refused"

  # ---------------------------------------------------------------- ListSchedule
  $sc = Get-Page 'ListSchedule.aspx?class=10A1' $mgr
  $ts = Dec $sc.Body
  Result ($ts -match 'Toán' -and $ts -match '07:30' -and $ts -match 'Thứ Hai') "Manager grid shows 10A1 lessons and bell times"
  Result ((([regex]::Matches($sc.Body, 'ListSchedule\.aspx\?edit=')).Count) -gt 25) "grid cells link to edit"
  $gs = Get-Page 'ListSchedule.aspx?class=10A1' $gv
  $tgv = Dec $gs.Body
  Result ($tgv -match 'Toán' -and $tgv -notmatch '>Văn<' -and $tgv -notmatch 'ListSchedule\.aspx\?edit=') "GV sees only own lessons (Toán yes, Văn no), no edit links"
  $gs2 = Get-Page 'ListSchedule.aspx' $gv2
  Result ((Dec $gs2.Body) -match 'Văn') "GV2 sees own lessons (Văn)"
  # add
  $ad = Get-Page 'ListSchedule.aspx?add=1&class=ZZ9&day=3&period=2' $mgr
  Result ((Dec $ad.Body) -match 'Thêm tiết học') "add form opens from URL"
  $teacherId = Sql "SELECT id FROM dbo.Users WHERE email='gv@fschool.vn'"
  $o = @{ (UID $ad.Body 'txtClass') = 'ZZ9'; (UID $ad.Body 'ddlFormDay') = '3'; (UID $ad.Body 'ddlFormPeriod') = '2'; (UID $ad.Body 'txtSubject') = 'SmokeMon'
          (UID $ad.Body 'ddlFormTeacher') = $teacherId; (UID $ad.Body 'txtRoom') = 'P.999'; (UID $ad.Body 'txtMode') = 'Trực tiếp'; (UID $ad.Body 'txtNote') = 'smoke' }
  $s1 = Post-Page 'ListSchedule.aspx' $mgr $ad.Body $o $null (UID $ad.Body 'btnSave')
  Result ((Dec $s1.Body) -match 'Đã lưu tiết học SmokeMon') "lesson added"
  Result ((Sql "SELECT CONCAT(CONVERT(VARCHAR(5),startTime,108),'-',CONVERT(VARCHAR(5),endTime,108)) FROM dbo.Schedule WHERE className='ZZ9' AND dayOfWeek=3 AND period=2") -eq '08:25-09:10') "times follow the bell schedule (08:25-09:10)"
  $o2 = @{} + $o; $o2[(UID $ad.Body 'txtSubject')] = 'SmokeDup'
  $s2 = Post-Page 'ListSchedule.aspx' $mgr $ad.Body $o2 $null (UID $ad.Body 'btnSave')
  Result ((Dec $s2.Body) -match 'đã có tiết 2') "same class+day+period refused"
  $o3 = @{} + $o; $o3[(UID $ad.Body 'txtClass')] = 'ZZ8'; $o3[(UID $ad.Body 'ddlFormDay')] = '1'; $o3[(UID $ad.Body 'ddlFormPeriod')] = '1'
  $s3 = Post-Page 'ListSchedule.aspx' $mgr $ad.Body $o3 $null (UID $ad.Body 'btnSave')
  Result ((Dec $s3.Body) -match 'Giáo viên đã có tiết 1') "teacher double-booking (Mon period 1 in 10A1) refused"
  # edit via grid link
  $lid = Sql "SELECT id FROM dbo.Schedule WHERE className='ZZ9'"
  $ed = Get-Page "ListSchedule.aspx?edit=$lid" $mgr
  Result ((Dec $ed.Body) -match 'Sửa tiết học' -and (Dec $ed.Body) -match 'SmokeMon') "edit form opens with data"
  $e4 = Post-Page 'ListSchedule.aspx' $mgr $ed.Body @{ (UID $ed.Body 'txtSubject') = 'SmokeMon2'; (UID $ed.Body 'txtRoom') = 'P.998'; (UID $ed.Body 'ddlFormPeriod') = '3' } $null (UID $ed.Body 'btnSave')
  Result ((Dec $e4.Body) -match 'Đã lưu tiết học SmokeMon2') "lesson edited"
  Result ((Sql "SELECT CONCAT(subject,'|',period,'|',room,'|',CONVERT(VARCHAR(5),startTime,108)) FROM dbo.Schedule WHERE id=$lid") -eq 'SmokeMon2|3|P.998|09:20') "edit persisted (period 3 -> 09:20)"
  # delete via list
  $dl = Get-Page 'ListSchedule.aspx?class=ZZ9' $mgr
  $dt = Row-Target $dl.Body 'SmokeMon2' 'Xóa'
  $d2 = Post-Page 'ListSchedule.aspx' $mgr $dl.Body @{} $dt $null
  Result ((Dec $d2.Body) -match 'Đã xóa tiết học') "lesson deleted"
  Result ((Sql "SELECT COUNT(*) FROM dbo.Schedule WHERE className='ZZ9'") -eq '0') "lesson row gone"
  # GV forged save
  $gp = Get-Page 'ListSchedule.aspx?class=10A1' $gv
  $forged = Post-Page 'ListSchedule.aspx' $gv $gp.Body $o $null (UID $ad.Body 'btnSave')
  Result ((Sql "SELECT COUNT(*) FROM dbo.Schedule WHERE className='ZZ9'") -eq '0') "GV cannot add lessons (forged postback ignored)"

  # ---------------------------------------------------------------- ImportData
  $im = Get-Page 'ImportData.aspx' $mgr
  $csvU = "fullName,className,phone,email,role,parentPhone`nSmoke Import A,ZZ9,0977000201,impa@smoke.test,HS,0901234567`n`"Smoke, Import B`",ZZ9,0977000202,impb@smoke.test,HS,`nBad Phone,ZZ9,abc,badp@smoke.test,HS,`nNo Class,,0977000203,,HS,`nBad Role,ZZ9,0977000204,,XX,`nBad Parent,ZZ9,0977000205,,HS,0900000000`nDup Mix,ZZ9,0901000003,impa@smoke.test,HS,"
  $i1 = Post-Page 'ImportData.aspx' $mgr $im.Body @{ (UID $im.Body 'txtStudentsCsv') = $csvU } $null (UID $im.Body 'btnImportStudents')
  $ti = Dec $i1.Body
  Result ($ti -match '2 thêm mới' -and $ti -match '5 lỗi') "students import: 2 inserted, 5 bad rows reported"
  Result ($ti -match 'Dòng 4' -and $ti -match 'Dòng 5' -and $ti -match 'Dòng 6' -and $ti -match 'Dòng 7' -and $ti -match 'Dòng 8') "per-row error report has line numbers 4-8"
  Result ((Sql "SELECT COUNT(*) FROM dbo.Users WHERE phone IN ('0977000201','0977000202')") -eq '2') "2 good users inserted"
  Result ((Sql "SELECT name FROM dbo.Users WHERE phone='0977000202'") -eq 'Smoke, Import B') "quoted field with comma parsed"
  Result ((Sql "SELECT COUNT(*) FROM dbo.ParentStudent ps JOIN dbo.Users s ON s.id=ps.studentId WHERE s.phone='0977000201'") -eq '1') "import linked parent via parentPhone"
  $im = Get-Page 'ImportData.aspx' $mgr
  $i2 = Post-Page 'ImportData.aspx' $mgr $im.Body @{ (UID $im.Body 'txtStudentsCsv') = $csvU.Replace('Smoke Import A', 'Smoke Import A2') } $null (UID $im.Body 'btnImportStudents')
  Result ((Dec $i2.Body) -match '0 thêm mới, 2 cập nhật') "re-import is idempotent (0 inserted, 2 updated)"
  Result ((Sql "SELECT COUNT(*) FROM dbo.Users WHERE phone LIKE '09770002%'") -eq '2' -and (Sql "SELECT name FROM dbo.Users WHERE phone='0977000201'") -eq 'Smoke Import A2') "no duplicates, name updated"

  $csvS = "className,subject,dayOfWeek,period,teacher,room`nZZ8,ImpMon1,T2,6,0901000001,P.1`nZZ8,ImpMon2,3,7,gv2@fschool.vn,P.2`nZZ8,ImpBad,9,1,gv@fschool.vn,P.3`nZZ8,ImpNoTeacher,1,3,nobody,P.4`nZZ8,ImpBusy,1,1,gv@fschool.vn,P.5"
  $im = Get-Page 'ImportData.aspx' $mgr
  $i3 = Post-Page 'ImportData.aspx' $mgr $im.Body @{ (UID $im.Body 'txtSchedulesCsv') = $csvS } $null (UID $im.Body 'btnImportSchedules')
  $t3 = Dec $i3.Body
  Result ($t3 -match '2 thêm mới' -and $t3 -match '3 lỗi') "timetable import: 2 inserted, 3 bad rows (bad day, unknown teacher, teacher busy)"
  Result ((Sql "SELECT COUNT(*) FROM dbo.Schedule WHERE className='ZZ8'") -eq '2') "2 lessons in DB"
  $im = Get-Page 'ImportData.aspx' $mgr
  $i4 = Post-Page 'ImportData.aspx' $mgr $im.Body @{ (UID $im.Body 'txtSchedulesCsv') = $csvS } $null (UID $im.Body 'btnImportSchedules')
  Result ((Dec $i4.Body) -match '0 thêm mới, 2 cập nhật') "timetable re-import idempotent"

  $csvG = "student,subject,term,type,score,weight,gradeDate`n0977000201,SmokeSubj,HK1,15 phút,8.5,1,2026-10-08`n0977000201,SmokeSubj,HK1,15 phút,11,1,2026-10-08`nnobody@x.test,SmokeSubj,HK1,Miệng,7,,"
  $im = Get-Page 'ImportData.aspx' $mgr
  $i5 = Post-Page 'ImportData.aspx' $mgr $im.Body @{ (UID $im.Body 'txtGradesCsv') = $csvG } $null (UID $im.Body 'btnImportGrades')
  Result ((Dec $i5.Body) -match '1 thêm mới' -and (Dec $i5.Body) -match '2 lỗi') "grades import: 1 inserted, 2 bad rows"

  $gvIm = Post-Page 'ImportData.aspx' $gv $im.Body @{} $null (UID $im.Body 'btnImportStudents')
  Result ($gvIm.Status -eq 302) "GV posting to ImportData is redirected"

  $tpl = Post-Page 'ImportData.aspx' $mgr $im.Body @{} (UID $im.Body 'lnkTplStudents') $null
  Result ($tpl.Status -eq 200 -and $tpl.Body -match 'fullName,className,phone') "template download works"

  # quick seed does not change anything when data already exists
  $before = Sql "SELECT CONCAT((SELECT COUNT(*) FROM dbo.Schedule),'|',(SELECT COUNT(*) FROM dbo.ParentStudent))"
  $im = Get-Page 'ImportData.aspx' $mgr
  $qs = Post-Page 'ImportData.aspx' $mgr $im.Body @{} $null (UID $im.Body 'btnQuickSeed')
  $after = Sql "SELECT CONCAT((SELECT COUNT(*) FROM dbo.Schedule),'|',(SELECT COUNT(*) FROM dbo.ParentStudent))"
  Result ((Dec $qs.Body) -match 'dữ liệu mẫu' -and $before -eq $after) "seed button is non-destructive when data exists ($before -> $after)"

  # ---------------------------------------------------------------- REST API
  $mb = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("manager@fschool.vn:$Password")) }
  $gb = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("gv@fschool.vn:$Password")) }
  $x = Send-Http 'GET' 'api/students' $anon $null $null
  Result ($x.Status -eq 401) "GET /api/students without credentials -> 401"
  $x = Send-Http 'GET' 'api/students' $anon $null $mb
  Result ($x.Status -eq 200 -and $x.Body -match '"count"' -and $x.Body -match 'Hoc sinh Demo') "GET /api/students as Manager -> 200 with students"
  $x = Send-Http 'GET' 'api/students?className=10A1' $anon $null $gb
  Result ($x.Status -eq 200 -and $x.Body -match 'Hoc sinh Mai' -and $x.Body -notmatch 'Smoke Import') "GET /api/students?className=10A1 as GV -> 10A1 students only"
  $x = Send-Http 'GET' 'api/students?className=ZZ9' $anon $null $gb
  Result ($x.Status -eq 200 -and $x.Body -notmatch 'Smoke Import') "GV does not see students of a class he does not teach (ZZ9)"
  $x = Send-Http 'GET' 'api/schedules?className=10A1&dayOfWeek=T2' $anon $null $gb
  Result ($x.Status -eq 200 -and $x.Body -match 'Toán' -and $x.Body -notmatch '"subject": "Văn"') "GET /api/schedules as GV -> own lessons only"
  $x = Send-Http 'GET' 'api/schedules?className=10A1' $anon $null $mb
  Result ($x.Status -eq 200 -and $x.Body -match '"count": 29') "GET /api/schedules?className=10A1 as Manager -> 29 lessons"
  # JSON body helper (HttpWebRequest with application/json)
  function Send-Json($method, $path, $json, $headers) {
    $req = [System.Net.HttpWebRequest]::Create("$BaseUrl/$path"); $req.Method = $method; $req.Timeout = 120000
    foreach ($k in $headers.Keys) { $req.Headers[$k] = $headers[$k] }
    if ($json) { $bytes = [Text.Encoding]::UTF8.GetBytes($json); $req.ContentType = 'application/json; charset=utf-8'; $req.ContentLength = $bytes.Length; $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close() } else { $req.ContentLength = 0 }
    try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
    $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8); $b = $sr.ReadToEnd(); $sr.Close(); $s = [int]$resp.StatusCode; $resp.Close()
    return @{ Status = $s; Body = $b }
  }
  $x = Send-Json 'POST' 'api/students' '{}' $gb
  Result ($x.Status -eq 403) "POST /api/students as GV -> 403 (got $($x.Status) $($x.Body))"
  $x = Send-Json 'POST' 'api/import/students' '{"csvData":"x"}' $gb
  Result ($x.Status -eq 403) "POST /api/import/students as GV -> 403"
  $x = Send-Json 'POST' 'api/students' '{"name":"Smoke Api","phone":"0977000301","email":"api1@smoke.test","className":"ZZ9"}' $mb
  Result ($x.Status -eq 200 -and (Sql "SELECT COUNT(*) FROM dbo.Users WHERE phone='0977000301'") -eq '1') "POST /api/students as Manager creates a student"
  $apiId = Sql "SELECT id FROM dbo.Users WHERE phone='0977000301'"
  $x = Send-Json 'POST' 'api/students' '{"name":"Smoke Api","phone":"0977000301","className":"ZZ9"}' $mb
  Result ($x.Status -eq 400 -and $x.Body -match 'đã được đăng ký') "duplicate via API -> 400 with message"
  $x = Send-Json 'PUT' "api/students/$apiId" '{"name":"Smoke Api 2","phone":"0977000301","email":"api1@smoke.test","className":"ZZ9"}' $mb
  Result ($x.Status -eq 200 -and (Sql "SELECT name FROM dbo.Users WHERE id=$apiId") -eq 'Smoke Api 2') "PUT /api/students/{id} updates"
  $x = Send-Json 'DELETE' "api/students/$apiId" $null $mb
  Result ($x.Status -eq 200 -and (Sql "SELECT COUNT(*) FROM dbo.Users WHERE id=$apiId") -eq '0') "DELETE /api/students/{id} removes a free student"
  $x = Send-Json 'POST' 'api/schedules' ('{"teacherId":' + $teacherId + ',"className":"ZZ9","subject":"ApiMon","dayOfWeek":5,"period":4,"room":"P.7"}') $mb
  Result ($x.Status -eq 200 -and (Sql "SELECT COUNT(*) FROM dbo.Schedule WHERE subject='ApiMon'") -eq '1') "POST /api/schedules as Manager creates a lesson"
  $x = Send-Json 'POST' 'api/import/students' '{"csvData":"fullName,className,phone\nSmoke Api Imp,ZZ9,0977000302"}' $mb
  Result ($x.Status -eq 200 -and $x.Body -match '"insertedCount": 1') "POST /api/import/students as Manager works (got $($x.Status) $($x.Body))"
}
finally {
  # ---------------------------------------------------------------- cleanup: everything scratch, then verify seed counts
  Write-Host "--- cleanup"
  Sql "DELETE FROM dbo.ParentStudent WHERE studentId IN (SELECT id FROM dbo.Users WHERE phone LIKE '09770%' OR email LIKE '%@smoke.test');
       DELETE FROM dbo.Grade WHERE subject='SmokeSubj' OR studentId IN (SELECT id FROM dbo.Users WHERE phone LIKE '09770%' OR email LIKE '%@smoke.test');
       DELETE FROM dbo.Schedule WHERE className IN ('ZZ9','ZZ8') OR subject IN ('ApiMon');
       DELETE FROM dbo.Users WHERE phone LIKE '09770%' OR email LIKE '%@smoke.test';" | Out-Null
  $c = Sql "SELECT CONCAT((SELECT COUNT(*) FROM dbo.Users),'|',(SELECT COUNT(*) FROM dbo.Schedule WHERE className='10A1'),'|',(SELECT COUNT(*) FROM dbo.Schedule),'|',(SELECT COUNT(*) FROM dbo.ParentStudent WHERE parentId=(SELECT id FROM dbo.Users WHERE email='ph@fschool.vn')),'|',(SELECT COUNT(*) FROM dbo.ParentStudent),'|',(SELECT COUNT(*) FROM dbo.Grade))"
  Write-Host "Counts after cleanup (users|10A1 lessons|all lessons|children of ph|links|grades): $c"
  Result ($c -eq "$seedUsers|29|$seedSched|2|$seedLinks|96") "database back to seed values"
}

if ($script:fail -eq 0) { Write-Host "SMOKE-STUDENTS OK" -ForegroundColor Green; exit 0 } else { Write-Host "SMOKE-STUDENTS: $($script:fail) check(s) failed" -ForegroundColor Red; exit 1 }
