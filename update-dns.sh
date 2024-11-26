#!/bin/bash

# A bash script to update a Cloudflare DNS A record with the external IP of the source machine
# Used to provide DDNS service for my home
# Needs the DNS record pre-creating on Cloudflare

# Proxy - uncomment and provide details if using a proxy
#export https_proxy=http://<proxyuser>:<proxypassword>@<proxyip>:<proxyport>

# Default values
default_zone="example.com"
default_dns_record="www.example.com"

# Parse command line arguments
while getopts "z:d:e:k:" opt; do
    case $opt in
        z) zone_name=$OPTARG ;;
        d) dns_record=$OPTARG ;;
        e) cloudflare_auth_email=$OPTARG ;;
        k) api_token=$OPTARG ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    esac
done

# Use default values if arguments are not provided
zone_name=${zone_name:-$default_zone}
dns_record=${dns_record:-$default_dns_record}

# Check if all required arguments are provided
if [ -z "$zone_name" ] || [ -z "$dns_record" ] || [ -z "$cloudflare_auth_email" ] || [ -z "$api_token" ]; then
    echo "Usage: $0 -z <zone_name> -d <dns_record> -e <cloudflare_auth_email> -k <cloudflare_api_token>"
    exit 1
fi

echo "Updating $dns_record in $zone_name"

# Cloudflare zone_name is the zone_name which holds the record
# zone_name=example.com
# dns_record is the A record which will be updated
# dns_record=www.example.com

## Cloudflare authentication details
## keep these private
# cloudflare_auth_email=me@cloudflare.com
# api_token=1234567890abcdef1234567890abcdef


set -e

user_id=$(curl -s \
	-X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
	-H "Authorization: Bearer $api_token" \
	-H "Content-Type:application/json" \
	| jq -r '{"result"}[] | .id')

echo "User id: $user_id"

zone_id=$(curl -s \
	-X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name&status=active" \
	-H "Content-Type: application/json" \
	-H "X-Auth-Email: $cloudflare_auth_email" \
	-H "Authorization: Bearer $api_token" \
	| jq -r '{"result"}[] | .[0] | .id')

echo "Zone id: $zone_id"

record_data=$(curl -s \
	-X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$dns_record"  \
	-H "Content-Type: application/json" \
	-H "X-Auth-Email: $cloudflare_auth_email" \
	-H "Authorization: Bearer $api_token")

record_id=$(jq -r '{"result"}[] | .[0] | .id' <<< $record_data)
OLD_IP=$(jq -r '{"result"}[] | .[0] | .content' <<< $record_data)
PUBLIC_IP=$(curl -s -X GET -4 https://ifconfig.me)

echo "Old IP: $OLD_IP"
echo "Public IP: $PUBLIC_IP"

if [[ $OLD_IP != $PUBLIC_IP ]]; then
	result=$(curl -s \
		-X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
		-H "Content-Type: application/json" \
		-H "X-Auth-Email: $cloudflare_auth_email" \
		-H "Authorization: Bearer $api_token" \
		--data "{\"type\":\"A\",\"name\":\"$dns_record\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":false}" \
		| jq .success)
	if [[ $result == "true" ]]; then
		echo "$dns_record updated to: $PUBLIC_IP"
		exit 0
	else
		echo "$dns_record update failed"
		exit 1
	fi
else
	echo "$dns_record already up do date"
	exit 0
fi