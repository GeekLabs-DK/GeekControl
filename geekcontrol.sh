#! /bin/bash

# Copyright (C) 2015-2016 Mikkel Kirkgaard Nielsen
# This software can be distributed under the terms of the GNU General
# Public License (GNU GPL) v3 or later (http://www.gnu.org/licenses/gpl).

. ./BBB_funcs.sh
. ./apikey

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
function set_state ()
{
#  echo setting state: $1, present: $2
#  echo apikey: $apikey
  wget -q -O- "http://spaceapi.geeklabs.dk/?control=sensors&command=set&key=${apikey}&sensors={%22state%22:{%22open%22:${1}},%22sensors%22:{%22people_now_present%22:[{%22value%22:${2}}]}}"
}

function get_state
{
  json=`wget -q -O- http://spaceapi.geeklabs.dk/?format=json`
  state=`echo $json | js -e 'process.stdin.on("data", function (line) {console.log(JSON.parse(line).state.open)});'`
  geeks=`echo $json | js -e 'process.stdin.on("data", function (line) {console.log(JSON.parse(line).sensors.people_now_present[0].value)});'`
  echo got state: $state, present $geeks
}

function write_vfd()
{
  echo -ne "${1}" >${VFD_SERIAL}
}

function update_visuals()
{
  write_vfd "\\nGeekControl"
  if $state; then
    write_vfd "     open"
    set_pin $LED_STATE 1
   else
    write_vfd "   closed"
    set_pin $LED_STATE 0
  fi
  write_vfd "  Geeks present: ${geeks}"
}


last_plus=0
last_minus=0
last_tgl=0

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
  sleep 0.1
  BUTCHECK=$(($BUTCHECK-1))
done
done
