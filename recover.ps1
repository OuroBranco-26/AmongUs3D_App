$transcript_path = "C:\Users\kiabo\.gemini\antigravity\brain\d2fd5741-f700-448e-80b9-08fd027898e7\.system_generated\logs\transcript_full.jsonl"
$content = Get-Content -Path $transcript_path -Raw
# Find the specific diff block
$start_idx = $content.LastIndexOf('@@ -132,612 +132,6 @@')
if ($start_idx -eq -1) { Write-Host "Diff block not found"; exit }

$end_idx = $content.IndexOf('[diff_block_end]', $start_idx)
if ($end_idx -eq -1) { Write-Host "Diff block end not found"; exit }

$diff_text = $content.Substring($start_idx, $end_idx - $start_idx)
# Decode JSON newlines
$diff_text = $diff_text -replace '\\n', "
"
$diff_text = $diff_text -replace '\\t', "	"
$diff_text = $diff_text -replace '\\"', '"'

$lines = $diff_text -split "
"
$recovered = @()

foreach ($line in $lines) {
    if ($line -match '@@ -132,612 \+132,6 @@') { continue }
    if ($line.StartsWith('-')) {
        $recovered += $line.Substring(1)
    } elseif ($line.StartsWith(' ')) {
        $recovered += $line.Substring(1)
    }
}

Set-Content -Path recovered.gd -Value $recovered -Encoding UTF8
Write-Host ("Recovered " + $recovered.Count + " lines!")
