Param(
[Parameter(Mandatory=$false)]
[string] $package
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#################### Cmdlets ##################
function Get-Package {
    param( [string]$groupId, [string]$artifactId, [string]$version, [string]$type, [string]$repo, [string]$category )
    Write-Host "Getting package for $artifactId" -ForegroundColor yellow
    $groupIdPath = $groupId -replace "\.", "/"

    $packageDirectory = "$currentDir\cache\$category\$groupId"
    $packageName = "$artifactId-$version"

    if (-not (Test-Path $packageDirectory\$groupId-$packageName.jar)) {
        if ($repo -eq "maven") {
            $repoUri = $MAVEN_REPO
        }elseif ($repo -eq "fabric") {
            $repoUri = $FABRIC_REPO
        }elseif ($repo -eq "google") {
            $repoUri = $GOOGLE_REPO
        }elseif ($repo -eq "jcenter") {
            $repoUri = $JCENTER_REPO
        }elseif ($repo -eq "spring") {
            $repoUri = $SPRNG_REPO
        }

        if (-not (Test-Path $packageDirectory)) {
            New-Item -ItemType Directory -Force -Path $packageDirectory
        }
        
        Write-Host "Downloading $repoUri$groupIdPath/$artifactId/$version/$packageName.$type -OutFile $packageDirectory\$packageName.$type" -ForegroundColor yellow

        Invoke-WebRequest -Uri $repoUri$groupIdPath/$artifactId/$version/$packageName.$type -OutFile $packageDirectory\$packageName.$type

        if ($type -eq "aar") {
            Rename-Item -NewName $packageDirectory\$packageName.zip -Path $packageDirectory\$packageName.aar
            Expand-Archive -Path $packageDirectory\$packageName.zip -DestinationPath $packageDirectory\$packageName
            Remove-Item -Path $packageDirectory\$packageName.zip
            Rename-Item -NewName $packageDirectory\$packageName\$packageName.jar -Path $packageDirectory\$packageName\classes.jar
            Move-Item -Path $packageDirectory\$packageName\$packageName.jar -Destination $packageDirectory\$packageName.jar
            
            if ((Test-Path $currentDir\cache\$category\$groupId-$packageName-res)) {
                Remove-Item -Path $currentDir\cache\$category\$groupId-$packageName-res -Recurse
            }

            if ((Test-Path $packageDirectory\$packageName\res)) {
                Move-Item -Path $packageDirectory\$packageName\res -Destination $currentDir\cache\$category\$groupId-$packageName-res
            }

            if ((Test-Path $packageDirectory\$packageName\jni)) {
                if ((Test-Path $currentDir\cache\$category\$groupId-$packageName-jni)) {
                    Remove-Item -Path $currentDir\cache\$category\$groupId-$packageName-jni -Recurse
                }
                Move-Item -Path $packageDirectory\$packageName\jni -Destination $currentDir\cache\$category\$groupId-$packageName-jni -Force
            }
            
            Remove-Item -Path $packageDirectory\$packageName -Recurse
        } 

        Rename-Item -NewName $packageDirectory\$groupId-$packageName.jar -Path  $packageDirectory\$packageName.jar
        Move-Item -Path $packageDirectory\$groupId-$packageName.jar -Destination $currentDir\cache\$category\$groupId-$packageName.jar -Force ## TODO might already exist
        Remove-Item -Path $packageDirectory -Recurse

    }
}

function GetPackagedResourceXML {
    param( [string]$groupId, [string]$artifactId, [string]$version, [string]$packageName )
    $ret = "<packagedResource>
            <packageName>$packageName</packageName>
            <folderName>$groupId-$artifactId-$version-res</folderName>
        </packagedResource>"

    ## Write-Host "XML $ret" -ForegroundColor green

    return $ret
}

###############################################

$currentDir = (Get-Item -Path ".\" -Verbose).FullName
$AIR_SDK = Get-Content "$currentDir\airsdk.config"
$ADT_PATH = "$AIR_SDK\bin\adt.bat"
$MAVEN_REPO = "https://repo1.maven.org/maven2/"
$FABRIC_REPO = "https://maven.fabric.io/public/"
$GOOGLE_REPO = "https://dl.google.com/dl/android/maven2/"
$JCENTER_REPO ="https://jcenter.bintray.com/"
$SPRNG_REPO = "http://repo.spring.io/libs-release/"
$defaultResource = "<?xml version=`"1.0`" encoding=`"utf-8`"?><resources></resources>";

if (-not (Test-Path $ADT_PATH)) {
    Write-Error "Please set AIR SDK path in airsdk.config"
    Exit;
}

if (-not (Test-Path $currentDir\cache)) {
    New-Item -Path $currentDir\cache
}


[xml]$XmlDocument = Get-Content $currentDir\packages.xml


for($i=0;$i -lt $XmlDocument.packages.ChildNodes.Count;$i++) {
    $name = $XmlDocument.packages.package[$i].name
    $groupId = $XmlDocument.packages.package[$i].groupId
    $packageName = $groupId
    if($XmlDocument.packages.package[$i].packageName) {
        $packageName = $XmlDocument.packages.package[$i].packageName
    }
    $artifactId = $XmlDocument.packages.package[$i].artifactId
    $version = $XmlDocument.packages.package[$i].version
    $type = $XmlDocument.packages.package[$i].type
    $repo = $XmlDocument.packages.package[$i].repo
    $category = $XmlDocument.packages.package[$i].category
    $artifactIdSafe = $artifactId -replace "-", "_"

    if($package -eq $name -or $package -eq "") {
    }else{
        continue
    }

    if (-not (Test-Path $currentDir\cache\$category)) {
        New-Item -Path $currentDir\cache\$category -ItemType "directory"
    }
    
    Get-Package $groupId $artifactId $version $type $repo $category

    $packagedResources = ""
    $packagedResourceLoops = ""
    $packagedDependencies = ""
    $packagedDependencyLoops = ""
    $packagedDependencyLoops = "<packagedDependency>$groupId-$artifactId-$version.jar</packagedDependency>" 
    
    $numDependancies = $XmlDocument.packages.package[$i].dependancies.ChildNodes.Count
    $numResources = $numDependancies

    if ($type -eq "aar") {
        $numResources = $numResources + 1
        $packagedResourceLoops += GetPackagedResourceXML $groupId $artifactId $version $packageName
    }

    ## Write-Host "XML $packagedResourceLoops" -ForegroundColor green
    

    ## depend PUT BACK

    if($numDependancies -gt 0) {
        $dependancies = $XmlDocument.packages.package[$i].dependancies
        for($j=0;$j -lt $numDependancies;$j++) {
            if($numDependancies -eq 1) {
                $depend_groupId = $dependancies.package.groupId
                $depend_artifactId = $dependancies.package.artifactId
                $depend_version = $dependancies.package.version
                $depend_type = $dependancies.package.type
                $depend_repo = $dependancies.package.repo
                $depend_packageName = "$depend_groupId.$depend_artifactId"

                if($dependancies.package.packageName) {
                    $depend_packageName = $dependancies.package.packageName
                }

            } else {
                $depend_groupId = $dependancies.package[$j].groupId
                $depend_artifactId = $dependancies.package[$j].artifactId
                $depend_version = $dependancies.package[$j].version
                $depend_type = $dependancies.package[$j].type
                $depend_repo = $dependancies.package[$j].repo
                $depend_packageName = "$depend_groupId.$depend_artifactId"


                if($dependancies.package[$j].packageName) {
                    $depend_packageName = $dependancies.package[$j].packageName
                }
            }
            
            
            Get-Package $depend_groupId $depend_artifactId $depend_version $depend_type $depend_repo $category

            $packagedDependencyLoops += "<packagedDependency>$depend_groupId-$depend_artifactId-$depend_version.jar</packagedDependency>"
            if ($depend_type -eq "aar") {
                $packagedResourceLoops += GetPackagedResourceXML $depend_groupId $depend_artifactId $depend_version $depend_packageName
            }

        }
    }
    

    $packagedDependencies = "<packagedDependencies>
        $packagedDependencyLoops
    </packagedDependencies>"

    if($numResources -gt 0) {
         $packagedResources = "<packagedResources>
            $packagedResourceLoops
        </packagedResources>"
    }

    $platformXml = "<?xml version=`"1.0`" encoding=`"utf-8`"?>
    <platform xmlns=`"http://ns.adobe.com/air/extension/19.0`">
        $packagedDependencies
        $packagedResources
    </platform>"

    Set-Content -Path $currentDir\platforms\android\platform.xml -Value $platformXml

    $extensionXml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<extension xmlns=`"http://ns.adobe.com/air/extension/19.0`">
    <id>$groupId.$artifactId</id>
    <name>$artifactId</name>
    <copyright></copyright>
    <versionNumber>$version</versionNumber>
    <platforms>
        <platform name=`"Android-ARM`">
            <applicationDeployment>
            <nativeLibrary>classes.jar</nativeLibrary>
            <initializer>com.tuarua.DummyANE</initializer>
            <finalizer>com.tuarua.DummyANE</finalizer>
            </applicationDeployment>
        </platform>
        <platform name=`"Android-x86`">
            <applicationDeployment>
            <nativeLibrary>classes.jar</nativeLibrary>
            <initializer>com.tuarua.DummyANE</initializer>
            <finalizer>com.tuarua.DummyANE</finalizer>
            </applicationDeployment>
        </platform>
        <platform name=`"default`">
        <applicationDeployment/></platform>
    </platforms>
</extension>"
    Set-Content -Path $currentDir\extension.xml -Value $extensionXml    

    ### Create Java Class ###
    $jPath = "$currentDir..\..\..\native_library\android\dummyane\src\main\java"
    Remove-Item "$jPath\*" -Recurse

    $groupId.Split("\.") | ForEach {
        $jPath = $jPath + "\" + $_ 
        #echo $jPath
        if (-not (Test-Path $jPath)) {
            New-Item -Path $jPath -ItemType "directory"
        }
    }

    if (-not (Test-Path "$jPath\DummyANE.java")) {
        New-Item -Path $jPath\DummyANE.java
    } 

    Write-Host "Write DummyANE.java" -ForegroundColor yellow
    $javaContents = "package $groupId.$artifactIdSafe;public class DummyANE {}"
    Set-Content -Path $jPath\DummyANE.java -Value $javaContents

    Write-Host "gradlew clean" -ForegroundColor yellow
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$currentDir..\..\..\native_library\android\gradlew.bat","clean" -WorkingDirectory "$currentDir..\..\..\native_library\android" -windowstyle Hidden -PassThru
    Wait-Process -InputObject $process

    Write-Host "gradlew build" -ForegroundColor yellow
    $process2 = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$currentDir..\..\..\native_library\android\gradlew.bat","build" -WorkingDirectory "$currentDir..\..\..\native_library\android" -windowstyle Hidden -PassThru
    Wait-Process -InputObject $process2

    ##### BUILD ANE
    Write-Host "Building ANE $groupId.$artifactId-$version.ane" -ForegroundColor yellow

    Copy-Item -Path "$currentDir\..\bin\DummyANE.swc" -Destination "$currentDir\DummyANE.swc" -Force
    Copy-Item -Path "$currentDir\DummyANE.swc" -Destination "$currentDir\DummyANEExtract.swc" -Force
    Rename-Item -NewName "$currentDir\DummyANEExtract.zip" -Path "$currentDir\DummyANEExtract.swc" -Force

    Expand-Archive -Path $currentDir\DummyANEExtract.zip -DestinationPath $currentDir -Force
    Remove-Item $currentDir\DummyANEExtract.zip

    Copy-Item -Path $currentDir\library.swf -Destination $currentDir\platforms\android -Force
    Copy-Item -Path "$currentDir\..\..\native_library\android\dummyane\build\libs\dummyane.jar" -Destination $currentDir\platforms\android\classes.jar -Force
    
    $resFolderName = "$groupId-$artifactId-$version-res"
    
    if ($type -eq "aar") {
        if ((Test-Path "$currentDir\cache\$category\$resFolderName")) {
            Copy-Item -Path $currentDir\cache\$category\$resFolderName $currentDir\platforms\android -Force -Recurse
        }

        Write-Host "copying res to $currentDir\platforms\android\$resFolderName" -ForegroundColor yellow

        if (-not (Test-Path "$currentDir\platforms\android\$resFolderName\values")) {

            Write-Host "need to write new strings $currentDir\platforms\android\$resFolderName\values\strings.xml" -ForegroundColor yellow

            New-Item -Path $currentDir\platforms\android\$resFolderName\values -ItemType "directory"
            New-Item -Path $currentDir\platforms\android\$resFolderName\values\strings.xml
            Set-Content -Path $currentDir\platforms\android\$resFolderName\values\strings.xml -Value $defaultResource
        }
    }
    Copy-Item -Path $currentDir\cache\$category\$groupId-$artifactId-$version.jar $currentDir\platforms\android\$groupId-$artifactId-$version.jar -Force

    if (-not (Test-Path "$currentDir\..\..\anes\$category")) {
        New-Item -Path $currentDir\..\..\anes\$category -ItemType "directory"
    }

    
    $ADT_STRING = "$ADT_PATH -package -target ane $currentDir\..\..\anes\$category\$groupId.$artifactId-$version.ane extension.xml "
    $ADT_STRING += "-swc DummyANE.swc "
    
    
    $ADT_FILES_X86 = ""
    $ADT_FILES_X86 += "-C platforms/android library.swf classes.jar "
    $ADT_FILES_X86 += "-platformoptions platforms/android/platform.xml "
    $ADT_FILES_X86 += "$groupId-$artifactId-$version.jar "
    if ($type -eq "aar") {
        $ADT_FILES_X86 += "$resFolderName/. "
    }

    $ADT_FILES_ARM = ""
    $ADT_FILES_ARM += "-C platforms/android library.swf classes.jar "
    $ADT_FILES_ARM += "-platformoptions platforms/android/platform.xml "
    $ADT_FILES_ARM += "$groupId-$artifactId-$version.jar "
    if ($type -eq "aar") {
        $ADT_FILES_ARM += "$resFolderName/. "
    }


    if($numDependancies -gt 0) {
        $dependancies = $XmlDocument.packages.package[$i].dependancies
        for($j=0;$j -lt $numDependancies;$j++) {
            if($numDependancies -eq 1) {
                $depend_groupId = $dependancies.package.groupId
                $depend_artifactId = $dependancies.package.artifactId
                $depend_version = $dependancies.package.version
                $depend_type = $dependancies.package.type
                $depend_repo = $dependancies.package.repo
            } else {
                $depend_groupId = $dependancies.package[$j].groupId
                $depend_artifactId = $dependancies.package[$j].artifactId
                $depend_version = $dependancies.package[$j].version
                $depend_type = $dependancies.package[$j].type
                $depend_repo = $dependancies.package[$j].repo
            }

            $depend_resFolderName = "$depend_groupId-$depend_artifactId-$depend_version-res"

            if ($depend_type -eq "aar") {
                if ((Test-Path $currentDir\cache\$category\$depend_resFolderName)) {
                    Copy-Item -Path $currentDir\cache\$category\$depend_resFolderName $currentDir\platforms\android -Force -Recurse
                }
                
                if (-not (Test-Path "$currentDir\platforms\android\$depend_resFolderName\values")) {
                    New-Item -Path $currentDir\platforms\android\$depend_resFolderName\values -ItemType "directory"
                    New-Item -Path $currentDir\platforms\android\$depend_resFolderName\values\strings.xml
                    Set-Content -Path $currentDir\platforms\android\$depend_resFolderName\values\strings.xml -Value $defaultResource
                }

                if ((Test-Path $currentDir\cache\$category\$depend_groupId-$depend_artifactId-$depend_version-jni)) {
                    if (-not (Test-Path "$currentDir\platforms\android\jni")) {
                        Copy-Item -Path $currentDir\cache\$category\$depend_groupId-$depend_artifactId-$depend_version-jni\x86 $currentDir\platforms\android\jni\x86 -Force -Recurse
                        Copy-Item -Path $currentDir\cache\$category\$depend_groupId-$depend_artifactId-$depend_version-jni\armeabi-v7a $currentDir\platforms\android\jni\armeabi-v7a -Force -Recurse
                    }
                    $ADT_FILES_X86 += "jni/x86/. "
                    $ADT_FILES_ARM += "jni/armeabi-v7a/. "
                }


            }
            ## any depend jnis also

            $ADT_FILES_ARM += "$depend_groupId-$depend_artifactId-$depend_version.jar "
            $ADT_FILES_X86 += "$depend_groupId-$depend_artifactId-$depend_version.jar "
            if ($depend_type -eq "aar") {
                $ADT_FILES_ARM += "$depend_resFolderName/. "
                $ADT_FILES_X86 += "$depend_resFolderName/. "
            }

            Copy-Item -Path $currentDir\cache\$category\$depend_groupId-$depend_artifactId-$depend_version.jar $currentDir\platforms\android\$depend_groupId-$depend_artifactId-$depend_version.jar -Force
        }
    }

    $ADT_STRING += "-platform Android-ARM "
    $ADT_STRING += $ADT_FILES_ARM
    $ADT_STRING += "-platform Android-x86 "
    $ADT_STRING += $ADT_FILES_X86
    
    $ADT_STRING += "-platform default -C platforms/default library.swf"

    Write-Host "Building" -ForegroundColor yellow
    $process3 = start-process "cmd.exe" "/c $ADT_STRING" -WorkingDirectory $currentDir -PassThru -windowstyle Hidden
    Wait-Process -InputObject $process3

    Write-Host "Cleaning up" -ForegroundColor yellow

    if ($type -eq "aar") {
        Remove-Item $currentDir\platforms\android\$resFolderName -Recurse
    }
    Remove-Item $currentDir\platforms\android\$groupId-$artifactId-$version.jar
    if ((Test-Path "$currentDir\platforms\android\jni")) {
        Remove-Item $currentDir\platforms\android\jni -Recurse
    }

    if($numDependancies -gt 0) {
        $dependancies = $XmlDocument.packages.package[$i].dependancies
        for($j=0;$j -lt $numDependancies;$j++) {
            if($numDependancies -eq 1) {
                $depend_groupId = $dependancies.package.groupId
                $depend_artifactId = $dependancies.package.artifactId
                $depend_version = $dependancies.package.version
                $depend_type = $dependancies.package.type
            } else {
                $depend_groupId = $dependancies.package[$j].groupId
                $depend_artifactId = $dependancies.package[$j].artifactId
                $depend_version = $dependancies.package[$j].version
                $depend_type = $dependancies.package[$j].type
            }


            if ($depend_type -eq "aar") {
                Remove-Item $currentDir\platforms\android\$depend_groupId-$depend_artifactId-$depend_version-res -Recurse
            }
            Remove-Item $currentDir\platforms\android\$depend_groupId-$depend_artifactId-$depend_version.jar
        }
    }


    Remove-Item $currentDir\platforms\android\classes.jar
    Remove-Item $currentDir\library.swf
    Remove-Item $currentDir\catalog.xml
    Remove-Item $currentDir\DummyANE.swc

    Write-Host "Finished" -ForegroundColor green

}
