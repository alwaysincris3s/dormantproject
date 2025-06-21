#!/bin/bash

REPORT_DIR="/dormant_reports"
TMPFILE=$(mktemp)
EMAIL_CONF="/etc/user_emails.conf"
CONFIG_FILE="/etc/dormant.conf"

main_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "Dormant User Management UI" \
            --title "Main Menu" \
            --menu "Choose an option:" 20 60 9 \
            1 "View Dormant Reports" \
            2 "Set Account Expiry" \
            3 "Create User Account" \
            4 "Update User Email" \
            5 "Update Configuration" \
            6 "Edit Existing User" \
            7 "Exit" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) view_reports ;;
            2) set_expiry ;;
            3) create_user ;;
            4) update_email ;;
            5) update_config ;;
            6) edit_existing_user ;;
            7) clear; break ;;
        esac
    done
}

view_reports() {
    mapfile -t files < <(ls -t "$REPORT_DIR"/dormant_report_*.txt 2>/dev/null)
    if [ ${#files[@]} -eq 0 ]; then
        dialog --msgbox "No reports found in $REPORT_DIR." 10 40
        return
    fi

    OPTIONS=()
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        OPTIONS+=("$file" "$filename")
    done

    FILE=$(dialog --title "Dormant Reports" \
        --menu "Select a report to view:" 20 70 10 \
        "${OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    if [ -n "$FILE" ]; then
        dialog --textbox "$FILE" 25 80
    fi
}

set_expiry() {
    dialog --inputbox "Enter username:" 8 40 2> "$TMPFILE"
    username=$(<"$TMPFILE")

    if ! id "$username" &>/dev/null; then
        dialog --msgbox "User '$username' not found." 8 40
        return
    fi

    dialog --inputbox "Enter expiry date (YYYY-MM-DD):" 8 40 2> "$TMPFILE"
    expiry_date=$(<"$TMPFILE")

    if date -d "$expiry_date" &>/dev/null; then
        sudo chage -E "$expiry_date" "$username"
        dialog --msgbox "Expiry date set for $username: $expiry_date" 8 50
    else
        dialog --msgbox "Invalid date format." 8 40
    fi
}

create_user() {
    step=1
    newuser=""
    useremail=""
    password=""
    password_confirm=""
    sudo_answer=""

    while true; do
        case $step in
            1)
                dialog --cancel-label "Back to Menu" --ok-label "Next" \
                       --inputbox "Enter new username:" 8 40 2> "$TMPFILE"
                result=$?
                if [[ $result -ne 0 ]]; then return; fi
                newuser=$(<"$TMPFILE")

                if id "$newuser" &>/dev/null; then
                    dialog --msgbox "User '$newuser' already exists." 8 40
                else
                    step=2
                fi
                ;;
            2)
                dialog --cancel-label "Back" --ok-label "Next" \
                       --inputbox "Enter email for $newuser:" 8 60 2> "$TMPFILE"
                result=$?
                if [[ $result -eq 1 ]]; then step=1; continue; fi
                useremail=$(<"$TMPFILE")
                step=3
                ;;
            3)
                dialog --cancel-label "Back" --ok-label "Next" \
                       --insecure --passwordbox "Enter password for $newuser:" 8 40 2> "$TMPFILE"
                result=$?
                if [[ $result -eq 1 ]]; then step=2; continue; fi
                password=$(<"$TMPFILE")
                step=4
                ;;
            4)
                dialog --cancel-label "Back" --ok-label "Next" \
                       --insecure --passwordbox "Confirm password for $newuser:" 8 40 2> "$TMPFILE"
                result=$?
                if [[ $result -eq 1 ]]; then step=3; continue; fi
                password_confirm=$(<"$TMPFILE")

                if [[ "$password" != "$password_confirm" ]]; then
                    dialog --msgbox "Passwords do not match." 8 40
                    step=3
                else
                    step=5
                fi
                ;;
            5)
                dialog --cancel-label "Back" --yes-label "Yes" --no-label "No" \
                       --yesno "Should $newuser have sudo privileges?" 7 50
                result=$?
                case $result in
                    0) sudo_answer="Yes"; step=6 ;;
                    1) sudo_answer="No"; step=6 ;;
                    255) step=4 ;;
                esac
                ;;
            6)
                homedir="/home/$newuser"
                dialog --yes-label "Confirm" --no-label "Back" --yesno "Please confirm the user details:\n\nUsername: $newuser\nEmail: $useremail\nHome: $homedir\nSudo: $sudo_answer\n\nProceed?" 16 60
                result=$?
                if [[ $result -eq 0 ]]; then
                    sudo useradd -m "$newuser" || {
                        dialog --msgbox "Failed to create user." 8 40
                        return
                    }
                    echo "$newuser:$password" | sudo chpasswd

                    [[ "$sudo_answer" == "Yes" ]] && sudo usermod -aG sudo "$newuser"

                    if ! grep -q "^$newuser=" "$EMAIL_CONF" 2>/dev/null; then
                        echo "$newuser=$useremail" | sudo tee -a "$EMAIL_CONF" > /dev/null
                    else
                        sudo sed -i "s/^$newuser=.*/$newuser=$useremail/" "$EMAIL_CONF"
                    fi

                    dialog --msgbox "User $newuser created successfully.\nEmail saved." 10 50
                    return
                else
                    step=5
                fi
                ;;
        esac
    done
}

update_email() {
    if [ ! -f "$EMAIL_CONF" ]; then
        dialog --msgbox "Email config file not found at $EMAIL_CONF." 8 50
        return
    fi

    mapfile -t users < <(cut -d= -f1 "$EMAIL_CONF")
    if [ ${#users[@]} -eq 0 ]; then
        dialog --msgbox "No users found in $EMAIL_CONF." 8 50
        return
    fi

    OPTIONS=()
    for u in "${users[@]}"; do
        email=$(grep "^$u=" "$EMAIL_CONF" | cut -d= -f2-)
        OPTIONS+=("$u" "$email")
    done

    selected_user=$(dialog --menu "Select user to update email:" 20 60 10 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
    if [ -z "$selected_user" ]; then
        return
    fi

    dialog --inputbox "Enter new email for $selected_user:" 8 60 2> "$TMPFILE"
    if [ $? -ne 0 ]; then return; fi
    new_email=$(<"$TMPFILE")

    sudo sed -i "s/^$selected_user=.*/$selected_user=$new_email/" "$EMAIL_CONF"
    dialog --msgbox "Email for $selected_user updated successfully." 8 50
}

update_config() {
    source "$CONFIG_FILE"

    CHOICE=$(dialog --menu "Which setting do you want to update?" 20 60 10 \
        1 "User Dormancy (Current: $DORMANT_USERACCOUNT_DURATION days)" \
        2 "Service Dormancy (Current: $DORMANT_SERVICEACCOUNT_DURATION days)" \
        3 "Password Expiry (Current: $DORMANT_PASSWORD_EXPIRY_DURATION days)" \
        4 "Cron Job Schedule (Current: $DORMANT_CRON_SCHEDULE)" \
        3>&1 1>&2 2>&3)

    case $CHOICE in
        1)
            NEW=$(dialog --inputbox "Enter new dormant user account duration (days):" 8 50 "$DORMANT_USERACCOUNT_DURATION" 2>&1 >/dev/tty)
            sudo sed -i "s/^DORMANT_USERACCOUNT_DURATION=.*/DORMANT_USERACCOUNT_DURATION=$NEW/" "$CONFIG_FILE"
            dialog --msgbox "Updated user dormancy to $NEW days." 6 50
            ;;
        2)
            NEW=$(dialog --inputbox "Enter new dormant service account duration (days):" 8 50 "$DORMANT_SERVICEACCOUNT_DURATION" 2>&1 >/dev/tty)
            sudo sed -i "s/^DORMANT_SERVICEACCOUNT_DURATION=.*/DORMANT_SERVICEACCOUNT_DURATION=$NEW/" "$CONFIG_FILE"
            dialog --msgbox "Updated service dormancy to $NEW days." 6 50
            ;;
        3)
            NEW=$(dialog --inputbox "Enter new password expiry duration (days):" 8 50 "$DORMANT_PASSWORD_EXPIRY_DURATION" 2>&1 >/dev/tty)
            sudo sed -i "s/^DORMANT_PASSWORD_EXPIRY_DURATION=.*/DORMANT_PASSWORD_EXPIRY_DURATION=$NEW/" "$CONFIG_FILE"
            dialog --msgbox "Updated password expiry to $NEW days." 6 50
            ;;
        4)
            TIME=$(dialog --clear --backtitle "Cron Job Setup" \
                --title "Select Cron Time" \
                --menu "Choose when to run the dormant script daily:" 20 60 24 \
                "0 0 * * *"   "12:00 AM" \
                "30 0 * * *"  "12:30 AM" \
                "0 1 * * *"   "01:00 AM" \
                "30 1 * * *"  "01:30 AM" \
                "0 2 * * *"   "02:00 AM" \
                "30 2 * * *"  "02:30 AM" \
                "0 3 * * *"   "03:00 AM" \
                "30 3 * * *"  "03:30 AM" \
                "0 4 * * *"   "04:00 AM" \
                "30 4 * * *"  "04:30 AM" \
                "0 5 * * *"   "05:00 AM" \
                "30 5 * * *"  "05:30 AM" \
                "0 6 * * *"   "06:00 AM" \
                "30 6 * * *"  "06:30 AM" \
                "0 7 * * *"   "07:00 AM" \
                "30 7 * * *"  "07:30 AM" \
                "0 8 * * *"   "08:00 AM" \
                "30 8 * * *"  "08:30 AM" \
                "0 9 * * *"   "09:00 AM" \
                "30 9 * * *"  "09:30 AM" \
                "0 10 * * *"  "10:00 AM" \
                "30 10 * * *" "10:30 AM" \
                "0 11 * * *"  "11:00 AM" \
                "30 11 * * *" "11:30 AM" \
                "0 12 * * *"  "12:00 PM" \
                "30 12 * * *" "12:30 PM" \
                "0 13 * * *"  "01:00 PM" \
                "30 13 * * *" "01:30 PM" \
                "0 14 * * *"  "02:00 PM" \
                "30 14 * * *" "02:30 PM" \
                "0 15 * * *"  "03:00 PM" \
                "30 15 * * *" "03:30 PM" \
                "0 16 * * *"  "04:00 PM" \
                "30 16 * * *" "04:30 PM" \
                "0 17 * * *"  "05:00 PM" \
                "30 17 * * *" "05:30 PM" \
                "0 18 * * *"  "06:00 PM" \
                "30 18 * * *" "06:30 PM" \
                "0 19 * * *"  "07:00 PM" \
                "30 19 * * *" "07:30 PM" \
                "0 20 * * *"  "08:00 PM" \
                "30 20 * * *" "08:30 PM" \
                "0 21 * * *"  "09:00 PM" \
                "30 21 * * *" "09:30 PM" \
                "0 22 * * *"  "10:00 PM" \
                "30 22 * * *" "10:30 PM" \
                "0 23 * * *"  "11:00 PM" \
                "30 23 * * *" "11:30 PM" \
                3>&1 1>&2 2>&3)

            if [ -n "$TIME" ]; then
                sudo sed -i "s|^DORMANT_CRON_SCHEDULE=.*|DORMANT_CRON_SCHEDULE=\"$TIME\"|" "$CONFIG_FILE"
                (crontab -l 2>/dev/null | grep -v "/usr/local/bin/dormant.sh" ; echo "$TIME bash /usr/local/bin/dormant.sh") | crontab -
                dialog --msgbox "Cron job updated to: $TIME" 6 50
            else
                dialog --msgbox "Cron update canceled." 6 40
            fi
            ;;
    esac
}

edit_existing_user() {
    declare -A user_emails
    if [ -f "$EMAIL_CONF" ]; then
        while IFS='=' read -r u e; do
            user_emails["$u"]="$e"
        done < "$EMAIL_CONF"
    fi

    mapfile -t all_users < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)

    if [ ${#all_users[@]} -eq 0 ]; then
        dialog --msgbox "No regular users found on system." 8 40
        return
    fi

    while true; do
        dialog --inputbox "Search user by name (leave empty to list all):" 8 50 2> "$TMPFILE"
        if [ $? -ne 0 ]; then return; fi
        search_term=$(<"$TMPFILE")

        if [ -z "$search_term" ]; then
            filtered_users=("${all_users[@]}")
        else
            filtered_users=()
            for u in "${all_users[@]}"; do
                if [[ "$u" =~ $search_term ]]; then
                    filtered_users+=("$u")
                fi
            done
        fi

        if [ ${#filtered_users[@]} -eq 0 ]; then
            dialog --msgbox "No users match your search." 8 40
            continue
        fi

        OPTIONS=()
        for u in "${filtered_users[@]}"; do
            email="${user_emails[$u]}"
            OPTIONS+=("$u" "${email:-No email set}")
        done

        selected_user=$(dialog --menu "Select user to edit:" 20 60 10 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
        if [ -z "$selected_user" ]; then
            return
        fi

        while true; do
            action=$(dialog --menu "Editing user: $selected_user\nChoose an action:" 15 60 6 \
                1 "Reset Password" \
                2 "Update Email" \
                3 "Create Home Directory (if missing)" \
                4 "Toggle Sudo (root) Access" \
                5 "Back to User Search" \
                3>&1 1>&2 2>&3)
            if [ $? -ne 0 ]; then break; fi

            case $action in
                1)
                    dialog --insecure --passwordbox "Enter new password for $selected_user:" 8 50 2> "$TMPFILE"
                    pwd1=$(<"$TMPFILE")
                    dialog --insecure --passwordbox "Confirm new password:" 8 50 2> "$TMPFILE"
                    pwd2=$(<"$TMPFILE")

                    if [ "$pwd1" != "$pwd2" ]; then
                        dialog --msgbox "Passwords do not match. Try again." 8 40
                    elif [ -z "$pwd1" ]; then
                        dialog --msgbox "Password cannot be empty." 8 40
                    else
                        echo "$selected_user:$pwd1" | sudo chpasswd
                        dialog --msgbox "Password updated for $selected_user." 8 40
                    fi
                    ;;
                2)
                    current_email="${user_emails[$selected_user]}"
                    dialog --inputbox "Current email: ${current_email:-None}\nEnter new email for $selected_user:" 8 60 2> "$TMPFILE"
                    if [ $? -eq 0 ]; then
                        new_email=$(<"$TMPFILE")
                        if grep -q "^$selected_user=" "$EMAIL_CONF" 2>/dev/null; then
                            sudo sed -i "s|^$selected_user=.*|$selected_user=$new_email|" "$EMAIL_CONF"
                        else
                            echo "$selected_user=$new_email" | sudo tee -a "$EMAIL_CONF" > /dev/null
                        fi
                        user_emails["$selected_user"]="$new_email"
                        dialog --msgbox "Email updated for $selected_user." 8 40
                    fi
                    ;;
                3)
                    homedir=$(getent passwd "$selected_user" | cut -d: -f6)
                    if [ -d "$homedir" ]; then
                        dialog --msgbox "Home directory already exists: $homedir" 8 50
                    else
                        sudo mkdir -p "$homedir"
                        sudo chown "$selected_user":"$selected_user" "$homedir"
                        dialog --msgbox "Home directory created at $homedir" 8 50
                    fi
                    ;;
                4)
                    if id -nG "$selected_user" | grep -qw "sudo"; then
                        sudo deluser "$selected_user" sudo
                        dialog --msgbox "Sudo access removed from $selected_user." 8 50
                    else
                        sudo usermod -aG sudo "$selected_user"
                        dialog --msgbox "Sudo access granted to $selected_user." 8 50
                    fi
                    ;;
                5)
                    break
                    ;;
                *)
                    dialog --msgbox "Invalid choice." 6 40
                    ;;
            esac
        done
    done
}

trap "rm -f $TMPFILE" EXIT
main_menu
