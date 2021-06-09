using Docker.DotNet;
using Docker.DotNet.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Xunit;

namespace Tests
{
    public class HelloWorld
    {
        private async Task CleanupContainer(DockerClient client, string name)
        {
            try
            {
                await client.Containers.StopContainerAsync(name, new ContainerStopParameters());
            }
            catch (Exception ex)
            {
                //no-op
            }

            try
            {
                await client.Containers.RemoveContainerAsync(name, new ContainerRemoveParameters());
            }
            catch (Exception ex)
            {
                //no-op
            }
        }

        private async Task CreateRuntimeContainer(DockerClient client, string name, string stack, string version, string appDir, string image, string port)
        {
            string bindPort = "8080";
            string helloWorldApp = $"{Environment.CurrentDirectory}/{appDir}";
            string localImageName = image.Replace("public/appsvc/", "");
            CreateContainerParameters containerConfig = new CreateContainerParameters
            {
                Name = name,
                Image = localImageName,
                ExposedPorts = new Dictionary<string, EmptyStruct> { { bindPort, new EmptyStruct() } },
                Volumes = new Dictionary<string, EmptyStruct> { { "/home/site/wwwroot", new EmptyStruct() } },
                HostConfig = new HostConfig
                {
                    PortBindings = new Dictionary<string, IList<PortBinding>>
                    {
                        { bindPort, new List<PortBinding> { new PortBinding { HostIP = "localhost", HostPort = port } } }
                    },
                    Binds = new List<String>
                    {
                        $"{helloWorldApp}:/home/site/wwwroot"
                    }
                }
            };
            await client.Containers.CreateContainerAsync(containerConfig);
            await client.Containers.StartContainerAsync(name, new ContainerStartParameters());
            Thread.Sleep(10 * 1000);
        }
        private async Task CreateKuduContainer(DockerClient client, string name, string runtimeName, string stack, string version, string appDir, string image)
        {
            string bindPort = "8080";
            string helloWorldApp = $"{Environment.CurrentDirectory}/{appDir}";
            string port = new Random().Next(10000, 65635).ToString();
            string localImageName = image.Replace("public/appsvc/", "");
            CreateContainerParameters containerConfig = new CreateContainerParameters
            {
                Name = name,
                Image = localImageName,
                ExposedPorts = new Dictionary<string, EmptyStruct> { { bindPort, new EmptyStruct() } },
                Volumes = new Dictionary<string, EmptyStruct> { { "/home/site", new EmptyStruct() } },
                HostConfig = new HostConfig
                {
                    PortBindings = new Dictionary<string, IList<PortBinding>>
                    {
                        { bindPort, new List<PortBinding> { new PortBinding { HostIP = "localhost", HostPort = port } } }
                    },
                    Binds = new List<String>
                    {
                        $"{helloWorldApp}:/home/site/"
                    }
                },
                Env = new List<String>
                {
                    $"WEBSITE_SITE_NAME={runtimeName}",
                    $"APPSETTING_WEBSITE_SITE_NAME={runtimeName}",
                    "ORYX_ENV_TYPE=AppService",
                    $"ORYX_ENV_NAME=~1{runtimeName}",
                    "ENABLE_ORYX_BUILD=true",
                    $"FRAMEWORK={stack.ToUpper()}",
                    $"FRAMEWORK_VERSION={version}",
                    "APPSETTING_SCM_USE_LIBGIT2SHARP_REPOSITORY=0",
                    $"HTTP_HOST=localhost:{bindPort}"
                },
                Cmd = new List<String>
                {
                    "1006",
                    "8e62d73f722067ccb9936a1e",
                    "1003",
                    "8e62d73f722067ccb9936a1e",
                    runtimeName
                },
            };
            await client.Containers.CreateContainerAsync(containerConfig);
            await client.Containers.StartContainerAsync(name, new ContainerStartParameters());
            Thread.Sleep(10 * 1000);

            ContainerExecCreateResponse resp = await client.Containers.ExecCreateContainerAsync(name, new ContainerExecCreateParameters()
            {
                Cmd = new List<String>
                {
                    "benv",
                    "dotnet=2.2.8",
                    "dotnet",
                    "/opt/Kudu/KuduConsole/kudu.dll",
                    "/home/site",
                    "/home/site/wwwroot",
                },
            });

            await client.Containers.StartContainerExecAsync(resp.ID);

            Thread.Sleep(10 * 1000);
        }

        private async Task TestKuduImages(string stack, string version, string appDir, string kuduImage, string runtimeImage, string expected)
        {
            DockerClient client = new DockerClientConfiguration(
                new Uri("unix:///var/run/docker.sock"))
                .CreateClient();

            string runtimeName = $"{stack}-test";
            string kuduName = $"{stack}-test-kudu";

            Console.WriteLine($"testing kudu with {stack}");

            int tryNumber = 1;
            int maxTries = 3;
            while (tryNumber <= maxTries)
            {
                tryNumber++;
                try
                {
                    await CleanupContainer(client, runtimeName);
                    await CleanupContainer(client, kuduName);
                    if (Directory.Exists($"{appDir}/wwwroot"))
                    {
                        Directory.Delete($"{appDir}/wwwroot", true);
                    }
                    Directory.CreateDirectory($"{appDir}/wwwroot");

                    string runtimePort = new Random().Next(10000, 65635).ToString();

                    await CreateKuduContainer(client, kuduName, runtimeName, stack, version, appDir, kuduImage);
                    await CreateRuntimeContainer(client, runtimeName, stack, version, $"{appDir}/wwwroot", runtimeImage, runtimePort);

                    WebClient webClient = new WebClient();
                    string html = webClient.DownloadString($"http://localhost:{runtimePort}");
                    Assert.Equal(expected, html);

                    await CleanupContainer(client, runtimeName);
                    await CleanupContainer(client, kuduName);
                    if (Directory.Exists($"{appDir}/wwwroot"))
                    {
                        Directory.Delete($"{appDir}/wwwroot", true);
                    }

                    tryNumber = maxTries + 1;
                    Console.WriteLine("pass");
                    
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex.ToString());
                    if (tryNumber == maxTries+1){
                        throw ex;
                    }
                }
                finally
                {
                    await CleanupContainer(client, runtimeName);
                    await CleanupContainer(client, kuduName);
                    if (Directory.Exists($"{appDir}/wwwroot"))
                    {
                        Directory.Delete($"{appDir}/wwwroot", true);
                    }
                }
            }
        }

        private IEnumerable<string> GetImages(string filename)
        {
            return File.ReadLines(filename);
        }

        [Fact]
        public async Task NodeTests()
        {
            string runtimeImage = GetImages("nodebuiltImageList").Where(s => s.Contains("12-lts")).First();
            string kuduImage = GetImages("KuduLitebuiltImageList").First();
            await TestKuduImages("node", "12-lts", "node", kuduImage, runtimeImage, "Hello World!");
        }

        [Fact]
        public async Task DotNetCoreTests()
        {
            if (!File.Exists("dotnetcore/repository/Startup.cs"))
            {
                File.Move("dotnetcore/repository/Startup.cs-tmp", "dotnetcore/repository/Startup.cs");
            }
            if (!File.Exists("dotnetcore/repository/Program.cs"))
            {
                File.Move("dotnetcore/repository/Program.cs-tmp", "dotnetcore/repository/Program.cs");
            }

            string runtimeImage = GetImages("dotnetcorebuiltImageList").Where(s => s.Contains("3.1")).First();
            string kuduImage = GetImages("KuduLitebuiltImageList").First();
            await TestKuduImages("dotnetcore", "3.1", "dotnetcore", kuduImage, runtimeImage, "Hello, World!");
        }
    }
}
