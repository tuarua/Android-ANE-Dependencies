using System.Xml;

namespace AndroidDependencyBuilder {
    public class Dependency : PackageBase {
        public readonly string PackageName;

        public Dependency(XmlNode node) {
            Name = node.Attributes["name"].Value;
            GroupId = node["groupId"]?.ChildNodes[0].Value;
            ArtifactId = node["artifactId"].ChildNodes[0].Value;
            Version = node["version"].ChildNodes[0].Value;
            Type = ConvertType(node["type"].ChildNodes[0].Value);
            Repo = ConvertRepo(node["repo"].ChildNodes[0].Value);
            PackageName = node["packageName"]?.ChildNodes[0].Value;
        }
    }
}