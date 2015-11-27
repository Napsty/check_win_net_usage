#!/bin/bash
############################################################################
# check_win_net_usage.sh
#
# Description:
# This script launches two different COUNTER checks on the target server.
# Unfortunately this is necessary because the Windows perfomance output
# has two separate entries for Received and Sent Bytes/s.
#
# Author:     Claudio Kuenzler www.claudiokuenzler.com
# History:
# 20111116    First version released
# 20120126    Bugfix in port check
# 20121010    Bugfix in password handling
# 20121019    Handling Connection Error (thanks Hermit)
# 20151126    Verify interface parameter was set
# 20151127    Handling connection error on second connection, too
#############################################################################
# Set path to the location of your Nagios plugin (check_nt)
pluginlocation="/usr/local/nagios/libexec"
#############################################################################
# Help
help="check_win_net_usage.sh (c) 2011-2015 Claudio Kuenzler (GPLv2)\n
Usage: ./check_win_net_usage.sh -H host [-p port] [-s password] -i intname
Requirements: check_nt plugin and NSClient++ installed on target server
\nOptions:\n-H Hostname of Windows server to check
-p Listening port of NSClient++ on target server (default 12489)
-s Password in case NSClient++ is set to use password
-i Name of network interface to use (not ethX, check Windows performance GUI)
-o Choose output of value in KB, MB (default Byte)"
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
while getopts "H:p:s:i:o:" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       p)      port=${OPTARG};;
       s)      password=${OPTARG};;
       i)      interface=${OPTARG};;
       o)      output=${OPTARG};;
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

# Verify interface parameter was set
if [[ -z ${interface} ]]; then echo "UNKNOWN - No interface given"; exit 3; fi
#############################################################################
# The checks itself (with password)
if [[ -n ${password} ]]
then
bytes_in=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -s ${password} -v COUNTER -l "\\Network Interface(${interface})\\Bytes Received/sec")
bytes_out=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -s ${password} -v COUNTER -l "\\Network Interface(${interface})\\Bytes Sent/sec")
else
# Without password
bytes_in=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -v COUNTER -l "\\Network Interface(${interface})\\Bytes Received/sec")
bytes_out=$(${pluginlocation}/check_nt -H ${host} -p ${insertport} -v COUNTER -l "\\Network Interface(${interface})\\Bytes Sent/sec")
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
echo "Network OK - ${return_bytes_in} ${value} received/sec, ${return_bytes_out} ${value} sent/sec|bytes_in=${bytes_in};bytes_out=${bytes_out}"
exit 0
