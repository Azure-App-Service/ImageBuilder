# ImageBuilder

[![Build Pipeline Status]()]()
[![Release Pipeline Status]()]()

ImageBuilder is the CI and Release pipeline for the Build and Runtime Blessed Images for Azure App Service Linux platform. These images use [Microsoft Oryx](https://github.com/microsoft/oryx) as the base images.

To receive updates on runtimes and versions supported by App Service,
subscribe to [Azure Updates][] or watch the
[github.com/Azure/app-service-announcements](https://github.com/Azure/app-service-announcements)
tracker.

[Azure App Service]: https://azure.microsoft.com/services/app-service/
[Azure Updates]: https://azure.microsoft.com/updates

The build container and runtime images share the '/home' directory. The [Build container](https://github.com/Azure-App-Service/KuduLite) provides a various methods to publish code. The published code is then built as an artifact depending upong the configured Framework and the Framework Version into 'home/site/wwwroot' directory. This built artifact is then consumed by the runtime images.

# Supported platforms


Framework | Framework Version | Image Repo | 
--------|--------|--------|
Python  | 3.7<br />3.6 <br/>2.7 | mcr.microsoft.com/appservice/python:3.7_20200101.1 <br /> mcr.microsoft.com/appservice/python:3.6_20200101.1 <br /> mcr.microsoft.com/appservice/python:2.7_20200101.1 <br /> |
Node.js |  8-lts <br /> 10-lts <br /> 12-lts <br /> 4.4<br /> 4.5 <br/> 4.8 <br />6.2 <br /> 6.6 <br /> 6.9 <br /> 6.10 <br /> 6.11 <br /> 8.0 <br /> 8.1 <br /> 8.2 <br /> 8.8 <br /> 8.9 <br /> 8.11 <br /> 8.12 <br /> 9.4<br /> 10.1 <br /> 10.10 <br /> 10.12 <br /> 10.14 |  mcr.microsoft.com/appservice/node:8-lts <br /> mcr.microsoft.com/appservice/node:10-lts <br /> mcr.microsoft.com/appservice/node:12-lts <br /> mcr.microsoft.com/appservice/node:4.4_1905131832 <br /> mcr.microsoft.com/appservice/node:4.5_1905131832 <br /> mcr.microsoft.com/appservice/node:4.8_1905131832 <br /> mcr.microsoft.com/appservice/node:6.2_1905131832 <br /> mcr.microsoft.com/appservice/node:6.6_1905131832 <br /> mcr.microsoft.com/appservice/node:6.9_1905131832 <br /> mcr.microsoft.com/appservice/node:6.10_1905131832 <br /> mcr.microsoft.com/appservice/node:6.11_1905131832 <br /> mcr.microsoft.com/appservice/node:8.0_1905131832 <br /> mcr.microsoft.com/appservice/node:8.1_1905131832 <br /> mcr.microsoft.com/appservice/node:8.2_1905131832 <br /> mcr.microsoft.com/appservice/node:8.8_1905131832 <br /> mcr.microsoft.com/appservice/node:8.9_1905131832 <br /> mcr.microsoft.com/appservice/node:8.11_1905131832 <br /> mcr.microsoft.com/appservice/node:8.12_1905131832 <br /> mcr.microsoft.com/appservice/node:9.4_1905131832 <br /> mcr.microsoft.com/appservice/node:10.1_1905131832 <br /> mcr.microsoft.com/appservice/node:10.10_1905131832 <br /> mcr.microsoft.com/appservice/node:10.12_1905131832 <br /> mcr.microsoft.com/appservice/node:10.14_1905131832|
.NET Core | 1.0 <br /> 1.1<br /> 2.0 <br /> 2.1 <br /> 2.2 <br /> 3.0 </br> 3.1| mcr.microsoft.com/appservice/dotnetcore:1.0_20200101.1 <br /> mcr.microsoft.com/appservice/dotnetcore:1.1_20200101.1 <br /> mcr.microsoft.com/appservice/dotnetcore:2.0_20200101.1 <br /> mcr.microsoft.com/appservice/dotnetcore:2.1_20200101.1 <br /> mcr.microsoft.com/appservice/dotnetcore:2.2_20200101.1 <br /> mcr.microsoft.com/appservice/dotnetcore:3.0_20200101.1 <br /> mcr.microsoft.com/appservice/dotnetcore:3.1_20200101.1 |
PHP     | 5.6<br />7.0 <br /> 7.2 <br /> 7.3 |  mcr.microsoft.com/appservice/php:5.6.40-apache_20200101.1 <br /> mcr.microsoft.com/appservice/php:7.0.33-apache_190307131 <br /> mcr.microsoft.com/appservice/php:7.2.15-apache_20200101.1 <br /> mcr.microsoft.com/appservice/php:7.3.2-apache_190307131 <br /> |
Ruby    | 2.3.3 <br /> 2.3.8 <br /> 2.4.5 <br /> 2.5.5 <br /> 2.6.2 |  mcr.microsoft.com/appservice/ruby:2.3.3_20200101.1 <br /> mcr.microsoft.com/appservice/ruby:2.3.8_20200101.1 <br /> mcr.microsoft.com/appservice/ruby:2.4.5_20200101.1 <br /> mcr.microsoft.com/appservice/ruby:2.5.5_20200101.1 <br /> mcr.microsoft.com/appservice/ruby:2.6.2_20200101.1 <br /> |

Patches (0.0.**x**) are applied as soon as possible after they are released upstream.

# Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

# License

MIT, see [LICENSE.md](./LICENSE.md).

# Security

Security issues and bugs should be reported privately, via email, to the
Microsoft Security Response Center (MSRC) at
[secure@microsoft.com](mailto:secure@microsoft.com). You should receive a
response within 24 hours. If for some reason you do not, please follow up via
email to ensure we received your original message. Further information,
including the [MSRC
PGP](https://technet.microsoft.com/en-us/security/dn606155) key, can be found
in the [Security
TechCenter](https://technet.microsoft.com/en-us/security/default).

# Data/Telemetry

When utilized within Azure services, this project collects usage data and
sends it to Microsoft to help improve our products and services. Read
[Microsoft's privacy statement][] to learn more.

[Microsoft's privacy statement]: http://go.microsoft.com/fwlink/?LinkId=521839

This project follows the [Microsoft Open Source Code of Conduct][coc]. For
more information see the [Code of Conduct FAQ][cocfaq]. Contact
[opencode@microsoft.com][cocmail] with questions and comments.

[coc]: https://opensource.microsoft.com/codeofconduct/
[cocfaq]: https://opensource.microsoft.com/codeofconduct/faq/
[cocmail]: mailto:opencode@microsoft.com