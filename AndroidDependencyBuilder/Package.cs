using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Xml;

namespace AndroidDependencyBuilder {
    public class Package : PackageBase {
        public readonly string Category;
        private readonly List<Dependency> _dependencies = new List<Dependency>();
        private readonly bool _hasDependencies;

        private static string BuildDirectory => $"{CurrentDirectory}/buildpad";
        private static string Shell => RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "cmd.exe" : "bash";

        private static string Gradlew =>
            RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "/c gradlew.bat" : "gradlew";

        private static readonly List<string> PlatformsList = new List<string>
            {"Android-ARM", "Android-ARM64", "Android-x86", "default"};

        private static readonly Dictionary<string, string> Arches = new Dictionary<string, string>
            {{"Android-ARM", "armeabi-v7a"}, {"Android-ARM64", "arm64-v8a"}, {"Android-x86", "x86"}};

        public Package(XmlNode node) {
            Name = node.Attributes["name"].Value;
            GroupId = node["groupId"]?.ChildNodes[0].Value;
            ArtifactId = node["artifactId"].ChildNodes[0].Value;
            Version = node["version"].ChildNodes[0].Value;
            Type = ConvertType(node["type"].ChildNodes[0].Value);
            Repo = ConvertRepo(node["repo"].ChildNodes[0].Value);
            Category = node["category"]?.ChildNodes[0].Value;

            var xmlNodeList = node["dependancies"]?.ChildNodes;
            if (xmlNodeList == null) return;
            _hasDependencies = xmlNodeList.Count > 0;
            foreach (XmlNode dependency in xmlNodeList) {
                _dependencies.Add(new Dependency(dependency));
            }
        }

        public new async Task Download(string category) {
            await base.Download(category);
            if (!_hasDependencies) return;
            foreach (var dependency in _dependencies) {
                await dependency.Download(category);
            }
        }

        public void CreateAneFiles() {
            CleanupBuildFiles();
            CreateBuildFolder();
            BuildPlatformXml();
            BuildExtensionXml();
            BuildJavaFiles();
            BuildAne();
            CleanupBuildFiles();
        }

        private static void CreateBuildFolder() {
            Directory.CreateDirectory(BuildDirectory);
            Directory.CreateDirectory($"{BuildDirectory}/bin");
            Directory.CreateDirectory($"{BuildDirectory}/platforms");
            Directory.CreateDirectory($"{BuildDirectory}/platforms/android");
            Directory.CreateDirectory($"{BuildDirectory}/platforms/default");
            File.Copy($"{CurrentDirectory}/DummyANE.swc", $"{BuildDirectory}/bin/DummyANE.swc");
        }

        private void BuildPlatformXml() {
            var doc = new XmlDocument();
            var xmlDeclaration = doc.CreateXmlDeclaration("1.0", "UTF-8", null);
            var root = doc.DocumentElement;
            doc.InsertBefore(xmlDeclaration, root);
            var rootNode = doc.CreateElement("platform");
            var xmlns = doc.CreateAttribute("xmlns");
            xmlns.Value = "http://ns.adobe.com/air/extension/19.0";
            rootNode.Attributes.Append(xmlns);
            doc.AppendChild(rootNode);

            XmlNode packagedDependenciesNode = doc.CreateElement("packagedDependencies");
            // rootJar
            XmlNode baseJarNode = doc.CreateElement("packagedDependency");
            baseJarNode.AppendChild(doc.CreateTextNode($"{GroupId}-{ArtifactId}-{Version}.jar"));
            packagedDependenciesNode.AppendChild(baseJarNode);

            XmlNode packagedResourcesNode = doc.CreateElement("packagedResources");
            if (HasResources) {
                XmlNode resourceNode = doc.CreateElement("packagedResource");

                XmlNode packageNameNode = doc.CreateElement("packageName");
                XmlNode folderNameNode = doc.CreateElement("folderName");

                packageNameNode.AppendChild(doc.CreateTextNode($"{GroupId}"));
                folderNameNode.AppendChild(doc.CreateTextNode($"{GroupId}-{ArtifactId}-{Version}-res"));

                resourceNode.AppendChild(packageNameNode);
                resourceNode.AppendChild(folderNameNode);

                packagedResourcesNode.AppendChild(resourceNode);
            }

            foreach (var dependency in _dependencies) {
                XmlNode dependencyJarNode = doc.CreateElement("packagedDependency");
                dependencyJarNode.AppendChild(
                    doc.CreateTextNode($"{dependency.GroupId}-{dependency.ArtifactId}-{dependency.Version}.jar"));
                packagedDependenciesNode.AppendChild(dependencyJarNode);

                if (!dependency.HasResources) continue;
                XmlNode resourceNode = doc.CreateElement("packagedResource");
                XmlNode packageNameNode = doc.CreateElement("packageName");
                XmlNode folderNameNode = doc.CreateElement("folderName");

                packageNameNode.AppendChild(dependency.PackageName != null
                    ? doc.CreateTextNode($"{dependency.PackageName}")
                    : doc.CreateTextNode($"{dependency.GroupId}-{dependency.ArtifactId}"));
                folderNameNode.AppendChild(
                    doc.CreateTextNode($"{dependency.GroupId}-{dependency.ArtifactId}-{dependency.Version}-res"));
                resourceNode.AppendChild(packageNameNode);
                resourceNode.AppendChild(folderNameNode);

                packagedResourcesNode.AppendChild(resourceNode);
            }

            rootNode.AppendChild(packagedDependenciesNode);

            if (packagedResourcesNode.HasChildNodes) {
                rootNode.AppendChild(packagedResourcesNode);
            }

            doc.Save($"{BuildDirectory}/platforms/android/platform.xml");
        }

        private void BuildExtensionXml() {
            var doc = new XmlDocument();
            var xmlDeclaration = doc.CreateXmlDeclaration("1.0", "utf-8", null);
            var root = doc.DocumentElement;
            doc.InsertBefore(xmlDeclaration, root);
            var rootNode = doc.CreateElement("extension");
            var xmlns = doc.CreateAttribute("xmlns");
            xmlns.Value = "http://ns.adobe.com/air/extension/19.0";
            rootNode.Attributes.Append(xmlns);
            doc.AppendChild(rootNode);

            XmlNode idNode = doc.CreateElement("id");
            idNode.AppendChild(doc.CreateTextNode($"{GroupId}.{ArtifactId}"));
            rootNode.AppendChild(idNode);

            XmlNode nameNode = doc.CreateElement("name");
            nameNode.AppendChild(doc.CreateTextNode($"{ArtifactId}"));
            rootNode.AppendChild(nameNode);

            XmlNode copyrightNode = doc.CreateElement("copyright");
            rootNode.AppendChild(copyrightNode);

            var versionCleaned = Version.Replace("-android", "");
            XmlNode versionNumberNode = doc.CreateElement("versionNumber");
            versionNumberNode.AppendChild(doc.CreateTextNode($"{versionCleaned}"));
            rootNode.AppendChild(versionNumberNode);

            XmlNode platformsNode = doc.CreateElement("platforms");

            foreach (var p in PlatformsList) {
                XmlNode platformNode = doc.CreateElement("platform");
                var nameAttr = doc.CreateAttribute("name");
                nameAttr.Value = p;
                platformNode.Attributes.Append(nameAttr);

                XmlNode applicationDeploymentNode = doc.CreateElement("applicationDeployment");

                if (p != "default") {
                    XmlNode nativeLibraryNode = doc.CreateElement("nativeLibrary");
                    nativeLibraryNode.AppendChild(doc.CreateTextNode("classes.jar"));
                    applicationDeploymentNode.AppendChild(nativeLibraryNode);

                    XmlNode initializerNode = doc.CreateElement("initializer");
                    initializerNode.AppendChild(doc.CreateTextNode("com.tuarua.DummyANE"));
                    applicationDeploymentNode.AppendChild(initializerNode);

                    XmlNode finalizerNode = doc.CreateElement("finalizer");
                    finalizerNode.AppendChild(doc.CreateTextNode("com.tuarua.DummyANE"));
                    applicationDeploymentNode.AppendChild(finalizerNode);
                }

                platformNode.AppendChild(applicationDeploymentNode);
                platformsNode.AppendChild(platformNode);
            }

            rootNode.AppendChild(platformsNode);
            doc.Save($"{BuildDirectory}/extension.xml");
        }

        private void BuildJavaFiles() {
            var javaPath = $"{CurrentDirectory}/../native_library/android/dummyane/src/main/java";
            foreach (var subDir in new DirectoryInfo(javaPath).GetDirectories()) {
                subDir.Delete(true);
            }

            foreach (var s in GroupId.Split(".")) {
                javaPath = javaPath + "/" + s;
                if (!Directory.Exists(javaPath)) {
                    Directory.CreateDirectory(javaPath);
                }
            }

            var artifactIdSafe = ArtifactId.Replace("-", "_");
            File.WriteAllText($"{javaPath}/DummyANE.java",
                $"package {GroupId}.{artifactIdSafe};public class DummyANE {{}}");

            var startInfo = new ProcessStartInfo(Shell) {
                CreateNoWindow = false,
                UseShellExecute = false,
                WorkingDirectory = $"{CurrentDirectory}/../native_library/android",
                WindowStyle = ProcessWindowStyle.Hidden,
                Arguments = $"{Gradlew} clean"
            };

            try {
                using var exeProcess = Process.Start(startInfo);
                exeProcess?.WaitForExit();
            }
            catch (Exception e) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(e.Message);
                return;
            }

            startInfo.Arguments = $"{Gradlew} build";
            try {
                using var exeProcess = Process.Start(startInfo);
                exeProcess?.WaitForExit();
            }
            catch (Exception e) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(e.Message);
                return;
            }

            Console.ResetColor();
        }

        private void BuildAne() {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Building ANE {GroupId}.{ArtifactId}-{Version}.ane");
            if (!Directory.Exists($"{CurrentDirectory}/../anes/{Category}")) {
                Directory.CreateDirectory($"{CurrentDirectory}/../anes/{Category}");
            }

            File.Copy($"{BuildDirectory}/bin/DummyANE.swc", $"{BuildDirectory}/DummyANE.swc", true);
            File.Copy($"{BuildDirectory}/bin/DummyANE.swc", $"{BuildDirectory}/DummyANEExtract.zip", true);

            ZipFile.ExtractToDirectory($"{BuildDirectory}/DummyANEExtract.zip",
                $"{BuildDirectory}", true);
            File.Delete($"{BuildDirectory}/DummyANEExtract.zip");
            File.Copy($"{BuildDirectory}/library.swf", $"{BuildDirectory}/platforms/android/library.swf", true);
            File.Copy($"{BuildDirectory}/library.swf", $"{BuildDirectory}/platforms/default/library.swf", true);

            var doc = new XmlDocument();
            doc.Load($"{BuildDirectory}/platforms/android/platform.xml");
            var packageDirectory = $"{CurrentDirectory}/cache/{Category}";

            var jars = new List<string>();
            var resources = new List<string>();

            foreach (var name in from XmlNode node in doc.DocumentElement["packagedDependencies"]
                select node.InnerText) {
                jars.Add(name);
                File.Copy($"{packageDirectory}/{name}", $"{BuildDirectory}/platforms/android/{name}", true);
            }

            if (doc.DocumentElement["packagedResources"] != null) {
                foreach (var folderName in from XmlNode node in doc.DocumentElement["packagedResources"]
                    select node["folderName"].InnerText) {
                    resources.Add(folderName);
                    DirectoryCopy($"{packageDirectory}/{folderName}",
                        $"{BuildDirectory}/platforms/android/{folderName}");
                }
            }

            File.Copy($"{CurrentDirectory}/../native_library/android/dummyane/build/libs/dummyane.jar",
                $"{BuildDirectory}/platforms/android/classes.jar", true);
            var adtString =
                $"{Program.AdtPath} -package -target ane {CurrentDirectory}/../anes/{Category}/{GroupId}.{ArtifactId}-{Version}.ane extension.xml ";
            adtString += "-swc DummyANE.swc";

            foreach (var p in PlatformsList) {
                adtString += $" -platform {p} ";

                if (p == "default") {
                    adtString += "-C platforms/default library.swf";
                }
                else {
                    adtString += "-C platforms/android";
                    adtString += " library.swf classes.jar -platformoptions platforms/android/platform.xml ";
                    adtString += string.Join(" ", jars);
                    adtString += " ";
                    adtString += string.Join(" ", resources);

                    var hasDependencyJni = _dependencies.Any(dependency => dependency.HasJni);
                    if (!HasJni && !hasDependencyJni) continue;
                    var libsFolder = $"{BuildDirectory}/platforms/android/libs";
                    var arch = Arches[p];
                    var archFolder = $"{libsFolder}/{arch}";
                    if (!Directory.Exists(libsFolder)) {
                        Directory.CreateDirectory(libsFolder);
                    }

                    if (!Directory.Exists(archFolder)) {
                        Directory.CreateDirectory(archFolder);
                    }

                    if (HasJni) {
                        var jniSource = $"{CurrentDirectory}/cache/{Category}/{GroupId}-{ArtifactId}-{Version}-jni/{arch}";
                        DirectoryCopy(jniSource, archFolder);
                    }

                    if (hasDependencyJni) {
                        foreach (var jniSource in _dependencies.Select(dependency => $"{CurrentDirectory}/cache/{Category}/{dependency.GroupId}-{dependency.ArtifactId}-{dependency.Version}-jni/{arch}")) {
                            DirectoryCopy(jniSource, archFolder);
                        }
                    }

                    adtString += $" libs/{arch}/.";
                }
            }

            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) {
                adtString = adtString.Replace("/", "\\");
                adtString = "/c " + adtString;
            }

            var startInfo = new ProcessStartInfo(Shell) {
                CreateNoWindow = false,
                UseShellExecute = false,
                WorkingDirectory = $"{BuildDirectory}",
                WindowStyle = ProcessWindowStyle.Hidden,
                Arguments = adtString
            };

            try {
                using var exeProcess = Process.Start(startInfo);
                exeProcess?.WaitForExit();
            }
            catch (Exception e) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(e.Message);
            }
        }

        private static void CleanupBuildFiles() {
            var buildDir = $"{BuildDirectory}";
            if (Directory.Exists(buildDir)) {
                Directory.Delete(buildDir, true);
            }
        }

        private static void DirectoryCopy(string sourceDirName, string destDirName, bool copySubDirs = true) {
            var dir = new DirectoryInfo(sourceDirName);

            if (!dir.Exists) {
                throw new DirectoryNotFoundException(
                    "Source directory does not exist or could not be found: "
                    + sourceDirName);
            }

            var dirs = dir.GetDirectories();
            // If the destination directory doesn't exist, create it.
            if (!Directory.Exists(destDirName)) {
                Directory.CreateDirectory(destDirName);
            }

            // Get the files in the directory and copy them to the new location.
            var files = dir.GetFiles();
            foreach (var file in files) {
                var tempPath = Path.Combine(destDirName, file.Name);
                file.CopyTo(tempPath, false);
            }

            // If copying subdirectories, copy them and their contents to new location.
            if (!copySubDirs) return;
            {
                foreach (var subDir in dirs) {
                    var tempPath = Path.Combine(destDirName, subDir.Name);
                    DirectoryCopy(subDir.FullName, tempPath);
                }
            }
        }
    }
}