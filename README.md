# access_key_monitor

# This script will check the age of all access keys in an AWS account. Requires AWS CLI v1 installed.
# Human IAM users must have an Email tag (Ex: Email: kdkang24@gmail.com in their IAM user info) in order to distinguish them from service accounts.
# If a key is over 365 days old, then AWS SES will send an email notifying that user to rotate their keys.

# USAGE:
# Execute the script with the AWS environment you want to check as an argument
# Example: ./access_key_monitor.sh <ACCOUNT_PROFILE_NAME>
