# Smoke test for the mobile JSON API (/api/m): the things the Node contract suite does not cover (abuse protection, token forging,
# CORS, statelessness). The Node suite itself runs against this API with: cd backend; API_BASE=http://localhost:8088 API_PREFIX=/api/m npm test
# Usage (inside the lock): powershell -File tools\locked.ps1 -Cmd "run.ps1; smoke-mobile.ps1; stop.ps1"
# Creates ONE scratch HS user (+ one scratch request) with a unique name and removes them at the end; seeded accounts are never rate-limited.
param([string]$BaseUrl = 'http://localhost:8088', [string]$Password = '123456')
$ErrorActionPreference = 'Continue'
$script:fail = 0
function Result($ok, $msg) { if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green } else { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ } }

function Sql($q) { $o = & sqlcmd -S 'localhost,1433' -E -C -I -d FSchoolDB -h -1 -W -Q "SET NOCOUNT ON; $q" 2>&1; return (($o | Out-String).Trim()) }

# Secret for forging EXPIRED-but-correctly-signed tokens. Read from backend\.env, never printed.
$envFile = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'backend\.env'
$secret = $null
Get-Content $envFile -Encoding UTF8 | ForEach-Object { if ($_ -match '^\s*JWT_SECRET\s*=\s*(.*?)\s*$') { $secret = $Matches[1].Trim('"').Trim("'") } }

function B64Url([byte[]]$b) { return [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function B64UrlText([string]$s) { return B64Url ([Text.Encoding]::UTF8.GetBytes($s)) }
function Make-Token($sub, $exp, $key) {
  $h = B64UrlText '{"alg":"HS256","typ":"JWT"}'
  $p = B64UrlText ('{"sub":' + $sub + ',"role":"Manager","iat":1,"exp":' + $exp + '}')
  $hmac = New-Object Security.Cryptography.HMACSHA256 (, [Text.Encoding]::UTF8.GetBytes($key))
  return "$h.$p." + (B64Url $hmac.ComputeHash([Text.Encoding]::ASCII.GetBytes("$h.$p")))
}

function Send($method, $path, $body, $token, $headers) {
  $req = [System.Net.HttpWebRequest]::Create("$BaseUrl$path")
  $req.Method = $method; $req.AllowAutoRedirect = $false; $req.Timeout = 60000
  if ($token) { $req.Headers.Add('Authorization', "Bearer $token") }
  if ($headers) { foreach ($k in $headers.Keys) { $req.Headers.Add($k, $headers[$k]) } }
  if ($null -ne $body) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    $req.ContentType = 'application/json'; $req.ContentLength = $bytes.Length
    $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
  }
  try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
  if (-not $resp) { return @{ Status = 0; Body = 'no response'; Json = $null; Headers = @{}; Raw = $null } }
  $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
  $text = $sr.ReadToEnd(); $sr.Close()
  $j = $null; try { $j = $text | ConvertFrom-Json } catch { }
  $r = @{ Status = [int]$resp.StatusCode; Body = $text; Json = $j; Headers = $resp.Headers; Raw = $resp }
  $resp.Close()
  return $r
}
function Login($id, $pw) { return Send 'POST' '/api/m/login' (@{ identifier = $id; password = $pw } | ConvertTo-Json -Compress) $null $null }

$cookies = New-Object System.Collections.Generic.List[string]
function Track($r) { if ($r.Headers -and $r.Headers['Set-Cookie']) { $cookies.Add($r.Headers['Set-Cookie']) } }

$tag = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$scratchEmail = "zz-smoke-$tag@fschool.vn"
$scratchId = 0
$reqId = 0
try {
  # ---------------------------------------------------------------- basics, headers, statelessness
  $r = Send 'GET' '/api/m/health' $null $null $null; Track $r
  Result ($r.Status -eq 200 -and $r.Json.status -eq 'ok') 'GET /api/m/health -> 200 {"status":"ok"}'
  Result ($r.Headers['X-Content-Type-Options'] -eq 'nosniff') 'security header X-Content-Type-Options: nosniff'
  Result (([string]$r.Headers['Cache-Control']) -match 'no-store') 'Cache-Control contains no-store'
  Result (([string]$r.Headers['Content-Type']) -match 'application/json') 'Content-Type is JSON'
  $r = Send 'GET' '/api/m/nope' $null $null $null; Track $r
  Result ($r.Status -eq 404 -and $r.Body -eq '{"message":"Not found"}') 'unknown /api/m route -> 404 {"message":"Not found"}'
  $r = Send 'GET' '/api/m/login' $null $null $null; Track $r
  Result ($r.Status -eq 404) 'GET on a POST-only route -> 404 like Express'

  $r = Login 'hs@fschool.vn' $Password; Track $r
  Result ($r.Status -eq 200 -and $r.Json.user.role -eq 'HS' -and -not ($r.Body -match 'passwordHash')) 'login hs@fschool.vn -> 200, no passwordHash'
  $hsToken = $r.Json.token
  $parts = $hsToken.Split('.')
  $hdr = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($parts[0].Replace('-', '+').Replace('_', '/') + ('=' * ((4 - $parts[0].Length % 4) % 4)))))
  Result ($parts.Count -eq 3 -and $hdr -match '"alg":"HS256"') 'token is a 3-part JWT with alg HS256'
  $r = Send 'GET' '/api/m/me' $null $hsToken $null; Track $r
  Result ($r.Status -eq 200 -and $r.Json.email -eq 'hs@fschool.vn') 'GET /api/m/me with the token'
  $r = Send 'GET' '/api/m/me' $null $null $null; Track $r
  Result ($r.Status -eq 401 -and $r.Json.message -eq 'Missing or malformed Authorization header') '/me without header -> 401 message'
  $r = Send 'GET' '/api/m/clubs' $null $hsToken $null; Track $r
  Result ($r.Status -eq 200) 'GET /api/m/clubs'
  Result ($cookies.Count -eq 0) "no Set-Cookie on any /api/m response (saw $($cookies.Count))"

  # ---------------------------------------------------------------- forged tokens
  $none = (B64UrlText '{"alg":"none","typ":"JWT"}') + '.' + (B64UrlText '{"sub":1,"role":"Manager","exp":4102444800}') + '.'
  $r = Send 'GET' '/api/m/me' $null $none $null
  Result ($r.Status -eq 401 -and $r.Json.message -eq 'Invalid token') 'alg=none token rejected (Invalid token)'
  $none2 = (B64UrlText '{"alg":"none","typ":"JWT"}') + '.' + (B64UrlText '{"sub":1,"role":"Manager","exp":4102444800}') + '.' + ($parts[2])
  $r = Send 'GET' '/api/m/me' $null $none2 $null
  Result ($r.Status -eq 401 -and $r.Json.message -eq 'Invalid token') 'alg=none header with a copied signature rejected'
  $hs384 = (B64UrlText '{"alg":"HS384","typ":"JWT"}') + '.' + $parts[1] + '.' + $parts[2]
  $r = Send 'GET' '/api/m/me' $null $hs384 $null
  Result ($r.Status -eq 401 -and $r.Json.message -eq 'Invalid token') 'alg=HS384 token rejected'
  $tampered = $parts[0] + '.' + (B64UrlText '{"sub":1,"role":"Manager","iat":1,"exp":4102444800}') + '.' + $parts[2]
  $r = Send 'GET' '/api/m/me' $null $tampered $null
  Result ($r.Status -eq 401 -and $r.Json.message -eq 'Invalid token') 'payload tampered, signature kept -> Invalid token'
  $wrong = Make-Token 1 4102444800 'not-the-secret-not-the-secret'
  $r = Send 'GET' '/api/m/me' $null $wrong $null
  Result ($r.Status -eq 401 -and $r.Json.message -eq 'Invalid token') 'token signed with another secret -> Invalid token'
  if ($secret) {
    $expired = Make-Token 1 1000000000 $secret
    $r = Send 'GET' '/api/m/me' $null $expired $null
    Result ($r.Status -eq 401 -and $r.Json.message -eq 'Token expired') 'correctly signed but expired token -> Token expired'
    $okTok = Make-Token 1 4102444800 $secret
    $r = Send 'GET' '/api/m/me' $null $okTok $null
    Result ($r.Status -eq 200) 'hand-made HS256 token with the shared secret is accepted (Node interoperability)'
  } else { Result $false 'JWT_SECRET not found in backend\.env' }

  # ---------------------------------------------------------------- scratch user
  Sql "INSERT dbo.Users (name, email, phone, passwordHash, role, className) SELECT N'ZZ Smoke $tag', '$scratchEmail', NULL, passwordHash, 'HS', className FROM dbo.Users WHERE email = 'hs@fschool.vn'" | Out-Null
  $scratchId = [int](Sql "SELECT id FROM dbo.Users WHERE email = '$scratchEmail'")
  Result ($scratchId -gt 0) "scratch user created (id $scratchId)"
  Sql "INSERT dbo.Requests (studentId, createdBy, type, fromDate, toDate, reason) SELECT TOP 1 $scratchId, $scratchId, type, '2026-11-02', '2026-11-02', N'ZZ-SMOKE-$tag' FROM dbo.Requests" | Out-Null
  $reqId = [int](Sql "SELECT id FROM dbo.Requests WHERE reason = N'ZZ-SMOKE-$tag'")

  # ---------------------------------------------------------------- visibility: PH token vs an invisible request
  $ph = (Login 'ph@fschool.vn' $Password).Json.token
  $mg = (Login 'manager@fschool.vn' $Password).Json.token
  $r = Send 'GET' "/api/m/requests/$reqId" $null $ph $null
  Result ($r.Status -eq 404 -and $r.Json.message -eq 'Request not found') "PH cannot read request $reqId of a student that is not their child (404)"
  $r = Send 'GET' "/api/m/requests/$reqId" $null $mg $null
  Result ($r.Status -eq 200 -and $r.Json.student.id -eq $scratchId) 'Manager can read that request (200)'
  $r = Send 'GET' '/api/m/requests' $null $ph $null
  Result ($r.Status -eq 200 -and -not (($r.Body) -match "ZZ-SMOKE-$tag")) 'PH request list does not contain it either'
  $r = Send 'POST' "/api/m/requests/$reqId/decision" '{"decision":"approved"}' $ph $null
  Result ($r.Status -eq 403) 'PH cannot decide (403)'

  # ---------------------------------------------------------------- role is re-read from the database on every request
  $sTok = (Login $scratchEmail $Password).Json.token
  $r = Send 'POST' "/api/m/requests/$reqId/decision" '{"decision":"approved"}' $sTok $null
  Result ($r.Status -eq 403 -and $r.Json.message -eq 'Forbidden for your role') 'scratch HS token: decision -> 403'
  Sql "UPDATE dbo.Users SET role = 'GV' WHERE id = $scratchId" | Out-Null
  $r = Send 'POST' "/api/m/requests/$reqId/decision" '{"decision":"approved"}' $sTok $null
  Result ($r.Status -eq 404) 'same token after the DB role became GV: role gate passes (404, GV teaches no class) - role comes from the DB, not the token'
  Sql "UPDATE dbo.Users SET role = 'HS' WHERE id = $scratchId" | Out-Null

  # ---------------------------------------------------------------- rate limit: login
  $bad = @()
  1..5 | ForEach-Object { $bad += (Login $scratchEmail 'wrong-pass-1').Status }
  Result (($bad -join ',') -eq '401,401,401,401,401') "5 wrong passwords on the scratch account -> 401 each ($($bad -join ','))"
  $r = Login $scratchEmail 'wrong-pass-1'; Track $r
  Result ($r.Status -eq 429 -and $r.Json.message -eq 'Too many attempts. Try again later.') '6th attempt -> 429 {"message":"Too many attempts. Try again later."}'
  $ra = 0; [void][int]::TryParse([string]$r.Headers['Retry-After'], [ref]$ra)
  Result ($ra -gt 0 -and $ra -le 900) "Retry-After header present ($ra s)"
  $r = Login $scratchEmail $Password
  Result ($r.Status -eq 429) 'the CORRECT password is also blocked until the window passes'
  $r = Login "ZZ-Smoke-$tag@FSchool.VN" $Password
  Result ($r.Status -eq 429) 'identifier normalisation: same key with other letter case / spaces is still blocked'
  $r = Login 'hs@fschool.vn' $Password
  Result ($r.Status -eq 200) 'a seeded account is not affected by the scratch lock-out'
  $r = Send 'POST' '/api/m/login' '{"identifier":"x"' $null $null
  Result ($r.Status -eq 400 -and $r.Json.message -eq 'Malformed JSON') 'malformed JSON -> 400 {"message":"Malformed JSON"}'

  # ---------------------------------------------------------------- rate limit: reset-password (unknown scratch identifier, nothing changes)
  $ghost = "ghost-$tag@fschool.vn"
  $codes = @()
  1..5 | ForEach-Object { $codes += (Send 'POST' '/api/m/reset-password' (@{ identifier = $ghost; newPassword = 'abcdef12' } | ConvertTo-Json -Compress) $null $null).Status }
  Result (($codes -join ',') -eq '404,404,404,404,404') "5 reset-password calls -> 404 User not found ($($codes -join ','))"
  $r = Send 'POST' '/api/m/reset-password' (@{ identifier = $ghost; newPassword = 'abcdef12' } | ConvertTo-Json -Compress) $null $null
  Result ($r.Status -eq 429 -and $r.Json.message -eq 'Too many attempts. Try again later.' -and $r.Headers['Retry-After']) '6th reset-password call -> 429 with Retry-After'
  $r = Send 'POST' '/api/m/reset-password' (@{ identifier = $ghost; newPassword = '123' } | ConvertTo-Json -Compress) $null $null
  Result ($r.Status -eq 400) 'validation errors are still 400 (not counted, not 429)'

  # ---------------------------------------------------------------- CORS
  $r = Send 'OPTIONS' '/api/m/login' $null $null @{ Origin = 'http://localhost:5555'; 'Access-Control-Request-Method' = 'POST'; 'Access-Control-Request-Headers' = 'authorization,content-type' }
  $allowH = [string]$r.Headers['Access-Control-Allow-Headers']
  Result ($r.Status -in 200, 204 -and $r.Headers['Access-Control-Allow-Origin'] -eq 'http://localhost:5555') 'preflight from an allowed origin -> 204 + Allow-Origin = that origin'
  Result ($allowH -match 'Authorization' -and $allowH -match 'Content-Type') "preflight allows Authorization and Content-Type ($allowH)"
  Result ($r.Headers['Access-Control-Allow-Origin'] -ne '*') 'never "*"'
  $r = Send 'OPTIONS' '/api/m/login' $null $null @{ Origin = 'http://evil.example'; 'Access-Control-Request-Method' = 'POST' }
  Result (-not $r.Headers['Access-Control-Allow-Origin'] -and $r.Status -ge 400) "preflight from a disallowed origin -> no Allow-Origin (status $($r.Status))"
  $r = Send 'GET' '/api/m/health' $null $null @{ Origin = 'http://evil.example' }
  Result ($r.Status -eq 200 -and -not $r.Headers['Access-Control-Allow-Origin']) 'simple request from a disallowed origin gets no Allow-Origin'
  $r = Send 'GET' '/api/m/health' $null $null @{ Origin = 'http://localhost:8090' }
  Result ($r.Headers['Access-Control-Allow-Origin'] -eq 'http://localhost:8090') 'simple request from an allowed origin gets that origin'

  # ---------------------------------------------------------------- the portal API is unchanged
  $r = Send 'GET' '/api/students' $null $null $null
  Result ($r.Status -eq 401) 'portal /api/students still needs the portal login (401)'
  Result (-not (([string]$r.Headers['Cache-Control']) -match 'no-store')) 'portal responses do not get the mobile cache headers'
}
finally {
  if ($reqId -gt 0) { Sql "DELETE FROM dbo.Requests WHERE reason = N'ZZ-SMOKE-$tag'" | Out-Null }
  if ($scratchId -gt 0) { Sql "DELETE FROM dbo.Users WHERE id = $scratchId" | Out-Null }
  $left = Sql "SELECT (SELECT COUNT(*) FROM dbo.Users WHERE email LIKE 'zz-smoke-%') + (SELECT COUNT(*) FROM dbo.Requests WHERE reason LIKE N'ZZ-SMOKE-%')"
  Write-Host "scratch rows left: $left"
}
if ($script:fail -gt 0) { Write-Host "$($script:fail) check(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'ALL MOBILE SMOKE CHECKS PASSED' -ForegroundColor Green
exit 0
