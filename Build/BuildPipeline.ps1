param(
    $Branch = "lab",
    $SourcePath = "$PSScriptRoot\..",
    $GitHubUserName = "apobekiaris",
    $GitHubToken = $env:GitHubToken,
    $DXApiFeed = $env:DxFeed,
    $artifactstagingdirectory,
    $bindirectory,
    [string]$AzureToken = $env:AzureToken,
    [string]$CustomVersion = "20.2.4.0",
    [string]$UseLastVersion="1",
    $XpandBlobOwnerSecret=$env:AzXpandBlobOwnerSecret,
    $AzureApplicationId=$env:AzApplicationId,
    $AzureTenantId=$env:AzTenantId,
    [switch]$SkipVersioning
)

if (!(Get-Module eXpandFramework -ListAvailable)) {
    $env:AzureToken = $AzureToken
    $env:AzOrganization = "eXpandDevOps"
    $env:AzProject = "eXpandFramework"
    $env:DxFeed = $DxApiFeed
}
"XpandPwsh"
Get-Module XpandPwsh -ListAvailable
"CustomVersion=$CustomVersion"

$ErrorActionPreference = "Stop"
$regex = [regex] '(\d{2}\.\d*)'
$result = $regex.Match($CustomVersion).Groups[1].Value;
& "$SourcePath\go.ps1" -InstallModules


Clear-NugetCache -Filter XpandPackages
Invoke-Script {
    Set-VsoVariable build.updatebuildnumber "$env:build_BuildNumber-$CustomVersion"
    
    Set-Location $SourcePath
    dotnet tool restore
    $latestMinors = Get-XAFLatestMinors 
    "latestMinors:"
    $latestMinors | Format-Table
    $CustomVersion = $latestMinors | Where-Object { "$($_.Major).$($_.Minor)" -eq $result }
    "CustomVersion=$CustomVersion"

    $DXVersion = Get-DevExpressVersion 

    if ($UseLastVersion -eq "1"){
        # Write-HostFormatted "Connecting to Azure" -Section
        # Connect-Az -ApplicationSecret $XpandBlobOwnerSecret -AzureApplicationId $AzureApplicationId -AzureTenantId $AzureTenantId
        # $build=(Get-AzBuilds -Definition Reactive.XAF-Lab -Tag "$DXVersion.0" -Top 1).id
        # Get-AzArtifact -BuildId $build -ArtifactName PipelineWorkspace -Outpath "$SourcePath"
        # "Bin files= $((Get-ChildItem "$SourcePath\bin" -Recurse).count)"
    }

    $taskList = "Build"
    . "$SourcePath\build\UpdateDependencies.ps1" $CustomVersion
    . "$SourcePath\build\UpdateLatestProjectVersion.ps1"
    $bArgs = @{
        packageSources = "$(Get-PackageFeed -Xpand);$DxApiFeed"
        tasklist       = $tasklist
        dxVersion      = $CustomVersion
        Branch         = $Branch
    }

    $SourcePath | ForEach-Object {
        Set-Location $_
        Move-PaketSource 0 $DXApiFeed
    }

    Set-Location "$SourcePath"
    

    Write-HostFormatted "Start-ProjectConverter version $CustomVersion"  -Section
    Start-XpandProjectConverter -version $CustomVersion -path $SourcePath -SkipInstall
    "PaketRestore $SourcePath"
    try {
        Invoke-PaketRestore -Strict 
    }
    catch {
        Remove-Item "$SourcePath\bin" -Recurse -Force -ErrorAction SilentlyContinue
        "PaketRestore Failed"
        Write-HostFormatted "PaketInstall $SourcePath (due to different Version)" -section
        dotnet paket install 
    }
    $nugetPackageFolder = "$env:USERPROFILE\.nuget\packages"
    if (Test-AzDevops) {
        $nugetPackageFolder = "D:\a\1\.nuget\packages"
    }
    & powershell.exe "$SourcePath\build\targets\Xpand.XAF.Modules.JobScheduler.Hangfire.ps1" -nugetPackagesFolder $nugetPackageFolder
    
    Get-AssemblyPublicKeyToken (Get-ChildItem $nugetPackageFolder "*Hangfire.core.dll" -Recurse | Select-Object -First 1)

    & $SourcePath\go.ps1 @bArgs

    Move-PaketSource 0 "C:\Program Files (x86)\DevExpress $(Get-VersionPart $DXVersion Minor)\Components\System\Components\Packages"
    if (Test-AzDevops) {
        # Write-HostFormatted "Partition artifacts" -Section
        # "net461","net472"|ForEach-Object{
        #     Move-Item "$SourcePath\bin\$_" "$SourcePath\$_"
        # }
        
    }
    
}