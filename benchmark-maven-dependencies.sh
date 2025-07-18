#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BENCHMARK_RUNS=3
RESULTS_FILE="maven-dependency-benchmark-results.txt"
TEMP_BASE_DIR="/tmp/maven-benchmark"

# Function to log with timestamp
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to create a fresh temporary Maven repository
create_temp_maven_repo() {
    local temp_dir="$1"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    log "Created temporary Maven repository at: $temp_dir"
}

# Function to run a timed Maven build
run_timed_build() {
    local scenario="$1"
    local temp_repo="$2"
    local additional_args="$3"
    
    log "Running $scenario build with temporary repository: $temp_repo"
    
    # Start timing
    local start_time=$(date +%s.%N)
    
    # Run Maven build with custom repository
    ./mvnw clean compile \
        -Dmaven.repo.local="$temp_repo" \
        -q \
        $additional_args
    
    # End timing
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    log "$scenario build completed in ${duration}s"
    echo "$duration"
}

# Function to benchmark a scenario
benchmark_scenario() {
    local scenario="$1"
    local branch="$2"
    local additional_args="$3"
    
    log "===== Benchmarking $scenario Scenario ====="
    
    # Switch to appropriate branch
    if [ "$branch" != "main" ]; then
        git checkout "$branch" || error "Failed to checkout branch $branch"
    fi
    
    local times=()
    local total_time=0
    
    for i in $(seq 1 $BENCHMARK_RUNS); do
        log "Run $i/$BENCHMARK_RUNS for $scenario"
        
        # Create fresh temporary repo for each run
        local temp_repo="$TEMP_BASE_DIR/${scenario,,}-run-$i"
        create_temp_maven_repo "$temp_repo"
        
        # Run the build and capture time
        local build_time=$(run_timed_build "$scenario" "$temp_repo" "$additional_args")
        times+=("$build_time")
        total_time=$(echo "$total_time + $build_time" | bc)
        
        log "Run $i completed in ${build_time}s"
    done
    
    # Calculate average
    local avg_time=$(echo "scale=3; $total_time / $BENCHMARK_RUNS" | bc)
    
    # Find min and max
    local min_time=${times[0]}
    local max_time=${times[0]}
    for time in "${times[@]}"; do
        if (( $(echo "$time < $min_time" | bc -l) )); then
            min_time=$time
        fi
        if (( $(echo "$time > $max_time" | bc -l) )); then
            max_time=$time
        fi
    done
    
    # Log results
    log "$scenario Results:"
    log "  Individual runs: ${times[*]}"
    log "  Average: ${avg_time}s"
    log "  Min: ${min_time}s"
    log "  Max: ${max_time}s"
    
    # Save to results file
    echo "=== $scenario Scenario ===" >> "$RESULTS_FILE"
    echo "Date: $(date)" >> "$RESULTS_FILE"
    echo "Runs: $BENCHMARK_RUNS" >> "$RESULTS_FILE"
    echo "Individual times (seconds): ${times[*]}" >> "$RESULTS_FILE"
    echo "Average time: ${avg_time}s" >> "$RESULTS_FILE"
    echo "Min time: ${min_time}s" >> "$RESULTS_FILE"
    echo "Max time: ${max_time}s" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Return to main branch
    if [ "$branch" != "main" ]; then
        git checkout main || warn "Failed to return to main branch"
    fi
}

# Main execution
main() {
    log "Starting Maven Dependency Resolution Benchmark"
    log "Current working directory: $(pwd)"
    log "Benchmark runs per scenario: $BENCHMARK_RUNS"
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        error "bc command not found. Please install bc for time calculations."
        exit 1
    fi
    
    # Initialize results file
    echo "Maven Dependency Resolution Benchmark Results" > "$RESULTS_FILE"
    echo "Started: $(date)" >> "$RESULTS_FILE"
    echo "Project: $(basename $(pwd))" >> "$RESULTS_FILE"
    echo "================================================" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Create base temp directory
    mkdir -p "$TEMP_BASE_DIR"
    
    # Benchmark Scenario 1: Default Maven Central
    benchmark_scenario "DEFAULT" "main" ""
    
    # Benchmark Scenario 2: GCP Artifact Registry
    benchmark_scenario "GCP" "gcp" ""
    
    # Clean up temporary directories
    log "Cleaning up temporary directories..."
    rm -rf "$TEMP_BASE_DIR"
    
    log "Benchmark completed! Results saved to: $RESULTS_FILE"
    
    # Display summary
    log "===== BENCHMARK SUMMARY ====="
    cat "$RESULTS_FILE"
}

# Run main function
main "$@"