# Funções compartilhadas pelos scripts de transferência do ARK Survival Ascended
$ErrorActionPreference = 'Stop'
$AsaFolderName = 'ARK Survival Ascended'
$SavedSubpastas = @('SavedArksLocal', 'Config\Windows', 'LocalProfiles', 'SaveGames')

function Write-Titulo([string]$t) { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Write-Ok([string]$t)     { Write-Host "[OK] $t" -ForegroundColor Green }
function Write-Aviso([string]$t)  { Write-Host "[!] $t" -ForegroundColor Yellow }
function Write-Erro([string]$t)   { Write-Host "[ERRO] $t" -ForegroundColor Red }

function Confirmar([string]$pergunta) {
    $r = Read-Host "$pergunta (S/N)"
    return ($r -match '^\s*[sSyY]')
}

function Limpar-Caminho([string]$p) {
    if ($null -eq $p) { return '' }
    $p = $p.Trim().Trim('"').Trim()
    if ($p.Length -gt 3) { $p = $p.TrimEnd('\') }
    return $p
}

# Uma pasta é do ASA se tiver ShooterGame\Binaries\Win64 dentro
function Test-AsaRoot([string]$p) {
    $p = Limpar-Caminho $p
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    try { return (Test-Path -LiteralPath (Join-Path $p 'ShooterGame\Binaries\Win64')) } catch { return $false }
}

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $regs = @(
        @{ Path = 'HKCU:\Software\Valve\Steam';             Name = 'SteamPath'   },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
        @{ Path = 'HKLM:\SOFTWARE\Valve\Steam';             Name = 'InstallPath' }
    )
    foreach ($r in $regs) {
        try {
            $v = (Get-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction Stop).($r.Name)
            if ($v) { $roots.Add((Limpar-Caminho ($v -replace '/', '\'))) }
        } catch { }
    }
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $pf   = [Environment]::GetEnvironmentVariable('ProgramFiles')
    if ($pf86) { $roots.Add((Join-Path $pf86 'Steam')) }
    if ($pf)   { $roots.Add((Join-Path $pf 'Steam')) }
    return @($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
}

# Lê todas as bibliotecas da Steam (libraryfolders.vdf), inclusive em outros HDs
function Get-SteamLibraries {
    $libs = New-Object System.Collections.Generic.List[string]
    foreach ($root in @(Get-SteamRoots)) {
        $libs.Add($root)
        $vdfs = @((Join-Path $root 'steamapps\libraryfolders.vdf'), (Join-Path $root 'config\libraryfolders.vdf'))
        foreach ($vdf in $vdfs) {
            if (-not (Test-Path -LiteralPath $vdf)) { continue }
            try { $txt = Get-Content -LiteralPath $vdf -Raw } catch { continue }
            # formato novo: "path"  "D:\\SteamLibrary"
            foreach ($m in [regex]::Matches($txt, '"path"\s+"([^"]+)"')) {
                $libs.Add((Limpar-Caminho ($m.Groups[1].Value -replace '\\\\', '\')))
            }
            # formato antigo: "1"  "D:\\SteamLibrary"
            foreach ($m in [regex]::Matches($txt, '"\d+"\s+"([A-Za-z]:\\\\[^"]*)"')) {
                $libs.Add((Limpar-Caminho ($m.Groups[1].Value -replace '\\\\', '\')))
            }
        }
    }
    return @($libs | Where-Object { $_ } | Select-Object -Unique)
}

function Find-AsaInstalls {
    $found = New-Object System.Collections.Generic.List[string]

    # 1) Bibliotecas da Steam
    foreach ($lib in @(Get-SteamLibraries)) {
        $c = Join-Path $lib "steamapps\common\$AsaFolderName"
        if (Test-AsaRoot $c) { $found.Add($c) }
    }

    # 2) Epic Games (manifestos do launcher)
    if ($env:ProgramData) {
        $epicDir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        if (Test-Path -LiteralPath $epicDir) {
            foreach ($f in @(Get-ChildItem -LiteralPath $epicDir -Filter '*.item' -ErrorAction SilentlyContinue)) {
                try {
                    $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
                    if ($j.InstallLocation -and (Test-AsaRoot $j.InstallLocation)) { $found.Add((Limpar-Caminho $j.InstallLocation)) }
                } catch { }
            }
        }
    }

    # 3) Caminhos comuns em todos os discos
    $rels = @(
        "SteamLibrary\steamapps\common\$AsaFolderName",
        "Steam\steamapps\common\$AsaFolderName",
        "Program Files (x86)\Steam\steamapps\common\$AsaFolderName",
        "Program Files\Steam\steamapps\common\$AsaFolderName",
        "Games\Steam\steamapps\common\$AsaFolderName",
        "Games\SteamLibrary\steamapps\common\$AsaFolderName",
        "Jogos\Steam\steamapps\common\$AsaFolderName",
        "Jogos\SteamLibrary\steamapps\common\$AsaFolderName",
        "Steam Library\steamapps\common\$AsaFolderName",
        "Program Files\Epic Games\ARKSurvivalAscended",
        "Epic Games\ARKSurvivalAscended"
    )
    foreach ($drv in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        foreach ($r in $rels) {
            try {
                $c = Join-Path $drv.Root $r
                if (Test-AsaRoot $c) { $found.Add($c) }
            } catch { }
        }
    }

    $norm = foreach ($p in $found) {
        try { Limpar-Caminho ((Resolve-Path -LiteralPath $p).ProviderPath) } catch { }
    }
    return @($norm | Where-Object { $_ } | Sort-Object -Unique)
}

function Select-AsaRoot {
    Write-Titulo 'Procurando o ARK Survival Ascended neste PC'
    $list = @(Find-AsaInstalls)
    if ($list.Count -eq 1) {
        Write-Ok "Achei em: $($list[0])"
        if (Confirmar 'Usar essa pasta?') { return $list[0] }
    } elseif ($list.Count -gt 1) {
        Write-Aviso 'Achei mais de uma instalacao:'
        for ($i = 0; $i -lt $list.Count; $i++) { Write-Host "  [$($i + 1)] $($list[$i])" }
        $r = Read-Host 'Digite o numero da que voce quer usar (ou so Enter pra digitar outro caminho)'
        $n = 0
        if ([int]::TryParse($r, [ref]$n) -and $n -ge 1 -and $n -le $list.Count) { return $list[$n - 1] }
    } else {
        Write-Aviso 'Nao achei o ARK automaticamente.'
    }
    while ($true) {
        Write-Host 'Cole o caminho da pasta "ARK Survival Ascended" (a que tem a pasta ShooterGame dentro).'
        $p = Read-Host 'Caminho (vazio = cancelar)'
        $p = Limpar-Caminho $p
        if ([string]::IsNullOrWhiteSpace($p)) { throw 'Cancelado.' }
        # aceita se a pessoa colar a ShooterGame ou a Saved por engano
        $leaf = Split-Path $p -Leaf
        if ($leaf -ieq 'Saved') { $p = Split-Path $p -Parent; $leaf = Split-Path $p -Leaf }
        if ($leaf -ieq 'ShooterGame') { $p = Split-Path $p -Parent }
        if (Test-AsaRoot $p) { return (Limpar-Caminho ((Resolve-Path -LiteralPath $p).ProviderPath)) }
        Write-Erro 'Essa pasta nao parece ser do ARK (nao tem ShooterGame\Binaries\Win64 dentro).'
    }
}

function Assert-ArkFechado {
    while ($true) {
        $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^ArkAscended' })
        if ($procs.Count -eq 0) { return }
        Write-Aviso 'O ARK esta aberto. Fecha o jogo por completo antes (ele reescreve os arquivos quando fecha).'
        [void](Read-Host 'Depois de fechar, aperta Enter')
    }
}

# Copia uma pasta inteira (mesclando com o que já existe no destino)
function Copy-Pasta([string]$origem, [string]$destino) {
    $origem  = Limpar-Caminho $origem
    $destino = Limpar-Caminho $destino
    if (-not (Test-Path -LiteralPath $origem)) { return }
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    $rc = Get-Command 'robocopy.exe' -ErrorAction SilentlyContinue
    if ($rc) {
        & robocopy.exe $origem $destino /E /COPY:DT /DCOPY:T /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Falha ao copiar '$origem' para '$destino' (robocopy codigo $LASTEXITCODE)" }
    } else {
        Copy-Item -Path (Join-Path $origem '*') -Destination $destino -Recurse -Force
    }
    # garante que nada ficou como somente leitura (o jogo precisa salvar por cima)
    Get-ChildItem -LiteralPath $destino -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $false }
}

function Get-TamanhoGB([string]$p) {
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    $s = (Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $s) { return 0 }
    return [math]::Round($s / 1GB, 2)
}

# Gera MODS_NECESSARIOS.txt a partir do ActiveMods do GameUserSettings.ini
function Write-ListaMods([string]$gusPath, [string]$modsDir, [string]$saida) {
    if (-not (Test-Path -LiteralPath $gusPath)) { return }
    $linha = Select-String -LiteralPath $gusPath -Pattern '^\s*ActiveMods=(.*)$' | Select-Object -First 1
    if (-not $linha) { return }
    $ids = @($linha.Matches[0].Groups[1].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' })
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('Mods ativos no mundo (ID  -  nome da pasta do mod).')
    $out.Add('No PC novo, instale todos pelo menu de Mods do proprio jogo, pesquisando pelo ID ou pelo nome.')
    $out.Add('')
    foreach ($id in $ids) {
        $nome = ''
        if ($modsDir -and (Test-Path -LiteralPath $modsDir)) {
            $pasta = Get-ChildItem -LiteralPath $modsDir -Directory -Filter "$($id)_*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pasta) {
                $sub = Get-ChildItem -LiteralPath $pasta.FullName -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($sub) { $nome = $sub.Name }
            }
        }
        $out.Add(("{0,-9} {1}" -f $id, $nome))
    }
    $out.Add('')
    $out.Add("Total: $($ids.Count) mods")
    Set-Content -LiteralPath $saida -Value $out -Encoding UTF8
}
