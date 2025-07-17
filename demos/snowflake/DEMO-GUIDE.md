# Snowflake to Redis Data Integration Demo Guide

## Overview
This demo showcases real-time data integration from Snowflake to Redis using RIOTX. The demo will demonstrate CDC (Change Data Capture) capabilities, showing how data changes in Snowflake are automatically synchronized to Redis.

## Setup Verification (Before Demo)

### 1. Environment Setup
```bash
# Copy environment template and configure your values
cp .env.example .env
# Edit .env with your actual Snowflake and Redis credentials
```

### 2. Environment Check
```bash
# Verify tools are available
which riotx
which snowsql
```

### 3. Snowflake Connection Test
```bash
# Load environment variables
source .env
snowsql -c $SNOWFLAKE_ACCOUNT -q "SELECT COUNT(*) FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE;"
```

### 4. Redis Connection Test
```bash
# Test Redis connection (should be accessible via Redis Insights GUI)
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' ping
```

## Demo Flow (3-Window Setup)

### Window 1: Snowflake Terminal
**Purpose**: Show source data and simulate changes
**Command**: `snowsql -c $SNOWFLAKE_ACCOUNT`

### Window 2: RIOTX Data Sync
**Purpose**: Run the data synchronization process
**Command**: See main command below

### Window 3: Redis Insights GUI
**Purpose**: Visualize data in Redis in real-time
**URL**: Open Redis Insights and connect to Redis cluster

## Main Demo Script

### Phase 1: Initial Data Load (5 minutes)

#### 1.1 Show Current Snowflake Data
```sql
-- In Snowflake terminal (Window 1)
USE SCHEMA $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA;
SELECT COUNT(*) FROM $SNOWFLAKE_TABLE;
SELECT * FROM $SNOWFLAKE_TABLE LIMIT 10;
```

#### 1.2 Start RIOTX Sync Process
```bash
# In RIOTX terminal (Window 2)
riotx snowflake-import \
  -h $REDIS_HOST  \
  -p $REDIS_PORT  \
  -a $REDIS_PASS \
  $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE \
  --cdc-schema $SNOWFLAKE_CDC_SCHEMA \
  --role $SNOWFLAKE_ROLE \
  --warehouse $SNOWFLAKE_WAREHOUSE \
  --jdbc-url "jdbc:snowflake://$SNOWFLAKE_ACCOUNT.snowflakecomputing.com?private_key_file=$SNOWFLAKE_PRIVATE_KEY_FILE" \
  --jdbc-user $SNOWFLAKE_USER \
  hset 'orders:#{ORDER_ID}'
```

#### 1.3 Verify Initial Data in Redis
- **In Redis Insights**: Browse to see the `orders:*` keys
- **Expected**: Hash keys for each ORDER_ID with all order details

### Phase 2: CDC Demonstration (10 minutes)

#### 2.1 Insert New Orders
```sql
-- In Snowflake terminal (Window 1)
INSERT INTO $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
(ORDER_ID, TRUCK_ID, LOCATION_ID, ORDER_TS, ORDER_CURRENCY, ORDER_AMOUNT, ORDER_TOTAL)
VALUES 
(9999001, 99, 99999, CURRENT_TIMESTAMP(), 'USD', 150.00, 150.00),
(9999002, 99, 99999, CURRENT_TIMESTAMP(), 'USD', 75.50, 75.50);

-- Verify insertion
SELECT * FROM $SNOWFLAKE_TABLE WHERE ORDER_ID >= 9999001;
```

#### 2.2 Monitor RIOTX Output
- **In RIOTX terminal**: Watch for new records being processed
- **Expected**: Log messages showing CDC events being captured and sent to Redis

#### 2.3 Verify in Redis
- **In Redis Insights**: 
  - Refresh the key browser
  - Look for new keys: `orders:9999001` and `orders:9999002`
  - Click on keys to see the hash field values

#### 2.4 Update Existing Orders
```sql
-- In Snowflake terminal (Window 1)
UPDATE $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
SET ORDER_AMOUNT = 200.00, ORDER_TOTAL = 200.00 
WHERE ORDER_ID = 9999001;

-- Verify update
SELECT * FROM $SNOWFLAKE_TABLE WHERE ORDER_ID = 9999001;
```

#### 2.5 Verify Update in Redis
- **In Redis Insights**: Check `orders:9999001` to see updated values
- **Expected**: ORDER_AMOUNT and ORDER_TOTAL fields should reflect new values

### Phase 3: Scale and Performance (5 minutes)

#### 3.1 Bulk Insert - Load More Data from Main Table
```sql
-- In Snowflake terminal (Window 1)
-- The main order_header table has 1,698,440 rows vs incremental table's 100 rows
-- Let's add 1000 more records from the main table
INSERT INTO $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE 
SELECT * FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.order_header 
WHERE ORDER_ID NOT IN (SELECT ORDER_ID FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE)
LIMIT 1000;

-- Verify the insert
SELECT COUNT(*) FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE;
```

#### 3.2 Monitor Bulk Processing
- **In RIOTX terminal**: Watch batch processing metrics
- **In Redis Insights**: Watch key count increase in real-time

## Key Demo Points to Highlight

### 1. Real-Time CDC
- Changes in Snowflake appear in Redis within seconds
- No polling - event-driven architecture
- Maintains data consistency

### 2. Scalability
- Batch processing for bulk operations
- Efficient handling of large datasets
- Minimal impact on source system

### 3. Data Structure
- Snowflake rows → Redis hashes
- Flexible key naming patterns
- Preserves all data types and relationships

### 4. Enterprise Features
- Secure connections (TLS, authentication)
- Role-based access control
- Monitoring and observability

## Troubleshooting Commands

### Check Snowflake Stream Status
```sql
-- In Snowflake terminal
SHOW STREAMS IN SCHEMA $SNOWFLAKE_CDC_SCHEMA;
```

### Redis Connection Test
```bash
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' info replication
```

### RIOTX Debug Mode
```bash
# Add --debug flag to the main command for verbose logging
riotx snowflake-import --debug [... other parameters ...]
```

## Q&A Preparation

### Common Questions:
1. **"How does CDC work?"** - Snowflake Streams capture changes, RIOTX polls streams
2. **"What's the latency?"** - Typically 1-5 seconds depending on configuration
3. **"Can it handle schema changes?"** - Yes, but requires restart for new columns
4. **"What about failover?"** - Redis Enterprise provides high availability
5. **"Cost implications?"** - Snowflake compute costs, Redis memory usage

### Demo Recovery:
- If RIOTX fails: Restart the command (it will resume from last position)
- If Redis connection fails: Check Redis Insights connection settings
- If Snowflake fails: Verify network connectivity and credentials

## Post-Demo Cleanup

```sql
-- Optional: Clean up demo data
DELETE FROM $SNOWFLAKE_DATABASE.$SNOWFLAKE_SCHEMA.$SNOWFLAKE_TABLE WHERE ORDER_ID >= 9999001;
```

```bash
# Optional: Clean up Redis keys
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' --scan --pattern "orders:9999*" | xargs redis-cli -h $REDIS_HOST -p $REDIS_PORT -a '$REDIS_PASS' del
```

## Success Metrics
- [ ] Data appears in Redis within 5 seconds of Snowflake changes
- [ ] All 3 windows show synchronized activity
- [ ] Bulk operations process smoothly
- [ ] Q&A handled confidently
- [ ] Audience understands the value proposition

---

**Remember**: Take your time, breathe, and focus on the story: "Real-time data integration made simple with Snowflake and Redis."
