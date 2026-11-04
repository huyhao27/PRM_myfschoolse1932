# HTTP smoke test of the running site (start it first with tools\run.ps1).
# Usage: powershell -ExecutionPolicy Bypass -File tools\smoke.ps1 [-BaseUrl http://localhost:8088] [-Password 123456]
param([string]$BaseUrl = 'http://localhost:8088', [string]$Password = '123456')
$ErrorActionPreference = 'Continue'
$script:fail = 0
function Result($ok, $msg) { if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green } else { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ } }

# One HTTP call without auto-redirect; never throws. $jar is a CookieContainer. Returns @{Status; Body; Location}
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

# POST the login form; returns @{Status; Body; Location; Session}
function Do-Login($identifier, $pass) {
  $jar = New-Object System.Net.CookieContainer
  $g = Get-Page 'Login.aspx' $jar
  $form = @{
    '__VIEWSTATE' = (Field $g.Body '__VIEWSTATE'); '__VIEWSTATEGENERATOR' = (Field $g.Body '__VIEWSTATEGENERATOR')
    '__EVENTVALIDATION' = (Field $g.Body '__EVENTVALIDATION')
    'txtIdentifier' = $identifier; 'txtPassword' = $pass; 'btnLogin' = 'Đăng nhập'
  }
  $r = Send-Http 'POST' 'Login.aspx' $jar $form
  $r.Session = $jar
  return $r
}

function Has-Error($body) { return ($body -match 'Server Error in|Exception|Stack Trace|Lỗi máy chủ|Parser Error|Compilation Error|Host error') }

# --- 1. public pages
$s0 = New-Object System.Net.CookieContainer
$p = Get-Page 'Login.aspx' $s0
Result ($p.Status -eq 200 -and -not (Has-Error $p.Body)) "GET /Login.aspx -> $($p.Status)"
Result ($p.Body -match 'Số điện thoại') "Login.aspx shows 'Số điện thoại'"
try { $lr = Invoke-WebRequest "$BaseUrl/Content/fpt-logo.svg" -UseBasicParsing -TimeoutSec 30; Result ($lr.StatusCode -eq 200 -and "$($lr.Headers['Content-Type'])" -match 'image/svg\+xml') "GET /Content/fpt-logo.svg -> $($lr.StatusCode) $($lr.Headers['Content-Type'])" }
catch { Result $false "GET /Content/fpt-logo.svg -> $($_.Exception.Message)" }

# --- 2. login cases
$bad = Do-Login 'gv@fschool.vn' 'wrong-password'
Result ($bad.Status -eq 200 -and ([Net.WebUtility]::HtmlDecode($bad.Body)) -match 'không đúng') "wrong password rejected (200 + message)"
$ph = Do-Login 'ph@fschool.vn' $Password
Result ($ph.Status -eq 200 -and ([Net.WebUtility]::HtmlDecode($ph.Body)) -match 'không có quyền truy cập') "PH account rejected with portal-access message"

$sessions = @{}
foreach ($acc in 'manager@fschool.vn', 'gv@fschool.vn') {
  $l = Do-Login $acc $Password
  $ok = ($l.Status -eq 302 -and "$($l.Location)" -match 'Default\.aspx')
  Result $ok "login $acc -> $($l.Status) $($l.Location)"
  if ($ok) { $sessions[$acc] = $l.Session }
}
# phone login (works once phones are seeded)
$lp = Do-Login '0901000001' $Password
Write-Host ("[INFO] login by phone 0901000001 -> {0} {1}" -f $lp.Status, $lp.Location)

# --- 3. pages per account
$pages = 'Default.aspx', 'ListStudent.aspx', 'ListGrade.aspx', 'AddGrade.aspx', 'ListSchedule.aspx', 'ImportData.aspx', 'ViewGrade.aspx?id=1', 'EditGrade.aspx?id=1', 'api/students'
foreach ($acc in $sessions.Keys) {
  Write-Host "--- pages as $acc"
  foreach ($pg in $pages) {
    $r = Get-Page $pg $sessions[$acc]
    $err = Has-Error $r.Body
    $note = ''
    if ($err) { $t = [regex]::Match($r.Body, '<title>(.*?)</title>', 'Singleline').Groups[1].Value; $note = ' :: ' + ([Net.WebUtility]::HtmlDecode($t).Trim() -replace '\s+', ' ') ; if ($note.Length -gt 200) { $note = $note.Substring(0, 200) } }
    if ($r.Status -eq 302) { $note = " -> $($r.Location)" }
    $good = ($r.Status -eq 200 -and -not $err) -or ($r.Status -eq 302)
    $label = if ($good) { 'OK  ' } else { 'FAIL' }
    Write-Host ("  [{0}] {1,-24} {2}{3}" -f $label, $pg, $r.Status, $note) -ForegroundColor $(if ($good) { 'Green' } else { 'Yellow' })
  }
  # only Default.aspx is required to be green in the foundation
  $d = Get-Page 'Default.aspx' $sessions[$acc]
  Result ($d.Status -eq 200 -and -not (Has-Error $d.Body)) "Default.aspx renders for $acc"
}

# --- 4. unauthenticated access is bounced to login
$u = Get-Page 'Default.aspx' (New-Object System.Net.CookieContainer)
Result ($u.Status -eq 302 -and "$($u.Location)" -match 'Login\.aspx') "anonymous Default.aspx -> login redirect"

if ($script:fail -eq 0) { Write-Host "SMOKE OK" -ForegroundColor Green; exit 0 } else { Write-Host "SMOKE: $($script:fail) check(s) failed" -ForegroundColor Red; exit 1 }
