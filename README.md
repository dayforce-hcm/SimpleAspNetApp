# Introduction

This repository contains a simple Asp.Net 5 application, with commits demonstrating a progression from trivial single project web application to a simple web application comprised from multiple projects that support sane build and publish protocol. This is, of course, an outdated technology. But understanding it may be helpful to those who plan to migrate to Asp.Net Core **gradually**.

It has 7 tagged stages:
```powershell
C:\work\SimpleAspNetApp [master ≡]> git tag
01_TrivialStart
02_WebProcessorLibrary
03_EnableDotnetBuild
04_FixVSBuildAccel
05_EnableDotnetWatch
06_FUTDC
07_AspNetCompile
C:\work\SimpleAspNetApp [master ≡]>
```
TL;DR
- **All the projects are SDK style**.
- The VS Build Acceleration feature is broken at [02_WebProcessorLibrary](#02_WebProcessorLibrary) and [03_EnableDotnetBuild](#03_EnableDotnetBuild).
- It is fixed at [04_FixVSBuildAccel](#04_FixVSBuildAccel)
- Changing the [Lib](Lib) `Content` files does **not** trigger the publishing of [Main](Main) by default. 3 options exist:
  - explicit `dotnet publish --nobuild` on the console, enabled since [03_EnableDotnetBuild](#03_EnableDotnetBuild)
  - `dotnet watch publish` - enabled since [05_EnableDotnetWatch](#05_EnableDotnetWatch)
  - FUTDC - enabled since [06_FUTDC](#06_FUTDC)
- Neither `dotnet watch publish` nor FUTDC recognize addition of new `Content` files in [Lib](Lib).

# 01_TrivialStart
Contains a single Asp.Net 5 project with a single controller:
```powershell
C:\work\SimpleAspNetApp [master ≡]> git ls-tree -r --name-only 01_TrivialStart
.gitignore
Directory.Build.props
Main/App_Start/RouteConfig.cs
Main/Content/Dashboard.css
Main/Content/Site.css
Main/Controllers/HomeController.cs
Main/Global.asax
Main/Global.asax.cs
Main/Main.csproj
Main/Properties/launchSettings.json
Main/Scripts/Dashboard.js
Main/Views/Home/Index.cshtml
Main/Views/Shared/_Layout.cshtml
Main/Views/_ViewStart.cshtml
Main/Views/web.config
Main/web.config
SimpleAspNetApp.sln
C:\work\SimpleAspNetApp [master ≡]>
```
The only interesting part about it is that it is an SDK style project, despite being an Asp.Net 5 project:
```xml
C:\work\SimpleAspNetApp [master ≡]> git show 01_TrivialStart:Main/Main.csproj
<Project Sdk="MSBuild.SDK.SystemWeb/4.0.104">
  <PropertyGroup>
    <TargetFramework>net472</TargetFramework>
    <LangVersion>preview</LangVersion>
    <AutoGenerateBindingRedirects>true</AutoGenerateBindingRedirects>
    <GeneratedBindingRedirectsAction>Overwrite</GeneratedBindingRedirectsAction>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNet.Mvc" Version="5.3.0" />
    <PackageReference Include="Microsoft.AspNet.Razor" Version="3.3.0" />
    <PackageReference Include="Microsoft.AspNet.WebPages" Version="3.3.0" />
  </ItemGroup>
</Project>
C:\work\SimpleAspNetApp [master ≡]>
```
It uses Roslyn API to build the Asp.Net views and enables VS Build Acceleration:
```xml
C:\work\SimpleAspNetApp [master ≡]> git show 01_TrivialStart:Directory.Build.props
<Project>
  <PropertyGroup>
    <ProduceReferenceAssembly Condition="'$(ProduceReferenceAssembly)' == ''">true</ProduceReferenceAssembly>
    <MicrosoftCodeDomProvidersDotNetCompilerPlatform_Version>4.1.0</MicrosoftCodeDomProvidersDotNetCompilerPlatform_Version>
    <MicrosoftNetCompilersToolset_Version>4.14.0</MicrosoftNetCompilersToolset_Version>
  </PropertyGroup>
</Project>
C:\work\SimpleAspNetApp [master ≡]>
```
Running it opens a simple CSHTML view with one button.

# 02_WebProcessorLibrary
A single web project is not a good representative of the real world. A real product could still be a single web application, but its implementation would be scattered across many projects. In our case, not only is the business logic scattered across, but so are the controllers, the views, the static content.

This commit represents this world where:
1. Controllers, views and static content are in a different project ([Lib](Lib)).
1. The web application is published into a git ignored location (as opposed to the web applicaton project home directory)
1. VS IDE cannot be used to run the web application, because we cannot easily customize where it expects to find it.
   - We do it with the help of a dedicated VS extension, but it is off scope here. Hence a script is provided to run IIS Express ([run.ps1](run.ps1)).
```powershell
C:\work\SimpleAspNetApp [master ≡]> git diff --name-status -M10 01_TrivialStart 02_WebProcessorLibrary
M       Directory.Build.props
R100    Main/Content/Dashboard.css      Lib/Content/Dashboard.css
R100    Main/Content/Site.css   Lib/Content/Site.css
R011    Main/Controllers/HomeController.cs      Lib/Controllers/HomeController.cs
A       Lib/Lib.csproj
R100    Main/Scripts/Dashboard.js       Lib/Scripts/Dashboard.js
R100    Main/Views/Home/Index.cshtml    Lib/Views/Home/Index.cshtml
R100    Main/Views/Shared/_Layout.cshtml        Lib/Views/Shared/_Layout.cshtml
R100    Main/Views/_ViewStart.cshtml    Lib/Views/_ViewStart.cshtml
R100    Main/Views/web.config   Lib/Views/web.config
M       Main/Main.csproj
A       Microsoft.Web.Publishing.targets
M       SimpleAspNetApp.sln
A       run.ps1
A       scratch/test.html
C:\work\SimpleAspNetApp [master ≡]>
```
## Publishing
The single project application does not have to deal with it, but the multi-project does. The default behavior of the Asp.Net 5 build is to publish automatically to `$(OutDir)_PublishedWebsites\($MSBuildProjectName)` when `OutDir` is explicitly set to be different from the web application home project directory. We leverage this behavior in order to implement the publish on build logic as well as explicit support for the `publish` target:
```diff
C:\work\SimpleAspNetApp [master ≡]> git diff -U0 01_TrivialStart 02_WebProcessorLibrary -- .\Directory.Build.props
diff --git a/Directory.Build.props b/Directory.Build.props
index b27cc79..c3decb3 100644
--- a/Directory.Build.props
+++ b/Directory.Build.props
@@ -5,0 +6,5 @@
+    <PublishOnBuild Condition="'$(PublishOnBuild)' == ''">true</PublishOnBuild>
+    <OutDir>$(MSBuildThisFileDirectory)bin\</OutDir>
+    <AspNetTargetsPath>$(MSBuildThisFileDirectory)</AspNetTargetsPath>
+    <Disable_CopyWebApplication Condition="'$(PublishOnBuild)' != true">true</Disable_CopyWebApplication>
+    <OnBefore_CopyWebApplication>Before_CopyWebApplicationLegacy;_CopyWebApplicationLegacy</OnBefore_CopyWebApplication>
C:\work\SimpleAspNetApp [master ≡]>
```
- `PublishOnBuild` - controls whether to publish on build. Defaults to `true`.
- `OutDir` is set explicitly to the root bin directory. This has two effects:
  - all the projects build into the root bin directory, which becomes the shared bin directory. This is very similar to how a CI pipeline may configure it.
  - the default legacy Asp.Net web application publishing logic kicks in. It is implemented in **C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Microsoft\VisualStudio\v17.0\WebApplications\Microsoft.WebApplication.targets**
- `AspNetTargetsPath` is set to the root directory. This instructs **Microsoft.WebApplication.targets** to load the file [Microsoft.Web.Publishing.targets](Microsoft.Web.Publishing.targets) found at the root directory.
- `Disable_CopyWebApplication` - disables the legacy Asp.Net web application publishing logic, if we do NOT want to publish on build.
- `OnBefore_CopyWebApplication` - allows us to insert our own target before the legacy web application publishing logic starts

The legacy publishing procedure has a big defect - it does not attempt to collect Content from the referenced projects. This actually agrees with the VS inability to start a legacy web application from anything except its home project. It aligns with the idea that **ALL** the views and static content should be found under the main web application project. Which is incompatible with the reality of big applications. So, we need to fix it:
```xml
C:\work\SimpleAspNetApp [master ≡]> git show 02_WebProcessorLibrary:Microsoft.Web.Publishing.targets
<Project>
  <PropertyGroup>
    <ReferencedContentManifest>$(IntermediateOutputPath)ReferencedContent.txt</ReferencedContentManifest>
  </PropertyGroup>

  <Target Name="Publish" DependsOnTargets="_CopyWebApplication" />

  <Target Name="_GetReferencedProjectPublishItems">
    <MSBuild Projects="@(ProjectReference)"
             Targets="GetCopyToPublishDirectoryItems"
             Properties="TargetFramework=$(TargetFramework)"
             BuildInParallel="$(BuildInParallel)">
      <Output TaskParameter="TargetOutputs" ItemName="_ReferencedProjectPublishItems" />
    </MSBuild>
  </Target>

  <Target Name="Before_CopyWebApplicationLegacy" DependsOnTargets="_GetReferencedProjectPublishItems">
    <!-- Add referenced project items to Content so they get copied -->
    <ItemGroup>
      <Content Include="%(_ReferencedProjectPublishItems.FullPath)" Link="%(_ReferencedProjectPublishItems.TargetPath)" />
    </ItemGroup>

    <!-- Read what was copied last time -->
    <ReadLinesFromFile File="$(ReferencedContentManifest)" Condition="Exists('$(ReferencedContentManifest)')">
      <Output TaskParameter="Lines" ItemName="_FilesToDelete" />
    </ReadLinesFromFile>

    <ItemGroup>
      <!-- Get all content destination paths (using Link if set, otherwise relative path) -->
      <_CurrentPublishedFiles Include="@(Content->'$(WebProjectOutputDir)\%(Link)')" Condition="'%(Content.Link)' != ''" />
      <_CurrentPublishedFiles Include="@(Content->'$(WebProjectOutputDir)\%(RelativeDir)%(FileName)%(Extension)')" Condition="'%(Content.Link)' == ''" />

      <!-- Remove files that still exist from deletion list -->
      <_FilesToDelete Remove="@(_CurrentPublishedFiles)" />
    </ItemGroup>

    <!-- Delete obsolete files -->
    <Delete Files="@(_FilesToDelete)" />

    <!-- Write manifest for next time -->
    <WriteLinesToFile File="$(ReferencedContentManifest)"
                      Lines="@(_CurrentPublishedFiles)"
                      Overwrite="true"
                      WriteOnlyWhenDifferent="true" />
  </Target>
</Project>
C:\work\SimpleAspNetApp [master ≡]>
```
- The `Before_CopyWebApplicationLegacy` target is invoked before the legacy publishing procedure and it collects the `Content` from the referenced projects.
  - It also maintains a list of the currently published files in order to be able to delete the stale ones. The legacy procedure allows to cleanup before publish by removing the entire publish directory, which is too coarse in my opinion, so we do not use this functionality.
- The `Publish` target is added so that we could call `dotnet publish` in the future.

Finally, the [Lib](Lib) project must setup the `Content` item group correctly:
```xml
C:\work\SimpleAspNetApp [master ≡]> git show 02_WebProcessorLibrary:Lib/Lib.csproj
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net472</TargetFramework>
    <LangVersion>preview</LangVersion>
    <IsPublishable>False</IsPublishable>
  </PropertyGroup>
  <ItemGroup>
    <None Remove="Content/**/*.*;Scripts/**/*.*;Views/**/*.*" />
    <Content Include="Content/**/*.*;Scripts/**/*.*;Views/**/*.*" />
    <Content Update="@(Content)" CopyToPublishDirectory="PreserveNewest" />
  </ItemGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNet.Mvc" Version="5.3.0" />
  </ItemGroup>
</Project>
C:\work\SimpleAspNetApp [master ≡]>
```

## Building (and publishing)
```powershell
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> dir

    Directory: C:\work\SimpleAspNetApp

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----            2/9/2026  3:47 PM                Lib
d----            2/9/2026  3:47 PM                Main
-a---            2/8/2026  6:30 PM             24 .gitignore
-a---            2/9/2026  3:47 PM            827 Directory.Build.props
-a---            2/9/2026  3:11 PM            758 Microsoft.Web.Publishing.targets
-a---            2/9/2026  3:11 PM            803 run.ps1
-a---            2/9/2026  3:47 PM           1889 SimpleAspNetApp.sln

C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> msbuild -v:m -m -restore
MSBuild version 17.14.23+b0019275e for .NET Framework

  Determining projects to restore...
  Restored C:\work\SimpleAspNetApp\Lib\Lib.csproj (in 960 ms).
  Restored C:\work\SimpleAspNetApp\Main\Main.csproj (in 961 ms).
  Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
  Main -> C:\work\SimpleAspNetApp\bin\Main.dll
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> tree bin
Folder PATH listing for volume Windows
Volume serial number is 268C-52B1
C:\WORK\SIMPLEASPNETAPP\BIN
└───_PublishedWebsites
    └───Main
        ├───bin
        │   └───roslyn
        ├───Content
        ├───Scripts
        └───Views
            ├───Home
            └───Shared
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> test-path .\bin\_PublishedWebsites\Main\bin\Main.dll
True
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]>
```
To just publish without building run `msbuild -v:m -m -t:Publish`:
```powershell
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> del -r -force bin
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> msbuild -v:m -m -t:Publish
MSBuild version 17.14.23+b0019275e for .NET Framework

C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> tree bin
Folder PATH listing for volume Windows
Volume serial number is 268C-52B1
C:\WORK\SIMPLEASPNETAPP\BIN
└───_PublishedWebsites
    └───Main
        ├───bin
        ├───Content
        ├───Scripts
        └───Views
            ├───Home
            └───Shared
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> test-path .\bin\_PublishedWebsites\Main\bin\Main.dll
True
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]>
```
### Adding new/Deleting existing content files
This is an important scenario to make sure it works correctly.

- Adding a new content file
  ```powershell
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  False
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> copy scratch\test.html .\Lib\Content\
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary) +1 ~0 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  False
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary) +1 ~0 -0 !]> msbuild -v:m -m -t:Publish
  MSBuild version 17.14.23+b0019275e for .NET Framework
  MSBuild logs and debug information will be at "c:\temp\binlogs"

  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary) +1 ~0 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  True
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary) +1 ~0 -0 !]>
  ```
- Deleting an existing content file
  ```powershell
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary) +1 ~0 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  True
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary) +1 ~0 -0 !]> del .\Lib\Content\test.html
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  True
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> msbuild -v:m -m -t:Publish
  MSBuild version 17.14.23+b0019275e for .NET Framework
  MSBuild logs and debug information will be at "c:\temp\binlogs"

  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  False
  C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]>
  ```

Note, that we cannot use `dotnet build` or `dotnet publish` just yet:
```powershell
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]> dotnet build
Restore complete (0.8s)
   failed with 1 error(s) (0.0s)
    C:\Users\P11F70F\.nuget\packages\msbuild.sdk.systemweb\4.0.104\Sdk\Sdk.targets(32,3): error MSB4019: The imported project "C:\Program Files\dotnet\sdk\10.0.102\Microsoft\VisualStudio\v17.0\WebApplications\Microsoft.WebApplication.targets" was not found. Confirm that the expression in the Import declaration "$(WebApplicationsTargetPath)", which evaluated to "C:\Program Files\dotnet\sdk\10.0.102\Microsoft\VisualStudio\v17.0\WebApplications\Microsoft.WebApplication.targets", is correct, and that the file exists on disk.
  Lib net472 succeeded (0.2s) → bin\Lib.dll

Build failed with 1 error(s) in 1.1s
C:\work\SimpleAspNetApp [(02_WebProcessorLibrary)]>
```
# 03_EnableDotnetBuild
```powershell
C:\work\SimpleAspNetApp [master ≡]> git diff --name-status 02_WebProcessorLibrary 03_EnableDotnetBuild
M       Directory.Build.props
A       Microsoft.WebApplication.targets
M       SimpleAspNetApp.sln
C:\work\SimpleAspNetApp [master ≡]>
```
We save a private copy of **C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Microsoft\VisualStudio\v17.0\WebApplications\Microsoft.WebApplication.targets** and instruct the `MSBuild.SDK.SystemWeb` SDK to use it instead of the one from the VS installation:
```diff
C:\work\SimpleAspNetApp [master ≡]> git diff -U0 02_WebProcessorLibrary 03_EnableDotnetBuild -- .\Directory.Build.props
diff --git a/Directory.Build.props b/Directory.Build.props
index c3decb3..0bfd803 100644
--- a/Directory.Build.props
+++ b/Directory.Build.props
@@ -10,0 +11 @@
+    <WebApplicationsTargetPath>$(MSBuildThisFileDirectory)Microsoft.WebApplication.targets</WebApplicationsTargetPath>
C:\work\SimpleAspNetApp [master ≡]>
```
Now we can use `dotnet build` and `dotnet publish`:
1. Building without publishing
   ```powershell
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> dir

       Directory: C:\work\SimpleAspNetApp

   Mode                 LastWriteTime         Length Name
   ----                 -------------         ------ ----
   d----            2/9/2026  4:14 PM                Lib
   d----            2/9/2026  4:14 PM                Main
   -a---            2/8/2026  6:30 PM             24 .gitignore
   -a---            2/9/2026  4:13 PM            947 Directory.Build.props
   -a---            2/9/2026  3:11 PM            758 Microsoft.Web.Publishing.targets
   -a---            2/9/2026  4:09 PM          20332 Microsoft.WebApplication.targets
   -a---            2/9/2026  3:11 PM            803 run.ps1
   -a---            2/9/2026  4:13 PM           1960 SimpleAspNetApp.sln

   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> dotnet build -p:PublishOnBuild=false
   Restore complete (0.8s)
     Lib net472 succeeded (0.1s) → bin\Lib.dll
     Main net472 succeeded (0.3s) → bin\Main.dll

   Build succeeded in 1.4s
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> tree bin
   Folder PATH listing for volume Windows
   Volume serial number is 268C-52B1
   C:\WORK\SIMPLEASPNETAPP\BIN
   └───_PublishedWebsites
       └───Main
           └───bin
               └───roslyn
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> test-path .\bin\_PublishedWebsites\Main\bin\Main.dll
   False
   ```
   Notice the published bin directory does **NOT** contain the Main web application. There is only the roslyn folder there.
1. Publishing without building
   ```powershell
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> dotnet publish --no-build

   Build succeeded in 0.3s
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> tree bin
   Folder PATH listing for volume Windows
   Volume serial number is 268C-52B1
   C:\WORK\SIMPLEASPNETAPP\BIN
   └───_PublishedWebsites
       └───Main
           ├───bin
           │   └───roslyn
           ├───Content
           ├───Scripts
           └───Views
               ├───Home
               └───Shared
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]> test-path .\bin\_PublishedWebsites\Main\bin\Main.dll
   True
   C:\work\SimpleAspNetApp [(03_EnableDotnetBuild)]>
   ```

## VS Build Acceleration is broken
At this point when we change the private surface of the [Lib](Lib) project, the VS Build Acceleration feature would copy the Lib.dll to the bin directory of the [Main](Main) project, which is the same since both build into the shared bin directory **bin** found at the root of the repository. I.e. there is nothing to copy.

The only problem is that the [Main](Main) web application is running from the published bin directory **bin\_PublishedWebsites\Main\bin**, where we still have outdated Lib.dll.

One can easily observe this behavior by following these steps:
1. Open the solution in VS
1. Build the code
   ```
   Build started at 4:25 PM...
   1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
   1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
   2>------ Build started: Project: Main, Configuration: Debug Any CPU ------
   2>Main -> C:\work\SimpleAspNetApp\bin\Main.dll
   ========== Build: 2 succeeded, 0 failed, 0 up-to-date, 0 skipped ==========
   ========== Build completed at 4:25 PM and took 01.219 seconds ==========
   ```
1. Run the [run.ps1](run.ps1) script
   - It should open http://localhost:5100/ in the browser automatically
1. Press the "Test Ping" button. It should display a JSON like this:
   ```json
   {
     "Same": true,
     "Built": {
       "FullName": "C:\\work\\SimpleAspNetApp\\bin\\Lib.dll",
       "LastWriteTime": "2026-02-09 16:25:57",
       "FileHash": "EB7A20561EDF24A8A4A5FA439F4231E6CBE8CEEB1BB4F404167894E1C44F92E4"
     },
     "Loaded": {
       "FullName": "$env:TEMP\\Temporary ASP.NET Files\\root\\8b48b336\\d0270935\\assembly\\dl3\\52820a29\\7c6be0ad_0a9adc01\\Lib.dll",
       "LastWriteTime": "2026-02-09 17:23:33",
       "FileHash": "EB7A20561EDF24A8A4A5FA439F4231E6CBE8CEEB1BB4F404167894E1C44F92E4"
     }
   }
   ```
   ![The first run](image1.png)

The output tells us the following:
1. The web application loads the `Lib.dll` from `$env:TEMP\Temporary ASP.NET Files\root\8b48b336\d0270935\assembly\dl3\52820a29\7c6be0ad_0a9adc01`
1. The `Lib.dll` currently in the shared bin directory (`C:\work\SimpleAspNetApp\bin\Lib.dll`) has the same file hash, i.e. both dlls are identical.

Now let us modify the file [HomeController.cs](Lib/Controllers/HomeController.cs) by adding the `Version` property to the action result:
```csharp
return Json(new
{
    Version = 1,                            // THIS IS NEW CODE
    Same = builtFileHash == loadedFileHash,
    Built = new
    {
        builtLibFileInfo.FullName,
        LastWriteTime = builtLibFileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"),
        FileHash = builtFileHash
    },
    Loaded = new
    {
        FullName = loadedLibFileInfo.FullName.Replace(Environment.GetEnvironmentVariable("TEMP"), "$env:TEMP"),
        LastWriteTime = loadedLibFileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"),
        FileHash = loadedFileHash
    }
}, JsonRequestBehavior.AllowGet);
```
And build it:
```
Build started at 5:34 PM...
1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
========== Build: 1 succeeded, 0 failed, 1 up-to-date, 0 skipped ==========
========== Build completed at 5:34 PM and took 02.372 seconds ==========
```
Notice 1 project is up-to-date - that is the Main project. This is VS Build Acceleration at work, even though there is no output confirming it. I suppose because no dll had to be copied anywhere - Lib and Main share the same bin directory.

IIS Express is still running, so let us press the button again. This time the output is:
```json
{
  "Same": false,
  "Built": {
    "FullName": "C:\\work\\SimpleAspNetApp\\bin\\Lib.dll",
    "LastWriteTime": "2026-02-09 17:34:29",
    "FileHash": "A06A1D777E341F0CFDB7E9FDBD3F99D6254A04D1C9C25EC0BB2DC2D08315C520"
  },
  "Loaded": {
    "FullName": "$env:TEMP\\Temporary ASP.NET Files\\root\\8b48b336\\d0270935\\assembly\\dl3\\52820a29\\7c6be0ad_0a9adc01\\Lib.dll",
    "LastWriteTime": "2026-02-09 17:23:33",
    "FileHash": "EB7A20561EDF24A8A4A5FA439F4231E6CBE8CEEB1BB4F404167894E1C44F92E4"
  }
}
```
Which confirms the problem statement - VS build acceleration does not help, because it is unaware of the publish directory.

The next commit shows how we fix VS Build Acceleration to work correctly in our circumstances.

# 04_FixVSBuildAccel
VS Build Acceleration is too cool to give up on. When it works, it is much better than FUTDC. We fix it by changing the bin directory of the web application to be the same as the published bin directory:
```diff
C:\work\SimpleAspNetApp [master ≡]> git diff --name-status 03_EnableDotnetBuild 04_FixVSBuildAccel
M       Directory.Build.props
M       SimpleAspNetApp.sln
A       WebApp.props
C:\work\SimpleAspNetApp [master ≡]> git diff -U0 03_EnableDotnetBuild 04_FixVSBuildAccel -- Directory.Build.props
diff --git a/Directory.Build.props b/Directory.Build.props
index 0bfd803..8beb122 100644
--- a/Directory.Build.props
+++ b/Directory.Build.props
@@ -4,2 +3,0 @@
-    <MicrosoftCodeDomProvidersDotNetCompilerPlatform_Version>4.1.0</MicrosoftCodeDomProvidersDotNetCompilerPlatform_Version>
-    <MicrosoftNetCompilersToolset_Version>4.14.0</MicrosoftNetCompilersToolset_Version>
@@ -8,4 +5,0 @@
-    <AspNetTargetsPath>$(MSBuildThisFileDirectory)</AspNetTargetsPath>
-    <Disable_CopyWebApplication Condition="'$(PublishOnBuild)' != true">true</Disable_CopyWebApplication>
-    <OnBefore_CopyWebApplication>Before_CopyWebApplicationLegacy;_CopyWebApplicationLegacy</OnBefore_CopyWebApplication>
-    <WebApplicationsTargetPath>$(MSBuildThisFileDirectory)Microsoft.WebApplication.targets</WebApplicationsTargetPath>
@@ -12,0 +7 @@
+  <Import Project="$(MSBuildThisFileDirectory)WebApp.props" Condition="'$(UsingMSBuildSDKSystemWeb)' == true" />
C:\work\SimpleAspNetApp [master ≡]>
```
Essentially we are adding a build script dedicated to the web application, moving all the relevant configuration there and adding some more:
```xml
C:\work\SimpleAspNetApp [master ≡]> git show 04_FixVSBuildAccel:WebApp.props
<Project>
  <PropertyGroup>
    <MicrosoftCodeDomProvidersDotNetCompilerPlatform_Version>4.1.0</MicrosoftCodeDomProvidersDotNetCompilerPlatform_Version>
    <MicrosoftNetCompilersToolset_Version>4.14.0</MicrosoftNetCompilersToolset_Version>
    <AspNetTargetsPath>$(MSBuildThisFileDirectory)</AspNetTargetsPath>
    <Disable_CopyWebApplication Condition="'$(PublishOnBuild)' != true">true</Disable_CopyWebApplication>
    <OnBefore_CopyWebApplication>Before_CopyWebApplicationLegacy;_CopyWebApplicationLegacy</OnBefore_CopyWebApplication>
    <WebApplicationsTargetPath>$(MSBuildThisFileDirectory)Microsoft.WebApplication.targets</WebApplicationsTargetPath>
    <WebProjectOutputDir>$(OutDir)_PublishedWebsites\$(MSBuildProjectName)</WebProjectOutputDir>
    <OutDir>$(WebProjectOutputDir)\bin\</OutDir>
    <WebProjectOutputDirInsideProject Condition="'$(PublishOnBuild)' == true">False</WebProjectOutputDirInsideProject>
  </PropertyGroup>
</Project>
C:\work\SimpleAspNetApp [master ≡]>
```
The key property is `OutDir` - we override the previously assigned value (the shared bin directory) to be the published bin location.

Let us see the difference in action by first building without publishing and then publishing without building:
1. Building without publishing
   ```powershell
   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]> dir

       Directory: C:\work\SimpleAspNetApp

   Mode                 LastWriteTime         Length Name
   ----                 -------------         ------ ----
   d----            2/9/2026  6:00 PM                Lib
   d----            2/9/2026  6:00 PM                Main
   -a---            2/8/2026  6:30 PM             24 .gitignore
   -a---            2/9/2026  5:58 PM            425 Directory.Build.props
   -a---            2/9/2026  3:11 PM            758 Microsoft.Web.Publishing.targets
   -a---            2/9/2026  4:23 PM          20332 Microsoft.WebApplication.targets
   -a---            2/9/2026  3:11 PM            803 run.ps1
   -a---            2/9/2026  5:46 PM           1991 SimpleAspNetApp.sln
   -a---            2/9/2026  5:51 PM            966 WebApp.props

   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]> dotnet build -p:PublishOnBuild=false
   Restore complete (1.0s)
     Lib net472 succeeded (1.2s) → bin\Lib.dll
     Main net472 succeeded (0.4s) → bin\_PublishedWebsites\Main\bin\Main.dll

   Build succeeded in 2.6s
   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]> tree bin
   Folder PATH listing for volume Windows
   Volume serial number is 268C-52B1
   C:\WORK\SIMPLEASPNETAPP\BIN
   └───_PublishedWebsites
       └───Main
           └───bin
               └───roslyn
   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]> dir .\bin\_PublishedWebsites\Main\bin\Main.dll

       Directory: C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin

   Mode                 LastWriteTime         Length Name
   ----                 -------------         ------ ----
   -a---            2/9/2026  6:00 PM           6656 Main.dll

   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]>
   ```
   Notice that unlike before, now the published bin directory also contains the Main web application, in addition to the roslyn folder.
1. Publishing without building
   ```powershell
   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]> dotnet publish --no-build
   Build succeeded in 0.3s
   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]> tree bin
   Folder PATH listing for volume Windows
   Volume serial number is 268C-52B1
   C:\WORK\SIMPLEASPNETAPP\BIN
   └───_PublishedWebsites
       └───Main
           ├───bin
           │   └───roslyn
           ├───Content
           ├───Scripts
           └───Views
               ├───Home
               └───Shared
   C:\work\SimpleAspNetApp [(04_FixVSBuildAccel)]>
   ```

Let us repeat the aforementioned workflow to confirm that VS Build Acceleration now works:
1. Open the solution in VS
1. Build
   ```
   Build started at 6:12 PM...
   1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
   1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
   2>------ Build started: Project: Main, Configuration: Debug Any CPU ------
   2>Main -> C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin\Main.dll
   ========== Build: 2 succeeded, 0 failed, 0 up-to-date, 0 skipped ==========
   ========== Build completed at 6:12 PM and took 02.517 seconds ==========
   ```
1. Run the script [run.ps1](run.ps1)
1. Click the button to get something like this:
   ```json
   {
     "Same": true,
     "Built": {
       "FullName": "C:\\work\\SimpleAspNetApp\\bin\\Lib.dll",
       "LastWriteTime": "2026-02-09 18:10:54",
       "FileHash": "3D9E95B98D38F65517612026D03172BA000C2EF11C6AC58AB5087C71DCA78F57"
     },
     "Loaded": {
       "FullName": "$env:TEMP\\Temporary ASP.NET Files\\root\\8b48b336\\d0270935\\assembly\\dl3\\52820a29\\8f15ab57_199adc01\\Lib.dll",
       "LastWriteTime": "2026-02-09 18:13:32",
       "FileHash": "3D9E95B98D38F65517612026D03172BA000C2EF11C6AC58AB5087C71DCA78F57"
     }
   }
   ```
1. Add `Version = 1,` to the JSON result in the file [HomeController.cs](Lib/Controllers/HomeController.cs)
1. Build
   ```
   Build started at 6:18 PM...
   1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
   1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
   ========== Build: 1 succeeded, 0 failed, 1 up-to-date, 0 skipped ==========
   ========== Build completed at 6:18 PM and took 01.088 seconds ==========
   Visual Studio accelerated 1 project(s), copying 2 file(s). See https://aka.ms/vs-build-acceleration.
   ```
   **Aha** - VS Build Acceleration confirmation message! That means it really copied Lib.dll to Main's bin directory, which is also its published bin directory.
1. Press the button in the app again. Notice the message `Loading...` for a few seconds - this is IIS Express recompiling the views and then:
   ```json
   {
     "Version": 1,
     "Same": true,
     "Built": {
       "FullName": "C:\\work\\SimpleAspNetApp\\bin\\Lib.dll",
       "LastWriteTime": "2026-02-09 18:18:19",
       "FileHash": "5889B32575F67023D755748A72BCFA5ED4B85A681D5640F442F900F73745BEB0"
     },
     "Loaded": {
       "FullName": "$env:TEMP\\Temporary ASP.NET Files\\root\\8b48b336\\d0270935\\assembly\\dl3\\52820a29\\54a85a60_1a9adc01\\Lib.dll",
       "LastWriteTime": "2026-02-09 18:20:16",
       "FileHash": "5889B32575F67023D755748A72BCFA5ED4B85A681D5640F442F900F73745BEB0"
     }
   }
   ```
   **VS Build Acceleration works!**

## Views and static content
So we solved the problem with binary dependencies - the VS Build Acceleration takes care of them. However, we still have a problem with the views and the static content.

(In Asp.Net Core the views are compiled into the binary and so fixing the VS Build Acceleration also takes care of the changes to views.)

Let us confirm:
1. Open [Index.cshtml](Lib/Views/Home/Index.cshtml) and rename the "Test Ping" button to "Test"
1. Build
   ```
   Build started at 6:27 PM...
   ========== Build: 0 succeeded, 0 failed, 2 up-to-date, 0 skipped ==========
   ========== Build completed at 6:27 PM and took 00.042 seconds ==========
   ```
   Nothing is built because FUTDC does not consider views as a trigger for a build.
1. Refresh the open page (http://localhost:5100/) - the button still shows "Test Ping".

I see two ways to deal with it:
1. Leverage `dotnet watch publish`
1. Instruct FUTDC to treat views and static content as build triggers.

# 05_EnableDotnetWatch
The purpose of this commit is to enable `dotnet watch publish` workflow where modified static content or views are automatically published.
```diff
C:\work\SimpleAspNetApp [master ≡]> git diff --name-status 04_FixVSBuildAccel 05_EnableDotnetWatch
M       Directory.Build.props
A       watch.ps1
C:\work\SimpleAspNetApp [master ≡]> git diff -U0 04_FixVSBuildAccel 05_EnableDotnetWatch -- .\Directory.Build.props
diff --git a/Directory.Build.props b/Directory.Build.props
index 8beb122..439fb04 100644
--- a/Directory.Build.props
+++ b/Directory.Build.props
@@ -7,0 +8,21 @@
+
+  <ItemDefinitionGroup>
+    <Compile>
+      <Watch>False</Watch>
+    </Compile>
+    <EmbeddedResource>
+      <Watch>False</Watch>
+    </EmbeddedResource>
+  </ItemDefinitionGroup>
+
+  <Target Name="UnwatchProjectFile" AfterTargets="_CoreCollectWatchItems">
+    <ItemGroup>
+      <Watch Remove="$(MSBuildProjectFullPath)" />
+    </ItemGroup>
+  </Target>
+
+  <Target Name="_AspNetCustomCollectWatchItems" BeforeTargets="_CoreCollectWatchItems">
+    <ItemGroup>
+      <Watch Include="%(Content.FullPath)" />
+    </ItemGroup>
+  </Target>
C:\work\SimpleAspNetApp [master ≡]>
```
I am not interested to run publish when the C# source code or the project file change - VS IDE will build the code just fine and letting also `dotnet watch publish` build it potentially at the same time does not seem to be a good idea. Therefore I turn off watching for these files. On the other hand, the project `Content` is marked to be watched for.

Next the script itself:
```powershell
C:\work\SimpleAspNetApp [master ≡]> cat .\watch.ps1
$targetPath = "$PSScriptRoot\Main"
Start-Process powershell -ArgumentList @(
    "-NoProfile",
    "-NoExit",
    "-Command",
    "`$Host.UI.RawUI.WindowTitle = 'Dotnet Watch'; `
    Set-Location '$targetPath'; `
    dotnet watch publish --no-build -c:Debug"
)
C:\work\SimpleAspNetApp [master ≡]>
```
Unfortunately, I failed to figure out how to watch the solution itself or how to pass the project path on the command line. The only combination that worked for me is run the command from within the relevant project directory.

Other than that, it seems to be working.
Let us try it:
1. Revert the changes to the view (i.e. restore the button name as "Test Ping")
1. Run the [watch.ps1](watch.ps1) script.
1. Change the name of the button to "Test" and notice a movement in the watch window (takes ~2 seconds).
1. Refresh the open page (http://localhost:5100/) - the button should now show "Test".
1. Revert the view and refresh the page - the button should show "Test Ping" again.

## Adding new/Deleting existing content files
So we know this scenario works fine with the direct `dotnet publish --no-build` command. Let us check how it behaves with `dotnet watch publish`.

- Adding a new content file
  ```powershell
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch)]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  False
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch)]> .\watch.ps1
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch)]> copy scratch\test.html .\Lib\Content\
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch) +1 ~0 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  False
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch) +1 ~0 -0 !]>
  ```
  At this point in an ideal world we expect the watch window to come to life and indicate that it did something. Alas, nothing happens. And it is a long standing and known issue - https://github.com/dotnet/aspnetcore/issues/8321. **It is open for almost 7 years now.**

  Let us kill the watch window and retry the second scenario:

- Deleting an existing content file
  ```powershell
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch) +1 ~0 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  False
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch) +1 ~0 -0 !]> .\watch.ps1
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch) +1 ~0 -0 !]> curl.exe http://localhost:5100/Content/test.html
  <!DOCTYPE html>
  <html>
  <head>
      <title>Test Page</title>
  </head>
  <body>
      <h1>Test Content from Lib</h1>
      <p>This is a standalone test page to verify FUTDC triggers when content changes.</p>
      <p>Current time: <span id="time"></span></p>
      <script>
          document.getElementById('time').textContent = new Date().toLocaleString();
      </script>
  </body>
  </html>
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch) +1 ~0 -0 !]> del .\Lib\Content\test.html
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch)]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  False
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch)]> curl.exe -o NUL -s -w "%{http_code}" http://localhost:5100/Content/test.html
  404
  C:\work\SimpleAspNetApp [(05_EnableDotnetWatch)]>
  ```
  So deleting the file is picked up by `dotnet watch publish` a few seconds later and the file is deleted from the publish location. As a result the same url returns 404.

# 06_FUTDC
The purpose of this commit is to allow FUTDC to recognize changes to the `Content` files and trigger the Main web application build, which includes the publish logic by default.
```powershell
C:\work\SimpleAspNetApp [master ≡]> git diff --name-status 05_EnableDotnetWatch 06_FUTDC
A       Directory.Build.targets
A       EnableContentPublishThruFUTDC.targets
M       SimpleAspNetApp.sln
C:\work\SimpleAspNetApp [master ≡]>
```
The logic is unique to the web applications and therefore we invoke it only for them:
```xml
C:\work\SimpleAspNetApp [(06_FUTDC)]> cat .\Directory.Build.targets
<Project>
  <Import Project="$(MSBuildThisFileDirectory)EnableContentPublishThruFUTDC.targets"
          Condition="'$(UsingMSBuildSDKSystemWeb)' == true And '$(EnableContentPublishThruFUTDC)' == true" />
</Project>
C:\work\SimpleAspNetApp [(06_FUTDC)]>
```
The support is conditional for the reasons I explain a bit later.
```xml
C:\work\SimpleAspNetApp [(06_FUTDC)]> cat EnableContentPublishThruFUTDC.targets
<Project>
  <PropertyGroup>
    <!--Marker file to track when referenced project content is copied -->
    <ReferencedContentFUTDCMarker>$(IntermediateOutputPath)ReferencedContentFUTDC.marker</ReferencedContentFUTDCMarker>
  </PropertyGroup>

  <ItemGroup>
    <!-- Track own Content files as inputs in web projects -->
    <UpToDateCheckInput Include="@(Content)" />
    <!-- Track the marker file as output for referenced content -->
    <UpToDateCheckOutput Include="$(ReferencedContentFUTDCMarker)" Set="ReferencedProjectContent" />
    <!-- Trigger a design-time build when the referenced content manifest changes,
         so that the FUTDC input set is refreshed after files are added/removed -->
    <AdditionalDesignTimeBuildInput Include="$(ReferencedContentManifest)" />
  </ItemGroup>

  <Target Name="AddReferencedProjectPublishItemsToFUTDC"
          DependsOnTargets="_GetReferencedProjectPublishItems"
          BeforeTargets="CollectUpToDateCheckInputDesignTime">
    <ItemGroup>
      <!-- Track referenced project publish items as inputs -->
      <UpToDateCheckInput Include="@(_ReferencedProjectPublishItems->'%(FullPath)')" Set="ReferencedProjectContent" />
    </ItemGroup>
  </Target>

  <!-- Touch marker file after copying referenced content -->
  <Target Name="TouchReferencedContentMarker"
          AfterTargets="Before_CopyWebApplicationLegacy">
    <Touch Files="$(ReferencedContentFUTDCMarker)" AlwaysCreate="true" />
  </Target>
</Project>
C:\work\SimpleAspNetApp [(06_FUTDC)]>
```
The [EnableContentPublishThruFUTDC.targets](EnableContentPublishThruFUTDC.targets) file depends on [Microsoft.Web.Publishing.targets](Microsoft.Web.Publishing.targets).

Let us check it out.

> [!IMPORTANT]
> The FUTDC feature relies on the Design Time Builds (DTB). My anecdotal evidence is that whenever I change the build code affecting it I need to close VS, delete the .vs folder and then restart VS. I also enable binary log collection to be able to analyze the triggered DTBs.

1. Close the watch window if open.
1. `del -r -force .vs`
1. `$env:EnableContentPublishThruFUTDC = $true`
1. `devenv .\SimpleAspNetApp.sln`
   - I can see a DTB binary log has been created, so we are good.
1. Build
   ```
   Build started at 7:25 PM...
   1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
   1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
   2>------ Build started: Project: Main, Configuration: Debug Any CPU ------
   2>Main -> C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin\Main.dll
   ========== Build: 2 succeeded, 0 failed, 0 up-to-date, 0 skipped ==========
   ========== Build completed at 7:25 PM and took 02.422 seconds ==========
   ```
1. Build again to make sure all up-to-date
   ```
   Build started at 7:26 PM...
   ========== Build: 0 succeeded, 0 failed, 2 up-to-date, 0 skipped ==========
   ========== Build completed at 7:26 PM and took 00.048 seconds ==========
   ```
1. Let us modify the file [HomeController.cs](Lib/Controllers/HomeController.cs) by adding the `Version` property to the action result.
1. Build
   ```
   Build started at 7:29 PM...
   1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
   1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
   ========== Build: 1 succeeded, 0 failed, 1 up-to-date, 0 skipped ==========
   ========== Build completed at 7:29 PM and took 00.473 seconds ==========
   Visual Studio accelerated 1 project(s), copying 2 file(s). See https://aka.ms/vs-build-acceleration.
   ```
   The VS Build Acceleration takes care of business, as expected.
1. Press the "Test Ping" button - after a few seconds of reloading the correct result is shown:
   ```json
   {
     "Version": 1,
     "Same": true,
     "Built": {
   ...
   ```
1. Open [Index.cshtml](Lib/Views/Home/Index.cshtml) and rename the "Test Ping" button to "Test"
1. Build
   ```
   Build started at 7:32 PM...
   1>------ Build started: Project: Main, Configuration: Debug Any CPU ------
   1>Main -> C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin\Main.dll
   ========== Build: 1 succeeded, 0 failed, 1 up-to-date, 0 skipped ==========
   ========== Build completed at 7:32 PM and took 00.637 seconds ==========
   ```
   Notice that [Main](Main) is built, but **not** [Lib](Lib)! It is expected, because we configure FUTDC only and exclusively for the former. Inspecting the binary log confirms that nothing has actually been compiled, because the C# code is up to date, but because by default we publish on build, the changed `Content` file is copied to the right place.
1. Refresh the browser page - the button gets renamed to "Test".

## Adding new/Deleting existing content files
- Adding a new content file
  ```powershell
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  False
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]> copy scratch\test.html .\Lib\Content\
  C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  False
  C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]>
  ```
  At this moment I notice a new DTB has just run, however, inspecting the binary log reveals that the [Main](Main) project is not there! I.e. the `AddReferencedProjectPublishItemsToFUTDC` target has not run and the internal state of FUTDC facility has not been updated. This is confirmed by building in VS:
  ```
  Build started at 7:42 PM...
  ========== Build: 0 succeeded, 0 failed, 2 up-to-date, 0 skipped ==========
  ========== Build completed at 7:42 PM and took 00.043 seconds ==========
  ```
  That means the new `Content` file has **not** been published:
  ```powershell
  C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  False
  C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]>
  ```

Let us kill VS, delete the .vs folder and reopen VS. The new file is still there, so FUTDC should take it into account:
```powershell
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> $env:EnableContentPublishThruFUTDC
True
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> taskkill /f /im devenv.exe
SUCCESS: The process "devenv.exe" with PID 126324 has been terminated.
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> del -r -force .vs
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> devenv .\SimpleAspNetApp.sln
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]>
```
A fresh DTB binary log is created. Build:
```
Build started at 7:53 PM...
1>------ Build started: Project: Lib, Configuration: Debug Any CPU ------
1>Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
2>------ Build started: Project: Main, Configuration: Debug Any CPU ------
2>Main -> C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin\Main.dll
========== Build: 2 succeeded, 0 failed, 0 up-to-date, 0 skipped ==========
========== Build completed at 7:53 PM and took 01.344 seconds ==========
```
The new `Content` file has been published:
```xml
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> curl.exe http://localhost:5100/Content/test.html
<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
</head>
<body>
    <h1>Test Content from Lib</h1>
    <p>This is a standalone test page to verify FUTDC triggers when content changes.</p>
    <p>Current time: <span id="time"></span></p>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]>
```

- Deleting an existing content file
  ```powershell
  C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  True
  True
  C:\work\SimpleAspNetApp [(06_FUTDC) +1 ~2 -0 !]> del .\Lib\Content\test.html
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  True
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]>
  ```
  Build
  ```
  Build started at 7:56 PM...
  1>------ Build started: Project: Main, Configuration: Debug Any CPU ------
  1>Main -> C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin\Main.dll
  ========== Build: 1 succeeded, 0 failed, 1 up-to-date, 0 skipped ==========
  ========== Build completed at 7:56 PM and took 00.432 seconds ==========
  ```
  Let us build again to make sure FUTDC has settled down
  ```
  Build started at 8:24 PM...
  ========== Build: 0 succeeded, 0 failed, 2 up-to-date, 0 skipped ==========
  ========== Build completed at 8:24 PM and took 00.082 seconds ==========
  ```
  So it seems we are good, since the [Main](Main) project was built and thus the deletion was published:
  ```powershell
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]> Test-Path .\Lib\Content\test.html, .\bin\_PublishedWebsites\Main\Content\test.html
  False
  False
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]> curl.exe -o NUL -s -w "%{http_code}" http://localhost:5100/Content/test.html
  404
  C:\work\SimpleAspNetApp [(06_FUTDC) +0 ~2 -0 !]>
  ```

## Why the FUTDC logic is conditional?
FUTDC works by handing the project off to the msbuild. But it requests to **build** the project rather than **publish without building**. For a big project it would take a lot of time for msbuild to burn through all the relevant targets just to discover that actually no C# code needs to be compiled and no assemblies are to be recreated. That the only needed piece of work is the one equivalent to `dotnet publish --no-build`. And that is why this approach may not be desirable after all and we may wish to stick with `dotnet watch publish` approach.

# 07_AspNetCompile
## Before
The default behavior of the [msbuild.sdk.systemweb](https://github.com/CZEMacLeod/MSBuild.SDK.SystemWeb) SDK used by the [Main](Main) project is to compile Asp.Net Views in the Release build only:
```powershell
C:\work\SimpleAspNetApp [(06_FUTDC)]> dotnet build -c:Release
Restore complete (0.6s)
  Lib net472 succeeded (0.1s) → bin\Lib.dll
  Main net472 failed with 1 error(s) (0.2s) → bin\_PublishedWebsites\Main\bin\Main.dll
    C:\Users\P11F70F\.nuget\packages\msbuild.sdk.systemweb\4.0.104\Sdk\Sdk.targets(15,5): error MSB4803: The task "AspNetCompiler" is not supported on the .NET Core version of MSBuild. Please use the .NET Framework version of MSBuild. See https://aka.ms/msbuild/MSB4803 for further details.

Build failed with 1 error(s) in 1.3s
C:\work\SimpleAspNetApp [(06_FUTDC)]>
```
But it fails, because the `AspNetCompiler` msbuild task is not supported by the `dotnet` command. `msbuild` is fine:
```powershell
C:\work\SimpleAspNetApp [(06_FUTDC)]> git clean -qdfx
C:\work\SimpleAspNetApp [(06_FUTDC)]> msbuild -restore -v:m -m -p:Configuration=Release
MSBuild version 17.14.23+b0019275e for .NET Framework
MSBuild logs and debug information will be at "c:\temp\binlogs"

  Determining projects to restore...
  Restored C:\work\SimpleAspNetApp\Lib\Lib.csproj (in 1.02 sec).
  Restored C:\work\SimpleAspNetApp\Main\Main.csproj (in 1.02 sec).
  Lib -> C:\work\SimpleAspNetApp\bin\Lib.dll
  Main -> C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main\bin\Main.dll
C:\work\SimpleAspNetApp [(06_FUTDC)]>
```
The binary log confirms the `MvcBuildViews` target has run after the web application is published.

Let us check if it works when we build without publishing. The compilation of the Asp.Net views should happen at the publishing, not at the building:
```powershell
C:\work\SimpleAspNetApp [(06_FUTDC)]> git clean -qdfx
C:\work\SimpleAspNetApp [(06_FUTDC)]> dotnet build -p:PublishOnBuild=false -c:Release
Restore complete (1.5s)
  Lib net472 succeeded (1.9s) → bin\Lib.dll
  Main net472 failed with 1 error(s) (0.6s) → bin\_PublishedWebsites\Main\bin\Main.dll
    C:\Users\P11F70F\.nuget\packages\msbuild.sdk.systemweb\4.0.104\Sdk\Sdk.targets(15,5): error MSB4803: The task "AspNetCompiler" is not supported on the .NET Core version of MSBuild. Please use the .NET Framework version of MSBuild. See https://aka.ms/msbuild/MSB4803 for further details.

Build failed with 1 error(s) in 4.1s
C:\work\SimpleAspNetApp [(06_FUTDC)]>
```
It tries to compile the views anyway and predictably fails since we are using `dotnet`.

So we have 3 problems:
1. `dotnet` does not work.
1. Asp.Net views are compiled after the build, even if the build does not publish anything.
1. There is no support for precompiling the views.

## After
```powershell
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git diff --name-status 06_FUTDC
A       AspNetCompiler.Main/AspNetCompiler.Main.msbuildproj
A       AspNetCompiler.props
M       Directory.Build.props
A       EnableAspNetCompilerFUTDC.targets
M       SimpleAspNetApp.sln
M       WebApp.props
C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
```
The compilation of Asp.Net views is delegated to a dedicated utility project. The idea is to have one per each web application and the project name must be `"AspNetCompiler." + {Web App Project Name}`. In our case it must be `AspNetCompiler.Main`:
```xml
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> cat AspNetCompiler.Main/AspNetCompiler.Main.msbuildproj
<Project Sdk="Microsoft.Build.NoTargets/2.0.1">
  <PropertyGroup>
    <TargetFramework>net472</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\Main\Main.csproj" ReferenceOutputAssembly="false" />
  </ItemGroup>
</Project>
C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
```
The main logic is in the [AspNetCompiler.props](AspNetCompiler.props) file and the FUTDC related logic is in [EnableAspNetCompilerFUTDC.targets](EnableAspNetCompilerFUTDC.targets).

The implementation highlights are:
1. The default logic implemented in the SDK is suppressed (inside [WebApp.props](WebApp.props)).
1. View precompilation is enabled by the `AspNetPrecompile` build variable. It is unset by default.
1. We do not use the `AspNetCompiler` msbuild task, because `dotnet` cannot run it. Instead we invoke the **C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe** executable directly.
1. Asp.Net views are compiled on publish whether it is during the build or separate.

Let us test a few scenarios on the command line to confirm the sanity of the build code:

- Building in Debug
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git clean -qdfx
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build
  Restore complete (0.8s)
    Lib net472 succeeded (0.2s) → bin\Lib.dll
    Main net472 succeeded (0.5s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (0.2s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=false

  Build succeeded in 1.8s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
  As expected, no Asp.Net views are compiled.
- Building without publishing in Release
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git clean -qdfx
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -p:PublishOnBuild=false -c:Release
  Restore complete (0.8s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.4s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (0.0s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=false

  Build succeeded in 1.6s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
  Same as before.
- Publishing without building in Release
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet publish --no-build -c:Release
    AspNetCompiler.Main net472 succeeded (6.6s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 7.3s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
  Asp.Net views are compiled and it takes quite a lot of time relative to the project size.
- Building in Release
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git clean -qdfx
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.8s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.4s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (6.5s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 7.9s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
- Building in Debug with explicit request to compile Asp.Net views
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git clean -qdfx
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -p:MvcBuildViews=true
  Restore complete (0.8s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.4s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (6.5s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 7.9s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
- Building in Release twice in a row - we expect nothing to happen on the second build:
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git clean -qdfx
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.8s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.5s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (6.5s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 8.1s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.6s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.2s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (0.0s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 1.2s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
- Checking that modifying a view triggers Asp.Net view compilation on the first build only.
  ```powershell
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> touch.exe .\Lib\Views\Home\Index.cshtml
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.6s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.2s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (6.1s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 7.2s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.6s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.2s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (0.1s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 1.2s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```
- Checking that changing the C# code results in views compilation:
  ```
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> touch.exe .\Lib\Controllers\HomeController.cs
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.6s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.2s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (6.2s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 7.4s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release
  Restore complete (0.8s)
    Lib net472 succeeded (0.1s) → bin\Lib.dll
    Main net472 succeeded (0.2s) → bin\_PublishedWebsites\Main\bin\Main.dll
    AspNetCompiler.Main net472 succeeded (0.1s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

  Build succeeded in 1.5s
  C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
  ```

There is a whole bunch of tests we can do inside Visual Studio that would show that the FUTDC works correctly, when it is enabled, of course. We reuse the same build property that enables FUTDC for publishing content - `EnableContentPublishThruFUTDC`. To be honest, we usually build in Debug in VS so the Asp.Net views compilation is likely to be disabled anyway.

## Precompiling Asp.Net views
Enabled with the `AspNetPrecompile` build variable (or environment variable):
```powershell
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> git clean -qdfx
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dotnet build -c:Release -p:AspNetPrecompile=true
Restore complete (0.8s)
  Lib net472 succeeded (0.1s) → bin\Lib.dll
  Main net472 succeeded (0.4s) → bin\_PublishedWebsites\Main\bin\Main.dll
  AspNetCompiler.Main net472 succeeded (6.9s) → bin\_PublishedWebsites\Main\bin\Main.MvcBuildViews=true

Build succeeded in 8.4s
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> tree bin                                                                                                                                                 
Folder PATH listing for volume Windows
Volume serial number is 268C-52B1
C:\WORK\SIMPLEASPNETAPP\BIN
└───_PublishedWebsites
    ├───Main
    │   ├───bin
    │   │   └───roslyn
    │   ├───Content
    │   ├───Scripts
    │   └───Views
    │       ├───Home
    │       └───Shared
    └───Main_Precompiled
        ├───bin
        │   └───roslyn
        ├───Content
        ├───Scripts
        └───Views
            ├───Home
            └───Shared
C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
```
The cshtml files are now empty stubs:
```powershell
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dir .\bin\_PublishedWebsites\Main_Precompiled\ -filter '*cshtml' -r | ft Length,FullName

Length FullName
------ --------
    86 C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main_Precompiled\Views\_ViewStart.cshtml
    86 C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main_Precompiled\Views\Home\Index.cshtml
    86 C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main_Precompiled\Views\Shared\_Layout.cshtml

C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
```
And the bin directory contains the precompiled views:
```powershell
C:\work\SimpleAspNetApp [(07_AspNetCompile)]> dir .\bin\_PublishedWebsites\Main_Precompiled\bin\App*dll

    Directory: C:\work\SimpleAspNetApp\bin\_PublishedWebsites\Main_Precompiled\bin

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---           2/12/2026  8:49 PM           4608 App_global.asax.dll
-a---           2/12/2026  8:49 PM           7680 App_Web__layout.cshtml.639c3968.dll
-a---           2/12/2026  8:49 PM           4608 App_Web__viewstart.cshtml.65a2d1ee.dll
-a---           2/12/2026  8:49 PM           9216 App_Web_index.cshtml.a8d08dba.dll

C:\work\SimpleAspNetApp [(07_AspNetCompile)]>
```

# Conclusion
1. VS behavior with respect to Asp.Net 5 applications is not suitable for large enterprise applications due to hard coded expectation to find **all** the views or static content in the web application home project.
1. VS Build Acceleration works fine once we make sure the published bin directory is the project bin directory.
1. Neither `dotnet watch publish` nor FUTDC seem to recognize addition of new `Content` files:
   - `dotnet watch publish` - https://github.com/dotnet/aspnetcore/issues/8321 **is open for almost 7 years now**
   - FUTDC - VS does not trigger DTB when new `Content` files appear in the solution
1. FUTDC (when works) is not ideal, because it requests msbuild to **build** the project, which is necessarily more expensive than **publish --no-build**.
