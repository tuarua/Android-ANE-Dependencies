using System;
using System.Collections.Generic;
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
                PrintError("Pass the package name to compile as an argument or -all to compile all");
                return;
            }

            GetManifestMerger();
            LoadPackages();
            LoadAirConfig();

            var packageName = args[0];
            var list = new List<string>();
            if (packageName == "-all")
            {
                list.AddRange(Packages.Select(p=> p.Key));
            }
            else
            {
                if (!Packages.ContainsKey(packageName)) {
                    PrintError($"Cannot find the package {packageName}");
                    return;
                }
                list.Add(packageName);
            }

            foreach (var package in list.Select(pName => Packages[pName]))
            {
                await package.Download(package.Category);
                package.CreateAneFiles();
            }
            
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

        private static void GetManifestMerger() {
            var manifestMerger = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "manifest-merger.bat" : "manifest-merger";
            ManifestMergerPath = $"{Directory.GetCurrentDirectory()}/{manifestMerger}";
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