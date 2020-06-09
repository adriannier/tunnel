global gPROJECT_DIRECTORY
global gDATA_DIRECTORY
global gSETTINGS

property pVERSION : "1.0.0"

on run
	
	try
		
		init()
		
		set settingsPath to askForBuildSettings()
		
		set gSETTINGS to loadBuildSettings(settingsPath)
		
		resetDirectory(productsDirectory())
		
		build()
		
		postProcess()
		
	on error eMsg number eNum
		
		logError("run", eMsg, eNum)
		
		if eNum = -128 then return -- User canceled
		
		error "Failed to build applet. " & eMsg number eNum
		
	end try
	
	return
	
end run

on init()
	
	try
		
		set scriptPath to path to me as text
		
		set gPROJECT_DIRECTORY to hfsPathForParent(scriptPath)
		
		set appSupportDirectory to (path to application support folder from user domain) as text
		
		set gDATA_DIRECTORY to appSupportDirectory & "Tunnel:"
		
		checkDirectory(gDATA_DIRECTORY)
		
		checkDirectory(gDATA_DIRECTORY & "Settings:")
		
		checkDirectory(gDATA_DIRECTORY & "Keys:")
		
		checkDirectory(gDATA_DIRECTORY & "Icons:")
		
		logMessage("Initialized with data directory at " & POSIX path of gDATA_DIRECTORY)
		
	on error eMsg number eNum
		
		error "init: " & eMsg number eNum
		
	end try
	
end init

on ____________________________BUILD_SETTINGS()
end ____________________________BUILD_SETTINGS

on askForBuildSettings()
	
	try
		
		set settingsDirectory to gDATA_DIRECTORY & "Settings:"
		set settingsFileSuffix to ".applescript"
		set settingsFileSuffixLength to length of settingsFileSuffix
		
		set availableSettings to directoryContentsWithSuffix(settingsDirectory, settingsFileSuffix)
		
		if (count of availableSettings) is 1 then
			
			set chosenSettings to item 1 of availableSettings
			
		else if (count of availableSettings) is 0 then
			
			activate
			
			set theButton to button returned of (display alert "No settings found" message "The build process requires a settings file." buttons {"Cancel build", "Open settings directory", "Create and edit sample file"} default button 3 cancel button 1)
			
			if theButton is "Open settings directory" then
				
				openDirectoryInFinder(gDATA_DIRECTORY & "Settings:")
				
			else if the theButton is "Create and edit sample file" then
				
				echo(buildSettingsTemplate(), gDATA_DIRECTORY & "Settings:sample.applescript")
				
				do shell script "/usr/bin/open " & qpp(gDATA_DIRECTORY & "Settings:sample.applescript")
				
			end if
			
			error "User canceled." number -128
			
		else
			
			-- Remove suffix from file names
			repeat with itemNumber from 1 to count of availableSettings
				set item itemNumber of availableSettings to (text 1 thru ((settingsFileSuffixLength + 1) * -1) of item itemNumber of availableSettings)
			end repeat
			
			-- Let user select a build settings file
			activate
			set choice to choose from list availableSettings default items {item 1 of availableSettings} with prompt "Please select a build setting:"
			if choice is false then error "User canceled." number -128
			
			-- Set chosen settings and add back suffix
			set chosenSettings to item 1 of choice & settingsFileSuffix
			
		end if
		
		logMessage("Using settings at " & POSIX path of (settingsDirectory & chosenSettings))
		
		return settingsDirectory & chosenSettings
		
	on error eMsg number eNum
		
		error "askForBuildSettings: " & eMsg number eNum
		
	end try
	
end askForBuildSettings

on loadBuildSettings(settingsPath)
	
	set L to loadScriptText(settingsPath)
	set S to emptyBuildSettings()
	
	try
		
		try
			set S's productName to L's productName
		on error
			error "Product name is missing"
		end try
		
		try
			set S's connectionName to L's connectionName
		on error
			error "Connection name is missing"
		end try
		
		try
			set S's bundleIdentifier to L's bundleIdentifier
		on error
			error "Bundle identifier is missing"
		end try
		
		try
			set S's sshUserName to L's sshUserName
		on error
			error "SSH user name is missing"
		end try
		
		try
			set S's postProcess to L's postProcess
		end try
		
		try
			set S's localPort to L's localPort
		on error
			error "Local port is missing"
		end try
		
		try
			set S's remoteHosts to L's remoteHosts
		on error
			error "Remote hosts are missing"
		end try
		
		try
			set S's remotePorts to L's remotePorts
		on error
			error "Remote ports are missing"
		end try
		
		try
			set S's keyNames to L's keyNames
		on error
			try
				set S's keyNames to {L's keyName}
			on error eMsg number eNum
				error "Key name is missing: " & eMsg
			end try
		end try
		
		try
			set S's keyPassword to L's keyPassword
		end try
		
		try
			set S's iconName to L's iconName
		end try
		
		try
			set S's codeSignId to L's codeSignId
		end try
		
		return S
		
	on error eMsg number eNum
		
		error "loadBuildSettings: " & eMsg number eNum
		
	end try
	
end loadBuildSettings

on productsDirectory()
	
	return gDATA_DIRECTORY & "Products:"
	
end productsDirectory

on productPath()
	
	return productsDirectory() & productNameWithSuffix()
	
end productPath

on productName()
	
	return my gSETTINGS's productName
	
end productName

on productNameWithSuffix()
	
	return my gSETTINGS's productName & ".app"
	
end productNameWithSuffix

on bundleIdentifier()
	
	return my gSETTINGS's bundleIdentifier
	
end bundleIdentifier

on resourceInProductAtRelativePath(aPath)
	
	return productPath() & ":" & aPath
	
end resourceInProductAtRelativePath

on ____________________________BUILDING()
end ____________________________BUILDING

on emptyBuildSettings()
	
	return {productName:"", connectionName:"", bundleIdentifier:"", sshUserName:"", postProcess:"", localPort:"", remoteHosts:"", remotePorts:"", keyNames:"", keyPassword:"", iconName:"", codeSignId:""}
	
end emptyBuildSettings

on buildSettingsTemplate()
	
	return "(** The name of the applet **)
property productName : \"Open Tunnel\" -- Text

(** The name for the connection **)
property connectionName : \"Example\" -- Text

(** The bundle identifier for the applet **)
property bundleIdentifier : \"com.example.connection\" -- Text

(** The login name of the SSH client **)
property sshUserName : \"tunnel\" -- Text

(** The name for the connection **)
property postProcess : \"None\" -- Text

(* Available values for post processing:
   \"\" -- No post process action
   \"None\" -- No post process action
   \"Run\" -- Runs the built application
   \"Image\" -- Creates a disk image
   \"Archive\" -- Create a ZIP archive
   \"Image and archive\" -- Creates a disk image and a ZIP archive
   \"Image and mail\" -- Creates a disk image and opens it with Mail.app
   \"Archive and mail\" -- Creates a ZIP archive and opens it with Mail.app
   \"Image and run\" -- Creates a disk image and runs the built application after mounting it
*)

(** Local port **)
property localPort : 5900 -- Integer

(** Remote hosts **)
property remoteHosts : {\"127.0.0.1\"} -- List

(** Remote ports **)
property remotePorts : {22} -- Integer or list of lists of integers

(* Examples:

   1. Single integer: 22
      Communicate with every remote host over port 22.
   2. List of lists of integers: {{22, 30123}, {80, 443}}
      The first host will be contacted over port 22 or 30123.
      Communication with the second host will be attempted over port 80 and 443. *)

(** Name of the client's private keys **)
property keyNames : {\"id_ed52219\"} -- Text

(** Password for the client's private key (LEAVE EMPTY, NOT YET SUPPORTED) **)
property keyPassword : \"\" -- Text


(** Name of the icon file used for the built applet **)
property iconName : \"\" -- Text

(** Name of code signing identity **)
property codeSignId : \"\" -- Text; leave empty to disable code signing

(* Note:

   The identifier should start with *Developer ID Application*.

*)"
	
end buildSettingsTemplate

on build()
	
	try
		
		checkKeys()
		
		checkIcon()
		
		compileMainScript()
		
		setInfo()
		
		copyKeys()
		
		copyIcon()
		
		codeSignProduct()
		
	on error eMsg number eNum
		
		error "build: " & eMsg number eNum
		
	end try
	
end build

on setInfo()
	
	try
		
		logMessage("Setting info")
		
		set infoPath to resourceInProductAtRelativePath("Contents:Info.plist")
		
		defaults("write", infoPath, "CFBundleIdentifier", bundleIdentifier())
		defaults("write", infoPath, "CFBundleShortVersionString", my pVERSION)
		
	on error eMsg number eNum
		
		error "setInfo: " & eMsg number eNum
		
	end try
	
end setInfo

on compileMainScript()
	
	try
		
		logMessage("Compiling main script")
		
		set theSource to cat(gPROJECT_DIRECTORY & "tunnel.applescript")
		
		set theSource to insertProperty(theSource, "pCONNECTION_NAME", my gSETTINGS's connectionName)
		set theSource to insertProperty(theSource, "pLOCAL_PORT", my gSETTINGS's localPort)
		set theSource to insertProperty(theSource, "pSSH_LOGIN", my gSETTINGS's sshUserName)
		set theSource to insertProperty(theSource, "pREMOTE_HOSTS", my gSETTINGS's remoteHosts)
		set theSource to insertProperty(theSource, "pREMOTE_PORTS", my gSETTINGS's remotePorts)
		set theSource to insertProperty(theSource, "pKEY_NAMES", my gSETTINGS's keyNames)
		set theSource to insertProperty(theSource, "pKEY_PASSWORD", my gSETTINGS's keyPassword)
		
		set tempPath to temporaryPath()
		
		echo(theSource, tempPath)
		
		osacompile("-s -x", tempPath, productPath())
		
		rm("-f", tempPath)
		
	on error eMsg number eNum
		
		error "compileMainScript: " & eMsg number eNum
		
	end try
	
end compileMainScript

on insertProperty(theSource, propertyName, propertyValue)
	
	try
		
		if class of propertyValue is integer then
			
			set theSource to snr("property " & propertyName & " : missing value", "property " & propertyName & " : " & (propertyValue as text), theSource)
			
		else if class of propertyValue is list then
			set theSource to snr("property " & propertyName & " : missing value", "property " & propertyName & " : " & convertListToText(propertyValue), theSource)
			
		else
			set theSource to snr("property " & propertyName & " : missing value", "property " & propertyName & " : \"" & snr("\"", "\\\"", propertyValue as text) & "\"", theSource)
			
		end if
		
		return theSource
		
	on error eMsg number eNum
		
		error "insertProperty: " & eMsg number eNum
		
	end try
	
end insertProperty

on codeSignProduct()
	
	try
		
		logMessage("Signing code")
		
		codeSign("--timestamp --options runtime", productPath(), my gSETTINGS's codeSignId)
		
	on error eMsg number eNum
		
		error "codeSignProduct: " & eMsg number eNum
		
	end try
	
end codeSignProduct

on ____________________________ICON()
end ____________________________ICON

on iconIsSet()
	
	if my gSETTINGS's iconName is not "" and my gSETTINGS's iconName is not missing value and my gSETTINGS's iconName is not false then
		return true
	else
		return false
	end if
	
end iconIsSet

on iconPath()
	
	return my gDATA_DIRECTORY & "Icons:" & my gSETTINGS's iconName
	
end iconPath

on checkIcon()
	
	try
		
		(* Regenerate key if necessary *)
		
		if iconIsSet() and existsFile(iconPath()) is false then
			
			activate
			
			display alert "Icon missing" message "The icon file is missing." buttons {"Cancel Build", "Open Icon Directory"} default button 2 cancel button 1
			
			openDirectoryInFinder(gDATA_DIRECTORY & "Icons:")
			
			error "Icon missing"
			
		end if
		
	on error eMsg number eNum
		
		error "checkIcon: " & eMsg number eNum
		
	end try
	
end checkIcon

on copyIcon()
	
	try
		
		if iconIsSet() then
			
			logMessage("Copying icon")
			
			ditto("", iconPath(), resourceInProductAtRelativePath("Contents:Resources:applet.icns"))
			
		end if
		
	on error eMsg number eNum
		
		error "copyIcon: " & eMsg number eNum
		
	end try
	
end copyIcon

on ____________________________KEY()
end ____________________________KEY

on keyCount()
	
	return count of (my gSETTINGS's keyNames)
	
end keyCount

on keyPath(keyName)
	
	return my gDATA_DIRECTORY & "Keys:" & keyName
	
end keyPath

on keyPassword()
	
	return (my gSETTINGS's keyPassword)
	
end keyPassword

on checkKeys()
	
	try
		
		repeat with i from 1 to keyCount()
			
			set keyName to item i of (my gSETTINGS's keyNames)
			
			checkKey(keyName)
			
		end repeat
		
	on error eMsg number eNum
		
		error "checkKeys: " & eMsg number eNum
		
	end try
	
end checkKeys

on checkKey(keyName)
	
	try
		(* Regenerate key if necessary *)
		
		set pathForKey to keyPath(keyName)
		
		if existsFile(pathForKey) is false then
			
			activate
			
			display alert "Key pair \"" & keyName & "\" missing" message "Would you like to generate a new key pair?" buttons {"Cancel Build", "Generate Key Pair"} default button 2 cancel button 1
			
			generateKey(keyName)
			
		end if
		
		if existsFile(pathForKey) is false then
			
			error "Key missing at path \"" & pathForKey & "\""
			
		end if
		
	on error eMsg number eNum
		
		error "checkKey: " & eMsg number eNum
		
	end try
	
end checkKey

on generateKey(keyName)
	
	try
		
		set pathForKey to keyPath(keyName)
		
		try
			set keyType to item -1 of explodeString(keyName, "_", false)
		on error
			error "Could not derive key type from key name \"" & keyName & "\""
		end try
		
		set keyDirectoryPath to hfsPathForParent(pathForKey)
		
		mkdir("-p", keyDirectoryPath)
		
		set keyComment to "Generated for tunneling (" & timestampWithFormat(current date, 1) & ")"
		
		rm("-f", pathForKey)
		
		rm("-f", pathForKey & ".pub")
		
		do shell script "/usr/bin/ssh-keygen -q -C " & quoted form of keyComment & " -t " & quoted form of keyType & " -N " & quoted form of keyPassword() & " -f " & qpp(pathForKey)
		
	on error eMsg number eNum
		
		error "Could not generate key. " & eMsg number eNum
		
	end try
	
end generateKey

on copyKeys()
	
	try
		
		repeat with i from 1 to keyCount()
			
			set keyName to item i of (my gSETTINGS's keyNames)
			
			copyKey(keyName)
			
		end repeat
		
	on error eMsg number eNum
		
		error "copyKeys: " & eMsg number eNum
		
	end try
	
end copyKeys


on copyKey(keyName)
	
	try
		
		logMessage("Copying key \"" & keyName & "\"")
		
		ditto("", keyPath(keyName), resourceInProductAtRelativePath("Contents:Resources:Keys:" & keyName))
		
	on error eMsg number eNum
		
		error "copyKey: " & eMsg number eNum
		
	end try
	
end copyKey

on ____________________________POST_PROCESSING()
end ____________________________POST_PROCESSING

on postProcess()
	
	try
		
		if my gSETTINGS's postProcess is "Run" then
			
			do shell script "/usr/bin/open " & qpp(productPath())
			
		else if my gSETTINGS's postProcess contains "Image" and my gSETTINGS's postProcess contains "Archive" then
			
			createImage()
			
			createArchive()
			
		else if my gSETTINGS's postProcess contains "Image" then
			
			createImage()
			
			
		else if my gSETTINGS's postProcess contains "Archive" then
			
			createArchive()
			
		else
			
			revealFileInFinder(productPath())
			
		end if
		
	on error eMsg number eNum
		error "postProcess: " & eMsg number eNum
	end try
	
	
end postProcess

on createImage()
	
	try
		
		logMessage("Creating image")
		
		-- Generate paths
		set imageSourceDirectoryPath to productsDirectory() & productName() & ":"
		set imagePath to productsDirectory() & snr(" ", "_", lowercaseText(productName())) & ".dmg"
		
		-- Recreate image source directory and copy product into it
		resetDirectory(imageSourceDirectoryPath)
		ditto("", productPath(), imageSourceDirectoryPath & productNameWithSuffix())
		
		-- Create image and delete source directory
		rm("-f ", imagePath)
		do shell script "/usr/bin/hdiutil create -srcfolder " & qpp(imageSourceDirectoryPath) & " " & qpp(imagePath)
		rm("-rf ", imageSourceDirectoryPath)
		
		if my gSETTINGS's postProcess contains "Mail" then
			
			-- Open the disk image with Mail to create a new message
			do shell script "/usr/bin/open -a /Applications/Mail.app " & qpp(imagePath)
			
		else if my gSETTINGS's postProcess contains "run" then
			
			do shell script "/usr/bin/hdiutil attach " & qpp(imagePath)
			do shell script "/usr/bin/open " & qpp(productName() & ":" & productNameWithSuffix())
			
		else
			
			revealFileInFinder(imagePath)
			
		end if
		
	on error eMsg number eNum
		
		error "createImage: " & eMsg number eNum
		
	end try
	
end createImage

on createArchive()
	
	try
		
		logMessage("Creating archive")
		
		-- Generate paths
		set archivePath to productsDirectory() & snr(" ", "_", lowercaseText(productName())) & ".zip"
		
		-- Create archive
		rm("-f", archivePath)
		
		ditto("-ck --keepParent", productPath(), archivePath)
		
		if my gSETTINGS's postProcess contains "Mail" then
			
			-- Open the archive with Mail to create a new message
			do shell script "/usr/bin/open -a /Applications/Mail.app " & qpp(archivePath)
			
		else
			
			revealFileInFinder(archivePath)
			
		end if
		
	on error eMsg number eNum
		
		error "createArchive: " & eMsg number eNum
		
	end try
	
end createArchive

on ____________________________FILE_SYSTEM()
end ____________________________FILE_SYSTEM

on checkDirectory(directoryPath)
	
	try
		test("-d", directoryPath)
	on error
		try
			mkdir("-p", directoryPath)
		on error
			error "Could not create directory at " & directoryPath & "." number 2
		end try
	end try
	
end checkDirectory

on resetDirectory(directoryPath)
	
	try
		rm("-rf", directoryPath)
	end try
	
	try
		mkdir("-p", directoryPath)
	on error
		error "Could not create directory at " & directoryPath & "." number 2
	end try
	
end resetDirectory

on directoryContentsWithSuffix(directoryPath, suffix)
	
	try
		
		set directoryContents to list folder directoryPath
		
	on error eMsg number eNum
		
		if eNum = -43 then
			error "Could not get contents of " & directoryPath & ". No directory at specified path." number eNum
		else
			error "Could not get contents of directory at " & directoryPath & ". " & eMsg number eNum
		end if
		
	end try
	
	set foundContents to {}
	
	repeat with i from 1 to count of directoryContents
		
		if (item i of directoryContents) ends with suffix then
			set end of foundContents to (item i of directoryContents)
		end if
		
	end repeat
	
	return foundContents
	
end directoryContentsWithSuffix

on existsFile(aPath)
	
	try
		test("-f", aPath)
		return true
	on error
		return false
	end try
	
end existsFile

on existsDirectory(aPath)
	
	try
		test("-d", aPath)
		return true
	on error
		return false
	end try
	
end existsDirectory

on hfsPathForParent(anyPath)
	
	-- Convert path to text
	set anyPath to anyPath as text
	
	-- Remove quotes
	if anyPath starts with "'" and anyPath ends with "'" then
		set anyPath to text 2 thru -2 of anyPath
	end if
	
	-- Expand tilde
	if anyPath starts with "~" then
		
		-- Get the path to the userÕs home folder
		set userPath to POSIX path of (path to home folder)
		
		-- Remove trailing slash
		if userPath ends with "/" then set userPath to text 1 thru -2 of userPath as text
		
		if anyPath is "~" then
			set anyPath to userPath
		else
			set anyPath to userPath & text 2 thru -1 of anyPath
		end if
		
	end if
	
	-- Convert to HFS style path if necessary
	if anyPath does not contain ":" then set anyPath to (POSIX file anyPath) as text
	
	-- For simplification make sure every path ends with a colon
	if anyPath does not end with ":" then set anyPath to anyPath & ":"
	
	-- Get rid of the last path component
	set prvDlmt to text item delimiters
	set text item delimiters to ":"
	set parentPath to (text items 1 thru -3 of anyPath as text) & ":"
	set text item delimiters to prvDlmt
	
	return parentPath
	
end hfsPathForParent

on qpp(aPath)
	
	return quoted form of (POSIX path of aPath)
	
end qpp

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
		
		if existsFile(tempFilePath) is false then exit repeat
		set rNumber to rNumber + 1
	end repeat
	
	return tempFilePath
	
end temporaryPath

on ____________________________SHELL_TOOLS()
end ____________________________SHELL_TOOLS

on test(flags, aPath)
	
	do shell script "/bin/test " & flags & " " & qpp(aPath)
	
end test

on mkdir(flags, aPath)

	set cmd to "/bin/mkdir " & flags & " " & qpp(aPath)
	log cmd
	do shell script cmd
	
end mkdir

on rm(flags, aPath)

	set cmd to "/bin/rm " & flags & " " & qpp(aPath)
	log cmd
	do shell script cmd
	
end rm

on cat(aPath)
	
	return do shell script "/bin/cat " & qpp(aPath)
	
end cat

on echo(fileContents, aPath)
	
	do shell script "/bin/echo " & quoted form of fileContents & " > " & qpp(aPath)
	
end echo

on chmod(permissions, aPath)
	
	set cmd to "/bin/chmod " & permissions & " " & qpp(aPath)
	log cmd
	do shell script cmd
	
end chmod

on xattr(flags, aPath)
	
	set cmd to "/usr/bin/xattr " & flags & " " & qpp(aPath)
	log cmd
	do shell script cmd
	
end xattr

on ditto(flags, path1, path2)
	
	rm("-rf", path2)
	
	set cmd to "/usr/bin/ditto " & flags & " " & qpp(path1) & " " & qpp(path2)
	log cmd
	do shell script cmd
	
	if existsFile(path2) is false and existsDirectory(path2) is false then
		error "Copying " & path1 & " to " & path2 & " failed." number 1
	end if
	
end ditto

on defaults(aVerb, filePath, aKey, aValue)
	
	if aValue is not missing value then
		set cmd to "/usr/bin/defaults " & aVerb & " " & qpp(filePath) & " " & quoted form of aKey & " " & aValue
	else
		set cmd to "/usr/bin/defaults " & aVerb & " " & qpp(filePath) & " " & quoted form of aKey
	end if
	
	log cmd
	do shell script cmd
	
end defaults

on codeSign(flags, aPath, identity)
	
	try
		
		if identity is not "" then
			
			set posixPath to POSIX path of aPath
			
			if posixPath does not end with "/" then set posixPath to posixPath & "/"
			
			xattr("-cr", posixPath)
			
			chmod("a-w", posixPath & "Contents/Resources/Scripts/main.scpt")
			
			set cmd to "/usr/bin/codesign " & flags & " --sign " & quoted form of identity & " " & quoted form of posixPath
			
			log cmd
			
			do shell script cmd
			
		end if
		
	on error eMsg number eNum
		
		error "codeSign: " & eMsg number eNum
		
	end try
	
end codeSign

on osacompile(flags, inputFile, outputFile)
	
	set cmd to "/usr/bin/osacompile " & flags & " -o " & qpp(outputFile) & " " & qpp(inputFile)
	log cmd
	do shell script cmd
	
end osacompile

on ____________________________LOGGING()
end ____________________________LOGGING

on logError(fnc, eMsg, eNum)
	
	logMessage("Error in " & fnc & ": " & eMsg & " (" & (eNum as text) & ")")
	
end logError

on logMessage(msg)
	
	set prefixWithTimestamp to false
	
	if prefixWithTimestamp then
		set ts to timestampWithFormat(current date, 1)
		set msg to ts & tab & msg
	end if
	
	try
		set appName to name of current application
	on error
		set appName to "unknown"
	end try
	
	if appName is "Script Editor" then
		log " " & msg & " "
	else if appName is "osascript" then
		log msg
	end if
	
end logMessage

on ____________________________TEXT()
end ____________________________TEXT

on timestampWithFormat(aDate, aFormat)
	
	(*
		Returns the specified date and time as a string suitable for either log files or file names.
		
		Formats:
		
		1: 2000-01-28 23:15:59
		2: 2000-01-28_23-15-59
		3: Jan 28 23:15:59
		
	*)
	
	if aDate is false then set aDate to current date
	if aFormat is false then set aFormat to 1
	
	-- Get the month and day as integer
	set m to month of aDate as integer
	set d to day of aDate
	
	-- Get the year
	set y to year of aDate as text
	
	-- Get the seconds since midnight
	set theTime to (time of aDate)
	
	-- Get hours, minutes, and seconds
	set h to theTime div (60 * 60)
	set min to theTime mod (60 * 60) div 60
	set S to theTime mod 60
	
	if aFormat is not 3 then
		-- Zeropad month value
		set m to m as text
		if (count of m) is less than 2 then set m to "0" & m
	end if
	
	-- Zeropad day value
	set d to d as text
	if (count of d) is less than 2 then
		if aFormat is 3 then
			set d to " " & d
		else
			set d to "0" & d
		end if
	end if
	
	-- Zeropad hours value
	set h to h as text
	if (count of h) is less than 2 then set h to "0" & h
	
	-- Zeropad minutes value
	set min to min as text
	if (count of min) is less than 2 then set min to "0" & min
	
	-- Zeropad seconds value
	set S to S as text
	if (count of S) is less than 2 then set S to "0" & S
	
	if aFormat is 1 then
		-- Return in a format suitable for log files (e.g. 2000-01-28 23:15:59)
		return y & "-" & m & "-" & d & " " & h & ":" & min & ":" & S
	else if aFormat is 2 then
		-- Return in a format suitable for file names (e.g. 2000-01-28_23-15-59)
		return y & "-" & m & "-" & d & "_" & h & "-" & min & "-" & S
	else if aFormat is 3 then
		-- Return in an alternative log file format (e.g. Jan 28 23:15:59)
		set shortMonths to {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
		return (item m of shortMonths) & " " & d & " " & h & ":" & min & ":" & S
	else
		return ""
	end if
	
end timestampWithFormat

on snr(searchObj, theReplacement, aText)
	
	if class of searchObj is list then
		repeat with objNum from 1 to count of searchObj
			set aText to search_replace_inText_(item objNum of searchObj, theReplacement, aText)
		end repeat
		
		return aText
	end if
	
	if aText does not contain searchObj then return aText
	
	set prvDlmt to text item delimiters
	try
		set text item delimiters to searchObj
		set textItems to text items of aText
		set text item delimiters to theReplacement
		set aText to textItems as string
	end try
	set text item delimiters to prvDlmt
	
	return aText
	
	
end snr

on explodeString(aString, aDelimiter, lastItem)
	
	try
		
		if lastItem is false then set lastItem to -1
		
		set prvDlmt to AppleScript's text item delimiters
		set AppleScript's text item delimiters to aDelimiter
		set aList to text items 1 thru lastItem of aString
		set AppleScript's text item delimiters to prvDlmt
		
		return aList
		
	on error eMsg number eNum
		error "explodeString(): " & eMsg number eNum
	end try
	
end explodeString

on convertListToText(obj)
	
	try
		
		if class of obj is not in {list, record} then return obj as text
		
		repeat 10 times
			try
				get item ((count of obj) + 1) of obj
			on error eMsg
				if eMsg does not end with "É." then error eMsg -- Bug: Sometimes the record is not part of the error message
				delay 0.1
			end try
		end repeat
		
		return "Failed to convert list to text"
		
	on error eMsg
		
		set prvDlmt to text item delimiters
		try
			set text item delimiters to "{"
			set eMsg to "{" & text items 2 thru -1 of eMsg as text
			set text item delimiters to "}"
			set eMsg to (text items 1 thru -2 of eMsg as text) & "}"
		end try
		set text item delimiters to prvDlmt
		
		return eMsg
	end try
	
	
end convertListToText

on lowercaseText(aText)
	
	-- Define character sets
	set lowercaseCharacters to "abcdefghijklmnopqrstuvwxyz"
	set uppercaseCharacters to "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	set lowercaseSpecialCharacters to {138, 140, 136, 139, 135, 137, 190, 141, 142, 144, 145, 143, 146, 148, 149, 147, 150, 154, 155, 151, 153, 152, 207, 159, 156, 158, 157, 216}
	set uppercaseSpecialCharacters to {128, 129, 203, 204, 231, 229, 174, 130, 131, 230, 232, 233, 234, 235, 236, 237, 132, 133, 205, 238, 239, 241, 206, 134, 242, 243, 244, 217}
	
	-- Convert comma seperated strings into a list
	set lowercaseCharacters to characters of lowercaseCharacters
	set uppercaseCharacters to characters of uppercaseCharacters
	
	-- Add special characters to the character lists
	repeat with i from 1 to count of lowercaseSpecialCharacters
		set end of lowercaseCharacters to ASCII character (item i of lowercaseSpecialCharacters)
	end repeat
	repeat with i from 1 to count of uppercaseSpecialCharacters
		set end of uppercaseCharacters to ASCII character (item i of uppercaseSpecialCharacters)
	end repeat
	
	set prvDlmt to text item delimiters
	
	-- Loop through every upper case character
	repeat with i from 1 to count of uppercaseCharacters
		
		considering case
			
			if aText contains (item i of uppercaseCharacters) then
				
				-- Delimit string by upper case character
				set text item delimiters to (item i of uppercaseCharacters)
				set tempList to text items of aText
				-- Join list by lower case character
				set text item delimiters to (item i of lowercaseCharacters)
				set aText to tempList as text
				
			end if
			
		end considering
		
	end repeat
	
	set text item delimiters to prvDlmt
	
	return aText
	
end lowercaseText

on ____________________________FINDER()
end ____________________________FINDER

on revealFileInFinder(aPath)
	
	try
		
		with timeout of 2 seconds
			
			tell application "Finder"
				activate
				reveal file aPath
			end tell
			
		end timeout
		
	on error eMsg number eNum
		
		logError("revealDirectoryInFinder", eMsg, eNum)
		
	end try
	
end revealFileInFinder

on openDirectoryInFinder(directoryPath)
	
	try
		
		with timeout of 2 seconds
			
			tell application "Finder"
				activate
				open folder directoryPath
			end tell
			
		end timeout
		
	on error eMsg number eNum
		
		logError("openDirectoryInFinder", eMsg, eNum)
		
	end try
	
end openDirectoryInFinder

on ____________________________MISC()
end ____________________________MISC

on loadScriptText(scriptPath)
	
	try
		test("-f", scriptPath)
	on error
		error "Could not load script. No file found at " & scriptPath & "." number 3
	end try
	
	set tempPath to temporaryPath()
	
	try
		
		osacompile("", scriptPath, tempPath)
		
		set loadedScript to load script file tempPath
		
	on error eMsg number eNum
		
		error "Could not compile " & scriptPath & ". " & eMsg number eNum
		
	end try
	
	try
		rm("-f", tempPath)
	end try
	
	return loadedScript
	
end loadScriptText