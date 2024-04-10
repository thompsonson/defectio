#!/bin/bash

# Define path to the UFW before rules file
UFW_BEFORE_RULES="/etc/ufw/before.rules"

# Define the rules to add for ESP and AH protocols
ESP_RULES="-A ufw-before-input -p esp -j ACCEPT
-A ufw-before-output -p esp -j ACCEPT
-A ufw-before-forward -p esp -j ACCEPT"

AH_RULES="-A ufw-before-input -p ah -j ACCEPT
-A ufw-before-output -p ah -j ACCEPT
-A ufw-before-forward -p ah -j ACCEPT"

add_rules_if_not_present() {
    local file_path="$1"
    local rule_set="$2"
    local rule_indicator="$3"

    if ! grep -qF "$rule_indicator" "$file_path"; then
        echo "Adding rules for $rule_indicator protocol to $file_path"
        # Backup the original file
        sudo cp "$file_path" "${file_path}.bak"
        # Find the line number of the last occurrence of 'COMMIT' and use awk to insert rules before it
        local commit_line=$(grep -n 'COMMIT' "$file_path" | tail -1 | cut -d: -f1)
        sudo awk -v n="$commit_line" -v rules="$rule_set" 'NR == n {print rules} 1' "${file_path}.bak" | sudo tee "$file_path" > /dev/null
    else
        echo "Rules for $rule_indicator protocol already configured in $file_path"
    fi
}


# Add ESP and AH rules to the UFW before rules file
add_rules_if_not_present "$UFW_BEFORE_RULES" "$ESP_RULES" "esp"
add_rules_if_not_present "$UFW_BEFORE_RULES" "$AH_RULES" "ah"

# Reload UFW to apply changes
echo "Reloading UFW to apply changes..."
sudo ufw reload
echo "Firewall configuration completed successfully."
