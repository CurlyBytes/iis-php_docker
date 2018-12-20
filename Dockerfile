# escape=`

# BUILD WTIH CMD (from where Dockerfile is): 
# > docker build -t kef7/iis-php:dev .

# NOTE: DON'T USE " USE ', IN: RUN powershell -Command $var = ''; write-host $var;

# Getting, No input file specified, for *.php files when mounting new folder volumn under C:\inetpub\wwwroot\
# - could be container's permissions to file, PHP configuration, IIS configuration, IDK

# NOT READY FOR THIS YET, IDK!!!
# RESOURCES:
# https://hub.docker.com/r/microsoft/windowsservercore/
# https://blog.sixeyed.com/how-to-dockerize-windows-applications/
# https://docs.microsoft.com/en-us/iis/application-frameworks/install-and-configure-php-on-iis/install-and-configure-php
# https://docs.microsoft.com/en-us/iis/application-frameworks/install-and-configure-php-on-iis/install-php-and-fastcgi-support-on-server-core
# https://www.assistanz.com/steps-to-install-php-manually-on-windows-2016-server/
# https://github.com/Microsoft/iis-docker/blob/master/windowsservercore-ltsc2016/Dockerfile
# https://windows.php.net/download/

FROM microsoft/windowsservercore:ltsc2016

LABEL name="kef7/iis-php" tag="dev" version="1.1.0" maintainer="kef7"

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
COPY [ "build-files/php-7.3.0-Win32-VC15-x64.zip", "C:/php.zip" ]
RUN powershell -Command `
    #$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'; `
    #[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols; `
    #Invoke-WebRequest -UseBasicParsing -Uri 'https://windows.php.net/downloads/releases/php-7.3.0-nts-Win32-VC15-x64.zip' -OutFile 'C:/php.zip'; `
    #if ((Get-FileHash 'C:/php.zip' -Algorithm sha256).Hash -ne '5301e3ba616d4c01cafa8a29cb833b78efeb1e840d3efffb4696a10c462a22a3') { exit 1 }; `
    Expand-Archive -Path 'C:/php.zip' -DestinationPath $env:PHP_HOME; `
    Remove-Item 'C:/php.zip'; `
    $env:PATH = $env:PATH + ';' + $env:PHP_HOME; `
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine);
    # ABOVE: Defien supported sec protocol versions; Set supported sec protocol versions; DL PHP zip file from php.net; Check zip file hash; Unzip file; 
    #   Remove zip file; Move unziped data into PHP home; Contact PHP home into env PATH; Set new PATH in env; 

# Configure PHP and IIS for PHP support by added php-cgi.exe as FastCGI module and by adding a handler for PHP files 
COPY [ "build-files/php/php.ini", "C:/php/php.ini" ]
RUN %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/handlers /+[name='PHP-FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='C:\php\php-cgi.exe',resourceType='Either'] && `
    %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='C:\php\php-cgi.exe'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='c:\php\php-cgi.exe'].environmentVariables.[name='PHP_FCGI_MAX_REQUESTS',value='10000'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /+[fullPath='c:\php\php-cgi.exe'].environmentVariables.[name='PHPRC',value='C:\php'] && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/fastCgi /[fullPath='c:\php\php-cgi.exe'].instanceMaxRequests:10000 && `
    %windir%\system32\inetsrv\appcmd.exe set config /section:system.webServer/defaultDocument /enabled:true /+files.[value='index.php'] && `
    %WinDir%\System32\InetSrv\appcmd.exe set config /section:system.webServer/staticContent /+[fileExtension='.php',mimeType='application/php'] && `
    %WinDir%\System32\InetSrv\appcmd.exe add vdir /app.name:"Default Web Site/" /path:"/__test" /physicalPath:"C:\inetpub\__test"

# Copy example php files into __test virtual directory
COPY [ "src*", "C:/inetpub/__test/" ]

##### - WinCache not supported in PHP 7.3 :( #####
# Install PHP WinCache; configured in php.ini file copied over earlier
##COPY [ "build-files/wincache-2.0.0.8-dev-7.1-nts-vc14-x64.exe", "C:/wincache.exe" ]
##RUN C:\wincache.exe /Q /C /T:C:\php\ext
#COPY [ "build-files/wincache*", "C:/php/ext/" ]

# Install Visual C++ Redistributable 2015 that maybe used by PHP (DELETE ON RUN CMD: && del /F /Q C:\vc_redist.x64.exe)
#ADD [ "https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe", "C:/vc_redist.x64.exe" ]
COPY [ "build-files/vc_redist.x64.exe", "C:/vc_redist.x64.exe" ]
RUN C:\vc_redist.x64.exe /quiet /install

# Install ServiceMonitor.exe from MS to set and set as the entryp point so that it monitors IIS (w3svc)
#ADD [ "https://dotnetbinaries.blob.core.windows.net/servicemonitor/2.0.1.6/ServiceMonitor.exe", "C:/ServiceMonitor.exe" ]
COPY [ "build-files/ServiceMonitor.exe", "C:/ServiceMonitor.exe" ]
ENTRYPOINT [ "C:/ServiceMonitor.exe", "w3svc" ]

# Fix issues with PHP read/write to volumes by adding another abstraction in the form of a mapped drive
# THANKS: https://blog.sixeyed.com/docker-volumes-on-windows-the-case-of-the-g-drive/
#VOLUME "C:\\inetpub\\wwwroot"
#RUN powershell -Command `
#    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices' -Name 'G:' -Value "\??\C:\inetpub\wwwroot" -Type String; 
#RUN %WinDir%\System32\InetSrv\appcmd.exe set app "Default Web Site/" /[@start].physicalpath:"G:\\" && `
#    icacls "C:\\inetpub\\wwwroot" /grant IIS_IUSRS:M && `
#    icacls "G:\\" /grant IIS_IUSRS:M

# DEBUG CHECKS:
RUN powershell -Command `
    Write-Host !!! (Get-Date); `
    Write-Host !!! PHP INI Test: ; C:\php\php.exe --ini; `
    Write-Host !!! PHP CGI `(Exists`): ; Test-Path 'C:/php/php-cgi.exe'; `
    Write-Host !!! PHP WinCache `(Exists`): ; Test-Path 'C:/php/ext/php_wincache.dll'; `
    Write-Host !!! VD Test Files `(Exists`): ; Test-PATH 'C:/inetpub/__test/index.php'; `
    Write-Host !!! SvcMon EXE `(Exists`): ; Test-Path 'C:/ServiceMonitor.exe'; `
    Write-Host !!! Env Var PATH: ; Write-Host $env:PATH; `
    Write-Host !!! App Host Config: ; Get-Content 'C:/windows/system32/inetsrv/config/applicationHost.config'; `
    Write-Host !!! Win Features: ; Get-WindowsFeature;