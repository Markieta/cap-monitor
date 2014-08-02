#!/usr/bin/env bash

# Storage Capacity Monitor
# Author: Christopher Markieta

MY_DIR=$(dirname $0)
currentTime=$(date +%H%M)
subject=
body=
diskfree=
lastHost=
connection=

# Enable all disabled monitors at 7:00 AM
if [ 700 -le $currentTime ] && [ $currentTime -le 710 ]; then
    sed -i 's/^#monitor/monitor/' $MY_DIR/enabled
fi

# Determine available space and append warning message if necessary
monitor()
{
    if [ "$lastHost" != "$1" ]; then
        lastHost=$1
        diskfree=$(ssh $1 'df -PB GB')
        error=$?
        connection=
    fi

    if [ "$connection" != 'Failed' ]; then
        if [ $error -le 1 ]; then
            available=$(echo "$diskfree" | awk -v mounted=$2 '$6 == mounted {print substr($4, 1, length($4) - 2); exit;}')

                                        # Threshold
            if [ $(bc <<< "$available < $3") -eq 1 ]; then
                message="$2 on $1 has less than $available GB available"
                
                if [ "$subject" ]; then
                    subject='Multiple Warnings: See Body'
                else
                    subject=$message
                fi

                body="$body$1:\n$message\n\n"
            
                # Disable monitor for the rest of the day
                sed -i "\|^monitor *$1 *$2 |s|^|#|" $MY_DIR/enabled
            fi
        else
            message='Could not connect to '$1

            if [ "$subject" ]; then
                subject='Multiple Warnings: See Body'
            else
                subject=$message
            fi
        
            body=$body$message'\n\n'
            connection='Failed'
        
            sed -i "/^monitor *$1 /s/^/#/" $MY_DIR/enabled
        fi
    fi
}

# Run all enabled monitors
source $MY_DIR/enabled

# Send alert email if low on capacity
if [ "$subject" ]; then
    echo -e "$body" | mail -s "$subject" ostep-alert@senecac.on.ca ostep-team@senecac.on.ca
fi
