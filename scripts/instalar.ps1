# Instala os mundos, configs (e mods, se estiverem no pacote) no PC atual
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $pacote = Split-Path $PSScriptRoot -Parent
    $dados  = Join-Path $pacote 'dados'

    Write-Titulo 'Instalador de mundos do ARK Survival Ascended'

    $origemSaved = Join-Path $dados 'Saved'
    if (-not (Test-Path -LiteralPath (Join-Path $origemSaved 'SavedArksLocal'))) {
        throw "Nao achei 'dados\Saved\SavedArksLocal' dentro do pacote. Extraia o zip inteiro e rode o INSTALAR.bat de dentro da pasta."
    }

    Assert-ArkFechado
    $asa      = Select-AsaRoot
    $saved    = Join-Path $asa 'ShooterGame\Saved'
    $modsBase = Join-Path $asa 'ShooterGame\Binaries\Win64\ShooterGame'

    # Resumo do que tem no pacote
    Write-Titulo 'O que tem no pacote'
    Write-Host 'Mundos:'
    Get-ChildItem -LiteralPath (Join-Path $origemSaved 'SavedArksLocal') -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    foreach ($sub in $SavedSubpastas) {
        if ($sub -eq 'SavedArksLocal') { continue }
        if (Test-Path -LiteralPath (Join-Path $origemSaved $sub)) { Write-Host "Pasta: $sub" }
    }
    $pacoteMods     = Join-Path $dados 'Mods\83374'
    $pacoteModsUser = Join-Path $dados 'ModsUserData'
    $temMods = Test-Path -LiteralPath $pacoteMods
    if ($temMods) { Write-Host 'Mods: SIM (pasta de mods incluida)' } else { Write-Host 'Mods: NAO (vai ter que instalar pelo jogo, lista em MODS_NECESSARIOS.txt)' }

    Write-Host ''
    Write-Host "Destino: $saved"
    Write-Aviso 'Mundos e configs com o mesmo nome neste PC vao ser SUBSTITUIDOS. Antes eu faco backup de tudo.'
    if (-not (Confirmar 'Continuar?')) { throw 'Cancelado.' }

    # Backup do que já existe aqui
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $bk = Join-Path $saved "_BACKUP_antes_da_transferencia_$stamp"
    $fezBackup = $false
    Write-Titulo 'Backup do que ja existe neste PC'
    foreach ($sub in $SavedSubpastas) {
        $src = Join-Path $saved $sub
        if (Test-Path -LiteralPath $src) {
            Copy-Pasta $src (Join-Path $bk $sub)
            Write-Ok "Backup: $sub"
            $fezBackup = $true
        }
    }
    $modsUserDestino = Join-Path $modsBase 'ModsUserData'
    if ($temMods -and (Test-Path -LiteralPath $modsUserDestino)) {
        Copy-Pasta $modsUserDestino (Join-Path $bk 'ModsUserData')
        Write-Ok 'Backup: ModsUserData'
        $fezBackup = $true
    }
    if ($fezBackup) { Write-Ok "Backup salvo em: $bk" } else { Write-Host 'Nada pra fazer backup (instalacao limpa).' }

    # Copia mundos e configs
    Write-Titulo 'Copiando mundos e configs'
    foreach ($sub in $SavedSubpastas) {
        $src = Join-Path $origemSaved $sub
        if (Test-Path -LiteralPath $src) {
            Copy-Pasta $src (Join-Path $saved $sub)
            Write-Ok $sub
        }
    }

    # Mods
    if ($temMods) {
        $gb = Get-TamanhoGB $pacoteMods
        if (Confirmar "Copiar os mods do pacote ($gb GB)?") {
            Write-Host 'Copiando mods, pode demorar...'
            Copy-Pasta $pacoteMods (Join-Path $modsBase 'Mods\83374')
            Write-Ok 'Mods'
            if (Test-Path -LiteralPath $pacoteModsUser) {
                Copy-Pasta $pacoteModsUser $modsUserDestino
                Write-Ok 'ModsUserData'
            }
        }
    }

    Write-Titulo 'Pronto'
    Write-Host '1. Abre o ARK. Se algum mod nao aparecer instalado, instala pelo menu de Mods do jogo (lista em MODS_NECESSARIOS.txt).'
    Write-Host '2. Hospeda o mundo normalmente (mesmo mapa) e confere se ta tudo la.'
    Write-Host '3. O GameUserSettings.ini veio com os graficos do outro PC. Se ficar pesado, ajusta nas configuracoes do jogo.'
    if ($fezBackup) { Write-Host "Se der ruim, o que tinha antes ta em: $bk" }
}
catch {
    Write-Erro $_.Exception.Message
}
