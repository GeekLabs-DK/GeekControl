#! /bin/bash

# Copyright (C) 2015-2016 Mikkel Kirkgaard Nielsen
# This software can be distributed under the terms of the GNU General
# Public License (GNU GPL) v3 or later (http://www.gnu.org/licenses/gpl).

. ./BBB_funcs.sh
. ./apikey

# The hostname of your spaceapi implementation.
# Assumes it is running the official endpoint scripts from
# https://github.com/SpaceApi/endpoint-scripts/. But doesn't
# assume that mod_rewrite is enabled, thus uses index.php
# parameters directly (some hosting providers disallow .htacces).
SPACEAPI=spaceapi.geeklabs.dk

# Set this to an ip to force the use of, but still use
# $SPACEAPI in the HTTP Host header. This might be if the device
# is on the same local network as the spaceapi but its dns resolves
# to an external ip.
FORCE_IP=

if [ -z $FORCE_IP ]; then
  WGET_PARAMS=http://$SPACEAPI/
else
  WGET_PARAMS="--header=Host:$SPACEAPI http://$FORCE_IP"
fi

BTN_TGL=60
BTN_MINUS=50
BTN_PLUS=51
LED_STATE=30

config_cape BB-UART1
VFD_SERIAL=/dev/ttyO1

export_pin $LED_STATE out
export_pin $BTN_TGL   in
export_pin $BTN_MINUS in
export_pin $BTN_PLUS  in

#http://spaceapi.geeklabs.dk/?control=sensors&command=set&key=&sensors={%22state%22:{%22open%22:true}}
#http://spaceapi.geeklabs.dk/?format=json

# $1 state
# $2 members present
function set_state () {
#  echo setting state: $1, present: $2
#  echo apikey: $apikey
  wget -q -O- $WGET_PARAMS/?control=sensors\&command=set\&key=${apikey}\&sensors=\{%22state%22:\{%22open%22:${1}\},%22sensors%22:\{%22people_now_present%22:[\{%22value%22:${2}\}\]\}\}
}

function get_state
{
  json=`wget -q -O- $WGET_PARAMS/?format=json`
  state=`echo $json | js -e 'process.stdin.on("data", function (line) {console.log(JSON.parse(line).state.open)});'`
  geeks=`echo $json | js -e 'process.stdin.on("data", function (line) {console.log(JSON.parse(line).sensors.people_now_present[0].value)});'`
  echo got state: $state, present $geeks
}

function write_vfd()
{
  echo -ne "${1}" >${VFD_SERIAL}
}

spindex=0
spinners[0]='-'
spinners[1]='\'
spinners[2]='/'
IDLE_TOGGLE_INTERVAL=5
function update_visuals()
{
  if ([ $IDLE_TOGGLE_INTERVAL -gt 0 ] && [ $(((($(date +%s)-$but_stamp)/${IDLE_TOGGLE_INTERVAL})%2)) -eq 1 ]); then
    write_vfd "\\n$(wget --quiet -O- http://${FORCE_IP}/VFD.php?get=r)"
  else
    write_vfd "\\nGeekControl"
    if $state; then
      write_vfd "     open"
      set_pin $LED_STATE 1
    else
      write_vfd "   closed"
      set_pin $LED_STATE 0
    fi
    spindex=$(((spindex+1)%3))
    echo $spindex ${spinners[$spindex]}
    write_vfd "${spinners[$spindex]} Geeks present: ${geeks}"
  fi
}


last_plus=0
last_minus=0
last_tgl=0
but_stamp=$(date +%s)

while true; do
  get_state
  update_visuals

  BUTCHECK=100
  while [ $BUTCHECK -gt 0 ]; do
  now_tgl=$(get_pin $BTN_TGL)
  now_plus=$(get_pin $BTN_PLUS)
  now_minus=$(get_pin $BTN_MINUS)
  #echo $BUTCHECK:$now_tgl....

  if [ $now_tgl -eq 1 ]; then
    if [ $last_tgl -eq 0 ]; then
      # toggle pushed
      but_stamp=$(date +%s)
      echo toggling, state: $state
      if $state; then
        state=false
        geeks=0
      else
        state=true
	geeks=1
      fi
      update_visuals
      set_state $state $geeks
      #BUTCHECK=0
    fi
  fi
 
  if [ ! $BUTCHECK -eq 0 -a $now_plus -eq 1 ]; then
    if [ $last_plus -eq 0 ]; then
      # plus pushed
      but_stamp=$(date +%s)
      echo plus, present: $geeks
      geeks=$((${geeks}+1))
      state=true
      update_visuals
      set_state $state ${geeks}
      #BUTCHECK=0
    fi
  fi

  if [ ! $BUTCHECK -eq 0 -a $now_minus -eq 1 ]; then
    if [ $last_minus -eq 0 ]; then
      # minus pushed
      but_stamp=$(date +%s)
      echo minus, present: $geeks
      geeks=$((${geeks}-1))
      if [ $geeks -le 0 ]; then
        geeks=0
        state=false
      fi
      update_visuals
      set_state $state ${geeks}
      #BUTCHECK=0
    fi
  fi

  last_tgl=$now_tgl
  last_plus=$now_plus
  last_minus=$now_minus
  sleep 0.01
  BUTCHECK=$(($BUTCHECK-1))
done
done
