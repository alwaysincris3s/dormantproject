#!/bin/bash

# Paths and temp files
TMPFILE="/tmp/dormant_ui_tmp.$$"
REPORT_DIR="/dormant_reports"          # Set your actual report directory here
EMAIL_CONF="/etc/user_emails.conf"       # Set your email config file path here
CONFIG_FILE="/etc/dormant.conf"       # Your config file with dormancy variables
TARGET_SCRIPT="/usr/local/bin/dormant.sh" # Your main script that cron calls

# -------- main menu --------
main_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "Dormant User Management UI" \
            --title "Main Menu" \
            --menu "Choose a category:" 15 50 6 \
            1 "User Management" \
            2 "System Configuration" \
            3 "Reports" \
            4 "Account Expiry" \
            5 "Dormant.sh Patching" \
            6 "Exit" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) user_management_menu ;;
            2) system_configuration_menu ;;
            3) view_reports ;;
            4) set_expiry ;;
            5) dormant_patch_menu ;;
            6) clear; break ;;
            *) clear; break ;;
        esac
    done
}

# -------- User Management Submenu --------
user_management_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "User Management" \
            --title "User Management Menu" \
            --menu "Select an option:" 15 50 5 \
            1 "Create User Account" \
            2 "Update Email Address" \
            3 "Edit User Information" \
            4 "Back to Main Menu" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) create_user ;;
            2) update_email ;;
            3) edit_existing_user ;;
            4) break ;;
            *) break ;;
        esac
    done
}

# -------- System Configuration Submenu --------
system_configuration_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "System Configuration" \
            --title "System Configuration Menu" \
            --menu "Select an option:" 15 50 2 \
            1 "Update System Configuration" \
            2 "Back to Main Menu" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) update_config ;;
            2) break ;;
            *) break ;;
        esac
    done
}

# -------- Dormant.sh Patching Submenu --------
dormant_patch_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "Dormant.sh Patching" \
            --title "Dormant.sh Patching Menu" \
            --menu "Select an option:" 15 50 3 \
            1 "Update Server URL" \
            2 "Update Gmail Credentials" \
            3 "Back to Main Menu" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) update_server_url ;;
            2) update_gmail_credentials ;;
            3) break ;;
            *) break ;;
        esac
    done
}

# -------- view reports --------
view_reports() {
    declare -A FILE_MAP
    mapfile -t files < <(ls -t "$REPORT_DIR"/dormant_report_*.txt 2>/dev/null)
    if [ ${#files[@]} -eq 0 ]; then
        dialog --msgbox "No reports found in $REPORT_DIR." 10 40
        return
    fi

    dialog --inputbox "Enter date to search (e.g. 01/01/2025) or leave blank to list all:" 8 60 2> "$TMPFILE"
    search=$(<"$TMPFILE")

    OPTIONS=()
    for file in "${files[@]}"; do
        filename=$(basename "$file")
        rawdate="${filename#dormant_report_}"
        rawdate="${rawdate%.txt}"

        day=$(echo "$rawdate" | cut -d'_' -f1)
        month_text=$(echo "$rawdate" | cut -d'_' -f2)
        year=$(echo "$rawdate" | cut -d'_' -f3)
        time_raw=$(echo "$rawdate" | cut -d'_' -f4-)

        case "$month_text" in
            Jan) month="01" ;;
            Feb) month="02" ;;
            Mar) month="03" ;;
            Apr) month="04" ;;
            May) month="05" ;;
            Jun) month="06" ;;
            Jul) month="07" ;;
            Aug) month="08" ;;
            Sep) month="09" ;;
            Oct) month="10" ;;
            Nov) month="11" ;;
            Dec) month="12" ;;
            *) month="00" ;;
        esac

        formatted_date="${day}/${month}/${year}"
        formatted_time=$(echo "$time_raw" | sed 's/-/:/g')
        display="${formatted_date} ${formatted_time}"

        if [[ -z "$search" || "$display" == *"$search"* ]]; then
            OPTIONS+=("$display" "")
            FILE_MAP["$display"]="$file"
        fi
    done

    if [ ${#OPTIONS[@]} -eq 0 ]; then
        dialog --msgbox "No reports match your input." 8 40
        return
    fi

    CHOSEN=$(dialog --title "Dormant Reports" \
        --menu "Select a report to view:" 20 70 10 \
        "${OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    if [ -n "$CHOSEN" ]; then
        dialog --textbox "${FILE_MAP[$CHOSEN]}" 25 80
    fi
}

# -------- set account expiry --------
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

# -------- create user --------
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
                if [[ $result -ne 0 ]]; then step=1; continue; fi
                useremail=$(<"$TMPFILE")
                step=3
                ;;
            3)
                dialog --cancel-label "Back" --ok-label "Next" \
                    --insecure --passwordbox "Enter password for $newuser:" 8 40 2> "$TMPFILE"
                result=$?
                if [[ $result -ne 0 ]]; then step=2; continue; fi
                password=$(<"$TMPFILE")
                step=4
                ;;
            4)
                dialog --cancel-label "Back" --ok-label "Next" \
                    --insecure --passwordbox "Confirm password for $newuser:" 8 40 2> "$TMPFILE"
                result=$?
                if [[ $result -ne 0 ]]; then step=3; continue; fi
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
                    --yesno "Should $newuser have root privileges?" 7 50
                result=$?
                case $result in
                    0) sudo_answer="Yes"; step=6 ;;
                    1) sudo_answer="No"; step=6 ;;
                    255) step=4 ;;
                esac
                ;;
            6)
                homedir="/home/$newuser"
                dialog --yes-label "Confirm" --no-label "Back" \
                    --yesno "Please confirm the user details:\n\nUsername: $newuser\nEmail: $useremail\nHome: $homedir\nRoot Privileges: $sudo_answer\n\nProceed?" 16 60
                result=$?
                if [[ $result -eq 0 ]]; then
                    sudo useradd -m "$newuser" || {
                        dialog --msgbox "Failed to create user." 8 40
                        return
                    }
                    echo "$newuser:$password" | sudo chpasswd

                    if [[ "$sudo_answer" == "Yes" ]]; then
                        sudo usermod -aG sudo "$newuser"
                    fi

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

# -------- update email --------
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

# -------- update config --------
update_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        dialog --msgbox "Config file not found: $CONFIG_FILE" 8 50
        return
    fi

    source "$CONFIG_FILE"

    CHOICE=$(dialog --menu "Which setting do you want to update?" 20 60 10 \
        1 "User Dormancy (Current: $DORMANT_USERACCOUNT_DURATION days)" \
        2 "Service Dormancy (Current: $DORMANT_SERVICEACCOUNT_DURATION days)" \
        3 "Password Expiry (Current: $DORMANT_PASSWORD_EXPIRY_DURATION days)" \
        4 "Custom Cron Schedule Input (Current: $DORMANT_CRON_SCHEDULE)" \
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
            NEW=$(dialog --inputbox "Enter custom cron schedule (e.g. */5 * * * *):" 8 60 "$DORMANT_CRON_SCHEDULE" 2>&1 >/dev/tty)
            sudo sed -i "s|^DORMANT_CRON_SCHEDULE=.*|DORMANT_CRON_SCHEDULE=\"$NEW\"|" "$CONFIG_FILE"
            dialog --msgbox "Custom cron schedule set to: $NEW" 6 60

            # Update crontab: remove old and add new for TARGET_SCRIPT
            (crontab -l 2>/dev/null | grep -v "$TARGET_SCRIPT" ; echo "$NEW bash $TARGET_SCRIPT") | crontab -

            dialog --msgbox "Crontab updated with new schedule." 6 50
            ;;
        *)
            ;;
    esac

    source "$CONFIG_FILE"
}

# -------- edit existing user --------
edit_existing_user() {
    declare -A user_emails
    if [ -f "$EMAIL_CONF" ]; then
        while IFS='=' read -r u e; do
            user_emails["$u"]="$e"
        done < "$EMAIL_CONF"
    fi

    while true; do
        mapfile -t all_users < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)

        if [ ${#all_users[@]} -eq 0 ]; then
            dialog --msgbox "No standard users found." 8 40
            return
        fi

        search=$(dialog --inputbox "Enter username to search (leave blank to list all):" 8 60 2>&1 >/dev/tty)
        if [ $? -ne 0 ]; then return; fi

        if [ -z "$search" ]; then
            filtered_users=("${all_users[@]}")
        else
            filtered_users=()
            for u in "${all_users[@]}"; do
                if [[ "$u" == *"$search"* ]]; then
                    filtered_users+=("$u")
                fi
            done
            if [ ${#filtered_users[@]} -eq 0 ]; then
                dialog --msgbox "No users found matching \"$search\"." 8 40
                continue
            fi
        fi

        OPTIONS=()
        for u in "${filtered_users[@]}"; do
            email="${user_emails[$u]}"
            OPTIONS+=("$u" "${email:-No email}")
        done

        selected_user=$(dialog --menu "Select a user to edit:" 20 70 15 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
        if [ -z "$selected_user" ]; then
            return
        fi

        uid=$(id -u "$selected_user")
        gid=$(id -g "$selected_user")
        groups=$(id -Gn "$selected_user")
        homedir=$(getent passwd "$selected_user" | cut -d: -f6)
        email="${user_emails[$selected_user]:-No email}"
        has_sudo=$(echo "$groups" | grep -qw "sudo" && echo "Yes" || echo "No")

        dialog --msgbox "User Summary for $selected_user:\n\nUsername: $selected_user\nUID: $uid\nGID: $gid\nHome: $homedir\nEmail: $email\nSudo: $has_sudo" 12 60

        while true; do
            EDIT_CHOICE=$(dialog --menu "Edit User: $selected_user\nChoose action:" 18 60 10 \
                1 "Reset Password" \
                2 "Update Email" \
                3 "Create Home Directory if Missing" \
                4 "Modify Root Privileges" \
                5 "Remove User Account" \
                6 "Back to User Search" \
                3>&1 1>&2 2>&3)

            case $EDIT_CHOICE in
                1)
                    dialog --insecure --passwordbox "Enter new password for $selected_user:" 8 40 2> "$TMPFILE"
                    if [ $? -eq 0 ]; then
                        newpass=$(<"$TMPFILE")
                        echo "$selected_user:$newpass" | sudo chpasswd
                        dialog --msgbox "Password reset for $selected_user." 8 40
                    fi
                    ;;
                2)
                    dialog --inputbox "Enter new email for $selected_user:" 8 60 2> "$TMPFILE"
                    if [ $? -eq 0 ]; then
                        new_email=$(<"$TMPFILE")
                        if grep -q "^$selected_user=" "$EMAIL_CONF"; then
                            sudo sed -i "s/^$selected_user=.*/$selected_user=$new_email/" "$EMAIL_CONF"
                        else
                            echo "$selected_user=$new_email" | sudo tee -a "$EMAIL_CONF" > /dev/null
                        fi
                        user_emails["$selected_user"]="$new_email"
                        dialog --msgbox "Email updated for $selected_user." 8 50
                    fi
                    ;;
                3)
                    if [ ! -d "$homedir" ]; then
                        sudo mkdir -p "$homedir"
                        sudo chown "$selected_user:$selected_user" "$homedir"
                        sudo chmod 700 "$homedir"
                        dialog --msgbox "Home directory created for $selected_user." 8 50
                    else
                        dialog --msgbox "Home directory already exists." 8 40
                    fi
                    ;;
                4)
                    if [ "$has_sudo" == "Yes" ]; then
                        dialog --yesno "User currently has sudo privileges. Remove sudo privileges?" 8 50
                        if [ $? -eq 0 ]; then
                            sudo deluser "$selected_user" sudo
                            has_sudo="No"
                            dialog --msgbox "Sudo privileges removed." 8 40
                        fi
                    else
                        dialog --yesno "User does not have sudo privileges. Add sudo privileges?" 8 50
                        if [ $? -eq 0 ]; then
                            sudo usermod -aG sudo "$selected_user"
                            has_sudo="Yes"
                            dialog --msgbox "Sudo privileges granted." 8 40
                        fi
                    fi
                    ;;
                5)
                    dialog --yesno "Are you sure you want to remove user $selected_user? This action cannot be undone." 8 60
                    if [ $? -eq 0 ]; then
                        sudo deluser --remove-home "$selected_user"
                        sudo sed -i "/^$selected_user=/d" "$EMAIL_CONF"
                        dialog --msgbox "User $selected_user removed." 8 40
                        break
                    fi
                    ;;
                6) break ;;
                *) break ;;
            esac
        done
    done
}

# -------- update server url --------
update_server_url() {
    local new_url="$1"
    if [[ -z "$new_url" ]]; then
        echo "Usage: update_server_url <new_url>"
        return 1
    fi

    sudo sed -i -r "s|^\s*local server_url=.*|    local server_url=\"$new_url\"  # updated|" "$TARGET_SCRIPT"
    dialog --msgbox "Updated server_url to: $new_url" 6 50
}

# -------- update gmail credentials --------
update_gmail_credentials() {
    local new_email="$1"
    local new_password="$2"

    if [[ -z "$new_email" || -z "$new_password" ]]; then
        echo "Usage: update_gmail_credentials <email> <app_password>"
        return 1
    fi

    # Replace the -o tls=yes ... line with the updated email and password
    sudo sed -i -r "s|^\s*-o tls=yes -xu [^ ]+ -xp .*$|          -o tls=yes -xu $new_email -xp \"$new_password\"|" "$TARGET_SCRIPT"

    dialog --msgbox "Updated Gmail credentials to email: $new_email" 6 60
}


# -------- Dormant.sh Patching Submenu --------
dormant_patch_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "Dormant.sh Patching" \
            --title "Dormant.sh Patching Menu" \
            --menu "Select an option:" 15 50 3 \
            1 "Update Server URL" \
            2 "Update Gmail Credentials" \
            3 "Back to Main Menu" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1)
                dialog --inputbox "Enter new Server URL (e.g. http://ngrok_url):" 8 60 2> "$TMPFILE"
                new_url=$(<"$TMPFILE")
                if [[ -n "$new_url" ]]; then
                    update_server_url "$new_url"
                else
                    dialog --msgbox "No URL entered. Operation cancelled." 6 50
                fi
                ;;
            2)
                dialog --inputbox "Enter Gmail sender email:" 8 60 2> "$TMPFILE"
                new_email=$(<"$TMPFILE")
                if [[ -z "$new_email" ]]; then
                    dialog --msgbox "No email entered. Operation cancelled." 6 50
                    continue
                fi

                dialog --insecure --passwordbox "Enter Gmail app password:" 8 60 2> "$TMPFILE"
                new_password=$(<"$TMPFILE")
                if [[ -z "$new_password" ]]; then
                    dialog --msgbox "No password entered. Operation cancelled." 6 50
                    continue
                fi

                update_gmail_credentials "$new_email" "$new_password"
                ;;
            3) break ;;
            *) break ;;
        esac
    done
}

# -------- Script Entry Point --------

# Check for dialog
if ! command -v dialog &>/dev/null; then
    echo "Please install 'dialog' to run this script."
    exit 1
fi

main_menu

# Cleanup
rm -f "$TMPFILE"

clear
