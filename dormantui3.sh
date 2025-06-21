#!/bin/bash

REPORT_DIR="/dormant_reports"
TMPFILE=$(mktemp)
EMAIL_CONF="/etc/user_emails.conf"

main_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "Dormant User Management UI" \
            --title "Main Menu" \
            --menu "Choose an option:" 20 60 7 \
            1 "View Dormant Reports" \
            2 "Set Account Expiry" \
            3 "Create User Account" \
            4 "Update User Email" \
            5 "Exit" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) view_reports ;;
            2) set_expiry ;;
            3) create_user ;;
            4) update_email ;;
            5) clear; break ;;
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
    while true; do
        dialog --cancel-label "Back" --inputbox "Enter new username:" 8 40 2> "$TMPFILE"
        if [ $? -ne 0 ]; then return; fi
        newuser=$(<"$TMPFILE")

        if id "$newuser" &>/dev/null; then
            dialog --msgbox "User '$newuser' already exists." 8 40
            continue
        fi

        dialog --cancel-label "Back" --inputbox "Enter email for $newuser:" 8 60 2> "$TMPFILE"
        if [ $? -ne 0 ]; then continue; fi
        useremail=$(<"$TMPFILE")

        dialog --cancel-label "Back" --insecure --passwordbox "Enter password for $newuser:" 8 40 2> "$TMPFILE"
        if [ $? -ne 0 ]; then continue; fi
        password=$(<"$TMPFILE")

        dialog --cancel-label "Back" --insecure --passwordbox "Confirm password for $newuser:" 8 40 2> "$TMPFILE"
        if [ $? -ne 0 ]; then continue; fi
        password_confirm=$(<"$TMPFILE")

        if [ "$password" != "$password_confirm" ]; then
            dialog --msgbox "Passwords do not match. Please try again." 8 50
            continue
        fi

        dialog --cancel-label "Back" --yesno "Should $newuser have sudo (root) privileges?" 7 50
        case $? in
            0) sudo_answer="Yes" ;;
            1) sudo_answer="No" ;;
            255) continue ;; # back pressed
        esac

        homedir="/home/$newuser"

        dialog --yes-label "Confirm" --no-label "Back" --yesno "Please confirm the user details:\n\nUsername: $newuser\nEmail: $useremail\nHome Directory: $homedir\nSudo Access: $sudo_answer\n\nProceed with creating this user?" 16 60
        if [ $? -eq 0 ]; then
            sudo useradd -m "$newuser" || { dialog --msgbox "Failed to create user." 8 40; return; }
            echo "$newuser:$password" | sudo chpasswd

            if [ "$sudo_answer" = "Yes" ]; then
                sudo usermod -aG sudo "$newuser"
            fi

            if ! grep -q "^$newuser=" "$EMAIL_CONF" 2>/dev/null; then
                echo "$newuser=$useremail" | sudo tee -a "$EMAIL_CONF" > /dev/null
            else
                sudo sed -i "s/^$newuser=.*/$newuser=$useremail/" "$EMAIL_CONF"
            fi

            dialog --msgbox "User $newuser created successfully.\nEmail saved to $EMAIL_CONF." 10 60
            return
        else
            continue
        fi
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

trap "rm -f $TMPFILE" EXIT
main_menu
