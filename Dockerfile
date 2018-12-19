# escape=`

# BUILD WTIH CMD (from where Dockerfile is): 
# > docker build -t kef7/iis-php .

FROM microsoft/windowsservercore:ltsc2016

LABEL name="kef7/iis-php" tag="latest" version="1.1.0" maintainer="kef7"

# Create new user for IIS remote mgmt use
ARG pw="ii`$adm1nPWyes"
RUN echo #-iisadmin-password: %pw% & net user iisadmin %pw% /add && net localgroup administrators iisadmin /add

# Install IIS and FastCGI features
RUN powershell -Command `
    Install-WindowsFeature -Name 'web-server', 'web-cgi', 'web-http-redirect', 'web-cert-auth', 'web-includes', 'web-mgmt-service'; `
    Set-ItemProperty -Path  'HKLM:\SOFTWARE\Microsoft\WebManagement\Server' -Name 'EnableRemoteManagement'  -Value 1; `
    Set-Service -Name 'WMSVC'  -StartupType Automatic; `
    Start-service -Name 'WMSVC'; `
    Remove-Item 'C:/inetpub/wwwroot/*' -Recurse -Force; 
    # Above: Install IIS and IIS features; Enable remote IIS remote mgmt; Set IIS remote mgmt service to start automatically;
    #   Start IIS remote mgmt; Remove default site files so that volume can be mounted at that location

# Expose default HTTP & HTTPS port
EXPOSE 80 443 8172

# Download and install PHP; test hash to see if zip has been modified also
ENV PHP_HOME="C:\php"
RUN powershell -Command `
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'; `
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols; `
    Invoke-WebRequest -UseBasicParsing -Uri 'https://windows.php.net/downloads/releases/php-7.3.0-nts-Win32-VC15-x64.zip' -OutFile 'C:/php.zip'; `
    if ((Get-FileHash 'C:/php.zip' -Algorithm sha256).Hash -ne '5301e3ba616d4c01cafa8a29cb833b78efeb1e840d3efffb4696a10c462a22a3') { exit 1 }; `
    Expand-Archive -Path 'C:/php.zip' -DestinationPath $env:PHP_HOME; `
    Remove-Item 'C:/php.zip'; `
    Move-Item ($env:PHP_HOME + '/php.ini-production') ($env:PHP_HOME + '/php.ini'); `
    $env:PATH = $env:PATH + ';' + $env:PHP_HOME; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine);
    # ABOVE: Defien supported sec protocol versions; Set supported sec protocol versions; DL PHP zip file from php.net; Check zip file hash; Unzip file; 
    #   Remove zip file; Move unziped data into PHP home; Contact PHP home into env PATH; Set new PATH in env; 

# Configure IIS for PHP support by added php-cgi.exe as FastCGI module and by adding a handler for PHP files 
RUN %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/handlers /+[name='PHP-FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='C:\php\php-cgi.exe',resourceType='Either'] && `
    %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='C:\php\php-cgi.exe'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='c:\php\php-cgi.exe'].environmentVariables.[name='PHP_FCGI_MAX_REQUESTS',value='10000'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='c:\php\php-cgi.exe'].environmentVariables.[name='PHPRC',value='C:\php'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /[fullPath='c:\php\php-cgi.exe'].instanceMaxRequests:10000 && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/defaultDocument /enabled:true /+files.[value='index.php'] && `
    %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/staticContent /+[fileExtension='.php',mimeType='application/php']

# Install Visual C++ Redistributable 2015 that maybe used by PHP
ADD [ "https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe", "C:/vc_redist.x64.exe" ]
RUN C:\vc_redist.x64.exe /quiet /install && del /F /Q C:\vc_redist.x64.exe

# Install ServiceMonitor.exe from MS to set and set as the entryp point so that it monitors IIS (w3svc)
ADD [ "https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.6/ServiceMonitor.exe", "C:/ServiceMonitor.exe" ]
ENTRYPOINT [ "C:/ServiceMonitor.exe", "w3svc" ]

# Set default site root path as volume
VOLUME [ "C:/inetpub/wwwroot" ]