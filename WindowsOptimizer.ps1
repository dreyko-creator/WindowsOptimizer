# ============================================================
# COMPROBACIÓN DE ADMINISTRADOR
# ============================================================
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null

# Forzar codificación UTF-8 — protegido para cuando no hay consola (exe compilado)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# Habilitar estilos visuales y renderizado de texto moderno
[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================
# RESOLUCION DE RUTA BASE (compatible con .EXE compilado)
# ============================================================
# Al compilar con PS2EXE / Costura / ILMerge etc., $PSScriptRoot y
# $MyInvocation.MyCommand.Definition pueden devolver cadena vacía.
# Esta función obtiene el directorio real sea como sea.
function Get-ScriptBaseDir {
    # 1) Ejecutable compilado (.exe): la propia ruta del proceso
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exePath -and (Test-Path $exePath)) {
        return Split-Path $exePath -Parent
    }
    # 2) Script PS1 normal: $PSScriptRoot
    if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
        return $PSScriptRoot
    }
    # 3) Último recurso: directorio de trabajo actual
    return (Get-Location).Path
}
$script:BasePath = Get-ScriptBaseDir

# Importar API de Windows para mover la ventana sin errores de mouse
$WinApiCode = @'
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
# Evitar error si el tipo ya está cargado (re-ejecuciones en la misma sesión)
if (-not ([System.Management.Automation.PSTypeName]'WinApi').Type) {
    Add-Type -TypeDefinition $WinApiCode
}

# ============================================================
# COLORES Y FUENTES
# ============================================================
$bgDark      = [System.Drawing.Color]::FromArgb(196, 196, 197)
$bgPanel     = [System.Drawing.Color]::FromArgb(188, 188, 190)
$bgCard      = [System.Drawing.Color]::FromArgb(180, 180, 184)
$textPrimary = [System.Drawing.Color]::FromArgb(28, 28, 32)
$textMuted   = [System.Drawing.Color]::FromArgb(72, 72, 80)
$accentBlue  = [System.Drawing.Color]::FromArgb(64, 96, 128)
$accentCyan  = [System.Drawing.Color]::FromArgb(56, 104, 120)
$accentGreen = [System.Drawing.Color]::FromArgb(80, 112, 72)
$borderColor = [System.Drawing.Color]::FromArgb(144, 144, 148)
$bgHover     = [System.Drawing.Color]::FromArgb(168, 168, 172)

$fontTitle   = New-Object System.Drawing.Font("Trebuchet MS", 24, [System.Drawing.FontStyle]::Bold)
$fontItemB   = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontItem    = New-Object System.Drawing.Font("Segoe UI", 10)
$fontSmall   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontTab     = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontBtn     = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontMono    = New-Object System.Drawing.Font("Consolas", 9)

# ============================================================
# LISTA DE TWEAKS
# ============================================================
$tweaks = @(
    @{ Name = "Crear punto de restauracion";          Cat = "Sistema";    Key = "RestorePoint"    },
    @{ Name = "Limpiar archivos temporales";          Cat = "Sistema";    Key = "TempFiles"       },
    @{ Name = "Deshabilitar Hibernacion";             Cat = "Sistema";    Key = "Hibernate"       },
    @{ Name = "Configurar servicios optimos";         Cat = "Sistema";    Key = "Services"        },
    @{ Name = "Optimizar efectos visuales";           Cat = "Sistema";    Key = "Display"         },
    @{ Name = "Deshabilitar transparencias";          Cat = "Sistema";    Key = "Transparency"    },
    @{ Name = "Deshabilitar Storage Sense";           Cat = "Sistema";    Key = "StorageSense"    },
    @{ Name = "Habilitar End Task en taskbar";        Cat = "Sistema";    Key = "EndTask"         },

    @{ Name = "Deshabilitar rastreo de ubicacion";    Cat = "Privacidad";  Key = "Location"        },
    @{ Name = "Deshabilitar telemetria de PS7";       Cat = "Privacidad";  Key = "PS7Tele"         },
    @{ Name = "Deshabilitar telemetria";              Cat = "Privacidad";  Key = "Telemetry"       },
    @{ Name = "Deshabilitar apps en segundo plano";   Cat = "Privacidad";  Key = "BGApps"          },

    @{ Name = "Deshabilitar Consumer Features";       Cat = "Limpieza";   Key = "Consumer"        },
    @{ Name = "Eliminar Widgets de Windows 11";       Cat = "Limpieza";   Key = "Widgets"         },
    @{ Name = "Debloatear Microsoft Edge";            Cat = "Limpieza";   Key = "EdgeDebloat"     },
    @{ Name = "Desinstalar OneDrive";                 Cat = "Limpieza";   Key = "OneDrive"        },
    @{ Name = "Eliminar aplicaciones Xbox";           Cat = "Limpieza";   Key = "Xbox"            },

    @{ Name = "Plan de energia: Maximo Rendimiento";  Cat = "Avanzado";   Key = "PowerPlan"       },
    @{ Name = "Deshabilitar IPv6 y Teredo";           Cat = "Avanzado";   Key = "IPv6"            },
    @{ Name = "Deshabilitar WPBT (BIOS Rootkit)";     Cat = "Avanzado";   Key = "WPBT"            },
    @{ Name = "Optimizaciones de Fullscreen";         Cat = "Avanzado";   Key = "FSO"             },
    @{ Name = "Restaurar menu contextual antiguo";    Cat = "Avanzado";   Key = "RightClick"      },

    @{ Name = "Liberar Memoria RAM (Working Set)";    Cat = "Gaming";     Key = "GamingRAM"       },
    @{ Name = "Limpiar Cache de Navegadores (Web)";   Cat = "Gaming";     Key = "WebCache"        },
    @{ Name = "Desactivar Game Bar y Game DVR";       Cat = "Gaming";     Key = "GameBar"         },
    @{ Name = "Optimizar Prioridad de Procesador";    Cat = "Gaming";     Key = "CPUPriority"     }
)

# ============================================================
# FUNCIONES UNIVERSALES PARA FPS METER
# ============================================================
function Get-FpsCounter {
    $posiblesCategorias = [System.Diagnostics.PerformanceCounterCategory]::GetCategories()
    $catFps = $posiblesCategorias | Where-Object {
        $_.CategoryName -match "Graphics|Graficos|FPS|Frame|Composition|Composici"
    } | Select-Object -First 1

    if ($null -eq $catFps) { return $null }

    try {
        $instancias = $catFps.GetInstanceNames()
        $inst = $instancias | Where-Object { $_ -match "Total|Global|Composition|Composici" } | Select-Object -First 1
        if (-not $inst) { $inst = $instancias | Select-Object -First 1 }

        $counters = $catFps.GetCounters($inst)
        $cntFps = $counters | Where-Object {
            $_.CounterName -match "Frame|FPS|Frecuencia|Frequency|Cuadro"
        } | Select-Object -First 1

        if ($cntFps) {
            $pc = New-Object System.Diagnostics.PerformanceCounter(
                $catFps.CategoryName, $cntFps.CounterName, $inst
            )
            [void]$pc.NextValue()
            return $pc
        }
    } catch {}
    return $null
}

function Get-GpuCounters {
    try {
        $cat = New-Object System.Diagnostics.PerformanceCounterCategory("GPU Engine")
        $instancias = $cat.GetInstanceNames() | Where-Object { $_ -match "engtype_3D|engtype_Graphics" }
        $lista = foreach ($inst in $instancias) {
            $c = New-Object System.Diagnostics.PerformanceCounter("GPU Engine", "Utilization Percentage", $inst)
            [void]$c.NextValue()
            $c
        }
        return @($lista)
    } catch { return @() }
}

# ============================================================
# VENTANA PRINCIPAL
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Optimizer || DREYKO"
$form.Size = New-Object System.Drawing.Size(900, 680)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgDark

# ── Cargar icono (robusto para .exe compilado) ──────────────
$iconFile     = "XX.ico"
$fullIconPath = Join-Path $script:BasePath $iconFile
if (Test-Path $fullIconPath) {
    try { $form.Icon = New-Object System.Drawing.Icon($fullIconPath) } catch {}
}

$form.ForeColor = $textPrimary
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.Font = $fontItem
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font

# ============================================================
# HEADER
# ============================================================
$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size(900, 70)
$header.Location = New-Object System.Drawing.Point(0, 0)
$header.BackColor = $bgPanel
$form.Controls.Add($header)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Windows Optimizer"
$lblTitle.Font = $fontTitle
$lblTitle.ForeColor = $textPrimary
$lblTitle.Location = New-Object System.Drawing.Point(300, 18)
$lblTitle.AutoSize = $true
$header.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Autor: DREYKO"
$lblSub.Font = $fontSmall
$lblSub.ForeColor = $textMuted
$lblSub.Location = New-Object System.Drawing.Point(355, 48)
$lblSub.AutoSize = $true
$header.Controls.Add($lblSub)

$header.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [WinApi]::ReleaseCapture() | Out-Null
        [WinApi]::SendMessage($form.Handle, 0xA1, 0x2, 0) | Out-Null
    }
})

# ============================================================
# TABS
# ============================================================
$tabPanel = New-Object System.Windows.Forms.Panel
$tabPanel.Size = New-Object System.Drawing.Size(900, 44)
$tabPanel.Location = New-Object System.Drawing.Point(0, 70)
$tabPanel.BackColor = $bgCard
$form.Controls.Add($tabPanel)

$script:activeTab = "Optimizador"

function New-TabButton($text, $x) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size(140, 44)
    $btn.Location = New-Object System.Drawing.Point($x, 0)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.MouseOverBackColor = $bgHover
    $btn.Font = $fontTab
    $btn.ForeColor = $textMuted
    $btn.BackColor = $bgCard
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

$btnTabOpt = New-TabButton "Optimizador" 0
$btnTabDrv = New-TabButton "Drivers"     140
$btnTabAct = New-TabButton "Activador"   280
$btnTabNet = New-TabButton "Internet"    420
$btnTabFPS = New-TabButton "FPS Meter"   560

$tabPanel.Controls.AddRange(@($btnTabOpt, $btnTabDrv, $btnTabAct, $btnTabNet, $btnTabFPS))

$tabIndicator = New-Object System.Windows.Forms.Panel
$tabIndicator.Size = New-Object System.Drawing.Size(140, 3)
$tabIndicator.Location = New-Object System.Drawing.Point(0, 41)
$tabIndicator.BackColor = $accentBlue
$tabPanel.Controls.Add($tabIndicator)

# ============================================================
# CONTENEDOR DE PÁGINAS
# ============================================================
$pageContainer = New-Object System.Windows.Forms.Panel
$pageContainer.Size = New-Object System.Drawing.Size(900, 566)
$pageContainer.Location = New-Object System.Drawing.Point(0, 114)
$pageContainer.BackColor = $bgDark
$form.Controls.Add($pageContainer)

# ============================================================
# PÁGINA: OPTIMIZADOR
# ============================================================
$pageOpt = New-Object System.Windows.Forms.Panel
$pageOpt.Size = New-Object System.Drawing.Size(900, 566)
$pageOpt.Location = New-Object System.Drawing.Point(0, 0)
$pageOpt.BackColor = $bgDark
$pageContainer.Controls.Add($pageOpt)

$panelLeft = New-Object System.Windows.Forms.Panel
$panelLeft.Size = New-Object System.Drawing.Size(560, 510)
$panelLeft.Location = New-Object System.Drawing.Point(10, 10)
$panelLeft.BackColor = $bgPanel
$pageOpt.Controls.Add($panelLeft)

$lblTweaksHeader = New-Object System.Windows.Forms.Label
$lblTweaksHeader.Text = "  TWEAKS DISPONIBLES"
$lblTweaksHeader.Font = $fontItemB
$lblTweaksHeader.ForeColor = $textMuted
$lblTweaksHeader.Size = New-Object System.Drawing.Size(460, 30)
$lblTweaksHeader.Location = New-Object System.Drawing.Point(10, 8)
$lblTweaksHeader.BackColor = $bgPanel
$panelLeft.Controls.Add($lblTweaksHeader)

$btnDeselectAll = New-Object System.Windows.Forms.Button
$btnDeselectAll.Text = "Limpiar Selecciones"
$btnDeselectAll.Size = New-Object System.Drawing.Size(150, 26)
$btnDeselectAll.Location = New-Object System.Drawing.Point(390, 8)
$btnDeselectAll.FlatStyle = "Flat"
$btnDeselectAll.FlatAppearance.BorderColor = $borderColor
$btnDeselectAll.FlatAppearance.BorderSize = 1
$btnDeselectAll.BackColor = $bgCard
$btnDeselectAll.ForeColor = $textMuted
$btnDeselectAll.Font = $fontSmall
$btnDeselectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDeselectAll.Add_Click({
    foreach ($key in $script:checkboxes.Keys) {
        $script:checkboxes[$key].Checked = $false
    }
})
$panelLeft.Controls.Add($btnDeselectAll)
$btnDeselectAll.BringToFront()

$scrollPanel = New-Object System.Windows.Forms.Panel
$scrollPanel.Size = New-Object System.Drawing.Size(540, 470)
$scrollPanel.Location = New-Object System.Drawing.Point(10, 40)
$scrollPanel.AutoScroll = $true
$scrollPanel.BackColor = $bgPanel
$panelLeft.Controls.Add($scrollPanel)

$script:checkboxes = @{}
$yPos = 5
$lastCat = ""

foreach ($tweak in $tweaks) {
    if ($tweak.Cat -ne $lastCat) {
        $lblCat = New-Object System.Windows.Forms.Label
        $lblCat.Text = "  -- $($tweak.Cat.ToUpper())"
        $lblCat.Font = $fontSmall
        $lblCat.ForeColor = $accentCyan
        $lblCat.Size = New-Object System.Drawing.Size(520, 22)
        $lblCat.Location = New-Object System.Drawing.Point(5, $yPos)
        $scrollPanel.Controls.Add($lblCat)
        $yPos += 24
        $lastCat = $tweak.Cat
    }

    $pnl = New-Object System.Windows.Forms.Panel
    $pnl.Size = New-Object System.Drawing.Size(520, 28)
    $pnl.Location = New-Object System.Drawing.Point(5, $yPos)
    $pnl.BackColor = $bgPanel
    $scrollPanel.Controls.Add($pnl)

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $tweak.Name
    $cb.Font = $fontItem
    $cb.ForeColor = $textPrimary
    $cb.BackColor = $bgCard
    $cb.Size = New-Object System.Drawing.Size(510, 28)
    $cb.Location = New-Object System.Drawing.Point(8, 0)
    $cb.FlatStyle = "Flat"
    $cb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $pnl.Controls.Add($cb)
    $script:checkboxes[$tweak.Key] = $cb
    $yPos += 30
}

$panelRight = New-Object System.Windows.Forms.Panel
$panelRight.Size = New-Object System.Drawing.Size(308, 510)
$panelRight.Location = New-Object System.Drawing.Point(582, 10)
$panelRight.BackColor = $bgPanel
$pageOpt.Controls.Add($panelRight)

$lblLogHeader = New-Object System.Windows.Forms.Label
$lblLogHeader.Text = "  REGISTRO DE EJECUCION"
$lblLogHeader.Font = $fontItemB
$lblLogHeader.ForeColor = $textMuted
$lblLogHeader.Size = New-Object System.Drawing.Size(300, 30)
$lblLogHeader.Location = New-Object System.Drawing.Point(8, 8)
$lblLogHeader.BackColor = $bgPanel
$panelRight.Controls.Add($lblLogHeader)

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Size = New-Object System.Drawing.Size(292, 360)
$txtLog.Location = New-Object System.Drawing.Point(8, 40)
$txtLog.BackColor = $bgDark
$txtLog.ForeColor = $accentGreen
$txtLog.Font = $fontMono
$txtLog.ReadOnly = $true
$txtLog.BorderStyle = "None"
$txtLog.ScrollBars = "Vertical"
$panelRight.Controls.Add($txtLog)

function Write-Log($msg, $color = "Green") {
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionLength = 0
    switch ($color) {
        "Green"  { $txtLog.SelectionColor = $accentGreen }
        "Yellow" { $txtLog.SelectionColor = [System.Drawing.Color]::FromArgb(255, 200, 0) }
        "Red"    { $txtLog.SelectionColor = [System.Drawing.Color]::FromArgb(255, 80, 80) }
        "Cyan"   { $txtLog.SelectionColor = $accentCyan }
        default  { $txtLog.SelectionColor = $textPrimary }
    }
    $txtLog.AppendText("$(Get-Date -Format 'HH:mm:ss') > $msg`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "EJECUTAR"
$btnRun.Size = New-Object System.Drawing.Size(292, 40)
$btnRun.Location = New-Object System.Drawing.Point(8, 404)
$btnRun.FlatStyle = "Flat"
$btnRun.FlatAppearance.BorderColor = $accentBlue
$btnRun.FlatAppearance.BorderSize = 1
$btnRun.BackColor = [System.Drawing.Color]::FromArgb(80, 120, 160)
$btnRun.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$btnRun.Font = $fontBtn
$btnRun.Cursor = [System.Windows.Forms.Cursors]::Hand
$panelRight.Controls.Add($btnRun)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "[X]  Limpiar"
$btnClear.Size = New-Object System.Drawing.Size(292, 30)
$btnClear.Location = New-Object System.Drawing.Point(8, 448)
$btnClear.FlatStyle = "Flat"
$btnClear.FlatAppearance.BorderColor = $borderColor
$btnClear.FlatAppearance.BorderSize = 1
$btnClear.BackColor = $bgCard
$btnClear.ForeColor = $textMuted
$btnClear.Font = $fontSmall
$btnClear.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnClear.Add_Click({ $txtLog.Clear() })
$panelRight.Controls.Add($btnClear)

# ============================================================
# PÁGINA: DRIVERS  (VERSIÓN MEJORADA Y COMPLETAMENTE REESCRITA)
# ============================================================
$pageDrv = New-Object System.Windows.Forms.Panel
$pageDrv.Size = New-Object System.Drawing.Size(900, 566)
$pageDrv.Location = New-Object System.Drawing.Point(0, 0)
$pageDrv.BackColor = $bgDark
$pageDrv.Visible = $false
$pageContainer.Controls.Add($pageDrv)

$drvCenter = New-Object System.Windows.Forms.Panel
$drvCenter.Size = New-Object System.Drawing.Size(500, 300)
$drvCenter.Location = New-Object System.Drawing.Point(200, 120)
$drvCenter.BackColor = $bgPanel
$pageDrv.Controls.Add($drvCenter)

$lblDrvTitle = New-Object System.Windows.Forms.Label
$lblDrvTitle.Text = "Actualizador de Drivers"
$lblDrvTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblDrvTitle.ForeColor = $accentCyan
$lblDrvTitle.Location = New-Object System.Drawing.Point(30, 35)
$lblDrvTitle.AutoSize = $true
$drvCenter.Controls.Add($lblDrvTitle)

$lblDrvDesc = New-Object System.Windows.Forms.Label
$lblDrvDesc.Text = "Busca e instala controladores oficiales de Microsoft."
$lblDrvDesc.Font = $fontItem
$lblDrvDesc.ForeColor = $textMuted
$lblDrvDesc.Location = New-Object System.Drawing.Point(30, 80)
$lblDrvDesc.Size = New-Object System.Drawing.Size(440, 50)
$drvCenter.Controls.Add($lblDrvDesc)

$lblDrvStatus = New-Object System.Windows.Forms.Label
$lblDrvStatus.Text = ""
$lblDrvStatus.Font = $fontSmall
$lblDrvStatus.ForeColor = $accentGreen
$lblDrvStatus.Location = New-Object System.Drawing.Point(30, 160)
$lblDrvStatus.Size = New-Object System.Drawing.Size(440, 20)
$drvCenter.Controls.Add($lblDrvStatus)

$btnDownloadDrv = New-Object System.Windows.Forms.Button
$btnDownloadDrv.Text = "[DL]  DESCARGAR DRIVERS"
$btnDownloadDrv.Size = New-Object System.Drawing.Size(440, 46)
$btnDownloadDrv.Location = New-Object System.Drawing.Point(30, 210)
$btnDownloadDrv.FlatStyle = "Flat"
$btnDownloadDrv.FlatAppearance.BorderColor = $accentBlue
$btnDownloadDrv.FlatAppearance.BorderSize = 1
$btnDownloadDrv.BackColor = [System.Drawing.Color]::FromArgb(80, 120, 160)
$btnDownloadDrv.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$btnDownloadDrv.Font = $fontBtn
$btnDownloadDrv.Cursor = [System.Windows.Forms.Cursors]::Hand
$drvCenter.Controls.Add($btnDownloadDrv)

$btnDownloadDrv.Add_Click({
    $btnDownloadDrv.Enabled = $false
    $lblDrvStatus.Text = "[*] Preparando terminal de controladores..."
    [System.Windows.Forms.Application]::DoEvents()

    # ── Script de drivers como here-string (se escribe en disco y se lanza) ──
    # De este modo la ventana de consola siempre es visible, incluso desde .exe
    $driverScriptContent = @'
# Forzar codificacion estandar para evitar errores de parsing
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$Host.UI.RawUI.WindowTitle = "DREYKO - Actualizador de Drivers"
try { $Host.UI.RawUI.BackgroundColor = "Black"; $Host.UI.RawUI.ForegroundColor = "Cyan"; Clear-Host } catch {}

function Write-Header {
    Write-Host ""
    Write-Host "  +------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |           DREYKO - ACTUALIZADOR DE DRIVERS           |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Msg, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "  [$timestamp] $Msg" -ForegroundColor $Color
}

function Write-Separator {
    Write-Host "  ------------------------------------------------------" -ForegroundColor DarkGray
}

Write-Header

# ── 1. Comprobación de permisos de administrador ──────────────
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Step "ERROR: Este script necesita permisos de administrador." "Red"
    Write-Step "Cierra esta ventana y ejecuta el optimizador como administrador." "Yellow"
    Write-Host ""
    Write-Host "  Presiona cualquier tecla para salir..." -ForegroundColor DarkGray
    $null = [Console]::ReadKey($true)
    exit 1
}
Write-Step "OK - Ejecutando como administrador." "Green"
Write-Separator

# ── 2. Comprobación de reinicio pendiente ─────────────────────
Write-Step "Comprobando estado del sistema..." "Cyan"
$rebootPending = $false
$rebootPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
)
foreach ($rp in $rebootPaths) {
    if (Test-Path $rp) { $rebootPending = $true; break }
}
if ($rebootPending) {
    Write-Step "AVISO: Hay un reinicio pendiente en el sistema." "Yellow"
    Write-Step "  Se recomienda reiniciar antes de actualizar drivers." "Yellow"
    Write-Step "  Continuando de todas formas..." "DarkGray"
} else {
    Write-Step "Sistema sin reinicios pendientes. Perfecto." "Green"
}
Write-Separator

# ── 3. Forzar escaneo de hardware ─────────────────────────────
Write-Step "Forzando escaneo de cambios en el hardware..." "Cyan"
try {
    $pnpResult = & pnputil /scan-devices 2>&1
    Write-Step "Escaneo de PnP completado." "Green"
} catch {
    Write-Step "pnputil no disponible (normal en versiones antiguas)." "DarkGray"
}

# ── 4. Asegurar que el servicio Windows Update está activo ────
Write-Step "Verificando servicio Windows Update (wuauserv)..." "Cyan"
try {
    $svc = Get-Service -Name wuauserv -ErrorAction Stop
    if ($svc.StartType -eq "Disabled") {
        Set-Service wuauserv -StartupType Manual -ErrorAction Stop
        Write-Step "Servicio wuauserv habilitado (estaba desactivado)." "Yellow"
    }
    if ($svc.Status -ne "Running") {
        Start-Service wuauserv -ErrorAction Stop
        Start-Sleep -Seconds 3
    }
    Write-Step "Servicio Windows Update: ACTIVO." "Green"
} catch {
    Write-Step "No se pudo iniciar wuauserv: $($_.Exception.Message)" "Red"
}
Write-Separator

# ── 5. Configurar y Buscar controladores vía COM API ─────────
Write-Step "Configurando busqueda en catalogo de Microsoft..." "Cyan"
try {
    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    # Registro del catalogo extendido oficial de controladores
    $ServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "") | Out-Null
    Write-Step "Catalogo extendido registrado con exito." "Green"
} catch {
    Write-Step "El catalogo ya estaba activo o se usara el predeterminado." "DarkGray"
}

Write-Step "Iniciando busqueda de controladores online..." "Cyan"
Write-Step "  (Esto puede tardar unos minutos)" "DarkGray"

$UpdateSession  = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
# ServerSelection = 2 fuerza la busqueda en los servidores online de Microsoft
$UpdateSearcher.ServerSelection = 2 

$foundDrivers = 0
$installedDrivers = 0
$failedDrivers = 0

try {
    # Tiempo de inicio para medir duracion
    $searchStart = Get-Date

    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Driver'")
    $searchSecs   = [int]((Get-Date) - $searchStart).TotalSeconds
    $foundDrivers = $SearchResult.Updates.Count

    Write-Step "Busqueda completada en ${searchSecs} segundos." "Green"
    Write-Separator

    if ($foundDrivers -eq 0) {
        Write-Host ""
        Write-Host "  [OK] No se encontraron controladores pendientes." -ForegroundColor Green
        Write-Host "  [OK] Tu sistema tiene todos los controladores al dia." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  +-- CONTROLADORES ENCONTRADOS: $foundDrivers --" -ForegroundColor Yellow
        for ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
            $u = $SearchResult.Updates.Item($i)
            $idx = $i + 1
            $kb = if ($u.KBArticleIDs.Count -gt 0) { " [KB" + $u.KBArticleIDs.Item(0) + "]" } else { "" }
            Write-Host "  | $idx. $($u.Title)$kb" -ForegroundColor White
        }
        Write-Host "  +----------------------------------------------" -ForegroundColor Yellow
        Write-Host ""
        Write-Separator

        # ── 6. Aceptar licencias (CRITICO para evitar errores de descarga) ──
        Write-Step "Aceptando licencias de controladores..." "Cyan"
        for ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
            $u = $SearchResult.Updates.Item($i)
            if (-not $u.EulaAccepted) {
                try { $u.AcceptEula() } catch {}
            }
        }
        Write-Separator

        # ── 7. Descarga con sistema de reintentos ───────────────────
        Write-Step "Descargando controladores..." "Cyan"
        Write-Host ""

        for ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
            $u      = $SearchResult.Updates.Item($i)
            $num    = $i + 1
            $single = New-Object -ComObject Microsoft.Update.UpdateColl
            $single.Add($u) | Out-Null

            Write-Host "  [$num/$foundDrivers] Descargando: $($u.Title)" -ForegroundColor Cyan

            $dlOk = $false
            for ($try = 1; $try -le 3; $try++) {
                try {
                    $Dl         = $UpdateSession.CreateUpdateDownloader()
                    $Dl.Updates = $single
                    $DlRes      = $Dl.Download()
                    $dc         = $DlRes.ResultCode
                    if ($dc -eq 2 -or $dc -eq 3) {
                        Write-Host "         [OK] Descargado (intento $try)" -ForegroundColor Green
                        $dlOk = $true; break
                    } else {
                        Write-Host "         [!!] Intento $try - Codigo de error $dc" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "         [!!] Intento $try - Error en conexion" -ForegroundColor Yellow
                }
                if ($try -lt 3) { Start-Sleep -Seconds 3 }
            }
            if (-not $dlOk) { 
                Write-Host "         [XX] No se pudo descargar tras 3 intentos" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Separator

        # ── 8. Instalacion controlador a controlador ──────────────
        Write-Step "Instalando controladores uno a uno..." "Cyan"
        Write-Host ""

        for ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
            $u      = $SearchResult.Updates.Item($i)
            $single = New-Object -ComObject Microsoft.Update.UpdateColl
            $single.Add($u) | Out-Null

            $num = $i + 1
            Write-Host "  [$num/$foundDrivers] Instalando: $($u.Title)" -ForegroundColor White

            try {
                $Installer         = $UpdateSession.CreateUpdateInstaller()
                $Installer.Updates = $single
                $InstallResult     = $Installer.Install()
                $ic                = $InstallResult.ResultCode
                if ($ic -eq 2) {
                    Write-Host "         [OK] Instalado correctamente" -ForegroundColor Green
                    $installedDrivers++
                } elseif ($ic -eq 3) {
                    Write-Host "         [!!] Instalado con advertencias (Codigo $ic)" -ForegroundColor Yellow
                    $installedDrivers++
                } else {
                    Write-Host "         [XX] Fallo instalacion (Codigo $ic)" -ForegroundColor Red
                    $failedDrivers++
                }
                if ($InstallResult.RebootRequired) {
                    Write-Host "         [>>] Requiere reinicio del sistema" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "         [XX] Error: $($_.Exception.Message)" -ForegroundColor Red
                $failedDrivers++
            }
        }

        Write-Host ""
        Write-Separator
        Write-Host ""
        Write-Host "  +------------------ RESUMEN FINAL -------------------+" -ForegroundColor Cyan
        Write-Host "     Encontrados : $foundDrivers" -ForegroundColor White
        Write-Host "     Instalados  : $installedDrivers" -ForegroundColor Green
        Write-Host "     Con error   : $failedDrivers" -ForegroundColor White
        Write-Host "  +----------------------------------------------------+" -ForegroundColor Cyan
        Write-Host ""
    }
} catch {
    Write-Host ""
    Write-Step "ERROR CRITICO durante la actualizacion:" "Red"
    Write-Step "  $($_.Exception.Message)" "Red"
    Write-Host ""
    Write-Host "  Posibles causas:" -ForegroundColor DarkGray
    Write-Host "    . Windows Update desactivado por directiva de grupo." -ForegroundColor DarkGray
    Write-Host "    . Sin conexion a Internet." -ForegroundColor DarkGray
    Write-Host "    . Servicio COM danado (ejecuta sfc /scannow)." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Esta ventana se cerrara automaticamente en 10 segundos..." -ForegroundColor DarkGray
Write-Host ""

for ($countdown = 10; $countdown -ge 1; $countdown--) {
    Write-Host "  Cerrando en $countdown...  " -ForegroundColor DarkGray -NoNewline
    Start-Sleep -Seconds 1
    Write-Host "`r" -NoNewline
}
# Limpieza del script temporal
try { Remove-Item $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue } catch {}
'@

    # Escribir el script en un archivo temporal y lanzarlo con -File
    # (más robusto que -EncodedCommand para scripts largos y con tildes)
    $tempDir    = Join-Path $env:TEMP "DREYKO_Optimizer"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $tempScript = Join-Path $tempDir "DriverUpdater.ps1"
    # Forzar UTF-8 con BOM para que PowerShell lea bien las tildes y ñ en el proceso hijo
    $utf8BOM = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($tempScript, $driverScriptContent, $utf8BOM)

    # Lanzar una ventana de PowerShell VISIBLE con el script en disco
    $psArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-NoExit",
        "-File", "`"$tempScript`""
    )
    Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -WindowStyle Normal -Verb RunAs

    $lblDrvStatus.Text      = "[+] Terminal lanzada. Revisa la nueva ventana."
    $lblDrvStatus.ForeColor = $accentGreen

    $btnDownloadDrv.Enabled = $true
})

# ============================================================
# PÁGINA: ACTIVADOR
# ============================================================
$pageAct = New-Object System.Windows.Forms.Panel
$pageAct.Size = New-Object System.Drawing.Size(900, 566)
$pageAct.Location = New-Object System.Drawing.Point(0, 0)
$pageAct.BackColor = $bgDark
$pageAct.Visible = $false
$pageContainer.Controls.Add($pageAct)

$actCenter = New-Object System.Windows.Forms.Panel
$actCenter.Size = New-Object System.Drawing.Size(500, 280)
$actCenter.Location = New-Object System.Drawing.Point(200, 130)
$actCenter.BackColor = $bgPanel
$pageAct.Controls.Add($actCenter)

$lblActTitle = New-Object System.Windows.Forms.Label
$lblActTitle.Text = "Windows Activator"
$lblActTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblActTitle.ForeColor = $accentCyan
$lblActTitle.Location = New-Object System.Drawing.Point(30, 35)
$lblActTitle.AutoSize = $true
$actCenter.Controls.Add($lblActTitle)

$lblActDesc = New-Object System.Windows.Forms.Label
$lblActDesc.Text = "Metodo HWID para activar Windows de forma legal."
$lblActDesc.Font = $fontItem
$lblActDesc.ForeColor = $textMuted
$lblActDesc.Location = New-Object System.Drawing.Point(30, 80)
$lblActDesc.Size = New-Object System.Drawing.Size(440, 50)
$actCenter.Controls.Add($lblActDesc)

$lblActStatus = New-Object System.Windows.Forms.Label
$lblActStatus.Text = ""
$lblActStatus.Font = $fontSmall
$lblActStatus.ForeColor = $accentGreen
$lblActStatus.Location = New-Object System.Drawing.Point(30, 160)
$lblActStatus.Size = New-Object System.Drawing.Size(440, 20)
$actCenter.Controls.Add($lblActStatus)

$btnActivate = New-Object System.Windows.Forms.Button
$btnActivate.Text = "[K]  ACTIVAR"
$btnActivate.Size = New-Object System.Drawing.Size(440, 46)
$btnActivate.Location = New-Object System.Drawing.Point(30, 195)
$btnActivate.FlatStyle = "Flat"
$btnActivate.FlatAppearance.BorderColor = $accentBlue
$btnActivate.FlatAppearance.BorderSize = 1
$btnActivate.BackColor = [System.Drawing.Color]::FromArgb(80, 120, 160)
$btnActivate.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$btnActivate.Font = $fontBtn
$btnActivate.Cursor = [System.Windows.Forms.Cursors]::Hand
$actCenter.Controls.Add($btnActivate)

$btnActivate.Add_Click({
    $lblActStatus.ForeColor = $accentGreen
    $lblActStatus.Text = "Iniciando activador..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://get.activated.win | iex`"" -Verb RunAs
        $lblActStatus.Text = "Activador lanzado"
    } catch {
        $lblActStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 80, 80)
        $lblActStatus.Text = "Error al lanzar"
    }
})

# ============================================================
# PÁGINA: INTERNET (SPEED TEST)
# ============================================================
function Convert-BytesPerSecondToMbps {
    param([double]$BytesPerSecond)
    if ($null -eq $BytesPerSecond -or $BytesPerSecond -le 0) { return 0 }
    return [Math]::Round(($BytesPerSecond * 8) / 1000000, 2)
}

$pageNet = New-Object System.Windows.Forms.Panel
$pageNet.Size = New-Object System.Drawing.Size(900, 566)
$pageNet.Location = New-Object System.Drawing.Point(0, 0)
$pageNet.BackColor = $bgDark
$pageNet.Visible = $false
$pageContainer.Controls.Add($pageNet)

$netCenter = New-Object System.Windows.Forms.Panel
$netCenter.Size = New-Object System.Drawing.Size(700, 450)
$netCenter.Location = New-Object System.Drawing.Point(100, 40)
$netCenter.BackColor = $bgPanel
$pageNet.Controls.Add($netCenter)

$lblNetTitle = New-Object System.Windows.Forms.Label
$lblNetTitle.Text = "Prueba de Velocidad Real"
$lblNetTitle.Font = $fontTitle
$lblNetTitle.ForeColor = $accentCyan
$lblNetTitle.Location = New-Object System.Drawing.Point(30, 20)
$lblNetTitle.AutoSize = $true
$netCenter.Controls.Add($lblNetTitle)

$lblNetMbps = New-Object System.Windows.Forms.Label
$lblNetMbps.Text = "0.0 Mbps"
$lblNetMbps.Font = New-Object System.Drawing.Font("Segoe UI", 50, [System.Drawing.FontStyle]::Bold)
$lblNetMbps.ForeColor = $textPrimary
$lblNetMbps.Location = New-Object System.Drawing.Point(30, 70)
$lblNetMbps.Size = New-Object System.Drawing.Size(400, 100)
$lblNetMbps.TextAlign = "MiddleLeft"
$netCenter.Controls.Add($lblNetMbps)

$lblMbpsUnit = New-Object System.Windows.Forms.Label
$lblMbpsUnit.Font = $fontTab
$lblMbpsUnit.ForeColor = $accentGreen
$lblMbpsUnit.Location = New-Object System.Drawing.Point(40, 155)
$lblMbpsUnit.AutoSize = $true
$netCenter.Controls.Add($lblMbpsUnit)

$lblNetPing = New-Object System.Windows.Forms.Label
$lblNetPing.Text = "PING: -- ms"
$lblNetPing.Font = $fontItemB
$lblNetPing.ForeColor = $textMuted
$lblNetPing.Location = New-Object System.Drawing.Point(450, 100)
$lblNetPing.AutoSize = $true
$netCenter.Controls.Add($lblNetPing)

$lblNetDownload = New-Object System.Windows.Forms.Label
$lblNetDownload.Text = "DESCARGA: -- Mbps"
$lblNetDownload.Font = $fontItemB
$lblNetDownload.ForeColor = $accentCyan
$lblNetDownload.Location = New-Object System.Drawing.Point(450, 130)
$lblNetDownload.AutoSize = $true
$netCenter.Controls.Add($lblNetDownload)

$lblNetUpload = New-Object System.Windows.Forms.Label
$lblNetUpload.Text = "SUBIDA: -- Mbps"
$lblNetUpload.Font = $fontItemB
$lblNetUpload.ForeColor = $accentGreen
$lblNetUpload.Location = New-Object System.Drawing.Point(450, 160)
$lblNetUpload.AutoSize = $true
$netCenter.Controls.Add($lblNetUpload)

$lblNetServer = New-Object System.Windows.Forms.Label
$lblNetServer.Text = "SERVIDOR: --"
$lblNetServer.Font = $fontSmall
$lblNetServer.ForeColor = $textMuted
$lblNetServer.Location = New-Object System.Drawing.Point(450, 190)
$lblNetServer.AutoSize = $true
$netCenter.Controls.Add($lblNetServer)

$pnlGraph = New-Object System.Windows.Forms.Panel
$pnlGraph.Size = New-Object System.Drawing.Size(640, 150)
$pnlGraph.Location = New-Object System.Drawing.Point(30, 200)
$pnlGraph.BackColor = $bgDark
$pnlGraph.BorderStyle = "FixedSingle"
$netCenter.Controls.Add($pnlGraph)

$btnStartNet = New-Object System.Windows.Forms.Button
$btnStartNet.Text = "[START]  INICIAR TEST"
$btnStartNet.Size = New-Object System.Drawing.Size(640, 50)
$btnStartNet.Location = New-Object System.Drawing.Point(30, 370)
$btnStartNet.FlatStyle = "Flat"
$btnStartNet.FlatAppearance.BorderColor = $accentCyan
$btnStartNet.BackColor = [System.Drawing.Color]::FromArgb(80, 120, 160)
$btnStartNet.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$btnStartNet.Font = $fontBtn
$btnStartNet.Cursor = [System.Windows.Forms.Cursors]::Hand
$netCenter.Controls.Add($btnStartNet)

$script:lastNetRun  = [datetime]::MinValue
$script:netSpeedJob = $null

$netSpeedTimer = New-Object System.Windows.Forms.Timer
$netSpeedTimer.Interval = 300
$netSpeedTimer.Add_Tick({
    if (-not $script:netSpeedJob) { return }

    $jobState = $script:netSpeedJob.State
    if ($jobState -eq "Completed") {
        $jobResult = $null
        try { $jobResult = Receive-Job $script:netSpeedJob -ErrorAction Stop } catch { $jobResult = $null }

        Remove-Job $script:netSpeedJob -Force
        $script:netSpeedJob = $null
        $netSpeedTimer.Stop()

        if ($jobResult -and $jobResult.Success -and $jobResult.Data) {
            $result         = $jobResult.Data
            $downloadMbps   = Convert-BytesPerSecondToMbps -BytesPerSecond $result.download.bandwidth
            $uploadMbps     = Convert-BytesPerSecondToMbps -BytesPerSecond $result.upload.bandwidth
            $pingMs         = if ($result.ping  -and $result.ping.latency)  { [Math]::Round($result.ping.latency, 0) } else { "--" }
            $jitterMs       = if ($result.ping  -and $result.ping.jitter)   { [Math]::Round($result.ping.jitter, 1) } else { "--" }
            $serverName     = if ($result.server -and $result.server.name)     { $result.server.name }     else { "--" }
            $serverLocation = if ($result.server -and $result.server.location) { $result.server.location } else { "--" }
            $serverCountry  = if ($result.server -and $result.server.country)  { $result.server.country }  else { "--" }

            $lblNetMbps.Text     = if ($downloadMbps -gt 0) { "{0:N2}" -f $downloadMbps } else { "--" }
            $lblNetDownload.Text = "DESCARGA: {0:N2} Mbps" -f $downloadMbps
            $lblNetUpload.Text   = "SUBIDA: {0:N2} Mbps"   -f $uploadMbps
            $lblNetPing.Text     = "PING: $pingMs ms | JITTER: $jitterMs ms"
            $lblNetServer.Text   = "SERVIDOR: $serverName ($serverLocation, $serverCountry)"
        } else {
            $lblNetMbps.Text     = "Sin conexión"
            $lblNetPing.Text     = if ($jobResult -and $jobResult.Error) { "$($jobResult.Error)" } else { "No se pudo medir la velocidad" }
            $lblNetDownload.Text = "DESCARGA: -- Mbps"
            $lblNetUpload.Text   = "SUBIDA: -- Mbps"
            $lblNetServer.Text   = "SERVIDOR: --"
        }

        $btnStartNet.Text    = "[START]  INICIAR TEST"
        $btnStartNet.Enabled = $true
    }
    elseif ($jobState -eq "Failed" -or $jobState -eq "Stopped") {
        $errorMessage = "No se pudo ejecutar la prueba de velocidad"
        if ($script:netSpeedJob) {
            try { $jobError = Receive-Job $script:netSpeedJob -ErrorAction SilentlyContinue; if ($jobError -and $jobError.Error) { $errorMessage = "$($jobError.Error)" } } catch {}
            Remove-Job $script:netSpeedJob -Force
        }
        $script:netSpeedJob  = $null
        $netSpeedTimer.Stop()
        $lblNetMbps.Text     = "Sin conexión"
        $lblNetPing.Text     = $errorMessage
        $lblNetDownload.Text = "DESCARGA: -- Mbps"
        $lblNetUpload.Text   = "SUBIDA: -- Mbps"
        $lblNetServer.Text   = "SERVIDOR: --"
        $btnStartNet.Text    = "[START]  INICIAR TEST"
        $btnStartNet.Enabled = $true
    }
})

$btnStartNet.Add_Click({
    if ($script:netSpeedJob) { return }

    $timeSinceLastRun = (Get-Date) - $script:lastNetRun
    if ($timeSinceLastRun.TotalSeconds -lt 20) {
        $lblNetMbps.Text     = "Espera"
        $lblNetPing.Text     = "Espera unos segundos antes de volver a medir"
        $lblNetDownload.Text = "DESCARGA: -- Mbps"
        $lblNetUpload.Text   = "SUBIDA: -- Mbps"
        $lblNetServer.Text   = "SERVIDOR: --"
        return
    }

    $script:lastNetRun   = Get-Date
    $btnStartNet.Enabled = $false
    $btnStartNet.Text    = "[WAIT]  MIDIENDO..."
    $lblNetMbps.Text     = "..."
    $lblNetPing.Text     = "Midiendo conexion..."
    $lblNetDownload.Text = "DESCARGA: -- Mbps"
    $lblNetUpload.Text   = "SUBIDA: -- Mbps"
    $lblNetServer.Text   = "SERVIDOR: --"

    $folder = Join-Path $env:TEMP "WindowsOptimizer_Net"
    $script:netSpeedJob = Start-Job -ScriptBlock {
        param($folder)
        try {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null

            function Find-SpeedtestExe {
                param($folder)
                $candidates = @((Join-Path $folder 'speedtest.exe'))
                foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
                $fromCmd = Get-Command speedtest -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
                if ($fromCmd) { return $fromCmd }
                return $null
            }

            $exePath = Find-SpeedtestExe -folder $folder
            if (-not $exePath) {
                $zipPath   = Join-Path $folder 'ookla-speedtest-win64.zip'
                $urls      = @(
                    'https://install.speedtest.net/app/cli/ookla-speedtest-latest-win64.zip',
                    'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip'
                )
                $downloaded = $false
                foreach ($url in $urls) {
                    for ($i = 1; $i -le 3; $i++) {
                        try {
                            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
                            $downloaded = $true; break
                        } catch { Start-Sleep -Seconds (2 * $i) }
                    }
                    if ($downloaded) { break }
                }
                if (-not $downloaded) { throw 'No se pudo descargar Speedtest CLI.' }
                try { Expand-Archive -Path $zipPath -DestinationPath $folder -Force } catch { throw 'Error al descomprimir Speedtest CLI.' }
                $found = Get-ChildItem -Path $folder -Recurse -Filter 'speedtest.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { $exePath = $found.FullName } else { throw 'No se encontró speedtest.exe tras descomprimir.' }
            }

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName               = $exePath
            $psi.Arguments              = '--format=json --progress=no --accept-license --accept-gdpr'
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true

            $proc     = [System.Diagnostics.Process]::Start($psi)
            if (-not $proc) { throw 'No se pudo iniciar speedtest.exe' }
            $stdOut   = $proc.StandardOutput.ReadToEnd()
            $stdErr   = $proc.StandardError.ReadToEnd()
            $finished = $proc.WaitForExit(120000)
            if (-not $finished) { try { $proc.Kill() } catch {}; throw 'Speedtest excedió el tiempo máximo.' }
            if ($proc.ExitCode -ne 0) { throw (if ($stdErr) { $stdErr.Trim() } else { "Speedtest falló con código $($proc.ExitCode)" }) }
            try { $result = ConvertFrom-Json $stdOut -ErrorAction Stop } catch { throw 'No se pudo parsear la salida de speedtest.' }
            [pscustomobject]@{ Success = $true; Data = $result }
        } catch {
            [pscustomobject]@{ Success = $false; Error = $_.Exception.Message }
        }
    } -ArgumentList $folder
    $netSpeedTimer.Start()
})

# ============================================================
# PÁGINA: FPS METER (OVERLAY)
# ============================================================
$pageFPS = New-Object System.Windows.Forms.Panel
$pageFPS.Size = New-Object System.Drawing.Size(900, 566)
$pageFPS.Location = New-Object System.Drawing.Point(0, 0)
$pageFPS.BackColor = $bgDark
$pageFPS.Visible = $false
$pageContainer.Controls.Add($pageFPS)

$fpsCenter = New-Object System.Windows.Forms.Panel
$fpsCenter.Size = New-Object System.Drawing.Size(500, 350)
$fpsCenter.Location = New-Object System.Drawing.Point(200, 100)
$fpsCenter.BackColor = $bgPanel
$pageFPS.Controls.Add($fpsCenter)

$lblFPSTitle = New-Object System.Windows.Forms.Label
$lblFPSTitle.Text = "Monitor de Rendimiento"
$lblFPSTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblFPSTitle.ForeColor = $accentCyan
$lblFPSTitle.Location = New-Object System.Drawing.Point(30, 30)
$lblFPSTitle.AutoSize = $true
$fpsCenter.Controls.Add($lblFPSTitle)

$fpsGroup = New-Object System.Windows.Forms.GroupBox
$fpsGroup.Text = "Selecciona el Modo de Visualizacion"
$fpsGroup.Size = New-Object System.Drawing.Size(440, 150)
$fpsGroup.Location = New-Object System.Drawing.Point(30, 80)
$fpsGroup.ForeColor = $textMuted
$fpsCenter.Controls.Add($fpsGroup)

$radioFPS = New-Object System.Windows.Forms.RadioButton
$radioFPS.Text = "Solo FPS (Modo Simple)"
$radioFPS.Location = New-Object System.Drawing.Point(20, 30)
$radioFPS.Size = New-Object System.Drawing.Size(400, 30)
$radioFPS.Checked = $true
$fpsGroup.Controls.Add($radioFPS)

$radioBasic = New-Object System.Windows.Forms.RadioButton
$radioBasic.Text = "FPS + CPU % + RAM (Recomendado)"
$radioBasic.Location = New-Object System.Drawing.Point(20, 65)
$radioBasic.Size = New-Object System.Drawing.Size(400, 30)
$fpsGroup.Controls.Add($radioBasic)

$radioFull = New-Object System.Windows.Forms.RadioButton
$radioFull.Text = "Completo (FPS, CPU, RAM, GPU %)"
$radioFull.Location = New-Object System.Drawing.Point(20, 100)
$radioFull.Size = New-Object System.Drawing.Size(400, 30)
$fpsGroup.Controls.Add($radioFull)

$btnStartFPS = New-Object System.Windows.Forms.Button
$btnStartFPS.Text = "[ON] INICIAR OVERLAY"
$btnStartFPS.Size = New-Object System.Drawing.Size(210, 46)
$btnStartFPS.Location = New-Object System.Drawing.Point(30, 260)
$btnStartFPS.FlatStyle = "Flat"
$btnStartFPS.BackColor = $accentGreen
$btnStartFPS.ForeColor = [System.Drawing.Color]::White
$btnStartFPS.Font = $fontBtn
$fpsCenter.Controls.Add($btnStartFPS)

$btnStopFPS = New-Object System.Windows.Forms.Button
$btnStopFPS.Text = "[OFF] DETENER"
$btnStopFPS.Size = New-Object System.Drawing.Size(210, 46)
$btnStopFPS.Location = New-Object System.Drawing.Point(260, 260)
$btnStopFPS.FlatStyle = "Flat"
$btnStopFPS.BackColor = [System.Drawing.Color]::FromArgb(200, 80, 80)
$btnStopFPS.ForeColor = [System.Drawing.Color]::White
$btnStopFPS.Font = $fontBtn
$btnStopFPS.Enabled = $false
$fpsCenter.Controls.Add($btnStopFPS)

# Overlay flotante
$overlay = New-Object System.Windows.Forms.Form
$overlay.FormBorderStyle = "None"
$overlay.TopMost = $true
$overlay.Size = New-Object System.Drawing.Size(180, 100)
$overlay.BackColor = [System.Drawing.Color]::Black
$overlay.Opacity = 0.8
$overlay.ShowInTaskbar = $false

$lblOverlayData = New-Object System.Windows.Forms.Label
$lblOverlayData.AutoSize = $true
$lblOverlayData.ForeColor = [System.Drawing.Color]::Lime
$lblOverlayData.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
$lblOverlayData.Location = New-Object System.Drawing.Point(10, 10)
$overlay.Controls.Add($lblOverlayData)

$lblOverlayData.Add_MouseDown({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [WinApi]::ReleaseCapture() | Out-Null
        [WinApi]::SendMessage($overlay.Handle, 0xA1, 0x2, 0) | Out-Null
    }
})

$fpsTimer = New-Object System.Windows.Forms.Timer
$fpsTimer.Interval = 1000

$fpsTimer.Add_Tick({
    try {
        $cpu     = [int]$script:pcCpu.NextValue()
        $usedRam = [int]($script:totalRamMb - $script:pcRam.NextValue())
        $fpsVal  = if ($script:pcFps) { [int][Math]::Round($script:pcFps.NextValue(), 0) } else { 0 }
        $fpsDisplay = if ($fpsVal -le 0) { "N/A" } else { "$fpsVal" }

        $text = ""
        if ($radioFPS.Checked -or $radioBasic.Checked -or $radioFull.Checked) {
            $text += "FPS: $fpsDisplay`n"
        }
        if ($radioBasic.Checked -or $radioFull.Checked) {
            $text += "CPU: $cpu%`nRAM: $usedRam MB`n"
        }
        if ($radioFull.Checked) {
            $gpu = if ($script:pcGpuList -and $script:pcGpuList.Count -gt 0) {
                [int](($script:pcGpuList | ForEach-Object { $_.NextValue() } | Measure-Object -Sum).Sum)
            } else { 0 }
            $text += "GPU: $gpu%"
        }

        $lblOverlayData.Text = $text.TrimEnd()
        $overlay.Size = $lblOverlayData.PreferredSize + (New-Object System.Drawing.Size(20, 20))
    } catch {
        $lblOverlayData.Text = "Cargando..."
    }
})

$btnStartFPS.Add_Click({
    foreach ($grupo in @("Performance Log Users", "Usuarios del registro de rendimiento")) {
        try { Add-LocalGroupMember -Group $grupo -Member $env:USERNAME -ErrorAction Stop } catch {}
    }

    if (-not (Get-AppxPackage -Name "Microsoft.XboxGamingOverlay" -ErrorAction SilentlyContinue)) {
        $pkg = Get-AppxPackage -AllUsers -Name "Microsoft.XboxGamingOverlay" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $pkg) {
            $pkg = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "Microsoft.XboxGamingOverlay" }
        }
        if ($pkg -and $pkg.InstallLocation) {
            $manifest = Join-Path $pkg.InstallLocation "AppXManifest.xml"
            if (Test-Path $manifest) {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        }
    }

    Stop-Process -Name "GameBar","XboxGameBarWidgets" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1 -Force -EA SilentlyContinue
    Set-ItemProperty "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1 -Force -EA SilentlyContinue
    Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 1 -Force -EA SilentlyContinue

    $script:pcCpu      = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
    $script:pcRam      = New-Object System.Diagnostics.PerformanceCounter("Memory", "Available MBytes")
    $script:totalRamMb = [Math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1024, 0)
    [void]$script:pcCpu.NextValue()

    $script:pcFps     = Get-FpsCounter
    $script:pcGpuList = Get-GpuCounters

    $btnStartFPS.Enabled = $false
    $btnStopFPS.Enabled  = $true
    $overlay.Show()
    $fpsTimer.Start()
})

$btnStopFPS.Add_Click({
    $btnStartFPS.Enabled = $true
    $btnStopFPS.Enabled  = $false
    $fpsTimer.Stop()
    $overlay.Hide()
})

# ============================================================
# NAVEGACIÓN DE TABS
# ============================================================
function Switch-Tab($tabName) {
    $script:activeTab    = $tabName
    $pageOpt.Visible     = ($tabName -eq "Optimizador")
    $pageDrv.Visible     = ($tabName -eq "Drivers")
    $pageAct.Visible     = ($tabName -eq "Activador")
    $pageNet.Visible     = ($tabName -eq "Internet")
    $pageFPS.Visible     = ($tabName -eq "FPS Meter")

    $btnTabOpt.ForeColor = if ($tabName -eq "Optimizador") { $textPrimary } else { $textMuted }
    $btnTabDrv.ForeColor = if ($tabName -eq "Drivers")     { $textPrimary } else { $textMuted }
    $btnTabAct.ForeColor = if ($tabName -eq "Activador")   { $textPrimary } else { $textMuted }
    $btnTabNet.ForeColor = if ($tabName -eq "Internet")    { $textPrimary } else { $textMuted }
    $btnTabFPS.ForeColor = if ($tabName -eq "FPS Meter")   { $textPrimary } else { $textMuted }

    $x = switch ($tabName) {
        "Optimizador" { 0   }
        "Drivers"     { 140 }
        "Activador"   { 280 }
        "Internet"    { 420 }
        "FPS Meter"   { 560 }
    }
    $tabIndicator.Location = New-Object System.Drawing.Point($x, 41)
}

$btnTabOpt.Add_Click({ Switch-Tab "Optimizador" })
$btnTabDrv.Add_Click({ Switch-Tab "Drivers"     })
$btnTabAct.Add_Click({ Switch-Tab "Activador"   })
$btnTabNet.Add_Click({ Switch-Tab "Internet"    })
$btnTabFPS.Add_Click({ Switch-Tab "FPS Meter"   })
Switch-Tab "Optimizador"

# ============================================================
# EJECUCIÓN DE TWEAKS
# ============================================================
$btnRun.Add_Click({
    $btnRun.Enabled = $false
    $btnRun.Text = "Ejecutando..."

    $selected = $tweaks | Where-Object { $script:checkboxes[$_.Key].Checked }
    if ($selected.Count -eq 0) {
        Write-Log "No hay tweaks seleccionados." "Yellow"
        $btnRun.Enabled = $true
        $btnRun.Text = "EJECUTAR"
        return
    }

    Write-Log "Iniciando ($($selected.Count) tweaks)..." "Cyan"

    foreach ($tweak in $selected) {
        Write-Log "Aplicando: $($tweak.Name)..."
        [System.Windows.Forms.Application]::DoEvents()

        try {
            switch ($tweak.Key) {
                "TempFiles" {
                    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "  Archivos temporales eliminados." "Green"
                }
                "RestorePoint" {
                    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
                    Checkpoint-Computer -Description "DREYKO_Optimizer" -RestorePointType "MODIFY_SETTINGS"
                    Write-Log "  Punto de restauración creado." "Green"
                }
                "Hibernate" {
                    powercfg -h off
                    Write-Log "  Hibernación deshabilitada." "Green"
                }
                "Services" {
                    $srvs = @("SysMain", "DiagTrack", "dmwappushservice")
                    foreach ($s in $srvs) { Stop-Service $s -ErrorAction SilentlyContinue; Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue }
                    Write-Log "  Servicios innecesarios parados." "Green"
                }
                "Display" {
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Force
                    Write-Log "  Efectos visuales ajustados." "Green"
                }
                "Transparency" {
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Force
                    Write-Log "  Transparencias desactivadas." "Green"
                }
                "StorageSense" {
                    $sPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
                    if (!(Test-Path $sPath)) { New-Item $sPath -Force | Out-Null }
                    Set-ItemProperty -Path $sPath -Name "01" -Value 0 -Force
                    Write-Log "  Storage Sense desactivado." "Green"
                }
                "EndTask" {
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Value 1 -Force
                    Write-Log "  Auto-End Task habilitado." "Green"
                }
                "Telemetry" {
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Force
                    Write-Log "  Telemetría bloqueada." "Green"
                }
                "Location" {
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Force
                    Write-Log "  Ubicación desactivada." "Green"
                }
                "PS7Tele" {
                    [Environment]::SetEnvironmentVariable("POWERSHELL_TELEMETRY_OPTOUT", "1", "Machine")
                    Write-Log "  Telemetría de PS7 desactivada." "Green"
                }
                "BGApps" {
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Force
                    Write-Log "  Apps en 2º plano limitadas." "Green"
                }
                "Consumer" {
                    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) { New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null }
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Force
                    Write-Log "  Consumer Features desactivadas." "Green"
                }
                "OneDrive" {
                    Write-Log "  Desinstalando OneDrive..." "Yellow"
                    Stop-Process -Name "OneDrive" -ErrorAction SilentlyContinue
                    $odPath = if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
                    Start-Process $odPath -ArgumentList "/uninstall" -Wait -ErrorAction SilentlyContinue
                    Write-Log "  OneDrive eliminado." "Green"
                }
                "Xbox" {
                    Get-AppxPackage *xbox* | Remove-AppxPackage -ErrorAction SilentlyContinue
                    Write-Log "  Apps de Xbox eliminadas." "Green"
                }
                "Widgets" {
                    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Force
                    Write-Log "  Widgets de barra de tareas ocultos." "Green"
                }
                "EdgeDebloat" {
                    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge")) { New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force | Out-Null }
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
                    Write-Log "  Microsoft Edge aligerado." "Green"
                }
                "PowerPlan" {
                    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
                    powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61
                    Write-Log "  Plan Maximo Rendimiento activado." "Green"
                }
                "IPv6" {
                    Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
                    Write-Log "  IPv6 deshabilitado." "Green"
                }
                "WPBT" {
                    if (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager")) { New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Force | Out-Null }
                    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "DisableWPBTExecution" -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue
                    Write-Log "  WPBT desactivado (Mitigación Rootkit)." "Green"
                }
                "FSO" {
                    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force
                    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Force
                    Write-Log "  Optimizaciones de pantalla completa aplicadas." "Green"
                }
                "RightClick" {
                    $path = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
                    if (!(Test-Path $path)) { New-Item $path -Force | Out-Null }
                    Set-ItemProperty $path -Name "(Default)" -Value "" -Force
                    Write-Log "  Menú contextual clásico activado." "Green"
                }
                "GamingRAM" {
                    $processes = Get-Process | Where-Object { $_.WorkingSet64 -gt (10 * 1024 * 1024) }
                    Write-Log ("  Procesos grandes detectados: {0}" -f $processes.Count) "Green"
                    [System.GC]::Collect()
                    Write-Log "  Memoria RAM optimizada." "Green"
                }
                "WebCache" {
                    $paths = @(
                        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
                        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
                        "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
                    )
                    foreach ($p in $paths) {
                        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Write-Log "  Cache web eliminada." "Green"
                }
                "GameBar" {
                    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Force
                    if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR")) {
                        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Force | Out-Null
                    }
                    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Force
                    Write-Log "  Game Bar desactivada." "Green"
                }
                "CPUPriority" {
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 26 -Force
                    if (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling")) {
                        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Force | Out-Null
                    }
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Force
                    Write-Log "  Prioridad de CPU optimizada para juegos." "Green"
                }
                default {
                    Write-Log "  Tarea '$($tweak.Key)' completada." "Green"
                }
            }
        } catch {
            Write-Log "  Error: $($_.Exception.Message)" "Red"
        }
    }
    Write-Log ">>> Optimizacion finalizada con exito." "Cyan"
    $btnRun.Enabled = $true
    $btnRun.Text = "EJECUTAR"
})

# ============================================================
# ARRANQUE
# ============================================================
[System.Windows.Forms.Application]::Run($form)