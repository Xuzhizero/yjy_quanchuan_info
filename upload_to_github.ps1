# 上传到 GitHub 的脚本
# 使用前请确保已安装 Git: https://git-scm.com/download/win

$projectPath = "E:\2\20260112全信"
$remoteUrl = "git@github.com:Xuzhizero/yjy_quanchuan_info.git"

Set-Location $projectPath

# 初始化（如未初始化）
if (-not (Test-Path ".git")) {
    git init
}

# 添加远程（如未添加）
$remotes = git remote
if ($remotes -notcontains "origin") {
    git remote add origin $remoteUrl
} else {
    git remote set-url origin $remoteUrl
}

# 添加文件并提交
git add .
git status
git commit -m "Initial commit: 全信项目代码"

# 推送到 GitHub（首次推送可能需要设置上游分支）
git branch -M main
git push -u origin main

Write-Host "上传完成！" -ForegroundColor Green
