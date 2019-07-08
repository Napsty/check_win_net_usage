#!/bin/bash
############################################################################
# check_win_net_usage.sh
#
# Description:
# This script launches two different COUNTER checks on the target server.
# Unfortunately this is necessary because the Windows perfomance output
# has two separate entries for Received and Sent Bytes/s.
#
# Official doc: https://www.claudiokuenzler.com/monitoring-plugins/check_win_net_usage.php
#
# License:      GPLv2                                                          
# GNU General Public Licence (GPL) http://www.gnu.org/ 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses/>. 
#
# Copyright 2011,2012,2015,2019 Claudio Kuenzler www.claudiokuenzler.com
# 
# History:
# 20111116      First version released
# 20120126      Bugfix in port check
# 20121010      Bugfix in password handling
# 20121019      Handling Connection Error (thanks Hermit)
# 20151126      Verify interface parameter was set
# 20151127      Handling connection error on second connection, too
# 20151127      Fix perfdata format
# 20151215      Add network interface detection (-d parameter))
# 20190708	Handle different Windows languages (only 'de' for now)
#############################################################################
# Set path to the location of your Nagios plugin (check_nt)
pluginlocation="/usr/lib/nagios/plugins"
#############################################################################
# Help
help="check_win_net_usage.sh (c) 2011-2019 Claudio Kuenzler (GPLv2)\n
Usage: ./check_win_net_usage.sh -H host [-p port] [-s password] -i intname
Requirements: check_nt plugin and NSClient++ installed on target server
\nOptions:\n-H Hostname of Windows server to check
-p Listening port of NSClient++ on target server (default 12489)
-s Password in case NSClient++ is set to use password
-i Name of network interface to use (not ethX, check Windows performance GUI)
-o Choose output of value in KB, MB (default Byte)
-d Detect network interfaces on target host
-l Set Windows language if different than English, e.g. '-l de'"
#############################################################################
# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit 1;
fi
#############################################################################
# Some people might forget to set the plugin path (pluginlocation)
if [ ! -x ${pluginlocation}/check_nt ]
then
echo "CRITICAL - Plugin check_nt not found in ${pluginlocation}"; exit 2
fi
#############################################################################
# Get user-given variables
while getopts "H:p:s:i:o:dl:" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       p)      port=${OPTARG};;
       s)      password=${OPTARG};;
       i)      interface=${OPTARG};;
       o)      output=${OPTARG};;
       d)      detect=1;;
       l)      winlang=${OPTARG};;
       *)      echo "Wrong option given. Please rtfm or launch --help"
               exit 1
               ;;
       esac
done
#############################################################################
# If port was given
if [[ -n ${port} ]]
then insertport=${port}
else insertport=12489
fi
#############################################################################
# Handle different languages (might switch to case in future)
if [[ $winlang = "de" ]]; then interfacename="Netzwerkadapter"
else interfacename="Network Interface"
fi


# If -d (detection) is used, present list of interface names
if [[ ${detect} -eq 1 ]]; then
  if [[ -n ${password} ]]; then
    ${pluginlocation}/check_nt -H ${host} -p ${insertport} -s ${password} -v INSTANCES -l "${interfacename}" | sed "s/OK&//"; exit 0
  else
    ${pluginlocation}/check_nt -H ${host} -p ${insertport} -v INSTANCES -l "${interfacename}" | sed "s/OK&//"; exit 0
  fi
fi

# Verify interface parameter was set
if [[ -z ${interface} ]]; then echo "UNKNOWN - No interface given"; exit 3; fi
#############################################################################
# The checks itself (with password)
if [[ -n ${password} ]]
then
bytes_in=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -s ${password} -v COUNTER -l "\\${interfacename}(${interface})\\Bytes Received/sec")
bytes_out=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -s ${password} -v COUNTER -l "\\${interfacename}(${interface})\\Bytes Sent/sec")
else
# Without password
bytes_in=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -v COUNTER -l "\\${interfacename}(${interface})\\Bytes Received/sec")
bytes_out=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -v COUNTER -l "\\${interfacename}(${interface})\\Bytes Sent/sec")
fi

# Catch connection error
if !([  "$bytes_in" -eq "$bytes_in" ]) 2>/dev/null
then    echo "Network UNKNOWN: $bytes_in"
        exit 3
fi
if !([  "$bytes_out" -eq "$bytes_out" ]) 2>/dev/null
then    echo "Network UNKNOWN: $bytes_out"
        exit 3
fi

# In case KB or MB has been set in -o option
if [ -n "${output}" ]
then
        if [ "${output}" = "KB" ]
        then return_bytes_in=$(expr ${bytes_in} / 1024)
        return_bytes_out=$(expr ${bytes_out} / 1024)
        value="KBytes"
        elif [ "${output}" = "MB" ]
        then return_bytes_in=$(expr ${bytes_in} / 1024 / 1024)
        return_bytes_out=$(expr ${bytes_out} / 1024 / 1024)
        value="MBytes"
        fi
else
return_bytes_in=${bytes_in}
return_bytes_out=${bytes_out}
value="Bytes"
fi

# Output
echo "Network OK - ${return_bytes_in} ${value} received/sec, ${return_bytes_out} ${value} sent/sec|bytes_in=${bytes_in}B;;;; bytes_out=${bytes_out}B;;;;"
exit 0
