Param(
[Parameter(Mandatory=$false)]
[string] $package
)

#Write-Host "package $package"

$ADT_PATH ="D:\dev\sdks\AIR\AIRSDK_28\bin\adt.bat"
$MAVEN_REPO = "https://repo1.maven.org/maven2/"
$FABRIC_REPO = "https://maven.fabric.io/public/"
$GOOGLE_REPO = "https://dl.google.com/dl/android/maven2/"
$JCENTER_REPO ="https://jcenter.bintray.com/"
$defaultResource = "<?xml version=`"1.0`" encoding=`"utf-8`"?><resources></resources>";


if (-not (Test-Path $currentDir\cache)) {
    New-Item -Path $currentDir\cache
}

$currentDir = (Get-Item -Path ".\" -Verbose).FullName


function Get-Package {
    param( [string]$groupId, [string]$artifactId, [string]$version, [string]$type, [string]$repo, [string]$category )
    echo "Getting package for $artifactId"
    $groupIdPath = $groupId -replace "\.", "/"
    if (-not (Test-Path $currentDir\cache\$category\$artifactId-$version.jar)) {
        if ($repo -eq "maven") {
            $repoUri = $MAVEN_REPO
        }elseif ($repo -eq "fabric") {
            $repoUri = $FABRIC_REPO
        }elseif ($repo -eq "google") {
            $repoUri = $GOOGLE_REPO
        }elseif ($repo -eq "jcenter") {
            $repoUri = $JCENTER_REPO
        }

        echo "Downloading $repoUri$groupIdPath/$artifactId/$version/$artifactId-$version.$type -OutFile $currentDir\cache\$category\$artifactId-$version.$type"

        Invoke-WebRequest -Uri $repoUri$groupIdPath/$artifactId/$version/$artifactId-$version.$type -OutFile $currentDir\cache\$category\$artifactId-$version.$type

        if ($type -eq "aar") {
            Rename-Item -NewName $currentDir\cache\$category\$artifactId-$version.zip -Path $currentDir\cache\$category\$artifactId-$version.aar
            Expand-Archive -Path $currentDir\cache\$category\$artifactId-$version.zip -DestinationPath $currentDir\cache\$category\$artifactId-$version
            Remove-Item -Path $currentDir\cache\$category\$artifactId-$version.zip
            Rename-Item -NewName $currentDir\cache\$category\$artifactId-$version\$artifactId-$version-res -Path $currentDir\cache\$category\$artifactId-$version\res
            Rename-Item -NewName $currentDir\cache\$category\$artifactId-$version\$artifactId-$version.jar -Path $currentDir\cache\$category\$artifactId-$version\classes.jar
            Move-Item -Path $currentDir\cache\$category\$artifactId-$version\$artifactId-$version-res -Destination $currentDir\cache\$category\$artifactId-$version-res
            Move-Item -Path $currentDir\cache\$category\$artifactId-$version\$artifactId-$version.jar -Destination $currentDir\cache\$category\$artifactId-$version.jar
            Remove-Item -Path $currentDir\cache\$category\$artifactId-$version -Recurse
        }

    }

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
    $packagedDependencyLoops = "<packagedDependency>$artifactId-$version.jar</packagedDependency>"
    
    $numDependancies = $XmlDocument.packages.package[$i].dependancies.ChildNodes.Count
    $numResources = $numDependancies

    if ($type -eq "aar") {
        $numResources = $numResources + 1
        $packagedResourceLoops += "
        <packagedResource>
            <packageName>$packageName</packageName>
            <folderName>$artifactId-$version-res</folderName>
        </packagedResource>"
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

            Get-Package $depend_groupId $depend_artifactId $depend_version $depend_type $depend_repo $category

            $packagedDependencyLoops += "<packagedDependency>$depend_artifactId-$depend_version.jar</packagedDependency>"
            if ($depend_type -eq "aar") {
            $packagedResourceLoops += "
            <packagedResource>
            <packageName>$depend_groupId.$depend_artifactId</packageName>
            <folderName>$depend_artifactId-$depend_version-res</folderName>
            </packagedResource>"
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

    echo "Write DummyANE.java"
    $javaContents = "package $groupId.$artifactIdSafe;public class DummyANE {}"
    Set-Content -Path $jPath\DummyANE.java -Value $javaContents

    echo "gradlew clean"
    start-process "cmd.exe" "/c $currentDir..\..\..\native_library\android\gradlew.bat clean" -WorkingDirectory "$currentDir..\..\..\native_library\android" -Wait
    echo "gradlew build"
    start-process "cmd.exe" "/c $currentDir..\..\..\native_library\android\gradlew.bat build" -WorkingDirectory "$currentDir..\..\..\native_library\android" -Wait 

    ##### BUILD ANE
    echo "Building ANE $groupId.$artifactId-$version.ane"

    Copy-Item -Path "$currentDir\..\bin\DummyANE.swc" -Destination "$currentDir\DummyANE.swc" -Force
    Copy-Item -Path "$currentDir\DummyANE.swc" -Destination "$currentDir\DummyANEExtract.swc" -Force
    Rename-Item -NewName "$currentDir\DummyANEExtract.zip" -Path "$currentDir\DummyANEExtract.swc" -Force

    Expand-Archive -Path $currentDir\DummyANEExtract.zip -DestinationPath $currentDir -Force
    Remove-Item $currentDir\DummyANEExtract.zip

    Copy-Item -Path $currentDir\library.swf -Destination $currentDir\platforms\android -Force
    Copy-Item -Path "$currentDir\..\..\native_library\android\dummyane\build\libs\dummyane.jar" -Destination $currentDir\platforms\android\classes.jar -Force
    
    
    if ($type -eq "aar") {
        Copy-Item -Path $currentDir\cache\$category\$artifactId-$version-res $currentDir\platforms\android -Force -Recurse

        Write-Host "copying res to $currentDir\platforms\android\$artifactId-$version-res"

        if (-not (Test-Path "$currentDir\platforms\android\$artifactId-$version-res\values")) {

            Write-Host "need to write new strings $currentDir\platforms\android\$artifactId-$version-res\values\strings.xml"

            New-Item -Path $currentDir\platforms\android\$artifactId-$version-res\values -ItemType "directory"
            New-Item -Path $currentDir\platforms\android\$artifactId-$version-res\values\strings.xml
            Set-Content -Path $currentDir\platforms\android\$artifactId-$version-res\values\strings.xml -Value $defaultResource
        }
    }
    Copy-Item -Path $currentDir\cache\$category\$artifactId-$version.jar $currentDir\platforms\android\$artifactId-$version.jar -Force

    if (-not (Test-Path "$currentDir\..\..\anes\$category")) {
        New-Item -Path $currentDir\..\..\anes\$category -ItemType "directory"
    }

    
    $ADT_STRING = "$ADT_PATH -package -target ane $currentDir\..\..\anes\$category\$groupId.$artifactId-$version.ane extension.xml "
    $ADT_STRING += "-swc DummyANE.swc "
    
    
    $ADT_FILES = ""
    $ADT_FILES += "-C platforms/android library.swf classes.jar "
    $ADT_FILES += "-platformoptions platforms/android/platform.xml "
    $ADT_FILES += "$artifactId-$version.jar "
    if ($type -eq "aar") {
        $ADT_FILES += "$artifactId-$version-res/. "
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

            if ($depend_type -eq "aar") {
                Copy-Item -Path $currentDir\cache\$category\$depend_artifactId-$depend_version-res $currentDir\platforms\android -Force -Recurse

                if (-not (Test-Path "$currentDir\platforms\android\$depend_artifactId-$depend_version-res\values")) {
                    New-Item -Path $currentDir\platforms\android\$depend_artifactId-$depend_version-res\values -ItemType "directory"
                    New-Item -Path $currentDir\platforms\android\$depend_artifactId-$depend_version-res\values\strings.xml
                    Set-Content -Path $currentDir\platforms\android\$depend_artifactId-$depend_version-res\values\strings.xml -Value $defaultResource
                }
            }

            $ADT_FILES += "$depend_artifactId-$depend_version.jar "
            if ($depend_type -eq "aar") {
                $ADT_FILES += "$depend_artifactId-$depend_version-res/. "
            }

            Copy-Item -Path $currentDir\cache\$category\$depend_artifactId-$depend_version.jar $currentDir\platforms\android\$depend_artifactId-$depend_version.jar -Force
        }
    }


    $ADT_STRING += "-platform Android-ARM "
    $ADT_STRING += $ADT_FILES
    $ADT_STRING += "-platform Android-x86 "
    $ADT_STRING += $ADT_FILES
    
    $ADT_STRING += "-platform default -C platforms/default library.swf"

    #echo $ADT_STRING
    echo "Building"
    start-process "cmd.exe" "/c $ADT_STRING" -WorkingDirectory $currentDir -Wait

    echo "Cleaning up"

    if ($type -eq "aar") {
        Remove-Item $currentDir\platforms\android\$artifactId-$version-res -Recurse
    }
    Remove-Item $currentDir\platforms\android\$artifactId-$version.jar


    if($numDependancies -gt 0) {
        $dependancies = $XmlDocument.packages.package[$i].dependancies
        for($j=0;$j -lt $numDependancies;$j++) {
            #$depend_artifactId = $dependancies.package[$j].artifactId
            #$depend_version = $dependancies.package[$j].version
            #$depend_type = $dependancies.package[$j].type

            if($numDependancies -eq 1) {
                $depend_artifactId = $dependancies.package.artifactId
                $depend_version = $dependancies.package.version
                $depend_type = $dependancies.package.type
            } else {
                $depend_artifactId = $dependancies.package[$j].artifactId
                $depend_version = $dependancies.package[$j].version
                $depend_type = $dependancies.package[$j].type
            }


            if ($depend_type -eq "aar") {
                Remove-Item $currentDir\platforms\android\$depend_artifactId-$depend_version-res -Recurse
            }
            Remove-Item $currentDir\platforms\android\$depend_artifactId-$depend_version.jar
        }
    }


    Remove-Item $currentDir\platforms\android\classes.jar
    Remove-Item $currentDir\library.swf
    Remove-Item $currentDir\catalog.xml
    Remove-Item $currentDir\DummyANE.swc

    echo "Finished"

}