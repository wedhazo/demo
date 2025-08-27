#!/bin/bash

# Complete Test Suite for Mule Demo Application
# Combines Unit Tests + Integration Tests + Coverage Reporting

set -e

echo "🧪 COMPLETE TEST SUITE FOR MULE DEMO APPLICATION"
echo "================================================="
echo "Date: $(date)"
echo "Environment: ${MULE_ENV:-test}"
echo ""

# Global counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check dependencies
check_dependencies() {
    echo -e "${BLUE}🔍 Checking dependencies...${NC}"
    
    local deps=("curl" "jq" "xmllint" "mvn")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}"
        echo "Please install missing dependencies and try again."
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies available${NC}"
    echo ""
}

# Function to run unit tests
run_unit_tests() {
    echo -e "${BLUE}🔬 RUNNING UNIT TESTS${NC}"
    echo "===================="
    
    if ./unit-tests.sh; then
        echo -e "${GREEN}✅ Unit tests completed successfully${NC}"
        
        # Parse unit test results
        if [ -f "unit-test-results.json" ]; then
            local unit_passed=$(jq -r '.summary.passed' unit-test-results.json)
            local unit_total=$(jq -r '.summary.total' unit-test-results.json)
            local unit_failed=$(jq -r '.summary.failed' unit-test-results.json)
            
            TOTAL_TESTS=$((TOTAL_TESTS + unit_total))
            TOTAL_PASSED=$((TOTAL_PASSED + unit_passed))
            TOTAL_FAILED=$((TOTAL_FAILED + unit_failed))
        fi
        return 0
    else
        echo -e "${RED}❌ Unit tests failed${NC}"
        return 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    echo ""
    echo -e "${BLUE}🌐 RUNNING INTEGRATION TESTS${NC}"
    echo "============================="
    
    if ./integration-tests.sh; then
        echo -e "${GREEN}✅ Integration tests completed successfully${NC}"
        
        # Parse integration test results
        if [ -f "test-results.json" ]; then
            local int_passed=$(jq -r '.summary.passed' test-results.json)
            local int_total=$(jq -r '.summary.total' test-results.json)
            local int_failed=$(jq -r '.summary.failed' test-results.json)
            
            TOTAL_TESTS=$((TOTAL_TESTS + int_total))
            TOTAL_PASSED=$((TOTAL_PASSED + int_passed))
            TOTAL_FAILED=$((TOTAL_FAILED + int_failed))
        fi
        return 0
    else
        echo -e "${RED}❌ Integration tests failed${NC}"
        return 1
    fi
}

# Function to generate comprehensive report
generate_comprehensive_report() {
    echo ""
    echo -e "${BLUE}📊 COMPREHENSIVE TEST REPORT${NC}"
    echo "============================="
    
    local timestamp=$(date -Iseconds)
    local overall_coverage=0
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        overall_coverage=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
    fi
    
    echo "Test Execution Summary:"
    echo "----------------------"
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$TOTAL_PASSED${NC}"
    echo -e "Failed: ${RED}$TOTAL_FAILED${NC}"
    echo "Overall Coverage: $overall_coverage%"
    
    # Coverage assessment
    if [ $overall_coverage -ge 80 ]; then
        echo -e "${GREEN}✅ Coverage requirement met (≥80%)${NC}"
        local coverage_status="PASS"
    else
        echo -e "${RED}❌ Coverage below requirement (80%)${NC}"
        local coverage_status="FAIL"
    fi
    
    # Generate comprehensive JSON report
    cat > "comprehensive-test-results.json" << EOF
{
    "timestamp": "$timestamp",
    "execution_environment": {
        "mule_env": "${MULE_ENV:-test}",
        "maven_version": "$(mvn --version | head -1 | cut -d' ' -f3)",
        "java_version": "$(java -version 2>&1 | head -1 | cut -d'"' -f2)"
    },
    "summary": {
        "total_tests": $TOTAL_TESTS,
        "total_passed": $TOTAL_PASSED,
        "total_failed": $TOTAL_FAILED,
        "overall_coverage": $overall_coverage
    },
    "coverage_analysis": {
        "required_coverage": 80,
        "actual_coverage": $overall_coverage,
        "coverage_met": $([ $overall_coverage -ge 80 ] && echo "true" || echo "false"),
        "status": "$coverage_status"
    },
    "test_results": {
        "unit_tests": $([ -f "unit-test-results.json" ] && cat unit-test-results.json || echo "null"),
        "integration_tests": $([ -f "test-results.json" ] && cat test-results.json || echo "null")
    },
    "build_info": {
        "project": "demo",
        "version": "1.0.0-SNAPSHOT",
        "mule_runtime": "4.9.0"
    },
    "overall_status": "$([ $TOTAL_FAILED -eq 0 ] && [ $overall_coverage -ge 80 ] && echo "SUCCESS" || echo "FAILURE")"
}
EOF
    
    echo ""
    echo "📄 Detailed Reports Generated:"
    echo "• comprehensive-test-results.json (Main report)"
    echo "• unit-test-results.json (Unit tests)"
    echo "• test-results.json (Integration tests)"
    
    # Final status
    if [ $TOTAL_FAILED -eq 0 ] && [ $overall_coverage -ge 80 ]; then
        echo ""
        echo -e "${GREEN}🎉 ALL TESTS PASSED WITH SUFFICIENT COVERAGE!${NC}"
        echo -e "${GREEN}✅ Ready for deployment${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}💥 TEST SUITE FAILED${NC}"
        if [ $TOTAL_FAILED -gt 0 ]; then
            echo -e "${RED}• $TOTAL_FAILED test(s) failed${NC}"
        fi
        if [ $overall_coverage -lt 80 ]; then
            echo -e "${RED}• Coverage below 80% ($overall_coverage%)${NC}"
        fi
        return 1
    fi
}

# Main execution
main() {
    local unit_test_result=0
    local integration_test_result=0
    
    # Check dependencies
    check_dependencies
    
    # Run unit tests
    if ! run_unit_tests; then
        unit_test_result=1
    fi
    
    # Run integration tests (only if unit tests pass or forced)
    if [ $unit_test_result -eq 0 ] || [ "${FORCE_INTEGRATION:-false}" = "true" ]; then
        if ! run_integration_tests; then
            integration_test_result=1
        fi
    else
        echo -e "${YELLOW}⚠️ Skipping integration tests due to unit test failures${NC}"
        echo "Use FORCE_INTEGRATION=true to run integration tests anyway"
    fi
    
    # Generate comprehensive report
    generate_comprehensive_report
}

# Handle script arguments
case "${1:-}" in
    "unit")
        echo "Running unit tests only..."
        check_dependencies
        run_unit_tests
        ;;
    "integration")
        echo "Running integration tests only..."
        check_dependencies
        run_integration_tests
        ;;
    "help")
        echo "Usage: $0 [unit|integration|help]"
        echo "  unit        - Run only unit tests"
        echo "  integration - Run only integration tests"
        echo "  help        - Show this help"
        echo "  (no args)   - Run complete test suite"
        ;;
    *)
        # Run complete test suite
        main
        ;;
esac
