param(
    [Parameter(Mandatory = $true)]
    [string]$inputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 获取脚本目录
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MainImage = Join-Path $BaseDir "__Main__.png"
$TargetPath = "/usr/share/backgrounds/user/__Main__.png"

# 日志函数
function Write-Log
{
    param(
        [string]$message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($level)
    {
        "Info"
        { "Cyan"
        }
        "Warning"
        { "Yellow"
        }
        "Error"
        { "Red"
        }
        "Success"
        { "Green"
        }
    }

    Write-Host "[$timestamp] [$level] $message" -ForegroundColor $color
}

# 解析路径
function Resolve-FullPath
{
    param([string]$path)

    if ([System.IO.Path]::IsPathRooted($path))
    {
        return $path
    } else
    {
        return (Join-Path $BaseDir $path)
    }
}

$ResolvedPath = Resolve-FullPath $inputPath

function Test-PngSignature
{
    param([string]$file)

    if (-not (Test-Path $file -PathType Leaf))
    {
        return $false
    }

    try
    {
        $fs = [System.IO.File]::OpenRead($file)
        $buffer = New-Object byte[] 8

        $bytesRead = $fs.Read($buffer, 0, 8)
        $fs.Close()

        if ($bytesRead -ne 8)
        {
            Write-Log "文件太小，无法读取 PNG 头: $file" "Warning"
            return $false
        }

        # PNG 文件头: 89 50 4E 47 0D 0A 1A 0A (十进制: 137,80,78,71,13,10,26,10)
        $pngHeader = 137,80,78,71,13,10,26,10

        return (($buffer -join ',') -eq ($pngHeader -join ','))
    } catch
    {
        Write-Log "读取文件失败: $file - $_" "Error"
        return $false
    }
}

function Ensure-SwwwDaemon
{
    Write-Log "检查 swww-daemon 状态..." "Info"

    if (-not (Get-Process -Name "swww-daemon" -ErrorAction SilentlyContinue))
    {
        Write-Log "启动 swww-daemon..." "Info"
        Start-Process "swww-daemon" -WindowStyle Hidden

        $startTime = Get-Date
        for ($i = 0; $i -lt 30; $i++)
        {
            Start-Sleep -Milliseconds 100
            if (Get-Process -Name "swww-daemon" -ErrorAction SilentlyContinue)
            {
                $elapsed = ((Get-Date) - $startTime).TotalSeconds
                Write-Log "swww-daemon 启动成功 (耗时 $([math]::Round($elapsed, 2))s)" "Success"
                return
            }
        }

        throw "swww-daemon 启动失败（超时 3 秒）"
    } else
    {
        Write-Log "swww-daemon 已在运行" "Success"
    }
}

function Set-Wallpaper
{
    param([string]$img)

    if (-not (Test-Path $img -PathType Leaf))
    {
        throw "文件不存在: $img"
    }

    $extension = [System.IO.Path]::GetExtension($img).ToLower()
    if ($extension -ne ".png")
    {
        throw "仅允许 PNG 格式（当前扩展名: $extension）: $img"
    }

    Write-Log "验证 PNG 签名: $img" "Info"
    if (-not (Test-PngSignature $img))
    {
        throw "文件不是有效的 PNG（签名验证失败）: $img"
    }

    $needCopy = $true
    if (Test-Path $MainImage)
    {
        Write-Log "比较文件哈希..." "Info"
        $hash1 = (Get-FileHash $img -Algorithm SHA256).Hash
        $hash2 = (Get-FileHash $MainImage -Algorithm SHA256).Hash
        if ($hash1 -eq $hash2)
        {
            Write-Log "文件内容相同，跳过复制" "Info"
            $needCopy = $false
        }
    }

    if ($needCopy)
    {
        Write-Log "复制壁纸到缓存目录..." "Info"
        Copy-Item $img $MainImage -Force

        Write-Log "安装壁纸到系统目录..." "Info"
        $targetDir = Split-Path -Parent $TargetPath
        if (-not (Test-Path $targetDir))
        {
            sudo mkdir -p $targetDir
        }

        sudo install -m 644 $MainImage $TargetPath

        if ($LASTEXITCODE -ne 0)
        {
            throw "sudo install 失败（退出码: $LASTEXITCODE）"
        }
    }

    Write-Log "应用壁纸: $TargetPath" "Info"

    & swww img $TargetPath `
        --transition-type any `
        --transition-duration 1 `
        --transition-fps 60

    if ($LASTEXITCODE -ne 0)
    {
        throw "swww img 命令失败（退出码: $LASTEXITCODE）"
    }

    Write-Log "壁纸设置成功！" "Success"
}

function Get-Random-Png
{
    param([string]$dir)

    Write-Log "搜索目录中的 PNG 文件: $dir" "Info"

    $selected = $null
    $count = 0
    $scannedFiles = 0

    Get-ChildItem -Path $dir -Recurse -File -Filter "*.png" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $scannedFiles++

            if (-not (Test-PngSignature $_.FullName))
            {
                Write-Log "跳过无效文件: $($_.Name)" "Warning"
                return
            }

            $count++

            if ((Get-Random -Minimum 0 -Maximum $count) -eq 0)
            {
                $selected = $_.FullName
            }
        }

    Write-Log "扫描了 $scannedFiles 个文件，找到 $count 个有效 PNG" "Info"

    if ($count -eq 0)
    {
        throw "未找到有效 PNG 文件: $dir"
    }

    Write-Log "随机选择: $(Split-Path -Leaf $selected)" "Success"
    return $selected
}

# ---------------- 主流程 ----------------

try
{
    Write-Log "========== 壁纸设置脚本开始 ==========" "Info"
    Write-Log "输入路径: $inputPath" "Info"
    Write-Log "解析路径: $ResolvedPath" "Info"

    Ensure-SwwwDaemon

    if (Test-Path $ResolvedPath -PathType Leaf)
    {
        Write-Log "检测到文件模式" "Info"
        Set-Wallpaper $ResolvedPath
    } elseif (Test-Path $ResolvedPath -PathType Container)
    {
        Write-Log "检测到目录模式，将随机选择壁纸" "Info"
        $img = Get-Random-Png $ResolvedPath
        Set-Wallpaper $img
    } else
    {
        throw "路径不存在或无法访问: $ResolvedPath"
    }

    Write-Log "========== 壁纸设置完成 ==========" "Success"
} catch
{
    Write-Log "========== 脚本执行失败 ==========" "Error"
    Write-Log "错误信息: $_" "Error"
    Write-Log "错误位置: $($_.InvocationInfo.PositionMessage)" "Error"
    exit 1
}
