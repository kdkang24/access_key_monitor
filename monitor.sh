#!/bin/bash

# This script will check the age of all access keys in an AWS account. Requires AWS CLI v1 installed.
# Human IAM users must have an Email tag (Ex: Email: kdkang24@gmail.com in their IAM user info) in order to distinguish them from service accounts.
# If a key is over 365 days old, then AWS SES will send an email notifying that user to rotate their keys.

# USAGE:
# Execute the script with the AWS environment you want to check as an argument
# Example: ./access_key_monitor.sh <ACCOUNT_PROFILE_NAME>


#IMPORTANT VARIABLES
#profile argument passed to check different environments
profile=$1
#set at 15 for testing
max_age=365

# Modify as needed:
if [[ -z $profile ]];
    then
        echo "Requires one of the following arguments: <YOUR AWS ACCOUNTS HERE>"
        echo "Example: ./access_key_monitor.sh <ACCOUNT_NAME>"
fi

#get list of all users in AWS account in a list
all_users=$(aws iam list-users --query 'Users[*].{User:UserName}' --output text --profile $profile)

#human users will need to have a tag added with their email address
#only users with an email tag will have their access keys monitored
declare -a tagged_users=()

for user in $all_users;
do
    email_tag=$(aws iam get-user --user-name $user --query 'User.Tags[?Key==`Email`]' --output text --profile $profile)
    if [[ $email_tag = "None" ]] || [[ -z $email_tag ]];
        then
            continue
        else
            tagged_users+=($user)
    fi
done

echo "tagged users: ${tagged_users[@]}"

#check each user for active access keys
for person in ${tagged_users[@]}; 
do
    access_key=$(aws iam list-access-keys --user-name $person --query 'AccessKeyMetadata[?Status==`Active`]' --output text --profile $profile)
    #skip if no access key is active
    if [[ $access_key = "" ]];
        then
            continue
        else
            #filter for creation date only
            creation_date=$(echo ${access_key} | cut -f 2 -d ' ' | cut -b 1-10 )
            #convert to epoch time
            creation_time=$(date +%s --date ${creation_date})
            #get current time
            now=$(date +%s)
            #get difference
            difference=$(($now-$creation_time))
            #convert seconds to days
            age_in_days=$((difference/(3600*24))
            #checks age of key
            if [[ $age_in_days -gt $max_age ]];
                then
                    echo "User ${person} has old access key: ${age_in_days} days"
                    #Get email address associated with IAM user
                    email=$(aws iam get-user --user-name ${person} --query 'User.Tags[?Key==`Email`]' --output text --profile $profile | cut -f 2)
                    echo ${email}
                    #Get AWS account ID number
                    AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --profile $profile | tr -d \")
                    #Substitute user and AWS account ID variables in email message - message.json file must exist
                    sed -e 's/%USER%/'$person'/' -e 's/%ACCOUNT%/'$AWS_ACCOUNT'/' -e 's/%NAME%/'$profile'/' message.json > custom_message.json
                    #Send email to user via Amazon SES
                    #Update with your email
                    aws ses send-email --from <YOUR_EMAIL_HERE> --cc <YOUR_EMAIL_HERE> --to ${email} --message file://custom_message.json --region us-east-1
            fi
    fi
done
