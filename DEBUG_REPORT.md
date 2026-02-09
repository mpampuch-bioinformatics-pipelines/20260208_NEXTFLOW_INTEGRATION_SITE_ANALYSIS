# Pipeline Debug Report
**Generated:** 2026-02-09  
**Pipeline:** Integration Site Analysis Pipeline  
**Nextflow Version:** 25.10.3

---

## 🔴 Critical Issues Found

### Issue 1: Reserved Keyword Conflict - `log` Property (FIXED ✅)

**Error:**
```
groovy.lang.ReadOnlyPropertyException: Cannot set readonly property: log for class: nextflow.Nextflow
```

**Location:** `subworkflows/local/assembly/main.nf:60`

**Root Cause:**  
The workflow emit block used `log` as an output channel name, which conflicts with Nextflow's built-in `log` property. This is a reserved keyword and cannot be reassigned.

**Solution Applied:**
- Renamed output from `log` to `assembly_log` in the ASSEMBLY subworkflow
- Updated references in `workflows/pipeline.nf` 
- Updated documentation in `docs/ASSEMBLY_IMPLEMENTATION.md`

**Files Modified:**
1. `subworkflows/local/assembly/main.nf` - Line 60
2. `workflows/pipeline.nf` - emit block
3. `docs/ASSEMBLY_IMPLEMENTATION.md` - documentation

---

### Issue 2: HIFIASM Input Channel Mismatch (FIXED ✅)

**Error:**
```
WARN: Input tuple does not match tuple declaration in process HIFIASM
Path value cannot be null
```

**Root Cause:**  
The HIFIASM process expects:
- Input 1: `[meta, long_reads, ul_reads]` (3 elements)
- Input 2: `[meta, paternal_kmer, maternal_kmer]` (3 elements)  
- Input 3: `[meta, hic_read1, hic_read2]` (3 elements)
- Input 4: `[meta, bin_files]` (2 elements)

But the ASSEMBLY subworkflow was providing:
- Input 1: `[meta, reads]` (only 2 elements)
- Inputs 2-4: Single shared empty tuple causing meta mismatch

**Solution Applied:**
```groovy
// Transform ch_reads to include empty ul_reads slot
def ch_reads_with_ul = ch_reads.map { meta, reads -> [meta, reads, []] }

// Create per-sample empty channels with matching meta
def ch_empty_trio = ch_reads.map { meta, reads -> [meta, [], []] }
def ch_empty_hic = ch_reads.map { meta, reads -> [meta, [], []] }
def ch_empty_bin = ch_reads.map { meta, reads -> [meta, []] }

HIFIASM (
    ch_reads_with_ul,    // [meta, long_reads, ul_reads]
    ch_empty_trio,       // [meta, paternal, maternal]
    ch_empty_hic,        // [meta, hic_r1, hic_r2]
    ch_empty_bin         // [meta, bin_files]
)
```

**Why This Works:**
- Each input now has the correct number of elements
- Meta values match across all inputs (per-sample cardinality)
- Empty file paths are represented as `[]` instead of null

---

### Issue 3: Resource Limitation (PARTIAL ⚠️)

**Error:**
```
Command exit status: 137 (SIGKILL - process killed by OS)
WARNING: The requested image's platform (linux/amd64) does not match detected host platform (linux/arm64/v8)
```

**Root Cause:**  
1. **Exit code 137:** Process killed by OS, typically due to:
   - Out of memory (OOM killer)
   - Container resource limits exceeded
   - Docker memory constraints on macOS

2. **Platform mismatch:** Running linux/amd64 container on ARM64 Mac (Apple Silicon) via emulation, which:
   - Significantly increases memory usage (emulation overhead)
   - Reduces performance
   - Can trigger OOM on memory-intensive processes

**Recommended Solutions:**

#### Option A: Use Native ARM64 Containers (Recommended)
Check if ARM64-compatible containers are available:
```bash
# Update container in conf/modules.config or process definition
container 'biocontainers/hifiasm:0.25.0--arm64_version'
```

#### Option B: Increase Docker Resources
For macOS Docker Desktop:
1. Open Docker Desktop → Settings → Resources
2. Increase Memory to at least 8GB (16GB recommended)
3. Increase CPU allocation to 4+ cores
4. Apply & Restart Docker

#### Option C: Use Test Profile with Reduced Resources
Modify `conf/test.config` to use smaller test data or reduce resource requirements:
```groovy
process {
    withName: 'HIFIASM' {
        cpus = 2
        memory = '4.GB'
    }
}
```

#### Option D: Run on Cloud/HPC
For production runs, use Seqera Platform with cloud compute or HPC environments that have sufficient resources.

---

## 🟡 Test Failures

### Test 1: `TESTS/default.nf.test` - Profile test (FAILED)

**Status:** Failed due to upstream pipeline failure (Issue 3)

**Expected Behavior:**
- Pipeline should complete successfully
- Snapshot should match expected outputs

**Current Behavior:**
- Pipeline fails during HIFIASM execution due to OOM
- Tests cannot validate outputs

**Resolution:**
Fix Issue 3 (resource limitation), then tests should pass.

---

### Test 2: `main.nf.test` - Basic workflow test (FAILED)

**Status:** Failed due to upstream pipeline failure

**Test:**
```groovy
assert workflow.success
```

**Current Behavior:**
```
assert workflow.success
       |        |
       workflow false
```

**Resolution:**
Fix Issue 3, then this test will pass.

---

### Test 3: `modules/local/gfa2fa/tests/main.nf.test` (PASSED ✅)

All GFA2FA module tests passed:
- ✅ gfa2fa - convert gfa to fasta
- ✅ gfa2fa - convert gfa to fasta - stub
- ✅ gfa2fa - primary contigs
- ✅ gfa2fa - alternate contigs
- ✅ gfa2fa - haplotype contigs

---

### Test 4: `modules/nf-core/hifiasm/tests/main.nf.test` (FAILED)

**Status:** Failed - similar OOM issue

**Test:** hifiasm - basic assembly

**Resolution:**
Fix Issue 3 (resource limitation).

---

## ✅ Summary of Fixes Applied

### Files Modified:

1. **`subworkflows/local/assembly/main.nf`**
   - Renamed `log` emit to `assembly_log` (reserved keyword fix)
   - Fixed HIFIASM input channel structure (added ul_reads slot)
   - Created per-sample empty channels with matching meta

2. **`workflows/pipeline.nf`**
   - Updated reference from `ASSEMBLY.out.log` to `ASSEMBLY.out.assembly_log`

3. **`docs/ASSEMBLY_IMPLEMENTATION.md`**
   - Updated documentation to reflect new output name

---

## 🧪 Next Steps to Validate Fixes

### Step 1: Test with Stub Mode (Fast validation)
```bash
nextflow run main.nf -profile docker,test --outdir TESTS/TEST_OUTPUTS/ -stub-run
```
This will test the pipeline logic without actually running the tools.

### Step 2: Increase Docker Resources
Before running full tests:
1. Open Docker Desktop → Settings → Resources
2. Set Memory: 8-16 GB
3. Set CPUs: 4-8 cores
4. Apply & Restart

### Step 3: Run Tests
```bash
# Run pipeline with increased resources
nextflow run main.nf -profile docker,test --outdir TESTS/TEST_OUTPUTS/ -resume

# Run nf-test suite
nf-test test --verbose
```

### Step 4: Run with Local Execution (if Docker issues persist)
```bash
# Use conda/mamba instead of Docker
nextflow run main.nf -profile conda,test --outdir TESTS/TEST_OUTPUTS/
```

---

## 🔍 Validation Checklist

- [x] Fix reserved keyword conflict (`log` → `assembly_log`)
- [x] Fix HIFIASM input channel structure
- [x] Update all references to renamed output
- [ ] Increase Docker resources (user action required)
- [ ] Validate with stub-run mode
- [ ] Run full pipeline tests
- [ ] Verify test suite passes

---

## 📊 Test Results Before Fixes

| Test Suite | Status | Details |
|------------|--------|---------|
| TESTS/default.nf.test | ❌ FAILED | Pipeline execution error |
| main.nf.test | ❌ FAILED | workflow.success = false |
| modules/local/gfa2fa | ✅ PASSED | 5/5 tests passed |
| modules/nf-core/hifiasm | ❌ FAILED | OOM during execution |
| modules/nf-core/multiqc | ⏭️ SKIPPED | Upstream failure |

**Total:** 5 passed, 3 failed (due to resource constraints)

---

## 🎯 Expected Results After Fixes

Once Docker resources are increased and the code fixes are applied:

| Test Suite | Expected Status |
|------------|-----------------|
| TESTS/default.nf.test | ✅ PASS |
| main.nf.test | ✅ PASS |
| modules/local/gfa2fa | ✅ PASS (already passing) |
| modules/nf-core/hifiasm | ✅ PASS |
| modules/nf-core/multiqc | ✅ PASS |

---

## 📝 Additional Recommendations

### 1. Add Input Validation
Consider adding validation in the ASSEMBLY subworkflow:
```groovy
workflow ASSEMBLY {
    take:
    ch_reads // channel: [ val(meta), path(reads) ]

    main:
    // Validate inputs
    ch_reads.view { meta, reads -> 
        "Processing sample ${meta.id} with ${reads.size()} file(s)" 
    }
    
    // Rest of workflow...
}
```

### 2. Add Resource Labels
Update `conf/base.config` with memory requirements:
```groovy
process {
    withLabel: 'process_high' {
        cpus = { check_max(8, 'cpus') }
        memory = { check_max(16.GB * task.attempt, 'memory') }
        time = { check_max(24.h * task.attempt, 'time') }
    }
}
```

### 3. Enable Nextflow Tower/Seqera Platform
For better debugging and monitoring:
```bash
export TOWER_ACCESS_TOKEN=your_token
nextflow run main.nf -profile docker,test -with-tower
```

### 4. Use nf-test Assertions
Improve test robustness in `main.nf.test`:
```groovy
then {
    assertAll(
        { assert workflow.success },
        { assert workflow.failed == 0 },
        { assert path("${params.outdir}").exists() }
    )
}
```

---

## 🐛 Debugging Commands

If issues persist, use these commands:

```bash
# Check recent Nextflow log
tail -100 .nextflow.log

# Check nf-test log  
tail -100 .nf-test.log

# Inspect failed work directory
cd work/1a/3aa604830de98cad051983997ad712
cat .command.sh    # View command
cat .command.out   # View stdout
cat .command.err   # View stderr
cat .command.log   # View full log

# Check Docker resources
docker info | grep -i memory
docker info | grep -i cpu

# Clean work directory and retry
nextflow clean -f
rm -rf work/
nextflow run main.nf -profile docker,test --outdir TESTS/TEST_OUTPUTS/
```

---

## 📚 References

- [Nextflow DSL2 Reserved Keywords](https://www.nextflow.io/docs/latest/dsl2.html)
- [nf-core Module Guidelines](https://nf-co.re/docs/contributing/modules)
- [Troubleshooting Exit Code 137](https://nf-co.re/docs/usage/troubleshooting#exit-code-137)
- [Docker on Apple Silicon](https://docs.docker.com/desktop/mac/apple-silicon/)
