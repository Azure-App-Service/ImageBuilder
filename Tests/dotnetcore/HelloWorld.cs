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

        private async Task TestImages(string stack, string appDir, IEnumerable<string> images, string expected, string bindPort)
        {
            DockerClient client = new DockerClientConfiguration(
                new Uri("unix:///var/run/docker.sock"))
                .CreateClient();

            string name = String.Format("{0}-test", stack);

            int tryNumber = 1;
            int maxTries = 3;
            while (tryNumber <= maxTries)
            {
                tryNumber++;
                try
                {
                    await CleanupContainer(client, name);
                    string helloWorldApp = String.Format("{0}/{1}", Environment.CurrentDirectory, appDir);
                    string port = new Random().Next(10000, 65635).ToString();
                    foreach (string image in images)
                    {
                        Console.WriteLine(string.Format("testing {0}", image));
                        string localImageName = image.Replace("public/appsvc/","");
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
                                    String.Format("{0}:/home/site/wwwroot", helloWorldApp)
                                }
                            }
                        };
                        await client.Containers.CreateContainerAsync(containerConfig);
                        await client.Containers.StartContainerAsync(name, new ContainerStartParameters());
                        Thread.Sleep(10 * 1000);

                        WebClient webClient = new WebClient();
                        string html = webClient.DownloadString(String.Format("http://localhost:{0}", port));
                        Assert.Equal(expected, html);

                        await CleanupContainer(client, name);
                        tryNumber = maxTries + 1;
                        Console.WriteLine("pass");
                    }
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
                    await CleanupContainer(client, name);
                }
            }
        }

        private IEnumerable<string> GetImages(string filename)
        {
             return File.ReadLines(filename);
        }

        [Fact]
        public async Task Dotnetcore3_1Tests()
        {
            List<string> images = GetImages("dotnetcorebuiltImageList").ToList();
            string image = images.Find((string s) => s.Contains("dotnetcore:3.1_"));
            await TestImages("dotnetcore", "app/3.1", new List<string>{image}, "Hello World!", "8080");
        }

        [Fact]
        public async Task Dotnetcore3_0Tests()
        {
            List<string> images = GetImages("dotnetcorebuiltImageList").ToList();
            string image = images.Find((string s) => s.Contains("dotnetcore:3.0_"));
            await TestImages("dotnetcore", "app/3.0", new List<string>{image}, "Hello World!", "8080");
        }

        [Fact]
        public async Task Dotnetcore2_2Tests()
        {
            List<string> images = GetImages("dotnetcorebuiltImageList").ToList();
            string image = images.Find((string s) => s.Contains("dotnetcore:2.2_"));
            await TestImages("dotnetcore", "app/2.2", new List<string>{image}, "Hello World!", "8080");
        }

        [Fact]
        public async Task Dotnetcore2_1Tests()
        {
            List<string> images = GetImages("dotnetcorebuiltImageList").ToList();
            string image = images.Find((string s) => s.Contains("dotnetcore:2.1_"));
            await TestImages("dotnetcore", "app/2.1", new List<string>{image}, "Hello World!", "8080");
        }

        // [Fact] // FIX ME
        // public async Task Dotnetcore1_1Tests()
        // {
        //     List<string> images = GetImages("dotnetcorebuiltImageList").ToList();
        //     string image = images.Find((string s) => s.Contains("dotnetcore:1.1_"));
        //     await TestImages("dotnetcore", "app/1.1", new List<string>{image}, "Hello World!", "8080");
        // }

        // [Fact]
        // public async Task Dotnetcore1_0Tests()
        // {
        //     List<string> images = GetImages("dotnetcorebuiltImageList").ToList();
        //     string image = images.Find((string s) => s.Contains("dotnetcore:1.0_"));
        //     await TestImages("dotnetcore", "app/1.0", new List<string>{image}, "Hello World!", "8080");
        // }
    }
}
