# 🧪 MUnit Testing Guide

## Overview

This guide covers running MUnit tests for the Mule Trading application, including coverage reporting, adding new tests, and troubleshooting.

## 🏃‍♂️ Running MUnit Tests Locally

### Prerequisites
```bash
# Ensure required tools are installed
java -version          # OpenJDK 17+
mvn --version         # Maven 3.9+
psql --version        # PostgreSQL 15+ (for integration tests)
```

### Basic Test Execution

#### Run All MUnit Tests
```bash
# Set environment variables
export DB_PASSWORD="postgres123"
export MULE_ENV="test"

# Run all MUnit tests with coverage
mvn clean test -Dmule.env=test

# Run tests without coverage (faster)
mvn clean test -Dmule.env=test -Dcoverage.skip=true
```

#### Run Specific Test Suite
```bash
# Run only demoFlow tests
mvn test -Dtest=**/munit/demoFlow-test*

# Run specific test method
mvn test -Dtest=demoFlow-test#test-demoFlow-success-nvda-data
```

#### Skip Tests During Build
```bash
# Build without running tests
mvn clean package -DskipTests=true -Dmule.env=dev
```

### Environment-Specific Testing

#### Development Environment
```bash
export DB_PASSWORD="postgres123"
export MULE_ENV="dev"
mvn test -Dmule.env=dev
```

#### CI/CD Environment
```bash
# Jenkins will set these automatically
export DB_PASSWORD="${JENKINS_DB_PASSWORD}"
export MULE_ENV="test"
mvn test -Dmule.env=test -Dmaven.repo.local=/root/.m2/repository
```

## 📊 Coverage Reports

### Viewing Coverage Reports

#### HTML Report (Recommended)
```bash
# Run tests with coverage
mvn clean test -Dmule.env=test

# Open coverage report in browser
open target/site/munit/coverage/index.html
# OR
xdg-open target/site/munit/coverage/index.html  # Linux
```

#### JSON Report (for CI/CD)
```bash
# Coverage data is also available in JSON format
cat target/site/munit/coverage/munit-coverage.json | jq .
```

### Coverage Requirements

Current coverage thresholds (configured in `pom.xml`):
- **Line Coverage**: ≥ 80%
- **Branch Coverage**: ≥ 70%

#### Check Coverage Status
```bash
# View coverage summary
grep -A 10 "Coverage Summary" target/site/munit/coverage/index.html

# Check if build will fail due to coverage
mvn verify -Dmule.env=test
```

#### Bypass Coverage Temporarily (Development Only)
```bash
# Skip coverage enforcement (NOT recommended for CI/CD)
mvn test -Dmule.env=test -Dcoverage.failBuild=false
```

## ✅ Test Results

### Test Output Locations

```bash
# Surefire test reports (XML)
ls -la target/surefire-reports/

# MUnit HTML reports
ls -la target/site/munit/

# Coverage reports
ls -la target/site/munit/coverage/
```

### Understanding Test Results

#### Successful Test Run
```bash
# Expected output:
[INFO] Tests run: 5, Failures: 0, Errors: 0, Skipped: 0
[INFO] MUnit Coverage: Application coverage is: 85.2%
[INFO] BUILD SUCCESS
```

#### Failed Test Run
```bash
# Example failure output:
[ERROR] Tests run: 5, Failures: 1, Errors: 0, Skipped: 0
[ERROR] MUnit Coverage: Application coverage is: 65.0% - BELOW THRESHOLD (80%)
[ERROR] BUILD FAILURE
```

## 🆕 Adding New Tests

### Test File Structure

```
src/test/munit/
├── demoFlow-test.xml           # Main flow tests
├── [newFlow]-test.xml          # New flow tests
└── integration/
    └── end-to-end-test.xml     # Integration tests
```

### Creating a New Test Suite

#### 1. Create Test File
```bash
# Create new test file
touch src/test/munit/newFlow-test.xml
```

#### 2. Basic Test Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xmlns:munit="http://www.mulesoft.org/schema/mule/munit"
      xmlns:munit-tools="http://www.mulesoft.org/schema/mule/munit-tools"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/munit http://www.mulesoft.org/schema/mule/munit/current/mule-munit.xsd
        http://www.mulesoft.org/schema/mule/munit-tools http://www.mulesoft.org/schema/mule/munit-tools/current/mule-munit-tools.xsd">

    <munit:config name="newFlow-test.xml" />

    <munit:test name="test-newFlow-success" description="Test successful execution">
        <!-- Your test implementation here -->
    </munit:test>

</mule>
```

#### 3. Test Patterns

**Positive Test (Happy Path)**
```xml
<munit:test name="test-flow-success" description="Test successful execution">
    <munit:behavior>
        <!-- Mock external dependencies -->
        <munit-tools:mock-when processor="db:select">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{}]"/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>
    
    <munit:execution>
        <!-- Execute flow -->
        <flow-ref name="your-flow"/>
    </munit:execution>
    
    <munit:validation>
        <!-- Verify results -->
        <munit-tools:assert-that expression="#[payload]" is="#[MunitTools::notNullValue()]"/>
    </munit:validation>
</munit:test>
```

**Negative Test (Error Handling)**
```xml
<munit:test name="test-flow-error" description="Test error handling">
    <munit:behavior>
        <munit-tools:mock-when processor="db:select">
            <munit-tools:then-return>
                <munit-tools:error typeId="DB:CONNECTIVITY"/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>
    
    <munit:execution>
        <flow-ref name="your-flow"/>
    </munit:execution>
    
    <munit:validation>
        <munit-tools:assert-that expression="#[error.errorType.identifier]" is="#[MunitTools::equalTo('CONNECTIVITY')]"/>
    </munit:validation>
</munit:test>
```

### Best Practices for Test Development

#### Test Naming Convention
- `test-[flowName]-[scenario]-[expectedResult]`
- Examples:
  - `test-demoFlow-success-nvda-data`
  - `test-demoFlow-error-database-timeout`
  - `test-demoFlow-empty-result-graceful`

#### Mock Strategy
```xml
<!-- Mock external systems -->
<munit-tools:mock-when processor="db:select">
    <munit-tools:with-attributes>
        <munit-tools:with-attribute whereValue="Database_Config" attributeName="config-ref"/>
    </munit-tools:with-attributes>
    <munit-tools:then-return>
        <munit-tools:payload value="#[mockData]"/>
    </munit-tools:then-return>
</munit-tools:mock-when>

<!-- Mock HTTP requests -->
<munit-tools:mock-when processor="http:request">
    <munit-tools:with-attributes>
        <munit-tools:with-attribute whereValue="/api/data" attributeName="path"/>
    </munit-tools:with-attributes>
    <munit-tools:then-return>
        <munit-tools:payload value="#[{status: 'success'}]"/>
    </munit-tools:then-return>
</munit-tools:mock-when>
```

#### Assertion Examples
```xml
<!-- Basic assertions -->
<munit-tools:assert-equals actual="#[payload.status]" expected="#['success']"/>
<munit-tools:assert-that expression="#[payload]" is="#[MunitTools::notNullValue()]"/>
<munit-tools:assert-that expression="#[sizeOf(payload)]" is="#[MunitTools::greaterThan(0)]"/>

<!-- Type assertions -->
<munit-tools:assert-that expression="#[payload.price]" is="#[MunitTools::instanceOf('java.lang.String')]"/>

<!-- Regex assertions -->
<munit-tools:assert-that expression="#[payload.symbol]" is="#[MunitTools::matchesRegex('^[A-Z]{3,5}$')]"/>

<!-- Collection assertions -->
<munit-tools:assert-that expression="#[payload]" is="#[MunitTools::hasSize(10)]"/>
<munit-tools:assert-that expression="#[payload[0].symbol]" is="#[MunitTools::equalTo('NVDA')]"/>
```

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. **Tests Not Found**
```bash
# Symptoms: "No tests were executed"
# Solution: Check test file location and naming
ls -la src/test/munit/
mvn test -X  # Debug mode to see test discovery
```

#### 2. **Coverage Too Low**
```bash
# Symptoms: "Coverage is below threshold"
# Check current coverage
mvn test -Dmule.env=test
open target/site/munit/coverage/index.html

# Add more tests for uncovered flows/branches
# OR temporarily lower threshold in pom.xml (not recommended)
```

#### 3. **Database Connection Issues**
```bash
# Symptoms: "Cannot connect to database during tests"
# Solution: Use mocks instead of real database
# MUnit tests should mock db:select, not connect to real DB
```

#### 4. **Environment Variable Issues**
```bash
# Symptoms: "Property ${env:DB_PASSWORD} not resolved"
# Solution: Set environment variables before running tests
export DB_PASSWORD="postgres123"
export MULE_ENV="test"
mvn test -Dmule.env=test
```

#### 5. **Maven Build Issues**
```bash
# Symptoms: "Plugin execution not covered"
# Solution: Clean and rebuild
mvn clean compile test -Dmule.env=test

# Check for conflicting dependencies
mvn dependency:tree | grep -i munit
```

#### 6. **Test Timeout Issues**
```bash
# Symptoms: Tests hang or timeout
# Solution: Add timeouts to HTTP requests in tests
# OR increase timeout in pom.xml MUnit plugin config
```

### Debug Mode

#### Enable Debug Logging
```bash
# Run tests with debug output
mvn test -Dmule.env=test -X -Dmule.verbose.exceptions=true

# Enable MUnit debug logs
mvn test -Dmule.env=test -Dmunit.enableDebugMode=true
```

#### View Test Execution Details
```bash
# Detailed test output
mvn test -Dmule.env=test -Dmunit.test.verbose=true

# Print test execution time
mvn test -Dmule.env=test -Dmunit.printTestExecutionTime=true
```

### Performance Testing

#### Test Execution Time
```bash
# Measure test performance
time mvn test -Dmule.env=test

# Profile memory usage
mvn test -Dmule.env=test -Dmaven.surefire.jvmArgs="-XX:+PrintGCDetails -XX:+PrintGCTimeStamps"
```

## 📈 Coverage Goals & Metrics

### Current Test Coverage

| Component | Coverage | Target | Status |
|-----------|----------|--------|--------|
| demoFlow | 95% | 80% | ✅ |
| Error Handlers | 85% | 70% | ✅ |
| Transformations | 90% | 80% | ✅ |
| **Overall** | **85%** | **80%** | ✅ |

### Improving Coverage

#### Identify Uncovered Code
```bash
# Run coverage analysis
mvn test -Dmule.env=test

# Check coverage report for red/uncovered lines
open target/site/munit/coverage/index.html
```

#### Coverage Strategy
1. **Flow Coverage**: Test main happy path + 1-2 error scenarios
2. **Branch Coverage**: Test all conditional logic paths
3. **Error Handling**: Test exception scenarios
4. **Integration Points**: Mock and test external dependencies

## 🚀 Integration with CI/CD

### Jenkins Integration

The MUnit tests are automatically executed in the Jenkins pipeline:

```groovy
stage('MUnit Tests') {
    steps {
        sh 'mvn clean test -Dmule.env=test'
    }
    post {
        always {
            publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
            publishHTML([
                reportDir: 'target/site/munit/coverage',
                reportFiles: 'index.html',
                reportName: 'MUnit Coverage Report'
            ])
        }
    }
}
```

### Coverage Gate

The pipeline will **FAIL** if:
- Any test fails
- Line coverage < 80%
- Branch coverage < 70%

This ensures code quality and prevents deployment of untested code.

## 📝 Quick Reference

### Essential Commands
```bash
# Run all tests with coverage
mvn clean test -Dmule.env=test

# Run specific test
mvn test -Dtest=demoFlow-test

# Skip tests
mvn package -DskipTests=true

# View coverage report
open target/site/munit/coverage/index.html

# Debug mode
mvn test -X -Dmule.env=test
```

### File Locations
- **Test Files**: `src/test/munit/*.xml`
- **Test Results**: `target/surefire-reports/`
- **Coverage Reports**: `target/site/munit/coverage/`
- **Configuration**: `pom.xml` (MUnit plugin section)

---

**Need help?** Contact the development team or check the [MUnit documentation](https://docs.mulesoft.com/munit/latest/).
