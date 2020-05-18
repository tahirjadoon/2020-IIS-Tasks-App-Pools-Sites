@ECHO OFF

iisreset /stop
net stop W3SVC /y
C:\Windows\System32\inetsrv\appcmd stop apppools /apppool.name:Service1AP


C:\Windows\System32\inetsrv\appcmd delete app /app.name:"Default Web Site/Service1"
C:\Windows\System32\inetsrv\appcmd add app /site.name:"Default Web Site" /path:/Servicea /physicalPath:C:\inetpub\wwwroot\Servicea /preLoadEnabled:true
C:\Windows\System32\inetsrv\appcmd delete apppools /apppool.name:Service1AP
C:\Windows\System32\inetsrv\appcmd add apppool /name:Service1AP /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated /processModel.maxProcesses:1 /startMode:AlwaysRunning /processModel.idleTimeout:"24:00:00" /recycling.periodicRestart.time:"00:00:00"
C:\Windows\System32\inetsrv\appcmd set config -section:system.applicationHost/applicationPools /+"[name='Service1AP'].recycling.periodicRestart.schedule.[value='02:00:00']" /commit:apphost
C:\Windows\System32\inetsrv\appcmd set app /app.name:"Default Web Site/Service1" /applicationPool:Service1AP



iisreset /start
net start W3SVC /y
C:\Windows\System32\inetsrv\appcmd start apppools /apppool.name:Service1AP