#!/usr/bin/env bash

###############################################################################
# Validation script to check nf-test structure
# Usage: ./TESTS/validate-test-structure.sh
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    nf-test Structure Validation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function to check file exists
check_file() {
    local file=$1
    local description=$2
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file ${RED}(missing)${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local description=$2
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: $dir"
        return 0
    else
        echo -e "${RED}✗${NC} $description: $dir ${RED}(missing)${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if file contains pattern
check_pattern() {
    local file=$1
    local pattern=$2
    local description=$3
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} $description ${YELLOW}(not found)${NC}"
        ((WARNINGS++))
        return 1
    fi
}

echo -e "${BLUE}1. Configuration Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_file "nf-test.config" "Global nf-test config"
check_file "TESTS/nextflow.config" "Test-specific config"
check_file "TESTS/run-tests.sh" "Test runner script"
check_file "TESTS/README.md" "Test documentation"
check_file "TESTS/TEST_COVERAGE.md" "Test coverage documentation"
echo ""

echo -e "${BLUE}2. Test Data${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_dir "TESTS/TEST_DATA" "Test data directory"
check_file "TESTS/TEST_DATA/test.fastq.gz" "Test FASTQ file"
check_file "TESTS/TEST_DATA/test.gfa" "Test GFA file"
echo ""

echo -e "${BLUE}3. Module Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# HIFIASM
echo -e "${YELLOW}HIFIASM Module:${NC}"
check_file "modules/nf-core/hifiasm/main.nf" "Module definition"
check_file "modules/nf-core/hifiasm/tests/main.nf.test" "Test file"
check_file "modules/nf-core/hifiasm/tests/nextflow.config" "Test config"
if [ -f "modules/nf-core/hifiasm/tests/main.nf.test" ]; then
    check_pattern "modules/nf-core/hifiasm/tests/main.nf.test" "tag \"hifiasm\"" "Has hifiasm tag"
    check_pattern "modules/nf-core/hifiasm/tests/main.nf.test" "test.*basic assembly" "Has basic assembly test"
    check_pattern "modules/nf-core/hifiasm/tests/main.nf.test" "stub" "Has stub test"
fi
echo ""

# GFA2FA
echo -e "${YELLOW}GFA2FA Module:${NC}"
check_file "modules/local/gfa2fa/main.nf" "Module definition"
check_file "modules/local/gfa2fa/tests/main.nf.test" "Test file"
check_file "modules/local/gfa2fa/tests/nextflow.config" "Test config"
if [ -f "modules/local/gfa2fa/tests/main.nf.test" ]; then
    check_pattern "modules/local/gfa2fa/tests/main.nf.test" "tag \"gfa2fa\"" "Has gfa2fa tag"
    check_pattern "modules/local/gfa2fa/tests/main.nf.test" "test.*convert gfa to fasta" "Has conversion test"
    check_pattern "modules/local/gfa2fa/tests/main.nf.test" "stub" "Has stub test"
fi
echo ""

# MULTIQC
echo -e "${YELLOW}MULTIQC Module:${NC}"
check_file "modules/nf-core/multiqc/main.nf" "Module definition"
check_file "modules/nf-core/multiqc/tests/main.nf.test" "Test file"
echo ""

echo -e "${BLUE}4. Subworkflow Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ASSEMBLY
echo -e "${YELLOW}ASSEMBLY Subworkflow:${NC}"
check_file "subworkflows/local/assembly/main.nf" "Subworkflow definition"
check_file "subworkflows/local/assembly/tests/main.nf.test" "Test file"
check_file "subworkflows/local/assembly/tests/nextflow.config" "Test config"
if [ -f "subworkflows/local/assembly/tests/main.nf.test" ]; then
    check_pattern "subworkflows/local/assembly/tests/main.nf.test" "tag \"assembly\"" "Has assembly tag"
    check_pattern "subworkflows/local/assembly/tests/main.nf.test" "test.*basic HiFi" "Has HiFi reads test"
    check_pattern "subworkflows/local/assembly/tests/main.nf.test" "test.*multiple samples" "Has multi-sample test"
    check_pattern "subworkflows/local/assembly/tests/main.nf.test" "stub" "Has stub test"
fi
echo ""

echo -e "${BLUE}5. Pipeline Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_file "TESTS/default.nf.test" "Pipeline test"
check_file "main.nf" "Main pipeline file"
echo ""

echo -e "${BLUE}6. Test Structure Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Count test files
TEST_FILES=$(find modules subworkflows -name "main.nf.test" 2>/dev/null | wc -l | tr -d ' ')
echo -e "${GREEN}✓${NC} Found $TEST_FILES test files in modules/subworkflows"

# Check for test tags
if grep -q "tag \"modules\"" modules/*/tests/main.nf.test modules/*/*/tests/main.nf.test 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Module tests have proper tags"
else
    echo -e "${YELLOW}⚠${NC} Some module tests may be missing tags"
    ((WARNINGS++))
fi

if grep -q "tag \"subworkflows\"" subworkflows/*/tests/main.nf.test 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Subworkflow tests have proper tags"
else
    echo -e "${YELLOW}⚠${NC} Some subworkflow tests may be missing tags"
    ((WARNINGS++))
fi

# Check nf-test.config settings
if grep -q "configFile.*TESTS/nextflow.config" nf-test.config; then
    echo -e "${GREEN}✓${NC} nf-test.config points to correct config file"
else
    echo -e "${RED}✗${NC} nf-test.config may have incorrect config path"
    ((ERRORS++))
fi

echo ""
echo -e "${BLUE}7. Test Data Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "test_fastq" TESTS/nextflow.config; then
    echo -e "${GREEN}✓${NC} Test data paths configured in TESTS/nextflow.config"
else
    echo -e "${RED}✗${NC} Test data paths not found in config"
    ((ERRORS++))
fi

if [ -x "TESTS/run-tests.sh" ]; then
    echo -e "${GREEN}✓${NC} Test runner script is executable"
else
    echo -e "${YELLOW}⚠${NC} Test runner script is not executable (run: chmod +x TESTS/run-tests.sh)"
    ((WARNINGS++))
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Validation Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo -e "Test structure is ${GREEN}valid${NC} and ready for nf-test execution."
    echo ""
    echo "Next steps:"
    echo "  1. Install nf-test: curl -fsSL https://code.askimed.com/install/nf-test | bash"
    echo "  2. Run tests: ./TESTS/run-tests.sh all"
    echo "  3. Generate snapshots: nf-test test --update-snapshot"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Test structure is functional but has minor issues."
    echo "Review warnings above for improvements."
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please fix the errors above before running tests."
    exit 1
fi
