#!/bin/bash

# Insert here: YOUR_SUBDOMAIN your actual Zendesk subdomain (ref https://your_subdomain.zendesk.com) 
SUBDOMAIN="YOUR_SUBDOMAIN"
API_URL="https://$SUBDOMAIN.zendesk.com/api/v2/requests.json"

# Prompt for email, subject and body
echo "Enter your email:"
read email
echo "Enter feedback subject:"
read subject
echo "Enter feedback body:"
read body

# Construct the JSON payload
json_payload=$(cat <<EOF
{
  "request": {
    "requester": {
      "name": "Customer",
      "email": "$email"
    },
    "subject": "$subject",
    "comment": {
      "body": "$body"
    }
  }
}
EOF
)

# Send the request using curl
response=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$json_payload")

# Check if the request was successful
if echo "$response" | grep -q '"id":'; then
  echo "Feedback submitted successfully!"
  ticket_id=$(echo "$response" | grep -o '"id":[0-9]*' | cut -d':' -f2)
  echo "Ticket ID: $ticket_id"
else
  echo "Error submitting feedback:"
  echo "$response"
fi