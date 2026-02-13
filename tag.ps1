$Tags = @{
    "Simple Asp.Net MVC application"                                                                        = "01_TrivialStart"
    "Introduce a web processor library (Lib)"                                                               = "02_WebProcessorLibrary"
    "Allow dotnet command line to build and publish without dependency on VS"                               = "03_EnableDotnetBuild"
    "Fix VS Build Acceleration by setting Main published bin directory as the actual project bin directory" = "04_FixVSBuildAccel"
    "Allow dotnet watch publish to handle Lib content files"                                                = "05_EnableDotnetWatch"
    "Instruct FUTDC to trigger the web application build"                                                   = "06_FUTDC"
    "Implement compilation of Asp.Net views"                                                                = "07_AspNetCompile"
}

$Tags.GetEnumerator() | ForEach-Object {
    $Comment = $_.Key
    $Tag = $_.Value
    $CommitId = git log --format="%H" -i --grep="$Comment"
    if (!$CommitId)
    {
        Write-Host -ForegroundColor Red "Failed to locate the commit $Comment"
        exit 1
    }
    Write-Host -NoNewline "$Comment                                  `r"
    git tag -f $Tag $CommitId
}
git push -f --tags
