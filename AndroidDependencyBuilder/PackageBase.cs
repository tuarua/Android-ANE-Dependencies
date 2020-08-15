using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;

namespace AndroidDependencyBuilder {
    public abstract class PackageBase {
        public string Name;
        public string GroupId;
        public string ArtifactId;
        public string Version;
        protected Type Type;
        protected Repo Repo;
        public bool HasResources { get; private set; }
        protected internal bool HasJni { get; set; }
        protected static string CurrentDirectory => Directory.GetCurrentDirectory();

        public async Task Download(string category) {
            var packageName = $"{ArtifactId}-{Version}";
            var packageDirectory = $"{CurrentDirectory}/cache/{category}/{GroupId}";
            var resourcesSource = $"{packageDirectory}/{packageName}/res";
            var resourcesDestination = $"{packageDirectory}-{packageName}-res";
            var jniSource = $"{packageDirectory}/{packageName}/jni";
            var jniDestination = $"{packageDirectory}-{packageName}-jni";
            var groupIdPath = GroupId.Replace(".", "/");

            if (File.Exists($"{packageDirectory}-{packageName}.jar")) {
                Console.WriteLine($"{packageName} already exists");
                HasResources = Directory.Exists(resourcesDestination) && !IsDirectoryEmpty(resourcesDestination);
                HasJni = Directory.Exists(jniDestination);
                return;
            }

            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Getting package for {ArtifactId}");

            if (!Directory.Exists(packageDirectory)) {
                Directory.CreateDirectory(packageDirectory);
            }

            Console.WriteLine(
                $"Downloading {Program.RepoUrls[Repo]}{groupIdPath}/{ArtifactId}/{Version}/{packageName}.{Type}");

            var client = new HttpClient();
            try {
                var response = await client.GetByteArrayAsync(
                    new Uri($"{Program.RepoUrls[Repo]}{groupIdPath}/{ArtifactId}/{Version}/{packageName}.{Type}"));
                File.WriteAllBytes($"{packageDirectory}/{packageName}.{Type}", response);

                if (Type == Type.aar) {
                    var zipPath = $"{packageDirectory}/{packageName}.zip";
                    File.Move($"{packageDirectory}/{packageName}.aar", zipPath);
                    ZipFile.ExtractToDirectory(zipPath, $"{packageDirectory}/{packageName}");
                    File.Delete(zipPath);
                    File.Move($"{packageDirectory}/{packageName}/classes.jar", $"{packageDirectory}/{packageName}.jar");

                    if (Directory.Exists(resourcesSource) && !IsDirectoryEmpty(resourcesSource)) {
                        if (Directory.Exists(resourcesDestination)) {
                            Directory.Delete(resourcesDestination, true);
                        }

                        Directory.Move(resourcesSource, resourcesDestination);
                        HasResources = true;
                    }

                    if (Directory.Exists(jniSource)) {
                        if (Directory.Exists(jniDestination)) {
                            Directory.Delete(jniDestination, true);
                        }

                        Directory.Move(jniSource, jniDestination);
                        HasJni = true;
                    }
                }
            }
            catch (HttpRequestException e) {
                Console.WriteLine("\nException Caught!");
                Console.WriteLine("Message :{0} ", e.Message);
                return;
            }

            File.Move($"{packageDirectory}/{packageName}.jar",
                $"{packageDirectory}-{packageName}.jar", true);
            Directory.Delete(packageDirectory, true);
            Console.ResetColor();
        }

        protected static Repo ConvertRepo(string value) {
            return value switch {
                "google" => Repo.Google,
                "jcenter" => Repo.JCenter,
                "maven" => Repo.Maven,
                _ => Repo.Google
            };
        }

        protected static Type ConvertType(string value) {
            return value switch {
                "jar" => Type.jar,
                _ => Type.aar
            };
        }
        
        private static bool IsDirectoryEmpty(string path) {
            return !Directory.EnumerateFileSystemEntries(path).Any();
        }
    }
}