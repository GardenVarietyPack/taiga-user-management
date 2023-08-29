#!/bin/bash
# Taiga User Management TUI
# By lucid 2018

INPUT=/tmp/menusel.$$
AUTHCACHE=/tmp/authtoken.$$

trap "rm -f $INPUT" 0 1 2 5 15
trap "rm -f $AUTHCACHE" 0 1 2 5 15
trap "rm -f $SERVER_URL" 0 1 2 5 15
trap "rm -f $USERPARSED" 0 1 2 5 15

checkurl () {
    # Set width of window automatically
    width=${#SERVER_URL}
    width=$(($width+18))
    dialog \
    --backtitle "Taiga User Management" \
    --title "Is this correct?" \
    --yesno "URL:'https://${SERVER_URL}'" 6 $width
    verify=$?
    case $verify in
      0) echo "yay" ;;
      1) select_url ;;
      255) exit 0;;
    esac
}

select_url () {
  servername=""
  exec 3>&1

  SERVER_URL=$(dialog --ok-label "Go" \
    --backtitle "Taiga User Management" \
    --title "What is the server URL?" \
	--nocancel \
	--form "" \
	5 60 0 \
	"https://" 1 1 "$servername" 1 9 50 0 \
  2>&1 1>&3)
  #export $SERVER_URL
  exec 3>&-

  # open fd
  exec 3>&1
  checkurl
}
# Get URL at start
select_url

select_authtoken () {
  AUTH_USER=/tmp/authuser.$$
  AUTH_PASS=/tmp/authpass.$$

  trap "rm -f $AUTH_USER" 0 1 2 5 15
  trap "rm -f $AUTH_PASS" 0 1 2 5 15

  # Request username and password for connecting to Taiga
  dialog \
  --title "Cache Authorization Token" \
  --backtitle "Taiga User Management" \
  --clear \
  --inputbox "Username: " 8 60 2>"${AUTH_USER}"
  authuser=$(<$AUTH_USER)

  dialog \
  --title "Cache Authorization Token" \
  --backtitle "Taiga User Management" \
  --clear \
  --insecure \
  --passwordbox "Password: " 8 60 2>"${AUTH_PASS}"
  authpass=$(<$AUTH_PASS)

  dialog \
    --backtitle "Taiga User Management" \
    --title "Message" \
    --msgbox "Password $authpass" 7 30

  DATA=$(jq --null-input \
         --arg username "$authuser" \
         --arg password "$authpass" \
         '{ type: "normal", username: $username, password: $password }')

  # Get AUTH_TOKEN
  USER_AUTH_DETAIL=$( curl -X POST \
    -H "Content-Type: application/json" \
    -d "$DATA" \
    "https://$SERVER_URL/api/v1/auth" 2>/dev/null )

  AUTH_TOKEN=$( echo ${USER_AUTH_DETAIL} | jq -r '.auth_token' )
  if test var $AUTH_TOKEN == ''
  then
    dialog \
    --backtitle "Taiga User Management" \
    --title "Message" \
    --msgbox "Incorrect Username/Password" 7 30
  else
    AUTHCACHE=$AUTH_TOKEN
    dialog \
    --backtitle "Taiga User Management" \
    --title "Message" \
    --msgbox "Auth Token is ${AUTH_TOKEN}" 7 77
  fi
}
# Get Auth token at start
select_authtoken

select_list () {
  USERDUMP=$(curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTHCACHE}" \
  -s "https://$SERVER_URL/api/v1/users")

  USERPARSED=$(echo $USERDUMP | sed 's/ {/\n&/g' | awk -F, '{print$7","$3}' | \
  sed -e s/"full_name_display"//g | sed -e s/"id"//g | sed -e 's/""://g')
  height=$(echo $USERDUMP | sed 's/ {/\n&/g' | awk -F, '{print$7","$3}' | \
  sed -e s/"full_name_display"//g | sed -e s/"id"//g | sed -e 's/""://g' | wc -l | awk '{print $1}')
  height=$(($height + 4))
  dialog \
  --backtitle "Taiga User Management" \
  --title "Message" \
  --msgbox "${USERPARSED}" $height 30
}

select_add () {
  # instantiate variables in the form of temporary text files.
  # probably should encrypt them, shouldn't be necessary in most cases. 
  FULL="/tmp/full_$$"
  EMAIL="/tmp/email_$$"
  TAIGAUSER="/tmp/username_$$"
  PASS="/tmp/temppass_$$"

  # When the program exits the temp files will be deleted
  trap "rm -f $FULL" 0 1 2 5 15
  trap "rm -f $EMAIL" 0 1 2 5 15
  trap "rm -f $TAIGAUSER" 0 1 2 5 15
  trap "rm -f $PASS" 0 1 2 5 15


  # Send the user input into the temp file
  dialog \
  --title "Input the full name" \
  --backtitle "Taiga User Management" \
  --inputbox "Full name: " 8 60 2>$FULL
  # Send the data from the temp file into a variable
  # not sure how to just make it go directly to the variable
  fullname=$(<$FULL)

  dialog \
  --title "Input the email" \
  --backtitle "Taiga User Management" \
  --inputbox "Email: " 8 60 2>$EMAIL
  emailaddr=$(<$EMAIL)

  dialog \
  --title "Input the username" \
  --backtitle "Taiga User Management" \
  --inputbox  "Username: " 8 60 2>$TAIGAUSER
  username=$(<$TAIGAUSER)

  dialog \
  --title "Input the password" \
  --backtitle "Taiga User Management" \
  --clear \
  --insecure \
  --passwordbox "Password: " 8 60 2>$PASS
  plainpass=$(<$PASS)

  # Commands to API
  curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
	"email": "'${emailaddr}'",
        "full_name": "'${fullname}'",
        "password": "'${plainpass}'",
        "type": "public",
        "username": "'${username}'",
	"accepted_terms": "true"
    }' \
  -s "https://$SERVER_URL/api/v1/auth/register"

  read -p "Press [Enter] key to continue."
}

select_remove () {
  REMOVETHISUSERID=""

  # Get list of users and parse
  USERDUMP=$(curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTHCACHE}" \
  -s "https://$SERVER_URL/api/v1/users")
  USERPARSED=$(echo $USERDUMP | sed 's/ {/\n&/g' | awk -F, '{print$7","$3}' |\
  sed -e s/"full_name_display"//g | sed -e s/"id"//g | sed -e 's/""://g')
  height=$(echo $USERDUMP | sed 's/ {/\n&/g' | awk -F, '{print$7","$3}' |\
  sed -e s/"full_name_display"//g | sed -e s/"id"//g | sed -e 's/""://g' | wc -l | awk '{print $1}')
  height=$(($height + 6))

  REMOVETHISUSERID=$(dialog \
  --ok-label "Delete" \
  --backtitle "Taiga User Management" \
  --title "Who would you like to DELETE?" \
  --form "'${USERPARSED}'" $height 35 0 \
  "UID:" 1 1 "$USERID" 1 5 5 0 2>&1 1>&3)

  exec 3>&-
  exec 3>&1

  dialog \
  --backtitle "Taiga User Management" \
  --title "ARE YOU SURE?" \
  --yesno "Delete UID ${REMOVETHISUSERID}?" 6 25
  verify=$?
  case $verify in
    0) curl -X DELETE \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer ${AUTH_TOKEN}" \
       -s "https://$SERVER_URL/api/v1/users/$REMOVETHISUSERID" ;;
    1) main ;;
    255) exit 0;;
  esac
}

main () {
    dialog \
    --title "Main Menu" \
    --backtitle "Taiga User Management" \
    --menu "Select a function:" 13 35 6 \
    1 "Enter URL" \
    2 "Get Auth Token" \
    3 "Dump user information" \
    4 "Add a user" \
    5 "Remove a user by UserID" \
    6 "Exit to shell" 2>"${INPUT}"
    menuitem=$(<"${INPUT}")

    case $menuitem in
      1) select_url ;;
      2) select_authtoken ;;
      3) select_list ;;
      4) select_add ;;
      5) select_remove ;;
      6) clear; exit ;;
    esac
}
while true; do
	main
done
clear