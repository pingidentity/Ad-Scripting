#!/bin/bash
Version=1.65
########################################################################
# Created By: Scott LaPaglia & Ross Derewianko
# Creation Date: April 2014
# Last modified: April 18, 2014
# Brief Description: Binds a machine to AD and migrates the user to a network account
#***************************************************************************
# Copyright (C) 2014 Ping Identity Corporation
# All rights reserved.
#
# The contents of this file are subject to the
# Apache License, Version 2.0, available at:
# http://www.apache.org
#
# THIS SOFTWARE IS PROVIDED “AS IS”, WITHOUT ANY WARRANTIES, EXPRESS,
# IMPLIED, STATUTORY OR ARISING BY CUSTOM OR TRADE USAGE, INCLUDING,
# WITHOUT LIMITATION, WARRANTIES OF MERCHANTABILITY, SATISFACTORY QUALITY,
# TITLE, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. THE USER
# ASSUMES ALL RISK ASSOCIATED WITH ACCESS AND USE OF THE SOFTWARE.
########################################################################
# This version taken and adapted from the script below -Scott slapaglia@pingidentity.com
# MigrateLocalUserToDomainAcct.command
# Patrick Gallagher
# http://macadmincorner.com

# This script should not need any modification in most enviornments. 
# If the script does not execute when run, you may need to 'chmod +x /path/to/thisScript' to make it executable
# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 4 AND, IF SO, ASSIGN TO “vpn”
if [ "$4" != "" ] && [ "$domainjoinpass" == "" ]; then
	domainjoinpass=$4
fi

if [ "$5" != "" ] && [ "$domainjoin" == "" ]; then
	domainjoin=$5
fi

if [ "$6" != "" ] && [ "$OU" == "" ]; then
	OU=$6
fi

######## SCRIPT########
netname=`ls -tr /Users |grep -v pingadmin |grep -v Guest |grep -v Shared |tail -1`
check4AD=`/usr/bin/dscl localhost -list . | grep "Active Directory"`
user=`ls -tr /Users |grep -v pingadmin |grep -v Guest |grep -v Shared |tail -1`

dsconfigad -add corp.pingidentity.com -ou '$OU' -username $domainjoin -password $domainjoinpass -computer `scutil --get ComputerName` -mobile enable -mobileconfirm disable -localhome enable -useuncpath disable -shell /bin/bash -groups 'Support Level One'

# If the machine is not bound to AD, then there's no purpose going any further. 
until [ "${check4AD}" = "Active Directory" ]; do
	check4AD=`/usr/bin/dscl localhost -list . | grep "Active Directory"`
	sleep 5s
done
	
# Determine location of the users home folder
userHome=`/usr/bin/dscl . read /Users/$user NFSHomeDirectory | cut -c 19-`
			
# Get list of groups
lgroups="$(/usr/bin/id -Gn $user)"
					
# Delete user from each group it is a member of					
if [[ $? -eq 0 ]] && [[ -n "$(/usr/bin/dscl . -search /Groups GroupMembership "$user")" ]]; then 
	for lg in $lgroups; 
		do
			/usr/bin/dscl . -delete /Groups/${lg} GroupMembership $user >&/dev/null
		done
fi
# Delete the primary group
if [[ -n "$(/usr/bin/dscl . -search /Groups name "$user")" ]]; then
  	/usr/sbin/dseditgroup -o delete "$user"
fi
# Delete the password entry
guid="$(/usr/bin/dscl . -read "/Users/$user" GeneratedUID | /usr/bin/awk '{print $NF;}')"
if [[ -f "/private/var/db/shadow/hash/$guid" ]]; then
 	/bin/rm -f /private/var/db/shadow/hash/$guid
fi
# Delete the user
/usr/bin/dscl . -delete "/Users/$user"
			
# Verify NetID
sleep 10
/usr/bin/id $netname

# Resets permissions of home folder to AD account
/usr/sbin/chown -R ${netname} /Users/$netname

# Adds the user as a local admin on the machine
dscl . append /Groups/admin GroupMembership $user

exit 0