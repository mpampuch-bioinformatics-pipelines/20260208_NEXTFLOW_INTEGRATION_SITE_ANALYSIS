# nf-test Test Suite

This directory contains the nf-test suite for the integration-site-analysis pipeline.

## Test Coverage

### Modules

#### HIFIASM (`modules/nf-core/hifiasm/tests/main.nf.test`)
- ✅ Basic assembly with HiFi reads
- ✅ Assembly with ultralong reads
- ✅ Assembly with custom parameters
- ✅ Stub test for rapid validation

**Test scenarios:**
1. Basic assembly - Tests standard HiFiASM assembly with PacBio HiFi reads
2. Ultralong reads - Tests assembly with additional ultralong read input
3. Custom parameters - Tests assembly with user-defined parameters (e.g., `-l 3`)
4. Stub mode - Fast validation without actual tool execution

#### GFA2FA (`modules/local/gfa2fa/tests/main.nf.test`)
- ✅ GFA to FASTA conversion
- ✅ Primary contigs conversion
- ✅ Alternate contigs conversion
- ✅ Haplotype contigs conversion
- ✅ Stub test

**Test scenarios:**
1. Basic conversion - Tests standard GFA to FASTA conversion
2. Primary contigs - Tests conversion of primary assembly contigs
3. Alternate contigs - Tests conversion of alternate assembly contigs
4. Haplotype contigs - Tests conversion with custom configuration
5. Stub mode - Fast validation

### Subworkflows

#### ASSEMBLY (`subworkflows/local/assembly/tests/main.nf.test`)
- ✅ Basic HiFi read assembly workflow
- ✅ Multiple sample processing
- ✅ Custom configuration
- ✅ Output validation
- ✅ Stub test

**Test scenarios:**
1. Basic workflow - Tests complete assembly workflow from reads to FASTA
2. Multiple samples - Tests parallel processing of multiple samples
3. Custom config - Tests workflow with custom HIFIASM parameters
4. Output checks - Validates all expected outputs are produced
5. Stub mode - Fast validation of workflow structure

### Pipeline

#### Main Pipeline (`TESTS/default.nf.test`)
- ✅ Full pipeline execution with test profile
- ✅ Software version tracking
- ✅ Output file validation

## Test Data

Test data is located in `TESTS/TEST_DATA/`:
- `test.fastq.gz` - Minimal FASTQ file with synthetic HiFi reads
- `test.gfa` - Minimal GFA file for testing GFA2FA conversion

For actual pipeline testing, use the data specified in `samplesheet.test.csv`:
- PacBio HiFi reads: `/ibex/project/c2303/ALL-BCL-SEQ-READS/BCLCustomers/lauersk/Revio/r84180_20260202_132551/1_A01/version_01/cmc_087_11_C.merolae/cmc_087_11_C.merolae.hifi_reads.fastq`

## Running Tests

### Run all tests
```bash
nf-test test
```

### Run specific module tests
```bash
# Test HIFIASM module
nf-test test modules/nf-core/hifiasm/tests/main.nf.test

# Test GFA2FA module
nf-test test modules/local/gfa2fa/tests/main.nf.test
```

### Run subworkflow tests
```bash
# Test ASSEMBLY subworkflow
nf-test test subworkflows/local/assembly/tests/main.nf.test
```

### Run pipeline test
```bash
# Test full pipeline
nf-test test TESTS/default.nf.test
```

### Run with specific tags
```bash
# Run all module tests
nf-test test --tag modules

# Run all local module tests
nf-test test --tag modules_local

# Run all subworkflow tests
nf-test test --tag subworkflows
```

### Generate snapshots
```bash
# Generate or update snapshots for a test
nf-test test --update-snapshot modules/nf-core/hifiasm/tests/main.nf.test
```

## Test Configuration

- `TESTS/nextflow.config` - Configuration for nf-test runs, including test data paths
- `nf-test.config` - Global nf-test configuration
- Module-specific configs in each `tests/` directory

## Best Practices

1. **Use stub tests** for rapid validation during development
2. **Snapshot testing** for reproducible results
3. **Test multiple scenarios** - basic, edge cases, error conditions
4. **Tag tests appropriately** for selective execution
5. **Keep test data minimal** but representative
6. **Document test scenarios** in test file comments

## CI/CD Integration

Tests are automatically run in CI/CD pipelines. Ensure all tests pass before merging:

```bash
# Quick check with stub tests
nf-test test --tag modules -stub

# Full validation
nf-test test
```

## Troubleshooting

### Test fails with "file not found"
- Check test data paths in `TESTS/nextflow.config`
- Ensure test data files exist in `TESTS/TEST_DATA/`

### Snapshot mismatch
- Review the diff in `.nf-test/tests/*/snapshot.txt`
- Update snapshots if changes are intentional: `nf-test test --update-snapshot`

### Process not found
- Verify module/subworkflow imports in test file
- Check that process names match exactly

## Adding New Tests

When adding new modules or subworkflows:

1. Create a `tests/` directory in the module/subworkflow directory
2. Create `main.nf.test` with test cases
3. Add test-specific configuration in `tests/nextflow.config` if needed
4. Add appropriate tags
5. Run tests to generate initial snapshots
6. Document test scenarios in this README

## References

- [nf-test documentation](https://www.nf-test.com/)
- [nf-core testing guidelines](https://nf-co.re/docs/contributing/modules#testing)
- [Snapshot testing](https://www.nf-test.com/docs/assertions/snapshots/)
