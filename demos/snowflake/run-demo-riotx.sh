#!/bin/bash

# Demo Script for RIOTX - Snowflake to Redis Integration
# This script walks through the RIOTX portions of the demo

# Load environment variables
if [ ! -f ".env" ]; then
    echo "Error: .env file not found!"
    echo "Please copy .env.example to .env and configure your values."
    exit 1
fi

set -a  # automatically export all variables
source .env
set +a

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Redis host will be loaded from .env file

# Clear terminal and show realistic prompt
clear

wait_for_enter() {
    # echo -e "${DIM}Press ENTER to continue...${NC}"
    read
}

type_command() {
    local cmd="$1"
    echo -e "${DIM}\$ ${NC}${cmd}"
}

echo -e "${GREEN}jeremy@macbook${NC}:${BLUE}~/work/snowflake-demo${NC}\$ ./run-demo-riotx.sh"
echo

echo -e "${GREEN}SETUP PHASE - Redis Database Cleanup${NC}"
echo -e "Would you like to flush the Redis database before starting? (y/n)"
read -p "Enter choice: " flush_choice

if [[ $flush_choice =~ ^[Yy]$ ]]; then
    echo "Flushing Redis database..."
    type_command "redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' flushdb"
    #redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' flushdb
    redis-cli flushdb
    echo -e "${GREEN}Redis database flushed successfully${NC}"
else
    echo "Skipping Redis flush"
fi
echo

clear

echo -e "${GREEN}SETUP PHASE - Environment Verification${NC}"
echo "About to verify that riotx and Redis are accessible"
wait_for_enter

#echo "Checking riotx installation..."
#type_command "which riotx"
#which riotx
#echo

echo "Testing Redis connection..."
#type_command "redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' ping"
type_command "redis-cli ping"
#redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' ping
redis-cli ping
echo

echo -e "${GREEN}PHASE 1 - Initial Data Sync${NC}"
echo "About to start the main RIOTX sync process"
echo "This will:"
echo "  - Connect to Snowflake table tb_101.raw_pos.incremental_order_header"
echo "  - Set up CDC stream in raw_pos_cdc schema"
echo "  - Start syncing data to Redis as 'orders:{ORDER_ID}' hashes"
echo "  - Monitor for real-time changes"
echo
echo -e "${RED}NOTE: This will run continuously until you stop it with Ctrl+C${NC}"

type_command "riotx snowflake-import \\"
#echo -e "${DIM}  -h $REDIS_HOST \\"
#echo -e "${DIM}  -p 12001 \\"
#echo -e "${DIM}  -a '$REDIS_PASS' \\"
echo -e "${DIM}   -h $REDIS_HOST \\"
echo -e "${DIM}   -p $REDIS_PORT \\"
echo -e "${DIM}  $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE \\"
echo -e "${DIM}  --cdc-schema $SNOWFLAKE_CDC_SCHEMA \\"
echo -e "${DIM}  --role $SNOWFLAKE_ROLE \\"
echo -e "${DIM}  --warehouse $SNOWFLAKE_WAREHOUSE \\"
echo -e "${DIM}  --jdbc-url 'jdbc:snowflake://$SNOWFLAKE_ACCOUNT.snowflakecomputing.com?private_key_file=$SNOWFLAKE_PRIVATE_KEY_FILE' \\"
echo -e "${DIM}  --jdbc-user $SNOWFLAKE_USER \\"
echo -e "${DIM}  hset 'orders:#{ORDER_ID}'${NC}"
echo

wait_for_enter

riotx snowflake-import \
  -h $REDIS_HOST \
  -p $REDIS_PORT \
  $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE \
  --cdc-schema $SNOWFLAKE_CDC_SCHEMA \
  --role $SNOWFLAKE_ROLE \
  --warehouse $SNOWFLAKE_WAREHOUSE \
  --jdbc-url "jdbc:snowflake://$SNOWFLAKE_ACCOUNT.snowflakecomputing.com?private_key_file=$SNOWFLAKE_PRIVATE_KEY_FILE" \
  --jdbc-user $SNOWFLAKE_USER \
  hset 'orders:#{ORDER_ID}'

echo
echo -e "${GREEN}Demo Complete!${NC}"
echo "The RIOTX process has been stopped."
echo "Check Redis Insights to see the synchronized data."
echo
echo -e "${GREEN}jeremy@macbook${NC}:${BLUE}~/work/snowflake-demo${NC}\$ "
