# Android-ANE-Dependencies

Build Android dependencies for Adobe AIR ANEs

-------------

## Precompiled libraries
A set of precompiled ANEs are [available here](/tree/master/anes) This includes Google Play Services and Android Support libraries

## Compiling your own libaries

You will need:
- Windows
- Android Studio 3.0+ installed
- AIR 29 SDK
- Powershell

Packages are described in [packages.xml](/tree/master/build/scripts/packages.xml)   
The format follows closely the maven package descriptor
Packages can be loaded from jcenter|maven|google 

Build single package
````shell
.\build.ps1 -package eventbus
`````

Example package
````xml
<package name="eventbus">
    <groupId>org.greenrobot</groupId>
    <artifactId>eventbus</artifactId>
    <version>3.0.0</version>
    <type>jar</type>
    <repo>maven</repo>
    <category>misc</category>
    <dependancies></dependancies>
</package>
`````

Example package with child dependencies
````xml
<package name="support-design">
    <groupId>com.android.support</groupId>
    <packageName>android.support.design</packageName>
    <artifactId>design</artifactId>
    <version>27.1.0</version>
    <type>aar</type>
    <repo>google</repo>
    <category>support</category>
    <dependancies>
        <package name="transition">
            <groupId>com.android.support</groupId>
            <artifactId>transition</artifactId>
            <version>27.1.0</version>
            <type>aar</type>
            <repo>google</repo>
        </package>
        <package name="recyclerview-v7">
            <groupId>com.android.support</groupId>
            <artifactId>recyclerview-v7</artifactId>
            <version>27.1.0</version>
            <type>aar</type>
            <repo>google</repo>
        </package>
    </dependancies>
</package>
`````
