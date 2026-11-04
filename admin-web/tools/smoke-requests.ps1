# Smoke test for the Requests (Don tu) and Clubs (Cau lac bo) pages. Start the site first (use tools\locked.ps1).
# Usage (inside the lock): powershell -File tools\locked.ps1 -Cmd "run.ps1; smoke-requests.ps1; stop.ps1"
# Changes data temporarily (decides requests, scratch memberships, edits a club) and RESTORES everything at the end.
param([string]$BaseUrl = 'http://localhost:8088', [string]$Password = '123456')
$ErrorActionPreference = 'Continue'
$script:fail = 0
function Result($ok, $msg) { if ($ok) { Write-Host "[PASS] $msg" -ForegroundColor Green } else { Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:fail++ } }

function Sql($q) { $o = & sqlcmd -S 'localhost,1433' -E -C -I -d FSchoolDB -h -1 -W -Q "SET NOCOUNT ON; $q" 2>&1; return (($o | Out-String).Trim()) }
function SqlInt($q) { $v = Sql $q; $n = 0; if ([int]::TryParse(($v -split "\s+")[0], [ref]$n)) { return $n } else { Write-Host "[WARN] sql returned '$v' for $q"; return -1 } }

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
function Text($body) { return [Net.WebUtility]::HtmlDecode($body) }

function Do-Login($identifier) {
  $jar = New-Object System.Net.CookieContainer
  $g = Get-Page 'Login.aspx' $jar
  $form = @{ '__VIEWSTATE' = (Field $g.Body '__VIEWSTATE'); '__VIEWSTATEGENERATOR' = (Field $g.Body '__VIEWSTATEGENERATOR'); '__EVENTVALIDATION' = (Field $g.Body '__EVENTVALIDATION')
             'txtIdentifier' = $identifier; 'txtPassword' = $Password; 'btnLogin' = 'Đăng nhập' }
  $r = Send-Http 'POST' 'Login.aspx' $jar $form
  if ($r.Status -ne 302) { Write-Host "[WARN] login $identifier -> $($r.Status)" }
  return $jar
}

# Postback of a page: hidden fields from $page + extra fields. $target = LinkButton unique id (adds __EVENTTARGET).
function Post-Page($path, $jar, $page, $extra, $target) {
  $form = @{ '__VIEWSTATE' = (Field $page '__VIEWSTATE'); '__VIEWSTATEGENERATOR' = (Field $page '__VIEWSTATEGENERATOR'); '__EVENTVALIDATION' = (Field $page '__EVENTVALIDATION')
             '__EVENTTARGET' = $target; '__EVENTARGUMENT' = '' }
  foreach ($k in $extra.Keys) { $form[$k] = $extra[$k] }
  return Send-Http 'POST' $path $jar $form
}
# All unique ids used in __doPostBack('...') calls of the page, in document order.
function Targets($body) { return @([regex]::Matches($body, "__doPostBack\((?:&#39;|')([^&',]+)(?:&#39;|')") | ForEach-Object { $_.Groups[1].Value }) }
function Input-Name($body, $suffix) { if ($body -match "name=`"([^`"]*$suffix)`"") { return $Matches[1] } else { return $null } }
function Input-Value($body, $suffix) {
  $n = Input-Name $body $suffix; if (-not $n) { return '' }
  $m = [regex]::Match($body, "<textarea[^>]*name=`"$([regex]::Escape($n))`"[^>]*>(.*?)</textarea>", 'Singleline')
  if ($m.Success) { return [Net.WebUtility]::HtmlDecode($m.Groups[1].Value) }
  return (Field $body ([regex]::Escape($n)))
}

# ---------------------------------------------------------------- setup
$mgr = Do-Login 'manager@fschool.vn'
$gv = Do-Login 'gv@fschool.vn'
$gv2 = Do-Login 'gv2@fschool.vn'
$gvId = SqlInt "SELECT id FROM dbo.Users WHERE email='gv@fschool.vn'"
$gv2Id = SqlInt "SELECT id FROM dbo.Users WHERE email='gv2@fschool.vn'"
$mgrId = SqlInt "SELECT id FROM dbo.Users WHERE email='manager@fschool.vn'"
Result ($gvId -gt 0 -and $gv2Id -gt 0 -and $mgrId -gt 0) "accounts found (gv=$gvId gv2=$gv2Id manager=$mgrId)"

$touchedRequests = @(); $scratchClub = 0
$clubSnapshot = $null
try {
  # ------------------------------------------------------------ navigation + dashboard
  $d = Get-Page 'Default.aspx' $mgr
  Result ($d.Status -eq 200 -and -not (Has-Error $d.Body)) 'Default.aspx renders (manager)'
  Result ($d.Body -match 'href="ListRequest\.aspx"' -and $d.Body -match 'href="ListClub\.aspx"') 'navbar has Đơn từ and Câu lạc bộ links'
  Result ($d.Body -match 'ListRequest\.aspx\?status=pending') 'dashboard links to ListRequest?status=pending'
  Result ((Text $d.Body) -match 'ĐƠN CHỜ DUYỆT' -and (Text $d.Body) -match 'YÊU CẦU VÀO CLB CHỜ DUYỆT') 'dashboard shows both pending cards'
  $pendAll = SqlInt "SELECT COUNT(*) FROM dbo.Requests r JOIN dbo.Users s ON s.id=r.studentId WHERE r.status='pending' AND s.role='HS'"
  Result ($d.Body -match "text-danger`">$pendAll</h2>") "manager dashboard pending requests = $pendAll"
  $dg = Get-Page 'Default.aspx' $gv
  Result ($dg.Body -notmatch 'nav-link[^>]*href="ImportData\.aspx"') 'GV navbar hides Import'
  $lr0 = Get-Page 'ListRequest.aspx' $mgr
  Result ($lr0.Body -match "nav-link active' href=`"ListRequest\.aspx`"" -or $lr0.Body -match 'nav-link active" href="ListRequest\.aspx"') 'ListRequest nav link is highlighted'
  $anon = Get-Page 'ListRequest.aspx' (New-Object System.Net.CookieContainer)
  Result ($anon.Status -eq 302 -and "$($anon.Location)" -match 'Login') 'anonymous ListRequest -> login'

  # ------------------------------------------------------------ request lists
  $allCount = SqlInt "SELECT COUNT(*) FROM dbo.Requests r JOIN dbo.Users s ON s.id=r.studentId WHERE s.role='HS'"
  $rm = Get-Page 'ListRequest.aspx' $mgr
  $cm = ([regex]::Matches($rm.Body, 'ViewRequest\.aspx\?id=\d+')).Count
  Result ($rm.Status -eq 200 -and -not (Has-Error $rm.Body) -and $cm -eq $allCount -and $cm -ge 4) "manager sees all requests ($cm of $allCount)"
  Result ((Text $rm.Body) -match 'Xin nghỉ học') "manager list shows 'Xin nghỉ học'"
  $hsName = Sql "SELECT name FROM dbo.Users WHERE email='hs@fschool.vn'"
  Result ((Text $rm.Body) -match 'Chờ duyệt' -and (Text $rm.Body) -match 'Đã duyệt' -and (Text $rm.Body) -match 'Từ chối') 'status badges in Vietnamese'

  $scopeSql = { param($tid) "SELECT COUNT(*) FROM dbo.Requests r JOIN dbo.Users s ON s.id=r.studentId WHERE s.role='HS' AND s.className IN (SELECT className FROM dbo.Schedule WHERE teacherId=$tid)" }
  foreach ($t in @(@('gv', $gv, $gvId), @('gv2', $gv2, $gv2Id))) {
    $exp = SqlInt (& $scopeSql $t[2])
    $rr = Get-Page 'ListRequest.aspx' $t[1]
    $c = ([regex]::Matches($rr.Body, 'ViewRequest\.aspx\?id=\d+')).Count
    Result ($rr.Status -eq 200 -and $c -eq $exp) "$($t[0]) sees exactly the requests of students in taught classes ($c, expected $exp)"
    # invisible request -> friendly not-found
    $hidden = SqlInt "SELECT TOP 1 r.id FROM dbo.Requests r JOIN dbo.Users s ON s.id=r.studentId WHERE NOT (s.role='HS' AND s.className IN (SELECT className FROM dbo.Schedule WHERE teacherId=$($t[2]))) ORDER BY r.id"
    if ($hidden -gt 0) {
      $hv = Get-Page "ViewRequest.aspx?id=$hidden" $t[1]
      Result ($hv.Status -eq 200 -and (Text $hv.Body) -match 'Không tìm thấy đơn từ' -and (Text $hv.Body) -notmatch 'btnApprove') "$($t[0]) cannot open invisible request $hidden"
    } else { Write-Host "[INFO] $($t[0]) sees every request; no hidden request to test" }
  }
  $fp = Get-Page 'ListRequest.aspx?status=pending' $mgr
  $pc = ([regex]::Matches($fp.Body, 'ViewRequest\.aspx\?id=\d+')).Count
  Result ($pc -eq $pendAll) "status=pending filter shows $pc pending requests"
  $fr = Get-Page 'ListRequest.aspx?status=bogus&type=zzz&q=%27%3B--' $mgr
  Result ($fr.Status -eq 200 -and -not (Has-Error $fr.Body)) 'bad filter values do not crash'
  # search + type through postback
  $stName = Input-Name $lr0.Body 'ddlStatus'; $tyName = Input-Name $lr0.Body 'ddlType'; $qName = Input-Name $lr0.Body 'txtSearch'
  $sr = Post-Page 'ListRequest.aspx' $mgr $lr0.Body @{ $stName = 'ALL'; $tyName = 'Xin phép đi trễ'; $qName = '' } $stName
  $sc = ([regex]::Matches($sr.Body, 'ViewRequest\.aspx\?id=\d+')).Count
  $expT = SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE type LIKE N'Xin ph_p _i tr_'"
  Result ($sr.Status -eq 200 -and $sc -eq $expT) "type filter works ($sc, expected $expT)"
  $sr2 = Post-Page 'ListRequest.aspx' $mgr $lr0.Body @{ $stName = 'ALL'; $tyName = 'ALL'; $qName = 'zzzz-no-such-student' } ((Targets $lr0.Body) | Where-Object { $_ -like '*btnSearch' } | Select-Object -First 1)
  Result ($sr2.Status -eq 200 -and (Text $sr2.Body) -match 'Không có đơn nào') 'empty search shows friendly message'

  # ------------------------------------------------------------ bad ids
  foreach ($bad in 'ViewRequest.aspx', 'ViewRequest.aspx?id=abc', 'ViewRequest.aspx?id=999999', 'ViewRequest.aspx?id=-5', 'ViewClub.aspx', 'ViewClub.aspx?id=xyz', 'ViewClub.aspx?id=999999') {
    $b = Get-Page $bad $mgr
    Result ($b.Status -eq 200 -and -not (Has-Error $b.Body) -and (Text $b.Body) -match 'Không tìm thấy') "$bad -> friendly not-found"
  }
  $nb = Get-Page 'ViewClub.aspx?new=1' $gv
  Result ($nb.Status -eq 302 -and "$($nb.Location)" -match 'ListClub') 'GV cannot open ViewClub?new=1'

  # ------------------------------------------------------------ decide a request
  $ids = @((Sql "SELECT r.id FROM dbo.Requests r JOIN dbo.Users s ON s.id=r.studentId WHERE r.status='pending' AND s.role='HS' AND s.className IN (SELECT className FROM dbo.Schedule WHERE teacherId=$gvId) ORDER BY r.id") -split "\s+" | Where-Object { $_ -match '^\d+$' })
  Result ($ids.Count -ge 2) "found $($ids.Count) pending requests visible to gv"
  if ($ids.Count -ge 2) {
    $rA = [int]$ids[0]; $rB = [int]$ids[1]
    $touchedRequests = @($rA, $rB)
    $pg = Get-Page "ViewRequest.aspx?id=$rA" $gv
    $tApprove = (Targets $pg.Body) | Where-Object { $_ -like '*btnApprove' } | Select-Object -First 1
    $tReject = (Targets $pg.Body) | Where-Object { $_ -like '*btnReject' } | Select-Object -First 1
    $cName = Input-Name $pg.Body 'txtComment'
    Result ($tApprove -and $tReject -and $cName) 'pending request page has comment box and Duyệt/Từ chối buttons'

    # comment too long -> refused, stays pending
    $long = 'x' * 501
    $lg = Post-Page "ViewRequest.aspx?id=$rA" $gv $pg.Body @{ $cName = $long } $tApprove
    Result ($lg.Status -eq 200 -and (Text $lg.Body) -match 'tối đa 500' -and (SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE id=$rA AND status='pending'") -eq 1) '501-char comment rejected, request still pending'

    # approve with a comment
    $ap = Post-Page "ViewRequest.aspx?id=$rA" $gv $pg.Body @{ $cName = 'Smoke test: dong y' } $tApprove
    Result ($ap.Status -eq 302 -and "$($ap.Location)" -match 'msg=approved') "approve -> redirect ($($ap.Status) $($ap.Location))"
    $okRow = SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE id=$rA AND status='approved' AND teacherComment=N'Smoke test: dong y' AND handledBy=$gvId AND handledAt IS NOT NULL"
    Result ($okRow -eq 1) 'DB: status approved, comment and handler stored, handledAt set'
    $after = Get-Page "ViewRequest.aspx?id=$rA&msg=approved" $gv
    Result ((Text $after.Body) -match 'Đã duyệt' -and (Text $after.Body) -match 'Smoke test: dong y' -and $after.Body -notmatch 'btnApprove') 'page now shows result and no decision form'

    # second decision with the stale form (double click) and by manager must be refused
    $again = Post-Page "ViewRequest.aspx?id=$rA" $gv $pg.Body @{ $cName = 'second try' } $tReject
    Result ($again.Status -eq 302 -and "$($again.Location)" -match 'msg=already') 'second decision (stale form) refused'
    $a2 = Get-Page "ViewRequest.aspx?id=$rA&msg=already" $mgr
    Result ((Text $a2.Body) -match 'đã được xử lý trước đó') 'friendly "already handled" message'
    Result ((SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE id=$rA AND status='approved' AND teacherComment=N'Smoke test: dong y' AND handledBy=$gvId") -eq 1) 'DB unchanged after the refused second decision'

    # reject request B as manager (no comment)
    $pgB = Get-Page "ViewRequest.aspx?id=$rB" $mgr
    $tRejB = (Targets $pgB.Body) | Where-Object { $_ -like '*btnReject' } | Select-Object -First 1
    $cB = Input-Name $pgB.Body 'txtComment'
    $rj = Post-Page "ViewRequest.aspx?id=$rB" $mgr $pgB.Body @{ $cB = '' } $tRejB
    Result ($rj.Status -eq 302 -and "$($rj.Location)" -match 'msg=rejected') 'manager rejects request'
    Result ((SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE id=$rB AND status='rejected' AND teacherComment IS NULL AND handledBy=$mgrId AND handledAt IS NOT NULL") -eq 1) 'DB: rejected with NULL comment, handler = manager'
    $lp = Get-Page 'ListRequest.aspx?status=approved' $gv
    Result ((Text $lp.Body) -match "ViewRequest\.aspx\?id=$rA") 'approved request appears in the approved filter'
  }

  # ------------------------------------------------------------ clubs
  $clubCount = SqlInt "SELECT COUNT(*) FROM dbo.Clubs"
  $lc = Get-Page 'ListClub.aspx' $mgr
  $cc = ([regex]::Matches($lc.Body, 'ViewClub\.aspx\?id=\d+')).Count
  Result ($lc.Status -eq 200 -and -not (Has-Error $lc.Body) -and $cc -eq $clubCount -and (Text $lc.Body) -match 'CLB Lập trình') "ListClub shows $cc clubs"
  Result ($lc.Body -match '>56<') 'Lập trình member count 56 shown'
  Result ($lc.Body -match 'ViewClub\.aspx\?new=1') 'manager sees "Thêm CLB"'
  $lcg = Get-Page 'ListClub.aspx' $gv
  Result ($lcg.Status -eq 200 -and $lcg.Body -notmatch 'ViewClub\.aspx\?new=1') 'GV does not see "Thêm CLB"'

  $clubA = SqlInt "SELECT id FROM dbo.Clubs WHERE name LIKE N'CLB M_ thu_t'"
  $clubB = SqlInt "SELECT id FROM dbo.Clubs WHERE name LIKE N'CLB B_ng r_'"
  $hs2 = SqlInt "SELECT id FROM dbo.Users WHERE email='hs2@fschool.vn'"
  $scratch = @($clubA, $clubB)
  Sql "DELETE FROM dbo.ClubMembers WHERE userId=$hs2 AND clubId IN ($clubA,$clubB); INSERT dbo.ClubMembers(clubId,userId,status) VALUES ($clubA,$hs2,'pending'),($clubB,$hs2,'pending')" | Out-Null
  $cntBefore = SqlInt "SELECT baseMembers + (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId=c.id AND m.status='approved') FROM dbo.Clubs c WHERE c.id=$clubA"
  $va = Get-Page "ViewClub.aspx?id=$clubA" $mgr
  Result ($va.Status -eq 200 -and (Text $va.Body) -match 'Chờ duyệt' -and (Targets $va.Body).Count -ge 2) 'club page lists the pending member with Duyệt/Từ chối'
  $rt = (Targets $va.Body) | Where-Object { $_ -like '*rptMembers*' }
  $ar = Post-Page "ViewClub.aspx?id=$clubA" $mgr $va.Body @{} $rt[0]
  Result ($ar.Status -eq 302 -and "$($ar.Location)" -match 'msg=approved') 'manager approves membership'
  Result ((SqlInt "SELECT COUNT(*) FROM dbo.ClubMembers WHERE clubId=$clubA AND userId=$hs2 AND status='approved'") -eq 1) 'DB: membership approved'
  $cntAfter = SqlInt "SELECT baseMembers + (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId=c.id AND m.status='approved') FROM dbo.Clubs c WHERE c.id=$clubA"
  Result ($cntAfter -eq $cntBefore + 1) "member count went $cntBefore -> $cntAfter"
  $again2 = Post-Page "ViewClub.aspx?id=$clubA" $mgr $va.Body @{} $rt[0]
  Result ($again2.Status -eq 302 -and "$($again2.Location)" -match 'msg=gone') 'approving twice is refused gracefully'
  $rej0 = Post-Page "ViewClub.aspx?id=$clubA" $mgr $va.Body @{} $rt[1]
  Result ((SqlInt "SELECT COUNT(*) FROM dbo.ClubMembers WHERE clubId=$clubA AND userId=$hs2 AND status='approved'") -eq 1) 'reject of an already approved row does not delete it'

  $vb = Get-Page "ViewClub.aspx?id=$clubB" $gv
  $rtb = (Targets $vb.Body) | Where-Object { $_ -like '*rptMembers*' }
  Result ($vb.Status -eq 200 -and $rtb.Count -ge 2 -and $vb.Body -notmatch 'txtName') 'GV sees pending member buttons but no edit form'
  $rjb = Post-Page "ViewClub.aspx?id=$clubB" $gv $vb.Body @{} $rtb[1]
  Result ($rjb.Status -eq 302 -and "$($rjb.Location)" -match 'msg=rejected') 'GV rejects membership'
  Result ((SqlInt "SELECT COUNT(*) FROM dbo.ClubMembers WHERE clubId=$clubB AND userId=$hs2") -eq 0) 'DB: rejected pending row removed'
  Sql "DELETE FROM dbo.ClubMembers WHERE userId=$hs2 AND clubId IN ($clubA,$clubB)" | Out-Null

  # edit a club (manager) and revert
  $clubSnapshot = Sql "SELECT CHECKSUM(name,icon,description,meeting,location,advisor,president,baseMembers) FROM dbo.Clubs WHERE id=$clubA"
  $ve = Get-Page "ViewClub.aspx?id=$clubA" $mgr
  $names = 'txtName', 'txtIcon', 'txtDescription', 'txtMeeting', 'txtLocation', 'txtAdvisor', 'txtPresident', 'txtBase'
  $vals = @{}; $form = @{}
  foreach ($n in $names) { $vals[$n] = Input-Value $ve.Body $n; $form[(Input-Name $ve.Body $n)] = $vals[$n] }
  $saveT = (Targets $ve.Body) | Where-Object { $_ -like '*btnSave' } | Select-Object -First 1
  $form2 = $form.Clone(); $form2[(Input-Name $ve.Body 'txtMeeting')] = 'SMOKE-MEETING'; $form2[(Input-Name $ve.Body 'txtBase')] = '77'
  $sv = Post-Page "ViewClub.aspx?id=$clubA" $mgr $ve.Body $form2 $saveT
  Result ($sv.Status -eq 302 -and "$($sv.Location)" -match 'msg=saved') 'manager saves club edit'
  Result ((SqlInt "SELECT COUNT(*) FROM dbo.Clubs WHERE id=$clubA AND meeting=N'SMOKE-MEETING' AND baseMembers=77") -eq 1) 'DB: club edit stored'
  # validation: empty name / bad number
  $form3 = $form.Clone(); $form3[(Input-Name $ve.Body 'txtName')] = ''
  $v3 = Post-Page "ViewClub.aspx?id=$clubA" $mgr $ve.Body $form3 $saveT
  Result ($v3.Status -eq 200 -and (Text $v3.Body) -match 'nhập tên') 'empty name rejected'
  $form4 = $form.Clone(); $form4[(Input-Name $ve.Body 'txtBase')] = 'abc'
  $v4 = Post-Page "ViewClub.aspx?id=$clubA" $mgr $ve.Body $form4 $saveT
  Result ($v4.Status -eq 200 -and (Text $v4.Body) -match 'số nguyên') 'non-numeric baseMembers rejected'
  # revert through the page itself
  $sv2 = Post-Page "ViewClub.aspx?id=$clubA" $mgr $ve.Body $form $saveT
  Result ($sv2.Status -eq 302) 'club edit reverted through the page'
  $chk = Sql "SELECT CHECKSUM(name,icon,description,meeting,location,advisor,president,baseMembers) FROM dbo.Clubs WHERE id=$clubA"
  Result ($chk -eq $clubSnapshot) 'DB: club fields identical to the original (checksum)'

  # create a club (manager only)
  $nv = Get-Page 'ViewClub.aspx?new=1' $mgr
  $nf = @{}; foreach ($n in $names) { $nf[(Input-Name $nv.Body $n)] = '' }
  $nf[(Input-Name $nv.Body 'txtName')] = 'ZZ Smoke Club'; $nf[(Input-Name $nv.Body 'txtBase')] = '3'
  $sT = (Targets $nv.Body) | Where-Object { $_ -like '*btnSave' } | Select-Object -First 1
  $cr = Post-Page 'ViewClub.aspx?new=1' $mgr $nv.Body $nf $sT
  Result ($cr.Status -eq 302 -and "$($cr.Location)" -match 'msg=created') 'manager creates a club'
  $scratchClub = SqlInt "SELECT id FROM dbo.Clubs WHERE name=N'ZZ Smoke Club'"
  Result ($scratchClub -gt 0) 'DB: new club exists'
  # ------------------------------------------------------------ visibility rule with a scratch student in a class nobody teaches
  $phId = SqlInt "SELECT id FROM dbo.Users WHERE email='ph@fschool.vn'"
  Sql "INSERT dbo.Users(name,email,phone,passwordHash,role,className) VALUES (N'ZZ Smoke Student','zz.smoke@fschool.vn','0999000111','x','HS',N'99Z9')" | Out-Null
  $zz = SqlInt "SELECT id FROM dbo.Users WHERE email='zz.smoke@fschool.vn'"
  Sql "INSERT dbo.Requests(studentId,createdBy,type,fromDate,toDate,reason) VALUES ($zz,$phId,N'Xin nghi hoc','2026-11-01','2026-11-01',N'smoke hidden')" | Out-Null
  $zr = SqlInt "SELECT id FROM dbo.Requests WHERE studentId=$zz"
  $hm = Get-Page "ViewRequest.aspx?id=$zr" $mgr
  Result ($hm.Status -eq 200 -and $hm.Body -match 'btnApprove') 'manager can open a request of any class'
  foreach ($t in @(@('gv', $gv), @('gv2', $gv2))) {
    $hg = Get-Page "ViewRequest.aspx?id=$zr" $t[1]
    Result ($hg.Status -eq 200 -and (Text $hg.Body) -match 'Không tìm thấy đơn từ' -and $hg.Body -notmatch 'btnApprove') "$($t[0]) cannot see a request of a class he/she does not teach"
    $hl = Get-Page 'ListRequest.aspx' $t[1]
    Result ($hl.Body -notmatch "ViewRequest\.aspx\?id=$zr`"") "$($t[0]) list excludes it"
    # forged decision attempt: use the manager's page form with the gv session
    $tA = (Targets $hm.Body) | Where-Object { $_ -like '*btnApprove' } | Select-Object -First 1
    $cN = Input-Name $hm.Body 'txtComment'
    $fg = Post-Page "ViewRequest.aspx?id=$zr" $t[1] $hm.Body @{ $cN = 'forged' } $tA
    Result ((SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE id=$zr AND status='pending'") -eq 1) "$($t[0]) forged decision on invisible request has no effect"
  }
} finally {
  # ------------------------------------------------------------ restore
  Sql "DELETE FROM dbo.Requests WHERE studentId IN (SELECT id FROM dbo.Users WHERE email='zz.smoke@fschool.vn'); DELETE FROM dbo.Users WHERE email='zz.smoke@fschool.vn'" | Out-Null
  if ($scratchClub -gt 0) { Sql "DELETE FROM dbo.ClubMembers WHERE clubId=$scratchClub; DELETE FROM dbo.Clubs WHERE id=$scratchClub" | Out-Null }
  Sql "DELETE FROM dbo.Clubs WHERE name=N'ZZ Smoke Club'" | Out-Null
  if ($hs2 -gt 0 -and $clubA -gt 0) { Sql "DELETE FROM dbo.ClubMembers WHERE userId=$hs2 AND clubId IN ($clubA,$clubB)" | Out-Null }
  foreach ($id in $touchedRequests) { Sql "UPDATE dbo.Requests SET status='pending', teacherComment=NULL, handledBy=NULL, handledAt=NULL WHERE id=$id" | Out-Null }
}

# ---------------------------------------------------------------- verify restore
Result ((SqlInt "SELECT COUNT(*) FROM dbo.Requests") -eq 4) 'restore: 4 requests'
Result ((SqlInt "SELECT COUNT(*) FROM dbo.Requests WHERE status='pending' AND teacherComment IS NULL AND handledBy IS NULL AND handledAt IS NULL") -eq 2) 'restore: 2 pending requests with NULL comment/handler/handledAt'
Result ((SqlInt "SELECT COUNT(*) FROM dbo.Clubs") -eq 5) 'restore: 5 clubs'
Result ((SqlInt "SELECT COUNT(*) FROM dbo.ClubMembers") -eq 2) 'restore: 2 memberships (hs approved/pending)'
Result ((SqlInt "SELECT baseMembers + (SELECT COUNT(*) FROM dbo.ClubMembers m WHERE m.clubId=c.id AND m.status='approved') FROM dbo.Clubs c WHERE name LIKE N'CLB L_p tr_nh'") -eq 56) 'restore: Lập trình memberCount 56'

if ($script:fail -eq 0) { Write-Host "SMOKE-REQUESTS OK" -ForegroundColor Green; exit 0 } else { Write-Host "SMOKE-REQUESTS: $($script:fail) check(s) failed" -ForegroundColor Red; exit 1 }
