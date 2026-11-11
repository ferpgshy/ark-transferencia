# Atualiza o pacote com os arquivos atuais deste PC (rodar no PC de ORIGEM)
. (Join-Path $PSScriptRoot 'common.ps1')

try {
    $pacote = Split-Path $PSScriptRoot -Parent
    $dados  = Join-Path $pacote 'dados'

    Write-Titulo 'Atualizar pacote com os mundos deste PC'
    Assert-ArkFechado
    $asa      = Select-AsaRoot
    $saved    = Join-Path $asa 'ShooterGame\Saved'
    $modsBase = Join-Path $asa 'ShooterGame\Binaries\Win64\ShooterGame'
    $modsDir  = Join-Path $modsBase 'Mods\83374'

    if (-not (Test-Path -LiteralPath (Join-Path $saved 'SavedArksLocal'))) {
        throw "Nao achei '$saved\SavedArksLocal'. Esse PC tem algum mundo salvo?"
    }

    Write-Aviso 'A copia antiga dos mundos e configs dentro do pacote vai ser apagada e copiada de novo.'
    if (-not (Confirmar 'Continuar?')) { throw 'Cancelado.' }

    Write-Titulo 'Copiando mundos e configs pro pacote'
    foreach ($sub in $SavedSubpastas) {
        $src = Join-Path $saved $sub
        $dst = Join-Path $dados "Saved\$sub"
        if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
        if (Test-Path -LiteralPath $src) {
            Copy-Pasta $src $dst
            Write-Ok $sub
        }
    }

    # Mods (opcional, costuma ser varios GB)
    if (Test-Path -LiteralPath $modsDir) {
        Write-Titulo 'Mods'
        $gb = Get-TamanhoGB $modsDir
        Write-Host "A pasta de mods tem $gb GB."
        Write-Host 'Levar os mods junto evita baixar tudo de novo no outro PC, mas deixa o pacote bem maior.'
        if (Confirmar 'Incluir os mods no pacote?') {
            $dstMods = Join-Path $dados 'Mods\83374'
            if (Test-Path -LiteralPath $dstMods) { Remove-Item -LiteralPath $dstMods -Recurse -Force }
            Write-Host 'Copiando mods, pode demorar...'
            Copy-Pasta $modsDir $dstMods
            Write-Ok 'Mods'
            $mud = Join-Path $modsBase 'ModsUserData'
            $dstMud = Join-Path $dados 'ModsUserData'
            if (Test-Path -LiteralPath $dstMud) { Remove-Item -LiteralPath $dstMud -Recurse -Force }
            if (Test-Path -LiteralPath $mud) { Copy-Pasta $mud $dstMud; Write-Ok 'ModsUserData' }
        }
    }

    Write-ListaMods (Join-Path $dados 'Saved\Config\Windows\GameUserSettings.ini') $modsDir (Join-Path $pacote 'MODS_NECESSARIOS.txt')
    Write-Ok 'MODS_NECESSARIOS.txt atualizado'

    Write-Titulo 'Pronto'
    Write-Host "Pacote atualizado em: $pacote"
    Write-Host 'Agora copia essa pasta inteira (pendrive, HD externo, nuvem) pro outro PC e roda o INSTALAR.bat la.'
}
catch {
    Write-Erro $_.Exception.Message
}
