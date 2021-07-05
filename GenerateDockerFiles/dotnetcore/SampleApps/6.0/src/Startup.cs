using System;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.FileProviders;
using Microsoft.AspNetCore.StaticFiles;

namespace hostingstart
{
    public class Startup
    {
        public void Configure(IApplicationBuilder app)
        {
            var options = new DefaultFilesOptions();
            options.DefaultFileNames.Add("hostingstart.html");

            app.UseDefaultFiles(options)
               .UseStaticFiles();
        }
    }
}
