$targetPath = "$PSScriptRoot\Main"
Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-NoExit",
    "-Command",
    "`$Host.UI.RawUI.WindowTitle = 'Dotnet Watch'; `
    Set-Location '$targetPath'; `
    dotnet watch publish --no-build --no-restore -c:Debug"
)
