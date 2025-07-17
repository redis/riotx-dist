#!/bin/bash

# Demo Script for Snowflake SQL - Data Changes for CDC Demo
# This script walks through the SQL portions of the demo

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

# Clear terminal and show realistic prompt
clear

wait_for_enter() {
    #echo -e "${DIM}Press ENTER to continue...${NC}"
    read
}

type_command() {
    local cmd="$1"
    echo -e "${DIM}\$ ${NC}${cmd}"
}

run_sql() {
    local description="$1"
    local sql="$2"
    
    echo -e "About to run: ${description}"
    echo -e "${BLUE}SQL Command:${NC}"
    echo "$sql"
    echo
    wait_for_enter
    
    echo "Executing..."
    type_command "snowsql -c $SNOWFLAKE_ACCOUNT -q \"$sql\""
    snowsql -c $SNOWFLAKE_ACCOUNT -q "$sql"
    echo
}

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  SQL Demo Script - Snowflake Changes${NC}"
echo -e "${BLUE}======================================${NC}"
echo

echo -e "${YELLOW}Do you want to clear the incremental table before starting the demo? (y/n)${NC}"
read -r clear_table
if [[ $clear_table == "y" || $clear_table == "Y" ]]; then
    echo -e "${GREEN}Clearing incremental table...${NC}"
    snowsql -c $SNOWFLAKE_ACCOUNT -q "DELETE FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE;"
    echo -e "${GREEN}Incremental table cleared.${NC}"
    echo
fi

clear

echo -e "${GREEN}SETUP PHASE - Environment Verification${NC}"
echo "About to verify Snowflake connection and show initial data"
wait_for_enter

echo -e "${YELLOW}Testing Snowflake connection...${NC}"
snowsql -c $SNOWFLAKE_ACCOUNT -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();"
echo

echo -e "${GREEN}PHASE 1 - Show Initial Data${NC}"
run_sql "Show current row count in incremental table" \
"SELECT COUNT(*) as CURRENT_ROWS FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE;"

#run_sql "Show sample of current data" \
#"SELECT * FROM tb_101.raw_pos.incremental_order_header LIMIT 5;"

echo -e "${GREEN}PHASE 2 - CDC Demonstration - Insert New Orders${NC}"
run_sql "Insert 2 new test orders" \
"INSERT INTO $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
(ORDER_ID, TRUCK_ID, LOCATION_ID, ORDER_TS, ORDER_CURRENCY, ORDER_AMOUNT, ORDER_TOTAL)
VALUES 
(9999001, 99, 99999, CURRENT_TIMESTAMP(), 'USD', 150.00, 150.00),
(9999002, 99, 99999, CURRENT_TIMESTAMP(), 'USD', 75.50, 75.50);"

run_sql "Verify the new orders were inserted" \
"SELECT * FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE WHERE ORDER_ID >= 9999001;"

echo -e "${YELLOW}*** Check Redis Insights now - you should see new keys: orders:9999001 and orders:9999002 ***${NC}"
wait_for_enter

echo -e "${GREEN}PHASE 3 - CDC Demonstration - Update Existing Order${NC}"
run_sql "Update order 9999001 to show CDC on updates" \
"UPDATE $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
SET ORDER_AMOUNT = 200.00, ORDER_TOTAL = 200.00 
WHERE ORDER_ID = 9999001;"

run_sql "Verify the update" \
"SELECT * FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE WHERE ORDER_ID = 9999001;"

echo -e "${YELLOW}*** Check Redis Insights now - orders:9999001 should show updated amounts ***${NC}"
wait_for_enter

echo -e "${GREEN}PHASE 4 - Bulk Insert for Scale Demo${NC}"
run_sql "Show row count in main table vs incremental table" \
"SELECT 
  (SELECT COUNT(*) FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.order_header) as MAIN_TABLE_ROWS,
  (SELECT COUNT(*) FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE) as INCREMENTAL_TABLE_ROWS;"

echo -e "${YELLOW}About to insert 1000 records from main table to incremental table${NC}"
echo -e "${RED}This will trigger bulk CDC processing - watch RIOTX terminal for batch activity${NC}"
wait_for_enter

run_sql "Insert 1000 records from main table" \
"INSERT INTO $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
SELECT * FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.order_header 
WHERE ORDER_ID NOT IN (SELECT ORDER_ID FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE)
LIMIT 1000;"

run_sql "Insert ALL the rest of the records from main table" \
"INSERT INTO $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
SELECT * FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.order_header 
WHERE ORDER_ID NOT IN (SELECT ORDER_ID FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE);"

#run_sql "Verify the bulk insert" \
#"SELECT COUNT(*) as NEW_TOTAL_ROWS FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE;"


echo -e "${GREEN}PHASE 5 - Cleanup (Optional)${NC}"
echo "About to clean up the demo data we created"
echo -e "${YELLOW}This will remove the test records we added during the demo${NC}"
wait_for_enter

#run_sql "Clean up test records" \
#"DELETE FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE WHERE ORDER_ID >= 9999001;"

#run_sql "Verify cleanup" \
#"SELECT COUNT(*) as REMAINING_ROWS FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE;"

echo
echo -e "${GREEN}Demo Complete!${NC}"
echo "All SQL demo steps have been executed."
echo "The incremental table has been returned to its original state."
