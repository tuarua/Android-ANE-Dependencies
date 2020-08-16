using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Xml;

namespace AndroidDependencyBuilder {
    public static class Program {
        private static string _airSdkPath;
        public static string AdtPath;
        public static string ManifestMergerPath;
        private static readonly Dictionary<string, Package> Packages = new Dictionary<string, Package>();

        public static readonly Dictionary<Repo, string> RepoUrls = new Dictionary<Repo, string> {
            [Repo.Google] = "https://dl.google.com/dl/android/maven2/",
            [Repo.JCenter] = "https://jcenter.bintray.com/",
            [Repo.Maven] = "https://repo1.maven.org/maven2/"
        };

        private static async Task Main(string[] args) {
            if (args.Length == 0) {
                PrintError("Pass the package name to compile as an argument");
                return;
            }

            LoadAndroidSdkDir();
            if (ManifestMergerPath == null) {
                PrintError($"Cannot find the manifest-merger");
                return;
            }
            LoadPackages();
            LoadAirConfig();

            var packageName = args[0];
            if (!Packages.ContainsKey(packageName)) {
                PrintError($"Cannot find the package {packageName}");
                return;
            }

            var package = Packages[packageName];
            await package.Download(package.Category);
            package.CreateAneFiles();

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Finished");
            Console.ResetColor();
        }

        private static void PrintError(string message) {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine(message);
            Console.ResetColor();
        }

        private static void LoadAirConfig() {
            _airSdkPath = File.ReadAllText("airsdk.cfg");
            var adt = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "adt.bat" : "adt";
            AdtPath = $"{_airSdkPath}/bin/{adt}";
        }

        private static void LoadAndroidSdkDir() {
            var propsPath = $"{Directory.GetCurrentDirectory()}/../native_library/android/local.properties";
            var lines = File.ReadLines(propsPath);
            foreach (var line in lines) {
                if (line.Length < 8) {
                    continue;
                }
                if (line.Substring(0, 8) != "sdk.dir=") continue;
                var androidSdkPath = line.Split("=")[1];
                var manifestMerger = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "manifest-merger.bat" : "manifest-merger";
                ManifestMergerPath = $"{androidSdkPath}/tools/bin/{manifestMerger}";
                break;
            }
        }

        private static void LoadPackages() {
            var doc = new XmlDocument();
            doc.Load("packages.xml");

            foreach (var package in from XmlNode node in doc.DocumentElement select new Package(node)) {
                Packages.Add(package.Name, package);
            }
        }
    }
}