#!/bin/bash

###############################################################################
# Function to ask if the user wants to keep their DIG Node updated
###############################################################################
setup_auto_update() {
    echo -e "${YELLOW}Would you like to automatically keep your DIG Node updated?${NC}"
    echo -e "This will create a cron job to run './upgrade-node' once a day."
    echo -n "Do you want to set up automatic updates? (y/n): "
    read -r response

    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        echo -e "${GREEN}Setting up automatic updates...${NC}"

        # Ensure the upgrade-node script is executable
        sudo chmod +x ./upgrade-node

        # Create a cron job to run the upgrade-node script once a day
        cron_job="@daily cd $(pwd) && sudo ./upgrade-node"

        # Add the cron job to the root user's cron
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

        echo -e "${GREEN}Automatic updates have been set up successfully!${NC}"
        echo -e "Your DIG Node will be updated daily at midnight."
    else
        echo -e "${YELLOW}Automatic updates skipped.${NC}"
    fi
}
