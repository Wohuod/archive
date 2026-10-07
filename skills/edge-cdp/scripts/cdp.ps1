param(
  [string]$Url = 'about:blank',
  [int]$Port = 9222,
  [int]$WaitSeconds = 10,
  [int]$MaxChars = 3000,
  [switch]$KeepBlank
)

$ErrorActionPreference = 'Stop'

function Get-Json([string]$path) {
  return ((Invoke-WebRequest -Uri "http://127.0.0.1:$Port$path" -UseBasicParsing -TimeoutSec 10).Content | ConvertFrom-Json)
}

# --- 1. make sure a debug browser is running; reuse it if it already is ---
$up = $false
try { Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 3 | Out-Null; $up = $true } catch { }

if (-not $up) {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
  )
  $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $exe) { Write-Output 'NO CHROMIUM BROWSER FOUND'; exit 1 }

  $profile = Join-Path $env:TEMP 'edge-cdp-profile'
  if (-not (Test-Path -LiteralPath $profile)) { New-Item -ItemType Directory -Path $profile | Out-Null }

  Start-Process -FilePath $exe -ArgumentList @(
    "--remote-debugging-port=$Port",
    "--user-data-dir=$profile",
    '--no-first-run',
    '--no-default-browser-check',
    '--window-size=1280,900'
  ) | Out-Null

  for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 3 | Out-Null; $up = $true; break } catch { Start-Sleep -Milliseconds 700 }
  }
  if (-not $up) { Write-Output 'DEBUG PORT DID NOT OPEN'; exit 1 }
  Write-Output "started browser, debug port up on $Port"
} else {
  Write-Output "reusing running browser on $Port"
}

# --- 2. attach at the BROWSER level, then to a page target with flatten.
#        Page-level sockets die when a site swaps its document; this does not. ---
$ver = Get-Json '/json/version'
$browserWs = $ver.webSocketDebuggerUrl
if (-not $browserWs) { Write-Output 'NO BROWSER WEBSOCKET'; exit 1 }

$targets = Get-Json '/json/list'
$page = $targets | Where-Object { $_.type -eq 'page' -and $_.url -ne 'about:blank' } | Select-Object -First 1
if (-not $page) { $page = $targets | Where-Object { $_.type -eq 'page' } | Select-Object -First 1 }
if (-not $page) { Write-Output 'NO PAGE TARGET'; exit 1 }
Write-Output ("attaching to: " + $page.url)
$targetId = $page.id

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ct = [System.Threading.CancellationToken]::None
$ws.ConnectAsync([Uri]$browserWs, $ct).GetAwaiter().GetResult() | Out-Null
Write-Output 'browser socket connected'

$script:msgId = 0
function Send-Cdp {
  param([string]$method, $params = @{}, [string]$sessionId = '')
  $script:msgId++
  $m = @{ id = $script:msgId; method = $method; params = $params }
  if ($sessionId -ne '') { $m['sessionId'] = $sessionId }
  $payload = $m | ConvertTo-Json -Depth 10 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  $seg = New-Object 'System.ArraySegment[byte]' -ArgumentList (,$bytes)
  $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult() | Out-Null
  return $script:msgId
}
function Receive-Msg([int]$timeoutMs) {
  $buf = New-Object byte[] 2097152
  $seg = New-Object 'System.ArraySegment[byte]' -ArgumentList (,$buf)
  $cts = New-Object System.Threading.CancellationTokenSource
  $cts.CancelAfter($timeoutMs)
  try { $res = $ws.ReceiveAsync($seg, $cts.Token).GetAwaiter().GetResult() } catch { return $null }
  if ($res.Count -gt 0) { return [System.Text.Encoding]::UTF8.GetString($buf, 0, $res.Count) }
  return $null
}
function Wait-Cdp([int]$wantId, [int]$timeoutMs) {
  $deadline = (Get-Date).AddMilliseconds($timeoutMs)
  while ((Get-Date) -lt $deadline) {
    $m = Receive-Msg 3000
    if (-not $m) { continue }
    try { $o = $m | ConvertFrom-Json } catch { continue }
    if ($o.id -eq $wantId) { return $o }
  }
  return $null
}

$attachId = Send-Cdp -method 'Target.attachToTarget' -params @{ targetId = $targetId; flatten = $true }
$ar = Wait-Cdp $attachId 20000
if (-not $ar -or -not $ar.result -or -not $ar.result.sessionId) {
  Write-Output 'ATTACH FAILED'
  if ($ar) { $ar | ConvertTo-Json -Depth 6 }
  exit 1
}
$sid = $ar.result.sessionId
Write-Output "attached (session $sid)"

Send-Cdp -method 'Page.enable'    -sessionId $sid | Out-Null
Send-Cdp -method 'Runtime.enable' -sessionId $sid | Out-Null
Send-Cdp -method 'Page.navigate' -params @{ url = $Url } -sessionId $sid | Out-Null
Write-Output "navigated: $Url"
Start-Sleep -Seconds $WaitSeconds

# --- 3. read; retry, because a cross-document navigation briefly kills the context ---
$expr = 'location.href + " ||| " + document.title + " ||| " + document.body.innerText'
$v = $null
for ($attempt = 1; $attempt -le 4; $attempt++) {
  $evalId = Send-Cdp -method 'Runtime.evaluate' -params @{ expression = $expr; returnByValue = $true } -sessionId $sid
  $r = Wait-Cdp $evalId 20000
  if ($r -and $r.result -and $r.result.result -and $r.result.result.value) { $v = [string]$r.result.result.value; break }
  Write-Output ("read attempt $attempt returned nothing, retrying")
  Start-Sleep -Seconds 5
}

if ($v) {
  Write-Output '--- page text ---'
  Write-Output $v.Substring(0, [Math]::Min($MaxChars, $v.Length))
} else {
  Write-Output 'eval returned nothing after 4 attempts'
}
try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', $ct).GetAwaiter().GetResult() | Out-Null } catch { }

# --- 4. drop the blank tabs we left behind ---
if (-not $KeepBlank) {
  try {
    foreach ($b in (Get-Json '/json/list' | Where-Object { $_.type -eq 'page' -and $_.url -eq 'about:blank' })) {
      Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/close/$($b.id)" -UseBasicParsing -TimeoutSec 5 | Out-Null
      Write-Output ("closed blank tab: " + $b.id)
    }
  } catch { }
}
