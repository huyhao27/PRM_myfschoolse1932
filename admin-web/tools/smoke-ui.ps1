# UI shell smoke test of the running site (start it first with tools\run.ps1, or use tools\locked.ps1).
# Usage: powershell -ExecutionPolicy Bypass -File tools\smoke-ui.ps1 [-BaseUrl http://localhost:8088] [-Password 123456]
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
  if (-not $resp) { return @{ Status = 0; Body = 'no response'; Location = $null; Type = '' } }
  $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
  $body = $sr.ReadToEnd(); $sr.Close()
  $r = @{ Status = [int]$resp.StatusCode; Body = $body; Location = $resp.Headers['Location']; Type = "$($resp.ContentType)" }
  $resp.Close()
  return $r
}
function Get-Page($path, $jar) { return Send-Http 'GET' $path $jar $null }
function Field($html, $name) { if ($html -match "name=`"$name`"[^>]*value=`"([^`"]*)`"") { return [System.Net.WebUtility]::HtmlDecode($Matches[1]) } else { return '' } }
function Do-Login($identifier, $pass) {
  $jar = New-Object System.Net.CookieContainer
  $g = Get-Page 'Login.aspx' $jar
  $form = @{ '__VIEWSTATE' = (Field $g.Body '__VIEWSTATE'); '__VIEWSTATEGENERATOR' = (Field $g.Body '__VIEWSTATEGENERATOR'); '__EVENTVALIDATION' = (Field $g.Body '__EVENTVALIDATION')
             'txtIdentifier' = $identifier; 'txtPassword' = $pass; 'btnLogin' = 'Đăng nhập' }
  $r = Send-Http 'POST' 'Login.aspx' $jar $form
  $r.Session = $jar
  return $r
}
function Has-Error($body) { return ($body -match 'Server Error in|Stack Trace|Lỗi máy chủ|Parser Error|Compilation Error|Host error') }

# --- site.css / site.js / logo
$css = Get-Page 'Content/site.css' (New-Object System.Net.CookieContainer)
Result ($css.Status -eq 200 -and $css.Type -match 'text/css') "site.css served (200, $($css.Type))"
$tokens = '--brand:', '--brand-strong:', '--brand-soft:', '--navy:', '--ink:', '--muted:', '--line:', '--surface:', '--surface-alt:', '--success:', '--warning:', '--danger:', '--info:', '--bs-primary:', 'prefers-reduced-motion', ':focus-visible',
          '.page-header', '.card-panel', '.filter-bar', '.data-table', '.table-responsive-stack', '.status-badge', '.empty-state', '.btn-brand', '.btn-brand-outline', '.btn-danger-soft', '.icon-btn', '.form-field', '.stat-card', '.alert-inline', '.app-toast'
$missing = @($tokens | Where-Object { $css.Body.IndexOf($_) -lt 0 })
Result ($missing.Count -eq 0) ("site.css has tokens and components" + $(if ($missing.Count) { ' (missing: ' + ($missing -join ', ') + ')' } else { '' }))
$js = Get-Page 'Content/site.js' (New-Object System.Net.CookieContainer)
Result ($js.Status -eq 200 -and $js.Body -match 'sidebarToggle') 'site.js served'
try { $lr = Invoke-WebRequest "$BaseUrl/Content/fpt-logo.svg" -UseBasicParsing -TimeoutSec 30; Result ($lr.StatusCode -eq 200 -and "$($lr.Headers['Content-Type'])" -match 'image/svg\+xml') 'fpt-logo.svg served as image/svg+xml' }
catch { Result $false "fpt-logo.svg -> $($_.Exception.Message)" }

# --- login page
$lg = Get-Page 'Login.aspx' (New-Object System.Net.CookieContainer)
$b = $lg.Body
Result ($lg.Status -eq 200 -and -not (Has-Error $b)) 'Login.aspx renders'
Result ($b -match '<label for="txtIdentifier"') 'login: labeled phone field'
Result ($b -match 'id="txtIdentifier"[^>]*type="tel"' -or $b -match 'type="tel"[^>]*id="txtIdentifier"') 'login: phone input type=tel'
Result ($b -match 'inputmode="tel"' -and $b -match 'autocomplete="username"') 'login: inputmode=tel + autocomplete=username'
Result ($b -match 'data-toggle-password="txtPassword"' -and $b -match 'aria-pressed="false"') 'login: password show/hide toggle with aria-pressed'
Result ($b -match 'href="Content/site\.css"' -and $b -notmatch '<style') 'login: uses site.css, no inline <style>'
$bad = Do-Login '0901000001' 'wrong-password'
Result ($bad.Status -eq 200 -and $bad.Body -match 'role="alert"' -and $bad.Body -match 'alert-inline') 'login: wrong password shows role=alert inline error'

# --- master shell per account
$mgr = (Do-Login '0901000002' $Password).Session
$gv = (Do-Login '0901000001' $Password).Session
$pages = @(
  @('Default.aspx', 'Default.aspx'), @('ListStudent.aspx', 'ListStudent.aspx'), @('ListGrade.aspx', 'ListGrade.aspx'), @('AddGrade.aspx', 'ListGrade.aspx'),
  @('ListSchedule.aspx', 'ListSchedule.aspx'), @('ListRequest.aspx', 'ListRequest.aspx'), @('ListClub.aspx', 'ListClub.aspx'), @('ImportData.aspx', 'ImportData.aspx')
)
foreach ($acc in @(@('Manager', $mgr), @('GV', $gv))) {
  $name = $acc[0]; $jar = $acc[1]
  foreach ($pg in $pages) {
    if ($name -eq 'GV' -and $pg[0] -eq 'ImportData.aspx') { continue }
    $r = Get-Page $pg[0] $jar
    $h = $r.Body
    $ok = $r.Status -eq 200 -and -not (Has-Error $h)
    Result $ok "$name $($pg[0]) renders without server error"
    if (-not $ok) { continue }
    $nav = $h -match '<nav[^>]*aria-label="Menu chính"' -and $h -match '<main[^>]*id="main-content"' -and $h -match 'role="banner"'
    $cur = [regex]::Matches($h, 'aria-current="page"').Count -eq 1 -and $h -match ('href="' + [regex]::Escape($pg[1]) + '" aria-current="page"')
    Result ($nav -and $cur) "$name $($pg[0]): nav/main/banner landmarks, aria-current on $($pg[1]) only"
  }
  $d = Get-Page 'Default.aspx' $jar
  Result ($d.Body -match 'id="sidebarToggle"' -and $d.Body -match 'aria-controls="appSidebar"' -and $d.Body -match 'class="skip-link"') "$name master: sidebar toggle button + skip link"
  Result ($d.Body -match 'href="Content/site\.css"' -and $d.Body -notmatch '<style') "$name master: site.css linked, no inline <style>"
  Result ($d.Body -match 'href="Login\.aspx\?logout=true"') "$name master: logout link"
  $hasImport = $d.Body -match 'href="ImportData\.aspx"'
  if ($name -eq 'Manager') { Result $hasImport 'Manager sees Import link' } else { Result (-not $hasImport) 'GV does not see Import link' }
}
# dashboard content
$d = Get-Page 'Default.aspx' $mgr
$t = [Net.WebUtility]::HtmlDecode(($d.Body -replace '<[^>]+>', ' '))
Result ($t -match 'Xin chào' -and $t -match 'Việc cần làm' -and $t -match 'Đầu điểm cập nhật gần đây') 'dashboard: greeting, Việc cần làm, recent grades panels'
Result ($d.Body -match 'class="stat-card"' -and ([regex]::Matches($d.Body, 'stat-card')).Count -ge 5) 'dashboard: 5 stat cards'
Result ($d.Body -match 'href="AddGrade\.aspx"' -and $d.Body -match 'ListRequest\.aspx\?status=pending' -and $d.Body -match 'href="ListSchedule\.aspx"') 'dashboard: quick actions'
Result ($d.Body -match 'class="data-table"') 'dashboard: recent grades use .data-table'
# anonymous bounced
$u = Get-Page 'Default.aspx' (New-Object System.Net.CookieContainer)
Result ($u.Status -eq 302 -and "$($u.Location)" -match 'Login') 'anonymous Default.aspx -> login'

if ($script:fail -eq 0) { Write-Host "SMOKE-UI OK" -ForegroundColor Green; exit 0 } else { Write-Host "SMOKE-UI: $($script:fail) check(s) failed" -ForegroundColor Red; exit 1 }
