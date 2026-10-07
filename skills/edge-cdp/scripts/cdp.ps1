param(
  [string]$Url = 'about:blank',
  [int]$Port = 9222,
  [int]$WaitSeconds = 10,
  [int]$MaxChars = 3000
)

$ErrorActionPreference = 'Stop'

# find a Chromium browser
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

$argList = @(
  "--remote-debugging-port=$Port",
  "--user-data-dir=$profile",
  '--no-first-run',
  '--no-default-browser-check',
  '--window-size=1280,900',
  'about:blank'
)
Start-Process -FilePath $exe -ArgumentList $argList | Out-Null

$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  try { Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 3 | Out-Null; $ok = $true; break } catch { Start-Sleep -Milliseconds 700 }
}
if (-not $ok) { Write-Output 'DEBUG PORT DID NOT OPEN'; exit 1 }
Write-Output "debug port up on $Port"

$targets = ((Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/list" -UseBasicParsing -TimeoutSec 10).Content | ConvertFrom-Json)
$page = $targets | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
if (-not $page) { Write-Output 'NO PAGE TARGET'; exit 1 }
Write-Output ("attaching to: " + $page.url)
$wsUrl = $page.webSocketDebuggerUrl

$ws = New-Object System.Net.WebSockets.ClientWebSocket
$ct = [System.Threading.CancellationToken]::None
$ws.ConnectAsync([Uri]$wsUrl, $ct).GetAwaiter().GetResult()
Write-Output 'ws connected'

$script:msgId = 0
function Send-Cdp([string]$method, $params) {
  $script:msgId++
  $payload = @{ id = $script:msgId; method = $method; params = $params } | ConvertTo-Json -Depth 10 -Compress
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

Send-Cdp 'Page.enable' @{} | Out-Null
Send-Cdp 'Runtime.enable' @{} | Out-Null
Send-Cdp 'Page.navigate' @{ url = $Url } | Out-Null
Write-Output "navigated: $Url"
Start-Sleep -Seconds $WaitSeconds

$expr = 'document.title + " ||| " + document.body.innerText'
$evalId = Send-Cdp 'Runtime.evaluate' @{ expression = $expr; returnByValue = $true }
$r = Wait-Cdp $evalId 20000
if ($r -and $r.result -and $r.result.result -and $r.result.result.value) {
  $v = [string]$r.result.result.value
  Write-Output '--- page text ---'
  Write-Output $v.Substring(0, [Math]::Min($MaxChars, $v.Length))
} else {
  Write-Output 'eval returned nothing'
  if ($r) { $r | ConvertTo-Json -Depth 6 }
}
try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', $ct).GetAwaiter().GetResult() | Out-Null } catch { }
