#!/usr/bin/env bash

###############################################################################
# Script to run nf-test test suite
# Usage: ./TESTS/run-tests.sh [OPTIONS]
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if nf-test is installed
if ! command -v nf-test &> /dev/null; then
    echo -e "${RED}Error: nf-test is not installed${NC}"
    echo "Please install nf-test from: https://www.nf-test.com/docs/getting-started/installation/"
    echo ""
    echo "Quick install:"
    echo "  curl -fsSL https://code.askimed.com/install/nf-test | bash"
    exit 1
fi

echo -e "${GREEN}Found nf-test: $(nf-test --version)${NC}"
echo ""

# Parse command line arguments
MODE="${1:-all}"

case "$MODE" in
    all)
        echo -e "${YELLOW}Running all tests...${NC}"
        nf-test test
        ;;
    modules)
        echo -e "${YELLOW}Running module tests...${NC}"
        nf-test test --tag modules
        ;;
    subworkflows)
        echo -e "${YELLOW}Running subworkflow tests...${NC}"
        nf-test test --tag subworkflows
        ;;
    hifiasm)
        echo -e "${YELLOW}Running HIFIASM module tests...${NC}"
        nf-test test modules/nf-core/hifiasm/tests/main.nf.test
        ;;
    gfa2fa)
        echo -e "${YELLOW}Running GFA2FA module tests...${NC}"
        nf-test test modules/local/gfa2fa/tests/main.nf.test
        ;;
    assembly)
        echo -e "${YELLOW}Running ASSEMBLY subworkflow tests...${NC}"
        nf-test test subworkflows/local/assembly/tests/main.nf.test
        ;;
    pipeline)
        echo -e "${YELLOW}Running pipeline tests...${NC}"
        nf-test test TESTS/default.nf.test
        ;;
    stub)
        echo -e "${YELLOW}Running stub tests (fast validation)...${NC}"
        nf-test test --tag modules -stub
        ;;
    update)
        echo -e "${YELLOW}Updating snapshots...${NC}"
        nf-test test --update-snapshot
        ;;
    clean)
        echo -e "${YELLOW}Cleaning test cache...${NC}"
        rm -rf .nf-test
        echo "Test cache cleaned"
        exit 0
        ;;
    help|--help|-h)
        echo "Usage: $0 [MODE]"
        echo ""
        echo "Modes:"
        echo "  all          - Run all tests (default)"
        echo "  modules      - Run all module tests"
        echo "  subworkflows - Run all subworkflow tests"
        echo "  hifiasm      - Run HIFIASM module tests only"
        echo "  gfa2fa       - Run GFA2FA module tests only"
        echo "  assembly     - Run ASSEMBLY subworkflow tests only"
        echo "  pipeline     - Run full pipeline tests"
        echo "  stub         - Run fast stub tests"
        echo "  update       - Update test snapshots"
        echo "  clean        - Clean test cache"
        echo "  help         - Show this help message"
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown mode: $MODE${NC}"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac

# Check exit code
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Tests completed successfully!${NC}"
else
    echo ""
    echo -e "${RED}✗ Tests failed!${NC}"
    exit 1
fi
