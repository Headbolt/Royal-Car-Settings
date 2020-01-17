#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#	Royal-Car-Settings.sh
#	https://github.com/Headbolt/Royal-Car-Settings
#
#   This Script is designed for use in JAMF as a Script in a policy called by a custom trigger,
#		slaved to a Login Policy that calls this Policy and exits without waiting, this is to
#		counter the GUI not starting until after the script has completed.
#		
#   - This script will ...
#			Check for the existance of a OneDrive folder named according to the provided variable.
#				Then it will either report on the settings, or attempt to set them up according
#				the provided "Action" variable
#
#	- Note : There are potential inherant permissions issues in the "Configuring OneDrive" portion
#				of this script that at present do not seem solvable, so I cannot recommend permissions
#				to use with this script.
#				Therefore the current reccomendation for JAMF users, is to have this script run via a Policy
#				that is scoped for all Computers and all users and only Run by a custom Trigger.
#				Then have another policy with a login Script that as it's final action calls the policy with
#				this script in it as a background task.
#
###############################################################################################################################################
#
# HISTORY
#
#	Version: 1.0 - 16/01/2020
#
#	- 16/01/2020 - V1.0 - Created by Headbolt
#
###############################################################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
UserName="$3" # Grab the Username of the current logged in user from built in JAMF variable #3
ODFolderName="$4" # Grab the OneDrive Folder Name Expected from JAMF variable #4 eg OneDrive - Contoso
Act=$5 # Grab decision to "Report" or "Action" the findings of this script from JAMF variable #5 eg Action
#
Action=$(echo $Act | tr “[A-Z]” “[a-z]”) # Reformat the Action varible to Ignore case
#
ODFolder="/Users/$UserName/$ODFolderName" # Construct the OneDrive Folder path
#
# Set the name of the script for later logging
ScriptName="append prefix here as needed - OneDrive Settings Script"
#
###############################################################################################################################################
#
# SCRIPT CONTENTS - DO NOT MODIFY BELOW THIS LINE
#
###############################################################################################################################################
#
# Defining Functions
#
###############################################################################################################################################
#
# KeyChain Check Function
#
KeyChainCheck(){
#
# Keck KeyChain for existence on "Microsoft Office Credentials" Object
KeyChain=$(sudo -iu $UserName security -i find-internet-password -l "Microsoft Office Credentials" 2>&1)
#
if [[ "$KeyChain" == "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." ]]
	then
		KeyChainEntry="Does Not Exist"
	else
		KeyChainEntry="Exists"
fi
#
}
#
###############################################################################################################################################
#
# Defaults Check Function
#
DefaultsCheck(){
#
Defaults=$(sudo -u $UserName defaults read com.microsoft.OneDrive EnableOneAuth 2>&1) # Check for SSO Auth Setting
#
if [[ "$Defaults" == "0" ]]
	then
		DefaultsEntry="Is Not Set"
	else
		if [[ "$Defaults" == "1" ]]
			then
				DefaultsEntry="Is Set"
			else
				DefaultsEntry="Does Not Exist"
		fi
fi
#
}
#
###############################################################################################################################################
#
# Action Check Function
#
ActionCheck(){
#
# Check to see if the Parameter requires Reoprting only, or Action
if [ "$Action" == "report" ]
	then
		/bin/echo "Script Action is set to Report Only"
	else
		if [ "$Action" == "action" ]
			then
				/bin/echo "Script Action is set to Take Action if needed"
			else
				/bin/echo "Report / Action Variable Not Set For This Script"
				SectionEnd
				ScriptEnd
        fi
fi
#
}
#
###############################################################################################################################################
#
# OneDrive Folder Check Function
#
OneDriveFolderCheck(){
#
/bin/echo Checking if OneDrive Folder Exists
#
if ! [ -d "$ODFolder" ]
	then
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo Folder '"'$ODFolder'"' Does not exist.
		/bin/echo OneDrive Not Set Up For This User.
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo "Microsoft Office Credentials Keychain entry" $KeyChainEntry
		/bin/echo "Use Microsoft Office Credentials Keychain setting" $DefaultsEntry
		if [ "$Action" == "report" ]
			then
				SectionEnd
				ScriptEnd
				exit 0
		fi
		#
		if [ "$Action" == "action" ]
			then
				SectionEnd
				OneDrivePath=$(find /Applications/ -iname "OneDrive.app") # Find OneDrive App
				OneDriveVers=$(defaults read "${OneDrivePath}"/Contents/Info CFBundleVersion) # Extracts the OneDrive Version from the APP
				#
				IFS='.' # Internal Field Seperator Delimiter is set to dot (.)
				OneDriveBuildNumber=$(echo $OneDriveVers | awk '{ print $1 }') # Splits down the Version Number to extracts the Build Number
				unset IFS # Internal Field Seperator Delimiter re-disabled
				#
				if [[ $OneDriveBuildNumber > "19221" ]]
					then 
						ODsetup
					else
						/bin/echo "OneDrive is at Version $OneDriveVers"
						/bin/echo "Auto Setup script requies at least 19222.0000.0000"
				fi           
		fi
	else
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo Folder '"'$ODFolder'"' Exists.
		/bin/echo OneDrive must be Set Up For This User.
		/bin/echo Continuing Checks
fi
}
#
###############################################################################################################################################
#
# OneDrive Setup Function
#
ODsetup(){
#
/bin/echo "Seting Up OneDrive"
SectionEnd
#
/bin/echo "Processing OneDrive Credentials and Settings"
/bin/echo # Outputting a Blank Line for Reporting Purposes
if [[ "$KeyChainEntry" == "Exists" ]]
	then 
		/bin/echo "Microsoft Office Credentials Keychain entry Exists"
	else 
		/bin/echo "Microsoft Office Credentials Keychain entry Does Not Exist"
		/bin/echo "OneDrive Setup cannot continue."
		#
		SectionEnd
		ScriptEnd
		exit 1
fi
#
/bin/echo "Use Microsoft Office Credentials Keychain setting" $DefaultsEntry
#
if [[ "$DefaultsEntry" != "Is Set" ]]
	then
		/bin/echo "Use Microsoft Office Credentials Keychain setting entry Is NOT SET"
		/bin/echo "or Use Microsoft Office Credentials Keychain setting entry Does Not Exist"
		/bin/echo "Setting it now"
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo Running Command '"'sudo -u $UserName defaults write com.microsoft.OneDrive EnableOneAuth -int 1'"'
		sudo -u $UserName defaults write com.microsoft.OneDrive EnableOneAuth -int 1 2>&1
		/bin/echo "Re-Checking Microsoft Office Credentials Keychain setting"
		DefaultsCheck
		/bin/echo "Use Microsoft Office Credentials Keychain setting" $DefaultsEntry
		if [[ "$DefaultsEntry" != "Is Set" ]]
			then
				/bin/echo "OneDrive Setup cannot continue."
				SectionEnd
				ScriptEnd
				exit 1
		fi
fi
#
SectionEnd
#
/bin/echo "Launching OneDrive"
/bin/echo Running Command '"'sudo -iu $UserName open -n odopen://launch/&accounttype=Business'"'
sudo -iu $UserName open -n odopen://launch/&accounttype=Business
#
sleep 10
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
# Setting Command to be Run
#
ProcessCheckCommand=$(echo '
tell application "System Events"
	tell process "OneDrive"
		click button "Sign in" of window "Microsoft OneDrive"
		delay 5
		click button "Next" of window "Microsoft OneDrive"
		delay 2
		click button "Next" of window "Microsoft OneDrive"
		delay 2
		click button "Open my '$ODFolderName' folder" of window "Microsoft OneDrive"
	end tell
end tell
 '
)
#
if [[ "$UserName" != "" ]] # Checking if a user is logged in
	then
		/bin/echo 'Running Command'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		#
		/bin/echo sudo -iu $UserName osascript -e "'"$ProcessCheckCommand"'" # Displaying Command to be run
		#
		sudo -u $UserName osascript -e "$ProcessCheckCommand" #Executing Command
	else
		/bin/echo 'No User Logged in, cannot run command'
fi
#
}
#
###############################################################################################################################################
#
# Folder Processing Function
#
ProcessFolder(){
#
FolderCheck=$(ls -n "/Users/$UserName/" | grep "$FolderToProcess" | awk '{print $9,$10,$11,$12,$13,$14}') # Grab The Details of the Folder
FolderBackup=$(echo $FolderToProcess | cut -c -4) # Create a shorter, 4 character version of the folder name for backup purposes
#
/bin/echo "Checking Instances of $FolderToProcess Folder"
#
if [ "$FolderCheck" == "$FolderToProcess -> $ODFolder/$FolderToProcess" ] # Check to see if folder is a SymLink
	then 
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo $FolderToProcess Folder is a Symlink to..
		/bin/echo $ODFolder/$FolderToProcess
		/bin/echo $FolderToProcess Redirection into OneDrive must be Set Up For This User.
fi
#
if [ "$FolderCheck" == "$FolderToProcess     " ] # Check to see if Folder is an actual Real Folder
	then 
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo $FolderToProcess is an Actual Folder
		/bin/echo $FolderToProcess Redirection into OneDrive must not be configured
		if [ "$Action" == "report" ]
			then
				/bin/echo # Outputting a Blank Line for Reporting Purposes
		fi
		#
        if [ "$Action" == "action" ] # Check if the variable requires us to take action
			then
				if ! [ -d "$ODFolder"/$FolderToProcess ]
					then
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo OneDrive Folder '"'$FolderToProcess'"' Does not exist.
						/bin/echo OneDrive $FolderToProcess not Set Up For This User.
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Moving $FolderToProcess Files and Folders into OneDrive
						mv "/Users/$UserName/$FolderToProcess" "$ODFolder"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Creating $FolderToProcess Link into OneDrive Folder  
						ln -s "$ODFolder"/$FolderToProcess "/Users/$UserName/$FolderToProcess"                
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderToProcess Link to OneDrive"
						chown -R $UserName "/Users/$UserName/$FolderToProcess"
						chmod -R 755 "/Users/$UserName/$FolderToProcess"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						echo "Setting Permissions on $FolderToProcess Files and Folders in OneDrive"
						chown -R $UserName "$ODFolder"/$FolderToProcess
						chmod -R 755 "$ODFolder"/$FolderToProcess
						/bin/echo # Outputting a Blank Line for Reporting Purposes
					else
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo OneDrive Folder '"'$FolderToProcess'"' Already Exists but is not linked.
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Copying $FolderToProcess Files and Folders into OneDrive
						cp -R "/Users/$UserName/$FolderToProcess" "$ODFolder"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Moving $FolderToProcess Files and Folders to $FolderBackup-Old, Just Incase.
						mv "/Users/$UserName/$FolderToProcess" "/Users/$UserName/$FolderBackup-Old"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Hiding $FolderToProcess-Old, so it does not get used.
						chflags hidden "/Users/$UserName/$FolderBackup-Old"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderBackup-Old"
						chown -R $UserName "/Users/$UserName/$FolderBackup-Old"
						chmod -R 755 "/Users/$UserName/$FolderBackup-Old"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Creating $FolderToProcess Link into OneDrive Folder  
						ln -s "$ODFolder"/$FolderToProcess "/Users/$UserName/$FolderToProcess"                
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderToProcess Link to OneDrive"
						chown -R $UserName "/Users/$UserName/$FolderToProcess"
						chmod -R 755 "/Users/$UserName/$FolderToProcess"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderToProcess Files and Folders in OneDrive"
						chown -R $UserName "$ODFolder"/$FolderToProcess
						chmod -R 755 "$ODFolder"/$FolderToProcess
				fi
		fi
fi
#
if [ "$FolderCheck" == "" ] # Check if the Folder Actually Exists at all
	then 
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo $FolderToProcess Does not exist.
		if [ "$Action" == "report" ]
			then
				/bin/echo # Outputting a Blank Line for Reporting Purposes
		fi
		#
        if [ "$Action" == "action" ] # Check if the variable requires us to take action
			then
				if ! [ -d "$ODFolder"/$FolderToProcess ]
					then
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo OneDrive Folder '"'$FolderToProcess'"' Does not exist.
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Creating $FolderToProcess in OneDrive
						mkdir "$ODFolder/$FolderToProcess"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Creating $FolderToProcess Link into OneDrive Folder  
						ln -s "$ODFolder"/$FolderToProcess "/Users/$UserName/$FolderToProcess"                
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderToProcess Link to OneDrive"
						chown -R $UserName "/Users/$UserName/$FolderToProcess"
						chmod -R 755 "/Users/$UserName/$FolderToProcess"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						echo "Setting Permissions on $FolderToProcess Files and Folders in OneDrive"
						chown -R $UserName "$ODFolder"/$FolderToProcess
						chmod -R 755 "$ODFolder"/$FolderToProcess
					else
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo OneDrive Folder '"'$FolderToProcess'"' Already Exists but is not linked.
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo Creating $FolderToProcess Link into OneDrive Folder  
						ln -s "$ODFolder"/$FolderToProcess "/Users/$UserName/$FolderToProcess"                
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderToProcess Link to OneDrive"
						chown -R $UserName "/Users/$UserName/$FolderToProcess"
						chmod -R 755 "/Users/$UserName/$FolderToProcess"
						/bin/echo # Outputting a Blank Line for Reporting Purposes
						/bin/echo "Setting Permissions on $FolderToProcess Files and Folders in OneDrive"
						chown -R $UserName "$ODFolder"/$FolderToProcess
						chmod -R 755 "$ODFolder"/$FolderToProcess
				fi
		fi
fi
#
}
#
###############################################################################################################################################
#
# Section End Function
#
SectionEnd(){
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
}
#
###############################################################################################################################################
#
# Script End Function
#
ScriptEnd(){
#
/bin/echo Ending Script '"'$ScriptName'"'
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
}
#
###############################################################################################################################################
#
# End Of Function Definition
#
###############################################################################################################################################
#
# Beginning Processing
#
###############################################################################################################################################
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
SectionEnd
#
KeyChainCheck
DefaultsCheck
#
ActionCheck
SectionEnd
#
OneDriveFolderCheck
SectionEnd
#
FolderToProcess="Desktop"
ProcessFolder
SectionEnd
#
FolderToProcess="Documents"
ProcessFolder
SectionEnd
#
FolderToProcess="Pictures"
ProcessFolder
SectionEnd
#
ScriptEnd
