# Copyright (C) 2015-2016 Mikkel Kirkgaard Nielsen
# This software can be distributed under the terms of the GNU General
# Public License (GNU GPL) v3 or later (http://www.gnu.org/licenses/gpl).

# BBB_funcs.sh: shell script providing BeagleBone Black cape control functionality.
#               Meant to be sourced into a main script.

if [ -z $CAPELOG ]; then
	CAPELOG=/dev/null
fi

__BBB_GPIO_MAX=117    # Highest GPIO3_21 = 117(dec)

# $1 is pin no (in dec. eg. 60) to export
# $2 is pin direction to set (in or out)
# Errors are echoed to stdout
function export_pin
{
	if [ ! -z "$1" -a $1 -le $__BBB_GPIO_MAX ]; then
		if [ $2 == "in" -o $2 == "out" ]; then
			if [ ! -e /sys/class/gpio/gpio$1 ]; then
	        	        echo $1 > /sys/class/gpio/export
        	        	sleep 0.3
			else
	                        echo  `date +%FT%T` gpio $1 already exported. | tee --append $CAPELOG
			fi
			echo $2 > /sys/class/gpio/gpio$1/direction
			sleep 0.3
		else
			echo  `date +%FT%T` direction \"$2\" in gpio $1 invalid. | tee --append $CAPELOG
		fi
	else
		echo  `date +%FT%T` gpio \"$1\" invalid.  | tee --append $CAPELOG
	fi;
}

# $1 is pin no (in dec. eg. 60) to set
# $2 is desired pin state (0 or 1)
# Errors are echoed to stdout
function set_pin ()
{
    if [ ! -z "$1" -a $1 -le $__BBB_GPIO_MAX ]; then
	if [ $2 -eq 0 -o $2 -eq 1 ]; then
	    echo $2 > /sys/class/gpio/gpio$1/value
	else
	    echo  `date +%FT%T` gpio $1 value $2 invalid.  | tee --append $CAPELOG
	fi
    else
	echo  `date +%FT%T` gpio $1 invalid.  | tee --append $CAPELOG
    fi;
}

# $1 is pin no (in dec. eg. 60) for which state is wanted
# Result is echoed to stdout, -1 returned for invalid pin
function get_pin ()
{
	if [ $1 -le $__BBB_GPIO_MAX ]; then
		cat /sys/class/gpio/gpio$1/value
	else
		echo -1
	fi;
}


# $1 is identifier for cape to configure (eg. BB-BONE-GPS-GPRS)
function config_cape ()
{
        for CAPEMGR in 9 8 7 6 5 4 3 2 1 0 -1; do 
                if [ -d /sys/devices/bone_capemgr.$CAPEMGR ]; then
                        break
                fi
        done
        if [ ! $CAPEMGR -eq -1 ]; then
                echo `date +%FT%T` found cape manager at /sys/devices/bone_capemgr.$CAPEMGR.   | tee --append $CAPELOG
                # Allocate bone ressources
		local CAPE_GREP=`grep $1 /sys/devices/bone_capemgr.$CAPEMGR/slots`
		if [ x"$CAPE_GREP" == x ]; then
                	echo $1 2>/dev/null 1>/sys/devices/bone_capemgr.$CAPEMGR/slots
			if [ ! $? -eq 0 ]; then
				echo `date +%FT%T` error activating cap \"$1\". Did you install the dtbo-file and disable any conflicting features?
				exit 
			fi
		else
	                echo `date +%FT%T` cape already configured: \"$1\" | tee --append $CAPELOG
		fi
        else
                echo `date +%FT%T` no cape manager found. Aborting config_cape of $1.  | tee --append $CAPELOG
		exit
        fi;
}
