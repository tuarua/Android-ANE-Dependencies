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
        private static readonly Dictionary<string, Package> Packages = new Dictionary<string, Package>();

        public static readonly Dictionary<Repo, string> RepoUrls = new Dictionary<Repo, string> {
            [Repo.Google] = "https://dl.google.com/dl/android/maven2/",
            [Repo.JCenter] = "https://jcenter.bintray.com/",
            [Repo.Maven] = "https://repo1.maven.org/maven2/"
        };

        private static async Task Main(string[] args) {
            if (args.Length == 0) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Pass the package name to compile as an argument");
                Console.ResetColor();
                return;
            }

            LoadPackages();
            LoadAirConfig();

            var packageName = args[0];
            if (!Packages.ContainsKey(packageName)) {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Cannot find the package {packageName}");
                Console.ResetColor();
                return;
            }

            var package = Packages[packageName];
            await package.Download(package.Category);
            package.CreateAneFiles();

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Finished");
            Console.ResetColor();
        }

        private static void LoadAirConfig() {
            _airSdkPath = File.ReadAllText("airsdk.cfg");
            var adt = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "adt.bat" : "adt";
            AdtPath = $"{_airSdkPath}/bin/{adt}";
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