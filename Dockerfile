# BUILD WTIH CMD (from where Dockerfile is): 
# > docker build -t kef7/iis-php .

# NOT READY FOR THIS YET, IDK!!!
# RESOURCES:
# https://blog.sixeyed.com/how-to-dockerize-windows-applications/
# https://hub.docker.com/r/microsoft/windowsservercore/
# https://docs.microsoft.com/en-us/iis/application-frameworks/install-and-configure-php-on-iis/install-php-and-fastcgi-support-on-server-core
# https://www.assistanz.com/steps-to-install-php-manually-on-windows-2016-server/

FROM mcr.microsoft.com/windows/servercore:ltsc2016

LABEL maintainer="kef7"

# Install IIS and FastCGI features
RUN powershell -Command \
    Install-WindowsFeature -Name web-server, web-cgi;

# Download and install PHP; test hash to see if zip has been modified also
ENV PHP_ZIP_SHA256="8bc4e2cbfe8b17b9a269925dd005a23a9b8c07f87965b9f70a69b1420845d065"
ENV PHP_ZIP_URL="https://windows.php.net/downloads/releases/php-7.3.0-Win32-VC15-x64.zip"
ENV PHP_ZIP_FILEPATH="C:\php.zip"
ENV PHP_HOME="C:\php"
RUN powershell -Command \
    Invoke-WebRequest -UseBasicParsing -Uri $env:PHP_ZIP_URL -OutFile $env:PHP_ZIP_FILEPATH;
RUN powershell -Command \
    if ((Get-FileHash $env:PHP_ZIP_FILEPATH -Algorithm sha256).Hash -ne $env:PHP_ZIP_SHA256) { exit 1 }; \
    Expand-Archive -Path $env:PHP_ZIP_FILEPATH -DestinationPath $env:PHP_HOME; \
    Remove-Item $env:PHP_ZIP_FILEPATH; \
    Move-Item "$($env:PHP_HOME)\php.ini-development" "$($env:PHP_HOME)\php.ini";
RUN powershell -Command \
    $env:PATH = $env:PATH + ";" + $env:PHP_HOME; \
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine);
    # Above, in order: Download php.zip, check zip hash, unzip, remove zip, rename php.ini, get Path environment var, set php path to Path evnironment var

# Configure IIS for PHP support
RUN %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/fastCGI /+[fullPath='C:\php\php-cgi.exe']
RUN %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/handlers /+[name='PHP-FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='C:\php\php-cgi.exe',resourceType='Either']

# Install ServiceMonitor.exe from MS to set as the entry point of this image
RUN powershell -Command \
    Invoke-WebRequest -UseBasicParsing -Uri "https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.6/ServiceMonitor.exe" -OutFile "C:\ServiceMonitor.exe";

# Expose default HTTP & HTTPS port
EXPOSE 80
EXPOSE 443

# Set entry point; setup docker to run ServiceMonitor.exe that will monitor IIS (w3svc)
ENTRYPOINT [ "C:\\ServiceMonitor.exe", "w3svc" ]