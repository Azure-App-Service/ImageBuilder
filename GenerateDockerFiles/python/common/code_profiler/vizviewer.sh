#!/usr/bin/env bash
appname="${WEBSITE_SITE_NAME:-'<app-name>'}"

echo "Please use the following steps to download and review the trace locally:"
echo "1. Ensure Python is installed in you Linux machine / Windows Subsystem for Linux (WSL)
2. Run the following command :
   pip install viztracer
3. Navigate to file manager of Kudu site of the App Service 
   (e.g. https://$appname.scm.azurewebsites.net/newui/fileManager)
4. Navigate to /home/LogFiles/CodeProfiler/ and download profiler_trace.json
5. In your local machine (Linux / WSL), run the following command
   vizviewer profiler_trace.json
"