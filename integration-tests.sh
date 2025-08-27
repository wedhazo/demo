#!/bin/bash

# Integration Test Script for Mule Demo Application
# Tests the actual HTTP endpoints without MUnit dependency issues

set -e

echo "🧪 STARTING INTEGRATION TESTS FOR MULE DEMO APPLICATION"
echo "======================================================="

# Configuration
BASE_URL="http://localhost:8081"
DB_PASSWORD="beriha@123KB!"
TEST_RESULTS_FILE="test-results.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to log test results
log_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name - $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name - $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to make HTTP request and check response
test_http_endpoint() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local expected_content="$4"
    
    echo -e "${YELLOW}Testing:${NC} $test_name"
    
    # Make HTTP request
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$url" 2>/dev/null || echo "HTTPSTATUS:000")
    
    # Extract HTTP status and body
    http_status=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    # Check HTTP status
    if [ "$http_status" = "$expected_status" ]; then
        if [ -n "$expected_content" ]; then
            # Check if response contains expected content
            if echo "$body" | grep -q "$expected_content"; then
                log_test "$test_name" "PASS" "Status: $http_status, Content: Found '$expected_content'"
            else
                log_test "$test_name" "FAIL" "Status: $http_status, Content: Expected '$expected_content' not found in response"
            fi
        else
            log_test "$test_name" "PASS" "Status: $http_status"
        fi
    else
        log_test "$test_name" "FAIL" "Expected status: $expected_status, Got: $http_status"
    fi
}

# Function to check if application is running
check_application_health() {
    echo -e "${YELLOW}Checking application health...${NC}"
    
    # Wait for application to start (max 30 seconds)
    for i in {1..30}; do
        if curl -s "$BASE_URL/kb" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Application is running${NC}"
            return 0
        fi
        echo "Waiting for application to start... ($i/30)"
        sleep 1
    done
    
    echo -e "${RED}❌ Application failed to start within 30 seconds${NC}"
    return 1
}

# Start the application if not running
start_application() {
    echo -e "${YELLOW}Starting Mule application...${NC}"
    
    # Check if already running
    if curl -s "$BASE_URL/kb" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Application already running${NC}"
        return 0
    fi
    
    # Start application in background
    export DB_PASSWORD="$DB_PASSWORD"
    export mule.env=test
    
    # Use nohup to run in background
    nohup mvn mule:run -Dmule.env=test > mule-app.log 2>&1 &
    APP_PID=$!
    
    echo "Application starting with PID: $APP_PID"
    
    # Wait for it to start
    if check_application_health; then
        return 0
    else
        # Kill the process if it failed to start
        kill $APP_PID 2>/dev/null || true
        return 1
    fi
}

# Run the tests
run_tests() {
    echo -e "${YELLOW}Running Integration Tests...${NC}"
    echo ""
    
    # Test 1: Health Check
    test_http_endpoint "Health Check" "$BASE_URL/kb" "200" "NVDA"
    
    # Test 2: Invalid Path
    test_http_endpoint "Invalid Path" "$BASE_URL/invalid" "404" ""
    
    # Test 3: Check JSON Response Structure
    echo -e "${YELLOW}Testing:${NC} JSON Response Structure"
    response=$(curl -s "$BASE_URL/kb" 2>/dev/null || echo "")
    if echo "$response" | jq empty 2>/dev/null; then
        if echo "$response" | jq -e 'type == "array"' >/dev/null 2>&1; then
            log_test "JSON Response Structure" "PASS" "Valid JSON array returned"
        else
            log_test "JSON Response Structure" "FAIL" "Response is not a JSON array"
        fi
    else
        log_test "JSON Response Structure" "FAIL" "Invalid JSON response"
    fi
    
    # Test 4: Database Connectivity
    echo -e "${YELLOW}Testing:${NC} Database Connectivity"
    response=$(curl -s "$BASE_URL/kb" 2>/dev/null || echo "")
    if [ -n "$response" ] && [ "$response" != "[]" ] && [ "$response" != "null" ]; then
        log_test "Database Connectivity" "PASS" "Database returned data"
    else
        log_test "Database Connectivity" "FAIL" "No data returned from database"
    fi
    
    # Test 5: Response Time
    echo -e "${YELLOW}Testing:${NC} Response Time"
    start_time=$(date +%s%N)
    curl -s "$BASE_URL/kb" >/dev/null 2>&1
    end_time=$(date +%s%N)
    response_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [ $response_time -lt 5000 ]; then # Less than 5 seconds
        log_test "Response Time" "PASS" "Response time: ${response_time}ms"
    else
        log_test "Response Time" "FAIL" "Response time too slow: ${response_time}ms"
    fi
}

# Generate test report
generate_report() {
    echo ""
    echo "📊 TEST SUMMARY"
    echo "==============="
    echo "Total Tests: $TESTS_TOTAL"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    # Calculate coverage percentage
    if [ $TESTS_TOTAL -gt 0 ]; then
        coverage=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        echo "Coverage: $coverage%"
        
        # Generate JSON report
        cat > "$TEST_RESULTS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "summary": {
        "total": $TESTS_TOTAL,
        "passed": $TESTS_PASSED,
        "failed": $TESTS_FAILED,
        "coverage": $coverage
    },
    "status": "$([ $TESTS_FAILED -eq 0 ] && echo "SUCCESS" || echo "FAILURE")"
}
EOF
        
        echo "Test results saved to: $TEST_RESULTS_FILE"
    fi
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        exit 0
    else
        echo -e "${RED}💥 SOME TESTS FAILED!${NC}"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    if [ -n "$APP_PID" ]; then
        kill $APP_PID 2>/dev/null || true
        echo "Application stopped"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
main() {
    echo "🚀 Starting integration test suite..."
    
    # Check dependencies
    command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed"; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed"; exit 1; }
    
    # Start application if needed
    if ! start_application; then
        echo -e "${RED}❌ Failed to start application${NC}"
        exit 1
    fi
    
    # Run tests
    run_tests
    
    # Generate report
    generate_report
}

# Run main function
main "$@"
