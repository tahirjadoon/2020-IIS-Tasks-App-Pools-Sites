#Requires -RunAsAdministrator
#Requires -Modules WebAdministration

<#
	app pools settings 
		appPoolDotNetVersion = v2.0 | v4.0 | No Managed Code
		appPoolManagedPipelineMode = Classic | Integrated 
		appPoolStartMode = OnDemand | AlwaysRunning
		appPoolRecreateIfPresent = $true | $false
	
	application \ virtual directories settings 
		isApplication = $true : Application | $false : virtual directory
		isRecreateIfPresent = $true | $false
		
	Application or the virtual directory will be created under the default website. 
	
	hash table of arrays and associated sites 
	make sure that the user is created on the server when passing in the userId and Password
	
	IMPORTANT: must execute following command before runnig the script in power shell
			Set-ExecutionPolicy RemoteSigned
#>

$hashTableArray = @(
	@{
		runAllAppPoolsAtEnd = $true #$true | $false 
	},
    @{
		#app pools
        appPoolName = "AppPools.AppPools1AP"
        appPoolDotNetVersion = "No Managed Code" 
		appPoolManagedPipelineMode = "Classic"  
		appPoolStartMode = "AlwaysRunning"
		appPoolUserName = ""
		appPoolPassword = ""
		appPoolRecreateIfPresent = $true #$true and $false
		
		#application / virtual directories
		isApplication = $true 
		isRecreateIfPresent = $true 
		name = "Services.Service1"
		physicalPath = "C:\inetpub\wwwroot\Services\Service1"
		
    },
	@{
		#app pools
        appPoolName = "AppPools.AppPools2AP"
        appPoolDotNetVersion = "V4.0" 
		appPoolManagedPipelineMode = "Integrated"  
		appPoolStartMode = "AlwaysRunning"
		appPoolUserName = ""
		appPoolPassword = ""
		appPoolRecreateIfPresent = $true #$true and $false
		
		#application / virtual directories
		isApplication = $true 
		isRecreateIfPresent = $true 
		name = "Services.Service2"
		physicalPath = "C:\inetpub\wwwroot\Services\Service2"
		
    },
	@{
		#virtual directory - no app pool info is needed
		isApplication = $false #virtual directory  
		isRecreateIfPresent = $true
		name = "VirtualDirectory.VirtualDir1"
		physicalPath = "C:\inetpub\wwwroot\VirtualDir\VD1"
    }
)

# function to creaate App-Pools 
Function Create-AppPools($elem) {
	if (!$elem.appPoolName) {
        return;
    }

    Write-Host " "
	Write-Host "`t Creating AppPool: $($elem.appPoolName)"
	
    #navigate to the app pools root
    cd IIS:\AppPools\

	try{
	
		#check if the app pool exists
		$appPoolPresent = $false 
		if ((Test-Path $elem.appPoolName -pathType container)){
			$appPoolPresent = $true 
		}
		
		if($appPoolPresent -And $elem.appPoolRecreateIfPresent) {
			Remove-WebAppPool -Name $elem.appPoolName
			Write-Host "`t`t AppPool: $($elem.appPoolName) was present so deleted it" -ForegroundColor Red
			$appPoolPresent = $false
		}
		
		if (!($appPoolPresent)) {
			#create the app pool
			$appPool = New-Item $elem.appPoolName
			if ($elem.appPoolDotNetVersion) {
				$appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value $elem.appPoolDotNetVersion
			}
			if ($elem.appPoolManagedPipelineMode) {
				$appPool | Set-ItemProperty -Name "managedPipelineMode" -Value $elem.appPoolManagedPipelineMode
			}
			if ($elem.appPoolStartMode) {
				$appPool | Set-ItemProperty -Name "startMode" -Value $elem.appPoolStartMode
			}
			if ($elem.appPoolUserName -and $elem.appPoolPassword) {
				$apppool | Set-ItemProperty -Name processmodel -value @{userName = $elem.appPoolUserName; password = $elem.appPoolPassword; identitytype = 3 }
			}
			else {
				$apppool | Set-ItemProperty -Name "ProcessModel.IdentityType" -value  3
			}
			Write-Host "`t`t AppPool: $($elem.appPoolName) created successfully" -ForegroundColor Green
		}
		else {
			Write-Host "`t`t AppPool $($elem.appPoolName) already exists" -ForegroundColor Cyan
		}
	}
	catch {
		Write-Host "`t`t Error Creating AppPool: $($elem.appPoolName) Error: $($_)" -ForegroundColor Red
	}
}

Function Create-ApplicationVirtualDir($elem) {
	<#
	isApplication = $true 
		name = "Services.Service2"
		physicalPath
	#>
	if (($elem.isApplication -And !$elem.appPoolName) -Or !$elem.name) {
        return;
    }
	
	Write-Host " "
	$description = "Application"
	if(!$elem.isApplication) {
		$description = "Virtual Directory"
	}
		
	Write-Host "`t Creating $($description): $($elem.name)"
	
	try{
		#check and create the directory 
		if($elem.physicalPath -And !(test-path -Path $elem.physicalPath)){
			New-Item -ItemType Directory -Force -Path $elem.physicalPath | Out-Null #Out-Null will hide the output
			Write-Host "`t`t SourceDir: $($elem.physicalPath) created successfully" -ForegroundColor Green
		}
		else {
			Write-Host "`t`t SourceDir: $($elem.physicalPath) already exists" -ForegroundColor Cyan
		}
	
		$defaultWebSite = "Default Web Site"
		$iisPath = "IIS:\Sites\$($defaultWebSite)\$($elem.name)"
		
		#check if present 
		$isPresent = $false
		if(Test-Path $iisPath){
			$isPresent = $true 
		}
		
		if($isPresent -And $elem.isRecreateIfPresent){
			if($elem.isApplication){
				Remove-WebApplication -Site $defaultWebSite -Name $elem.name 
			}
			else {
				Remove-WebVirtualDirectory -Name $elem.name -Application $defaultWebSite
			}
			Write-Host "`t`t $($description): $($elem.name) was present so deleted it" -ForegroundColor Red
			$isPresent = $false
		}
		
		if($isPresent){
			Write-Host "`t`t $($description): $($elem.name) already exists" -ForegroundColor Cyan
		}
		elseif($elem.isApplication) {
			#application 
			New-WebApplication -Site $defaultWebSite -Name $elem.name -PhysicalPath $elem.physicalPath -ApplicationPool $elem.appPoolName -Force  | Out-Null
			Write-Host "`t`t $($description): $($elem.name) created successfully" -ForegroundColor Green
		}
		else {
			#virtual directory 
			New-WebVirtualDirectory -Name $elem.name -Application "" -PhysicalPath $elem.physicalPath -Site $defaultWebSite -Force  | Out-Null
			Write-Host "`t`t $($description): $($elem.name) created successfully" -ForegroundColor Green
		}
	}
	catch {
		Write-Host "`t`t Error Creating $($description): $($elem.name) Error: $($_)" -ForegroundColor Red
	}
}

#region create App Pools and sites 

if ($hashTableArray.Length -gt 0){
	Write-Host ">> Creating AppPools" -BackgroundColor Yellow  -ForegroundColor Black
	foreach ($x in $hashTableArray) {
		Create-AppPools	-elem $x 
	}

	Write-Host " "

	Write-Host ">> Creating Applications / Virtual Dirs" -BackgroundColor Yellow  -ForegroundColor Black
	foreach($x in $hashTableArray) {
		Create-ApplicationVirtualDir -elem $x
	}
}