(** Specify connection name **)
property pCONNECTION_NAME : missing value

(** Specify local port **)
property pLOCAL_PORT : missing value -- Integer

(** Specify SSH user name **)
property pSSH_LOGIN : missing value -- Text

(** Specify remote hosts **)
property pREMOTE_HOSTS : missing value -- List

(** Specify remote ports **)
property pREMOTE_PORTS : missing value -- Integer or list of lists of integers

-- Possible values:
--
-- 1. Single integer: 22
--    Communicate with every host over port 22.
-- 2. List of lists of integers: {{22, 30123}, {80, 443}}
--    The first host will be contacted over port 22 or 30123.
--    Communication with the second host will be attempted over port 80 and 443.

property pKEY_NAMES : missing value

property pKEY_PASSWORD : missing value

property pEDITOR_NAMES : {"AppleScript Editor", "Script Editor", "Coda"}

property pDEBUG_MODE : false

global gSYSTEM_LANGUAGE

property pTUNNEL_MANAGER : missing value

property pRUNS_IN_EDITOR : false

on _______________________________________________MAIN()
end _______________________________________________MAIN

on run
	
	-- Initializes the script, opens a tunnel and checks screen sharing settings and state.
	
	try
		main()
	end try
	
	return
	
end run

on idle
	
	-- Checks tunnel every 3 seconds and reopens it if necessary.
	
	try
		tell my pTUNNEL_MANAGER to checkTunnels()
	end try
	
	return 3
	
end idle

on quit
	
	(*
		Closes all tunnels
	*)
	
	try
		tell my pTUNNEL_MANAGER to closeTunnels()
	end try
	
	-- Don't quit if script runs in an editor
	
	try
		if (my pRUNS_IN_EDITOR) is false then continue quit
	on error
		continue quit
	end try
	
end quit

on main()
	
	try
		
		init() -- Initializes this script
		
		askForPermissionToOpenTunnel() -- Ask for permission
		
		connect() -- Opens a tunnel
		
		showSuccess() -- Displays information to the user
		
		if (my pRUNS_IN_EDITOR) then
			tell my pTUNNEL_MANAGER to closeTunnels()
		end if
		
	on error eMsg number eNum
		
		logMessage(eMsg & " (" & (eNum as text) & ")")
		
		if eNum ­ -128 then -- Ignore 'User canceled.' errors
			
			showError(eMsg)
			
		end if
		
		quit
		
	end try
	
	return
	
end main

on init()
	
	if minSystemVersion("10.6") is false then error "System requirements not met" number 59000
	
	-- Determine whether this script runs inside an editor
	if (name of current application) is in my pEDITOR_NAMES then
		set (my pRUNS_IN_EDITOR) to true
	else
		set my pRUNS_IN_EDITOR to false
	end if
	
	if my pRUNS_IN_EDITOR then
		
		set appSupportDirectory to path to application support folder from user domain as text
		set settingsPath to appSupportDirectory & "Tunnel:Settings:testing.applescript"
		set L to loadScriptText(settingsPath)
		
		set my pCONNECTION_NAME to L's connectionName
		set my pREMOTE_HOSTS to L's remoteHosts
		set my pREMOTE_PORTS to L's remotePorts
		set my pLOCAL_PORT to L's localPort
		set my pSSH_LOGIN to L's sshUserName
		set my pKEY_NAMES to L's keyNames
		set my pKEY_PASSWORD to L's keyPassword
		
	end if
	
	if my pRUNS_IN_EDITOR then
		set my pDEBUG_MODE to true
	else
		set my pDEBUG_MODE to false
	end if
	
	set my pTUNNEL_MANAGER to missing value
	
	clearLogWithMessage("Script initialized")
	
	return
	
end init

on connect()
	
	(*
		Tries to connect to the hosts specified by pREMOTE_HOSTS using 
		ports specified in pREMOTE_PORTS. Exits after the first successful
		connection or raises an error if all attempts fail.
	*)
	
	-- Get a list of hosts and their ports to connect to
	set remoteHosts to my pREMOTE_HOSTS
	if class of remoteHosts is not list then set remoteHosts to {remoteHosts}
	set remotePorts to my pREMOTE_PORTS
	if class of remotePorts is not list then set remotePorts to {remotePorts}
	
	-- Initialize variables to collect errors. 
	-- These will be raised collectively if all connections fail.
	set allErrorMessages to {}
	set allErrorNumbers to {}
	
	-- The counts of hosts and ports don't have to match, but it's important to
	-- get the larger count so that all hosts or all ports are tried.
	set tryCount to count of remoteHosts
	if (count of remoteHosts) < (count of remotePorts) then set tryCount to count of remotePorts
	
	repeat with tryNumber from 1 to tryCount
		
		-- Determine the port for this host
		try
			set remotePortSet to item tryNumber of remotePorts
		on error
			-- Default to the first specified port
			set remotePortSet to item 1 of remotePorts
		end try
		
		-- Determine the name of this host
		try
			set remoteHost to item tryNumber of remoteHosts
		on error eMsg number eNum
			logMessage("Could not get remote host " & (tryNumber as text) & ": " & eMsg)
			-- Default to the first specified host
			set remoteHost to item 1 of remoteHosts
		end try
		
		logMessage("Trying host at " & remoteHost)
		
		if class of remotePortSet is not list then set remotePortSet to {remotePortSet}
		
		repeat with remotePort in remotePortSet
			
			try
				-- Open the tunnel
				openTunnel(my pLOCAL_PORT, remoteHost, remotePort as text, my pSSH_LOGIN)
				return
				
			on error eMsg number eNum
				if eMsg is not in allErrorMessages then
					set end of allErrorMessages to eMsg
					set end of allErrorNumbers to eNum
				end if
				if eNum = -128 then exit repeat
			end try
			
		end repeat
		
	end repeat
	
	-- Combine error messages
	set prvDlmt to text item delimiters
	set text item delimiters to ", "
	set allErrorMessages to allErrorMessages as text
	set text item delimiters to prvDlmt
	
	error allErrorMessages number (item -1 of allErrorNumbers)
	
end connect

on openTunnel(localPort, remoteHost, remotePort, userName)
	
	(*
		Opens a reverse SSH tunnel from the specified local port to a given port of a remote host.
	*)
	
	set aManager to newTunnelManager() -- Create a new Tunnel Manager
	
	repeat with i from 1 to count of my pKEY_NAMES
		
		set keyName to item i of my pKEY_NAMES
		set pathForKey to pathToResource(keyName, "Keys")
		
		try
			do shell script "/usr/bin/ssh-keygen -P '' -e -f " & qpp(pathForKey)
			exit repeat
		on error eMsg number eNum
			set pathForKey to false
		end try
		
	end repeat
	
	if pathForKey is false then
		
		error "None of the keys are supported on this system" number 1
		
	else
		
		tell aManager
			
			-- Initialize Tunnel Manager
			init(remoteHost, remotePort, userName)
			
			-- Set key path
			setKeyFilePath(pathForKey)
			
			if (my pDEBUG_MODE) then enableDebugMode()
			
			-- Initialize tunnel
			set sshTunnel to newTunnel()'s initWithLocalPort(localPort)
			
			-- Close existing tunnel
			closeTunnels()
			
			-- Open tunnel
			openTunnels()
			
		end tell
		
		set my pTUNNEL_MANAGER to aManager
		
		return
		
	end if
	
end openTunnel

on _______________________________________________USER_INTERACTION()
end _______________________________________________USER_INTERACTION

on askForPermissionToOpenTunnel()
	
	(*
		Shows a dialog to the user, asking them to give permission to open the SSH tunnel.
	*)
	
	-- Setup
	set aTitle to localizedString("open_tunnel_title")
	set aMessage to localizedStringWithVar("open_tunnel_message", my pCONNECTION_NAME)
	set dialogButtons to {localizedString("dialog_cancel"), localizedString("open_tunnel_button")}
	set defaultButton to 2
	set cancelButton to 1
	set anIcon to 1
	
	-- Ask user for permission
	set theButton to button returned of displayMessage(aMessage, aTitle, dialogButtons, defaultButton, cancelButton, anIcon, false)
	
	if theButton is (item 1 of dialogButtons) then error "User canceled." number -128
	
	return
	
end askForPermissionToOpenTunnel

on askForPermissionToFixPrivateKeyPermissions()
	
	(*
		Shows a dialog to the user, asking them to give permission to modify the permissions for the private key.
	*)
	
	-- Setup
	set aTitle to localizedString("fix_private_key_permissions_title")
	set aMessage to localizedString("fix_private_key_permissions_message")
	set dialogButtons to {localizedString("dialog_cancel"), localizedString("fix_private_key_button")}
	set defaultButton to 2
	set cancelButton to 1
	set anIcon to 1
	
	-- Ask user for permission
	set buttonPressed to button returned of displayMessage(aMessage, aTitle, dialogButtons, defaultButton, cancelButton, anIcon, false)
	
	if buttonPressed is (item 1 of dialogButtons) then error "User canceled." number -128
	
	return true
	
end askForPermissionToFixPrivateKeyPermissions

on showSuccess()
	
	(*
		Shows information to the user upon a successful connection.
	*)
	
	-- Get generated port
	set generatedPort to my pTUNNEL_MANAGER's firstTunnel()'s generatedPortNumber()
	
	-- Setup dialog
	set aTitle to localizedStringWithVar("success_title", generatedPort as text)
	set aMessage to localizedString("success_message")
	set dialogButtons to {localizedString("dialog_ok")}
	set defaultButton to 1
	set anIcon to 1
	set givingUp to 60
	
	-- Show success message
	displayMessage(aMessage, aTitle, dialogButtons, defaultButton, false, anIcon, givingUp)
	
	return
	
end showSuccess

on showError(eMsg)
	
	(*
		Informs the user about an error that caused the connection to fail.
	*)
	
	-- Setup
	set aTitle to localizedString("error_title")
	set aMessage to localizedStringWithVar("error_message", eMsg)
	set dialogButtons to {localizedString("open_log"), localizedString("dialog_ok")}
	set defaultButton to localizedString("dialog_ok")
	set anIcon to 2
	
	-- Show error message
	set theButton to button returned of (displayMessage(aMessage, aTitle, dialogButtons, defaultButton, false, anIcon, false))
	
	if theButton is localizedString("open_log") then
		set logFilePath to ((path to library folder from user domain) as text) & "Logs:tunnel_ssh.log"
		do shell script "open " & quoted form of (POSIX path of logFilePath)
	end if
	
	return
	
end showError

on _______________________________________________TOOLS()
end _______________________________________________TOOLS

on logMessage(msg)
	
	set msg to timeStamp(current date, "logfile") & " " & msg
	if pRUNS_IN_EDITOR then log " " & msg & " "
	do shell script "/bin/echo " & quoted form of msg & " >> ~/Library/Logs/tunnel.log"
	
end logMessage

on clearLogWithMessage(msg)
	
	set msg to timeStamp(current date, "logfile") & " " & msg
	if pRUNS_IN_EDITOR then log " " & msg & " "
	do shell script "/bin/echo " & quoted form of msg & " > ~/Library/Logs/tunnel.log"
	
end clearLogWithMessage

on timeStamp(aDate, aFormat)
	
	-- Get the month and day as integer
	set aMonth to month of aDate as integer
	set aDay to day of aDate
	
	-- Get the year
	set aYear to year of aDate as string
	
	-- Get the seconds since midnight
	set aTime to (time of aDate)
	
	-- Get hours, minutes, and seconds
	set theHours to aTime div (60 * 60)
	set theMinutes to aTime mod (60 * 60) div 60
	set theSeconds to aTime mod 60
	
	-- Zeropad month value
	if aMonth is less than 10 then
		set aMonth to "0" & (aMonth as string)
	else
		set aMonth to aMonth as string
	end if
	
	-- Zeropad day value 
	if aDay is less than 10 then
		set aDay to "0" & (aDay as string)
	else
		set aDay to aDay as string
	end if
	
	-- Zeropad hours value
	if theHours is less than 10 then
		set theHours to "0" & (theHours as string)
	else
		set theHours to theHours as string
	end if
	
	-- Zeropad minutes value
	if theMinutes is less than 10 then
		set theMinutes to "0" & (theMinutes as string)
	else
		set theMinutes to theMinutes as string
	end if
	
	-- Zeropad seconds value
	if theSeconds is less than 10 then
		set theSeconds to "0" & (theSeconds as string)
	else
		set theSeconds to theSeconds as string
	end if
	
	if aFormat is "logfile" then
		return aYear & "-" & aMonth & "-" & aDay & " " & theHours & ":" & theMinutes & ":" & theSeconds
	else if aFormat is "filename" then
		return aYear & "-" & aMonth & "-" & aDay & "_" & theHours & "-" & theMinutes & "-" & theSeconds
	end if
	
end timeStamp

on pathToResource(resourceName, directoryName)
	
	(*
		Returns an alias file reference to the resource with a given name in the specified directory.
		The directory is ignored if set to false.
	*)
	
	try
		
		if my pRUNS_IN_EDITOR then
			
			set appSupportDirectory to path to application support folder from user domain as text
			
			if directoryName is false then
				return appSupportDirectory & "Tunnel:" & resourceName
			else
				return appSupportDirectory & "Tunnel:" & directoryName & ":" & resourceName
			end if
			
		else
			
			if directoryName is false then
				return path to resource resourceName
			else
				return path to resource resourceName in directory directoryName
			end if
			
		end if
		
	on error eMsg number eNum
		error "pathToResource: " & eMsg number eNum
	end try
	
end pathToResource

on qpp(aPath)
	
	return quoted form of (POSIX path of aPath)
	
end qpp

on displayMessage(aMessage, aTitle, someButtons, defaultButton, cancelButton, anIcon, aTimeout)
	
	(*
		Wrapper around display dialog (for Mac OS X 10.4) and display alert (for Mac OS X 10.5+).
	*)
	
	try
		set aTimeout to aTimeout as integer
	on error
		set aTimeout to 0
	end try
	
	if minSystemVersion("10.5") then
		
		set alertType to informational
		if anIcon is 2 then set alertType to warning
		
		activate
		if cancelButton is false then
			set dialogResult to (display alert aTitle message aMessage buttons someButtons default button defaultButton as alertType giving up after aTimeout)
		else
			set dialogResult to (display alert aTitle message aMessage buttons someButtons default button defaultButton cancel button cancelButton as alertType giving up after aTimeout)
		end if
	else
		
		activate
		set dialogResult to (display dialog aMessage with title aTitle buttons someButtons default button defaultButton with icon anIcon giving up after aTimeout)
		
	end if
	
	return dialogResult
	
end displayMessage

on systemVersion()
	
	checkSystemVersion(false)
	
end systemVersion

on minSystemVersion(minimumSystemVersion)
	
	checkSystemVersion(minimumSystemVersion)
	
end minSystemVersion

on checkSystemVersion(minimumSystemVersion)
	
	(*
		With the parameter set to false, returns the current system version. When a version string (e.g. 10.4) is supplied, returns true if the current system version is equal to or exceeds the specifed value; otherwise return false.
	*)
	
	if minimumSystemVersion is not false then
		set prvDlmt to text item delimiters
		set text item delimiters to "."
		set textItems to text items of minimumSystemVersion
		set text item delimiters to prvDlmt
		
		repeat (3 - (count of textItems)) times
			set end of textItems to false
		end repeat
		
		set minMajor to item 1 of textItems as integer
		set minMinor to item 2 of textItems as integer
		set minRevision to item 3 of textItems as integer
	else
		copy {false, false, false} to {minMajor, minMinor, minRevision}
	end if
	
	-- Get system version as hex
	set hex to system attribute "sysv"
	
	-- Get the revision
	set revision to hex mod 16
	set hex to hex div 16
	
	-- Get the minor version
	set minor to hex mod 16
	set hex to hex div 16
	
	-- Get the major version
	set major1 to hex mod 16 as text
	set hex to hex div 16
	set major2 to hex mod 16 as text
	set hex to hex div 16
	set major to (major2 & major1 as text) as integer
	
	-- Check minimum system version
	if minMajor is not false and major < minMajor then
		return false
		
	else if minMajor is not false and major = minMajor then
		
		if minMinor is not false and minor < minMinor then
			return false
			
		else if minMinor is not false and minor = minMinor then
			if minRevision is not false and revision < minRevision then
				return false
			else
				return true
			end if
			
		else
			return true
			
		end if
		
	else if minMajor is not false then
		return true
		
	end if
	
	-- Concatenate the version string
	set versionString to (major as text) & "." & (minor as text) & "." & (revision as text)
	
	return versionString
	
end checkSystemVersion

on loadScriptText(scriptPath)
	
	set scriptQPP to quoted form of (POSIX path of scriptPath)
	
	try
		do shell script "/bin/test -f " & scriptQPP
	on error
		error "Could not load script. No file found at " & scriptPath & "." number 3
	end try
	
	set tempPath to temporaryPath()
	
	set tempQPP to quoted form of (POSIX path of tempPath)
	
	try
		
		logMessage("Compiling script at " & POSIX path of scriptPath)
		
		do shell script "/usr/bin/osacompile -o " & tempQPP & " " & scriptQPP
		
		set loadedScript to load script file tempPath
		
	on error eMsg number eNum
		
		error "Could not compile " & scriptPath & ". " & eMsg number eNum
		
	end try
	
	try
		do shell script "/bin/rm -f " & tempQPP
	end try
	
	return loadedScript
	
end loadScriptText

on temporaryPath()
	
	-- Generate pseudorandom numbers
	set rand1 to (round (random number from 100 to 999)) as text
	set rand2 to (round (random number from 100 to 999)) as text
	set randomText to rand1 & "-" & rand2
	
	-- Create file name
	set fileName to (("AppleScriptTempFile_" & randomText) as text)
	
	-- Get the path to the parent folder
	set parentFolderPath to (path to temporary items folder from user domain) as text
	
	-- Make sure the file does not exist
	set rNumber to 1
	
	repeat
		if rNumber is 1 then
			set tempFilePath to parentFolderPath & fileName
		else
			set tempFilePath to parentFolderPath & fileName & "_" & (rNumber as text)
		end if
		
		tell application "System Events" to if (exists file tempFilePath) is false then exit repeat
		set rNumber to rNumber + 1
	end repeat
	
	return tempFilePath
	
end temporaryPath

on _______________________________________________LOCALIZATION()
end _______________________________________________LOCALIZATION


on systemLanguage()
	
	try
		set lng to my gSYSTEM_LANGUAGE
		if lng is missing value then error 1
		return lng
	end try
	
	try
		set lng to first word of (do shell script "/usr/bin/defaults read NSGlobalDomain AppleLanguages")
		set gSYSTEM_LANGUAGE to lng
		return lng
	on error
		set gSYSTEM_LANGUAGE to "en"
		return "en"
	end try
	
end systemLanguage


on localizedString(str)
	
	return localizedStringWithVar(str, "")
	
end localizedString

on localizedStringWithVar(str, var)
	
	set supportedLanguages to {"en", "de"}
	set targetLanguage to systemLanguage()
	if targetLanguage is not in supportedLanguages then set targetLanguage to item 1 of supportedLanguages
	
	set strKey to str & "/" & targetLanguage
	
	----------------------------------------------------------------------
	
	if strKey is "dialog_cancel/en" then return "Cancel"
	if strKey is "dialog_cancel/de" then return "Abbrechen"
	
	if strKey is "dialog_ok/en" then return "OK"
	if strKey is "dialog_ok/de" then return "OK"
	
	if strKey is "dialog_quit_now/en" then return "Quit now"
	if strKey is "dialog_quit_now/de" then return "Jetzt beenden"
	
	----------------------------------------------------------------------
	
	if strKey is "open_tunnel_title/en" then return "Start connection"
	if strKey is "open_tunnel_title/de" then return "Verbindungsaufbau"
	
	if strKey is "open_tunnel_message/en" then return "Would you like to connect to " & var & "'s network?"
	if strKey is "open_tunnel_message/de" then return "Mšchten Sie mit dem Netzwerk von " & var & " verbunden werden?"
	
	if strKey is "open_tunnel_button/en" then return "Connect"
	if strKey is "open_tunnel_button/de" then return "Verbinden"
	
	----------------------------------------------------------------------
	
	if strKey is "modify_settings_title/en" then return "Screen sharing settings"
	if strKey is "modify_settings_title/de" then return "Einstellungen zur Bildschirmfreigabe"
	
	if strKey is "modify_settings_message/en" then return "Please authenticate to allow this application to modify your MacÕs screen sharing settings."
	if strKey is "modify_settings_message/de" then return "Die Einstellungen zur Bildschirmfreigabe mŸssen angepasst werden. Bitte melden Sie sich dazu mit einem Benutzerkonto mit Verwaltungsrechten an."
	
	if strKey is "modify_settings_button/en" then return "Authenticate and modify"
	if strKey is "modify_settings_button/de" then return "Anmelden und anpassen"
	
	if strKey is "dont_modify_settings_button/en" then return "Keep current settings"
	if strKey is "dont_modify_settings_button/de" then return "Einstellungen belassen"
	
	----------------------------------------------------------------------
	
	if strKey is "fix_private_key_permissions_title/en" then return "Repair permissions"
	if strKey is "fix_private_key_permissions_title/de" then return "Zugriffsrechte reparieren"
	
	if strKey is "fix_private_key_permissions_message/en" then return "Please authenticate to allow this application to repair its own permissions."
	if strKey is "fix_private_key_permissions_message/de" then return "Die Zugriffsrechte dieses Programms mŸssen repariert werden. Bitte melden Sie sich dazu mit einem Benutzerkonto mit Verwaltungsrechten an."
	
	if strKey is "fix_private_key_button/en" then return "Authenticate and repair"
	if strKey is "fix_private_key_button/de" then return "Anmelden und reparieren"
	
	----------------------------------------------------------------------
	
	if strKey is "success_title/en" then return "Your number is " & (var as text)
	if strKey is "success_title/de" then return "Ihre Nummer lautet " & (var as text)
	
	if strKey is "success_message/en" then return "Connection established. To disconnect simply quit this application."
	if strKey is "success_message/de" then return "Die Verbindung wurde aufgebaut. Zur Trennung beenden Sie einfach dieses Programm."
	
	----------------------------------------------------------------------
	
	if strKey is "restore_settings_title/en" then return "Screen sharing settings"
	if strKey is "restore_settings_title/de" then return "Einstellungen zur Bildschirmfreigabe"
	
	if strKey is "restore_settings_message/en" then return "The previous screen sharing settings will be restored. You might be asked to authenticate to allow this application to do so."
	if strKey is "restore_settings_message/de" then return "Die vorherigen Einstellungen zur Bildschirmfreigabe werden jetzt wiederhergestellt. Mšglicherweise werden Sie nach den Zugangsdaten zur Verwaltung Ihres Macs gefragt."
	
	if strKey is "restore_settings_button/en" then return "Restore"
	if strKey is "restore_settings_button/de" then return "Wiederherstellen"
	
	----------------------------------------------------------------------
	
	if strKey is "error_title/en" then return "Something went wrong"
	if strKey is "error_title/de" then return "Etwas ist schief gelaufen"
	
	if strKey is "error_message/en" then return "The connection could not be established." & return & return & "(" & var & ")"
	if strKey is "error_message/de" then return "Die Verbindung konnte nicht aufgebaut werden." & return & return & "(" & var & ")"
	
	----------------------------------------------------------------------
	
	if strKey is "screen_sharing_error_title/en" then return "Screen sharing error"
	if strKey is "screen_sharing_error_title/de" then return "Fehler bei der Bildschirmfreigabe"
	
	if strKey is "screen_sharing_not_installed_error_message/en" then return "Apple Remote Desktop is not installed."
	if strKey is "screen_sharing_not_installed_error_message/de" then return "Apple Remote Desktop ist nicht installiert"
	
	if strKey is "screen_sharing_disabled_error_message/en" then return "Screen sharing could not be turned on. Please open the Sharing preferences and try to enable ÇRemote ManagementÈ manually." & return & return & "Relaunch this application afterwards."
	if strKey is "screen_sharing_disabled_error_message/de" then return "Die Bildschirmfreigabe konnte nicht eingeschaltet werden. …ffnen Sie bitte die Freigabe-Einstellungen und setzen Sie ein HŠkchen bei ÈEntfernte VerwaltungÇ." & return & return & "Danach starten Sie bitte das Verbindungsprogramm erneut."
	
	if strKey is "ask_for_permission_disabled_error_message/en" then return "The option ÇAnyone may request permission to control screenÈ could not be turned on. Please open the Sharing preferences, choose ÇRemote ManagementÈ on the left, click the ÇComputer SettingsÉÈ button, check that option manually and click the OK button." & return & return & "Launch this application again afterwards."
	if strKey is "ask_for_permission_disabled_error_message/de" then return "Die Einstellung ÈJeder kann eine Genehmigung zur Bildschirmsteuerung anfordernÇ konnte nicht aktiviert werden. Bitte šffnen Sie die Freigabe-Einstellungen, wŠhlen Sie ÈEntfernte VerwaltungÇ, klicken Sie auf ÇComputereinstellungenÉÈ, markieren Sie das entsprechende KŠstchen und drŸcken Sie abschlie§end die OK-Taste." & return & return & "Danach starten Sie bitte das Verbindungsprogramm erneut."
	
	if strKey is "open_sharing_pref_pane/en" then return "Open Sharing preferences"
	if strKey is "open_sharing_pref_pane/de" then return "Freigabe-Einstellungen šffnen"
	
	if strKey is "open_log/en" then return "Open log"
	if strKey is "open_log/de" then return "Protokoll šffnen"
	
	return str
	
end localizedStringWithVar

on _______________________________________________TUNNEL_MANAGER()
end _______________________________________________TUNNEL_MANAGER

on newTunnelManager()
	
	(*
		A script object to manage multiple SSH tunnels
	*)
	
	script TunnelManager
		
		property pHOST : missing value
		property pSSH_PORT : missing value
		property pSSH_USER : missing value
		property pSSH_PATH : "/usr/bin/ssh"
		property pKEY_PATH : missing value
		property pTUNNELS : {}
		property pDEBUG_MODE : false
		property pSSH_SUCCESS_MESSAGES : missing value
		property pSSH_ERROR_MESSAGES : missing value
		
		on init(hst, prt, usr)
			
			(*
				Initializes a new TunnelManager with the specified information
			*)
			
			set my pTUNNELS to {}
			set my pHOST to hst
			set my pSSH_PORT to prt
			set my pSSH_USER to usr
			
			-- Specify a list of expected success messages
			set my pSSH_SUCCESS_MESSAGES to {"Local forwarding listening on", "remote forward success for", "All remote forwarding requests processed"}
			
			-- Specify a list of expected error messages
			set my pSSH_ERROR_MESSAGES to {"Connection refused", "Operation timed out", "Permission denied", "Remote port forwarding failed", "Connection closed by remote host", "Connection timed out", "Bad port", "Could not resolve hostname", "Host key check failure", "Unprotected private key file"}
			
			return me
			
		end init
		
		on openTunnels()
			
			(*
				Opens associated tunnels.
			*)
			
			-- Check tunnels
			set tunnelCount to count of tunnels()
			if tunnelCount = 0 then error "No tunnels defined."
			
			-- Remove host key from known hosts
			try
				do shell script "/usr/bin/grep -v " & quoted form of (my pHOST) & " ~/.ssh/known_hosts > ~/.ssh/known_hosts_modified ; mv ~/.ssh/known_hosts_modified ~/.ssh/known_hosts"
			end try
			
			repeat with tunnelNum from 1 to tunnelCount
				
				set thisTunnel to item tunnelNum of tunnels()
				
				try
					
					thisTunnel's openTunnel()
					
				on error eMsg number eNum
					
					logMessage("Failed to open " & thisTunnel's tunnelIdentifier() & ": " & eMsg & " (" & (eNum as text) & ")")
					try
						thisTunnel's closeTunnel()
					end try
					if thisTunnel's isOptional() is false then error eMsg number eNum
					
				end try
				
			end repeat
			
		end openTunnels
		
		on closeTunnels()
			
			(*
				Closes associated tunnels.
			*)
			
			-- Check tunnels
			set tunnelCount to count of tunnels()
			if tunnelCount = 0 then error "No tunnels defined."
			
			repeat with tunnelNum from 1 to tunnelCount
				(item tunnelNum of tunnels())'s closeTunnel()
			end repeat
			
		end closeTunnels
		
		on checkTunnels()
			
			(*
				Checks associated tunnels for connectivity; reopening them if necessary.
			*)
			
			-- Check tunnels
			set tunnelCount to count of tunnels()
			if tunnelCount = 0 then error "No tunnels defined."
			
			repeat with tunnelNum from 1 to tunnelCount
				
				(item tunnelNum of tunnels())'s checkTunnel()
				
			end repeat
			
		end checkTunnels
		
		on tunnels()
			
			-- Returns associated tunnel objects
			return my pTUNNELS
			
		end tunnels
		
		on firstTunnel()
			
			-- Returns the first tunnel object
			return item 1 of my pTUNNELS
			
		end firstTunnel
		
		on sshHost()
			
			-- Returns the remote host
			return my pHOST
			
		end sshHost
		
		on sshPort()
			
			-- Returns the remote host's ssh port
			return my pSSH_PORT
			
		end sshPort
		
		on sshUser()
			
			-- Returns the login used to connect to the remote host
			return my pSSH_USER
			
		end sshUser
		
		on sshPath()
			
			-- Returns the path to the ssh executable
			return my pSSH_PATH
			
		end sshPath
		
		on sshSuccessMessages()
			
			-- Returns a list of error messages used by SSH
			return my pSSH_SUCCESS_MESSAGES
			
		end sshSuccessMessages
		
		on sshErrorMessages()
			
			-- Returns a list of error messages used by SSH
			return my pSSH_ERROR_MESSAGES
			
		end sshErrorMessages
		
		on setKeyFilePath(aPath)
			
			-- Sets the path to the private key used for authentication
			set my pKEY_PATH to aPath
			
		end setKeyFilePath
		
		on keyFilePath()
			
			(*
				Returns the path to the private key
			*)
			
			set idFilePath to my pKEY_PATH as text
			tell application "System Events" to set keyFileExists to exists file (idFilePath as string)
			if keyFileExists is false then error "Key is missing at " & (idFilePath as string) number 1
			
			set idQPP to quoted form of (POSIX path of idFilePath)
			set fileInfo to do shell script "ls -l " & idQPP
			if fileInfo does not start with "-rw-------" then
				
				askForPermissionToFixPrivateKeyPermissions()
				
				set userName to do shell script "/usr/bin/whoami"
				do shell script "/usr/sbin/chown " & quoted form of userName & " " & idQPP with administrator privileges
				do shell script "/bin/chmod 600 " & idQPP with administrator privileges
			end if
			
			return idFilePath
			
		end keyFilePath
		
		on enableDebugMode()
			
			-- Enables debug mode
			set my pDEBUG_MODE to true
			
		end enableDebugMode
		
		on disableDebugMode()
			
			-- Disables debug mode
			set my pDEBUG_MODE to false
			
		end disableDebugMode
		
		on newTunnel()
			
			(*
				A script object for handling an ssh tunnel
			*)
			
			set aManager to me
			
			script Tunnel
				
				property pMANAGER : aManager
				property pLOCAL_PORT : missing value
				property pREMOTE_PORT : missing value
				property pGENERATED_PORT_NUMBER : missing value
				property pTUNNEL_OPTION : missing value
				property pTUNNEL_IDENTIFIER : missing value
				property pOUTPUT_FILE_PATH : missing value
				property pOPTIONAL : false
				property pREVERSE : false
				
				on initWithLocalPort(prt)
					
					(*
						Initializes a new reverse tunnel object for the specifed local port. The port used on the remote host is generated automatically.
					*)
					
					return init(prt, false, true)
					
				end initWithLocalPort
				
				on initWithRemotePort(prt)
					(*
						Initializes a new tunnel object for the specifed remote port. The port used on the local host is generated automatically.
					*)
					
					return init(false, prt, false)
					
				end initWithRemotePort
				
				on init(prt1, prt2, reverseDirection)
					
					(*
						Initializes a new tunnel object for the specifed local port and remote port. By specifying true for the reverse parameter a reverse tunnel is created.
					*)
					
					try
						
						setIsReverse(reverseDirection) -- Determine forward or reverse tunnel
						
						-- Check port argument
						if prt1 is false and prt2 is false then error "Invalid arguments. Both ports are set to false."
						
						if prt1 is false then
							-- Set the remote port and generate local one
							set my pREMOTE_PORT to prt2
							set my pGENERATED_PORT_NUMBER to generatePortNumber()
							set my pLOCAL_PORT to my pGENERATED_PORT_NUMBER
							
						else if prt2 is false then
							-- Set the local port and generate remote one
							set my pLOCAL_PORT to prt1
							set my pGENERATED_PORT_NUMBER to generatePortNumber()
							set my pREMOTE_PORT to my pGENERATED_PORT_NUMBER
							
						else
							-- Set both ports as specified
							set my pLOCAL_PORT to prt1
							set my pREMOTE_PORT to prt2
							
						end if
						
						-- Specify the tunnel options for the ssh command
						if reverseDirection is true then
							set my pTUNNEL_OPTION to "-g -R " & my pREMOTE_PORT & ":127.0.0.1:" & my pLOCAL_PORT
						else
							set my pTUNNEL_OPTION to "-L " & my pLOCAL_PORT & ":127.0.0.1:" & my pREMOTE_PORT
						end if
						
						generateTunnelIdentifier()
						
						-- Specify the path to the output file
						setOutputFilePath(generateOutputFilePath())
						
						return me
						
					on error eMsg number eNum
						error "init: " & eMsg number eNum
					end try
					
				end init
				
				on openTunnel()
					
					(*
						Opens the SSH tunnel.
					*)
					
					try
						
						set cmd to composeShellCommand()
						
						do shell script cmd
						
						if isOptional() is false then waitForTunnelToOpen()
						
						logMessage("Opened " & tunnelIdentifier())
						
						return
						
					on error eMsg number eNum
						
						if eNum ³ 59100 and eNum ² 59199 then
							
							error eMsg number eNum
							
						else
							
							error "openTunnel: " & eMsg number eNum
							
						end if
						
					end try
					
				end openTunnel
				
				on closeTunnel()
					
					(*
						Closes the SSH tunnel.
					*)
					
					-- Get the PIDs of all ssh processes for this tunnel
					set allPIDs to pids()
					
					if allPIDs is not {} then
						
						-- Close found tunnels
						repeat with pid in allPIDs
							try
								do shell script "/bin/kill -HUP " & pid
								logMessage("Closed tunnel with pid " & (pid as text) & " for " & tunnelIdentifier())
							end try
						end repeat
						
					end if
					
					-- if my pDEBUG_MODE is false then deleteOutput()
					
				end closeTunnel
				
				on checkTunnel()
					
					(*
						Checks whether any ssh processes for this tunnel exist. Opening the tunnel again if not.
					*)
					
					if pids() is {} then
						
						logMessage("Found closed " & tunnelIdentifier())
						
						try
							openTunnel()
						end try
						
					end if
					
				end checkTunnel
				
				on waitForTunnelToOpen()
					
					(*
						Waits for the tunnel to establish.
					*)
					
					set successMessages to manager()'s sshSuccessMessages()
					set errorMessages to manager()'s sshErrorMessages()
					
					-- Get the quoted posix path for the output file
					set outputQPP to quoted form of outputPosixPath()
					
					-- Wait up to 20 seconds for connection to succeed
					repeat 20 times
						
						-- Does the output contain any of the success messages?						
						repeat with successNum from 1 to count of successMessages
							set successMessage to item successNum of successMessages
							
							try
								
								do shell script "/usr/bin/grep -i " & quoted form of successMessage & " " & outputQPP
								return
							end try
							
						end repeat
						
						-- Does the output contain any of the error messages?
						repeat with errorNum from 1 to count of errorMessages
							
							set errorMessage to item errorNum of errorMessages
							
							try
								do shell script "/usr/bin/grep -i " & quoted form of errorMessage & " " & outputQPP
								error errorMessage number 12345
								
							on error eMsg number eNum
								
								if eNum = 12345 then
									-- Do not raise errors produced by grep not finding anything
									error eMsg number (59100 + errorNum)
								end if
							end try
							
						end repeat
						
						delay 1
						
					end repeat
					
					error "Timed out" number 99
					
				end waitForTunnelToOpen
				
				on composeShellCommand()
					
					(*
						Composes the ssh command for this tunnel.
					*)
					
					set sshCmd to {}
					
					-- Start the command with the path to the ssh executable					
					set end of sshCmd to quoted form of manager()'s sshPath()
					
					set end of sshCmd to "-4" -- Limit to IPv4 addresses
					set end of sshCmd to "-N" -- Do not execute remote command
					set end of sshCmd to "-v" -- Turn on verbose mode
					
					-- Add the path to the private key if one is present
					set idFilePath to manager()'s keyFilePath()
					if idFilePath is not false then set end of sshCmd to "-i " & quoted form of (POSIX path of idFilePath)
					
					-- Add the tunnel option
					set end of sshCmd to tunnelOption()
					
					-- Add the login name
					set end of sshCmd to "-l " & manager()'s sshUser()
					
					-- Specify the ssh port of the remote host
					set end of sshCmd to "-p " & (manager()'s sshPort() as text)
					
					set end of sshCmd to "-o " & quoted form of "StrictHostKeyChecking no"
					set end of sshCmd to "-o " & quoted form of "VerifyHostKeyDNS no"
					set end of sshCmd to "-o " & quoted form of "ControlPath none"
					set end of sshCmd to "-o " & quoted form of "ExitOnForwardFailure yes"
					set end of sshCmd to "-o " & quoted form of "ServerAliveInterval 15"
					set end of sshCmd to "-o " & quoted form of "ConnectTimeout 15"
					
					-- Add the remote host name
					set end of sshCmd to manager()'s sshHost()
					
					-- Combine command components
					set prvDlmt to text item delimiters
					set text item delimiters to " "
					set sshCmd to sshCmd as text
					set text item delimiters to prvDlmt
					
					-- Determine which output to write to
					if isOptional() then
						set output to "/dev/null"
					else
						set output to quoted form of outputPosixPath()
					end if
					
					if my pDEBUG_MODE then log sshCmd
					
					return sshCmd & " > " & output & " 2>&1 &"
					
				end composeShellCommand
				
				on tunnelOption()
					
					-- Returns the tunnel option as used for the ssh tool
					return my pTUNNEL_OPTION
					
				end tunnelOption
				
				on tunnelIdentifier()
					
					-- Returns the tunnel identifier
					return my pTUNNEL_IDENTIFIER
					
				end tunnelIdentifier
				
				on generateTunnelIdentifier()
					
					(*
						Generates an identifier for this tunnel.
					*)
					
					set parts to {}
					
					-- Remote address
					set end of parts to manager()'s sshUser() & "@"
					set end of parts to manager()'s sshHost() & ":"
					set end of parts to (manager()'s sshPort() as text) & "_"
					
					-- Tunnel 
					if isReverse() then
						set end of parts to "[R]_"
						set end of parts to remotePort()
						set end of parts to "->"
						set end of parts to localPort()
					else
						set end of parts to "[L]_"
						set end of parts to localPort()
						set end of parts to "->"
						set end of parts to remotePort()
					end if
					
					set prvDlmt to text item delimiters
					set text item delimiters to ""
					set identifier to parts as text
					set text item delimiters to prvDlmt
					
					set my pTUNNEL_IDENTIFIER to identifier
					
				end generateTunnelIdentifier
				
				on tunnelDescription()
					
					(*
						Returns a description for this tunnel.
					*)
					
					if my pDEBUG_MODE then
						
						-- Get path to the private key
						set idFilePath to manager()'s keyFilePath()
						
						if isReverse() then
							set desc to "reverse tunnel from local port " & (localPort() as text) & " to remote port " & (remotePort() as text) & " by connecting to ssh://" & manager()'s sshUser() & "@" & manager()'s sshHost() & ":" & (manager()'s sshPort() as text)
						else
							set desc to "tunnel from remote port " & (remotePort() as text) & " to local port " & (localPort() as text) & " by connecting to ssh://" & manager()'s sshUser() & "@" & manager()'s sshHost() & ":" & (manager()'s sshPort() as text)
						end if
						if idFilePath is not false then
							set desc to desc & " using private key at path \"" & idFilePath & "\""
						end if
						
					else
						set desc to "tunnel from local port " & (localPort() as text)
						
					end if
					
					return desc
					
				end tunnelDescription
				
				on deleteOutput()
					
					-- Deletes the output file
					try
						do shell script "/bin/rm -f " & quoted form of outputPosixPath()
					on error eMsg
						activate
						display dialog eMsg
					end try
					
				end deleteOutput
				
				on setOutputFilePath(aPath)
					
					-- Sets the path to the output file
					set my pOUTPUT_FILE_PATH to aPath
					
				end setOutputFilePath
				
				on outputFilePath()
					
					-- Returns the path to the output file
					return my pOUTPUT_FILE_PATH
					
				end outputFilePath
				
				on outputPosixPath()
					
					-- Returns the posix path to the output file
					return POSIX path of my pOUTPUT_FILE_PATH
					
				end outputPosixPath
				
				on generateOutputFileName()
					
					(*
						Generates the name to the output file for this tunnel. The name is derived from a hash of the tunnel identifier.
					*)
					
					-- Get hash
					set hash to last word of (first paragraph of (do shell script "/sbin/md5 -s " & quoted form of tunnelIdentifier()))
					
					return "ssh_" & hash & ".log"
					
				end generateOutputFileName
				
				on generateOutputFilePath()
					
					(*
						Generates a path to the output file for this tunnel.
					*)
					
					(*
					-- Get the path to the temporary items folder
					set temporaryFolderPath to (path to temporary items folder from user domain) as text
					
					return temporaryFolderPath & generateOutputFileName()
					*)
					
					return ((path to library folder from user domain) as text) & "Logs:tunnel_ssh.log"
					
				end generateOutputFilePath
				
				on setIsOptional(newValue)
					
					-- Sets whether this tunnel should be optional. Optional tunnels fail silently.
					set my pOPTIONAL to newValue
					
				end setIsOptional
				
				on isOptional()
					
					-- Returns whether this tunnel is optional. Optional tunnels fail silently.
					return my pOPTIONAL
					
				end isOptional
				
				on setIsReverse(newValue)
					
					-- Sets whether this should be a reverse tunnel.
					set my pREVERSE to newValue
					
				end setIsReverse
				
				on isReverse()
					
					-- Returns whether this is a reverse tunnel.
					return my pREVERSE
					
				end isReverse
				
				on pids()
					
					(*
						Returns the PIDs of all process that open this tunnel.
					*)
					
					set psCmd to "/bin/ps -jx -wwwwwww | grep ssh | grep -v grep | grep -e " & quoted form of tunnelOption() & " | grep -e " & manager()'s sshHost()
					try
						set psResult to do shell script psCmd
					on error
						return {}
					end try
					
					set allProcesses to paragraphs of result
					set allPIDs to {}
					repeat with thisProcess in allProcesses
						set end of allPIDs to word 2 of thisProcess
					end repeat
					
					return allPIDs
					
				end pids
				
				on localPort()
					
					-- Returns the local port for this tunnel.
					return my pLOCAL_PORT
					
				end localPort
				
				on remotePort()
					
					-- Returns the remote port for this tunnel.
					return my pREMOTE_PORT
					
				end remotePort
				
				on manager()
					
					-- Returns the manager object responsible for this tunnel.
					return my pMANAGER
					
				end manager
				
				on generatedPortNumber()
					
					-- Returns the generated port number.
					return my pGENERATED_PORT_NUMBER
					
				end generatedPortNumber
				
				on generatePortNumber()
					
					(*
						Generates a port number. When using reverse tunnels the local hostname and the local port is used to determine a port number between 50000 and 59999 using a hash function. Forward tunnels use the remote host's name, ssh port and remote port.
					*)
					
					if isReverse() then
						-- Compose identifier for this host and its port
						set identifier to (do shell script "/bin/hostname") & ":" & localPort()
						
					else
						-- Compose identifier for remote host and its ports
						set identifier to manager()'s sshHost() & ":" & (manager()'s sshPort() as text) & ":" & remotePort()
						
					end if
					
					-- Generate hash
					set hash to characters 1 thru 16 of last word of (do shell script "/sbin/md5 -s " & quoted form of identifier)
					
					-- Calculate port number
					set portNumber to 50000 + (convertToDecimal(hash, 16) mod 9999 as integer)
					
					return portNumber
					
				end generatePortNumber
				
				on convertToDecimal(aValue, aBase)
					
					(*
						Convert a given value of the specifed base to a decimal number
					*)
					
					if class of aValue is not list then
						set aValue to characters of (aValue as string)
					end if
					set aValue to reverse of aValue
					
					set decimalValue to 0
					repeat with loopNum from 1 to count of aValue
						set aChar to item loopNum of aValue
						
						if aChar is "A" then
							set aChar to 10
						else if aChar is "B" then
							set aChar to 11
						else if aChar is "C" then
							set aChar to 12
						else if aChar is "D" then
							set aChar to 13
						else if aChar is "E" then
							set aChar to 14
						else if aChar is "F" then
							set aChar to 15
						else
							set aChar to aChar as integer
						end if
						
						repeat loopNum - 1 times
							set aChar to aChar * aBase
						end repeat
						set decimalValue to decimalValue + aChar
					end repeat
					
					return decimalValue
					
				end convertToDecimal
				
			end script
			
			addTunnel(Tunnel)
			
			return Tunnel
			
		end newTunnel
		
		on addTunnel(aTunnel)
			
			-- Adds a new tunnel to this manager object
			set end of my pTUNNELS to aTunnel
			
		end addTunnel
		
	end script
	
	return TunnelManager
	
end newTunnelManager