$files = Get-ChildItem -Filter "*UI.gd"
foreach ($f in $files) {
    $c = Get-Content $f.FullName
    $c = $c -replace 'main_node\.complete_task\(\)', 'main_node.finish_player_task(self)'
    Set-Content -Path $f.FullName -Value $c
}
