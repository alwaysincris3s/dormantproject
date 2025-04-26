#!/bin/bash

# Load the configuration file to get the durations
source /etc/dormant.conf

# Double check if the config file has the required parameters
if [ -z "$DORMANT_USERACCOUNT_DURATION" ] || [ -z "$DORMANT_SERVICEACCOUNT_DURATION" ]; then
    echo "Error: Config file missing required parameters."
    exit 1
fi

# Duration output check
echo "Duration of User account: $DORMANT_USERACCOUNT_DURATION days"
echo "Duration of Service account: $DORMANT_SERVICEACCOUNT_DURATION days"

# Function to extract the list of user accounts
check_user_account() {
    # Extract the list of usernames with UID >= 1000 in a variable (to store it)
    user_account=$(grep '^[^:]*:[^:]*:[1-9][0-9]\{3,\}:' /etc/passwd | cut -d: -f1)
} 

#detect and see if user accounts are dormant
detect_dormant_user() {
    dormant_user=""
    no_log_user=""
    
    for user in $user_account; do
        # extract the login date
        lastlogin=$(lastlog -u "$user" | awk 'NR==2')
        
        #if the user has never logged in
        if echo "$lastlogin" | grep -q "Never logged in"; then
          
            no_log_user+="$user "

            continue
        fi

        #extract date 
        last_login_date=$(echo "$lastlogin" | awk '{print $4, $5, $6, $7}')
        
        #check valid date
        if [[ -n "$last_login_date" ]]; then
            #calculate difference
            if last_login_ts=$(date -d "$last_login_date" +%s 2>/dev/null); then
                now=$(date +%s)
                difference=$(( (now - last_login_ts) / 86400 ))
                echo "User $dormant_user last logged in on: $last_login_date ($difference days ago)"

                if [ "$difference" -eq "$DORMANT_USERACCOUNT_DURATION" ]; then
        
                    dormant_detected_user+="$user "
                fi
            else
                echo "Could not parse last login date for user $user: $last_login_date"
            fi
        else
            echo " No valid last login date for user $user."
        fi
    done
}

# Call the function to extract users
check_user_account

# Call the function to check dormant users
detect_dormant_user

# Output the list of dormant users detected
echo "Dormant users detected: $dormant_detected_user"
echo "Dormant users that never logged in: $no_log_user"
