#!/bin/bash
set -euo pipefail

declare -i GPIO_PIN=13
declare FILENAME="axelf.ton"

declare mode=0
declare t=1
declare s=0
declare octave=4
declare stop=1 # false

declare pitch=$(echo "523.50 / 32.0" | bc ) 

banner() {
  echo "Raspberry Pi PC Speaker GPIO player"
	echo "by Carlos Milán Figueredo. https://www.hispamsx.org"
	echo ""
}

helpmsg() {
	echo "Usage: ./playtone.sh --gpio-pin <BCM_GPIO> --filename <filename.ton>"
	echo ""
}

chkbin() {
    if ! [ -x "$(command -v $1)" ]; then
        echo "ERROR: This script requires $1 program to continue. Please install it."
        exit 1
    fi
}

checkdeps() {
    chkbin perl
    chkbin bc
    chkbin gpio
    chkbin tr
    chkbin awk
}

tone() {
  local freq="$1"
  local dur="$2"
  if test "$freq" -eq 0; then
    gpio -g mode $GPIO_PIN in
  else
    # If we are passing frequencies directly, the period is the inverse
    local period="$(perl -e "printf '%.0f', 1000000/$freq")" 
    gpio -g mode $GPIO_PIN pwm
    gpio pwmr "$(( period ))"

    gpio -g pwm $GPIO_PIN "$(( period/2 ))"
    gpio pwm-ms
  fi
  if [ $(bc <<< "$dur != 0") -eq 1 ]; then
    sleep $(echo "scale=3; $dur / 1000" | bc )
    tone 0 0
  fi
}

is_number() {
  local var="$1"
  if [[ $var =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    return 0
  else
    return 1
  fi
}

parseInt() {
  local var="$1"
  if [[ $var =~ ^-?[0-9]+$ ]]; then
    integer=$((var + 0))
  else
    integer="NaN"
  fi
  echo $integer
}

parseFloat() {
  local var="$1"

  if [[ $var =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    float=$(echo "$var" | bc)
  else
    float="NaN"
  fi
  echo $float
}

truncsp() {
    local input="$1"
    # Remove trailing white-space characters
    trimmed="${input%"${input##*[![:space:]]}"}"
    echo "$trimmed"
}

play() {
  local freq="$1"
  local dur="$2"
  
  local notes_string="c, ,d, ,e,f, ,g, ,a, ,b"
  IFS=',' read -a notes <<< "$notes_string"
  local sharp_string="B,C, ,D, ,E,F, ,G, ,A, "
  IFS=',' read -a sharp <<< "$sharp_string"

  local i
  local n
  local o
  local d
  local len
  local f

  if ! is_number $dur; then
    dur="0"
  fi

  d=$(parseFloat $dur)
  f=$(parseInt $freq)
  if [ "$f" = "NaN" ]; then
    c=$(echo ${freq:0:1} | tr '[:lower:]' '[:upper:]')
    d0=$(echo ${dur:0:1})
    case "$c" in
      O)
        if is_number $d0; then
          octave=$d
        else
          octave+=$d
        fi
        return 0
        ;;
      P)
        d1=$(parseFloat $dur)
        if is_number $d0; then  
          pitch=$(echo "$d1 / 32.0" | bc)
        else
          pitch+=$d1
        fi
        return 0
        ;;
      R)
        f=0
        ;;
      S)
        if is_number $d0; then
          s=$d
        else
          s+=$d
        fi
        return 0
        ;;
      T)
        t=$d
        return 0
        ;;
      V)
        return 0
        ;;
      Q)
        ;;
      X)
        stop=0 # true
        ;;
      *)
        i=0
        for n in "${notes[@]}"; do
          if [ "${freq:0:1}" = "$n" ] || [ "${freq:0:1}" = "${sharp[$i]}" ]; then
            break
          fi
          ((i+=1))
        done
        f1=${freq:1:1}
        f1i=$(parseInt $f1)
        if is_number $f1i; then
          f1_ascii=$(printf "%d" "'$f1'")
          o=$((f1_ascii & 0xf))
        else
          o=$octave
        fi
        f=$(echo "scale=4; $pitch * e($o + $i / 12 * l(2))" | bc -l | awk '{printf "%d\n", $1}')
        ;;
    esac
  fi

  if [ "$t" -gt 10 ]; then
    len=$(echo "($d * $t) - ($d * $s)" | bc)
  else
    len=$(echo "($d * $t)" | bc)
  fi
  if ! is_number $len; then
    return 0
  fi
  if [ "$f" -gt "0" ]; then
    tone $f $len
  else
    sleep $(echo "scale=3; $len / 1000" | bc )
  fi
  if [ "$s" -gt 0 ]; then
    if [ "$t" -gt 10 ]; then
      sleep $(echo "($d * $s) / 1000" | bc)
    else
      sleep $(echo "$s / 1000" | bc)
    fi
  fi
}

handle_interrupt() {
  echo "Interrupt signal received. Exiting the script."
  tone 0 0
  exit 1
}

banner
checkdeps

while [ $# -gt 0 ]
do
  case "$1" in
    --gpio-pin)
      GPIO_PIN="$2"
      shift 2
      ;;
    --filename)
      FILENAME="$2"
      shift 2
      ;;
    *)
      helpmsg
      echo "Invalid argument or syntax fail: $1"; echo ''
      exit 1
      ;;
  esac
done

trap handle_interrupt SIGINT

while read -r freq dur
do
  echo "$freq $dur"
  if [ "${freq:0:1}" != ":" ] \
  && [ "${freq:0:1}" != " " ] \
  && [ "${freq:0:1}" != "" ]; then
    freq_token=$(truncsp $freq)
    dur_token=$(truncsp $dur)
    play $freq_token $dur_token
  fi
done < "$FILENAME"