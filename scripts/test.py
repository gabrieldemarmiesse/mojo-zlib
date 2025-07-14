#!/usr/bin/env python3
"""Run all Mojo test files one at a time with progress tracking."""

import os
import subprocess
import time
from pathlib import Path


def find_mojo_test_files(tests_dir):
    """Find all .mojo files in the tests directory recursively."""
    test_files = []
    for root, _, files in os.walk(tests_dir):
        for file in files:
            if file.endswith('.mojo'):
                test_files.append(os.path.join(root, file))
    return sorted(test_files)


def run_test(test_file):
    """Run a single test file and return success status and duration."""
    start_time = time.time()
    try:
        result = subprocess.run(
            ['pixi', 'run', 'test', test_file],
            capture_output=True,
            text=True
        )
        duration = time.time() - start_time
        return result.returncode == 0, duration, result.stdout, result.stderr
    except Exception as e:
        duration = time.time() - start_time
        return False, duration, "", str(e)


def main():
    tests_dir = 'tests'
    
    # Find all test files
    test_files = find_mojo_test_files(tests_dir)
    
    if not test_files:
        print("No .mojo test files found in tests directory")
        return
    
    print(f"Found {len(test_files)} test files")
    print("=" * 80)
    
    total_start_time = time.time()
    passed = 0
    failed = 0
    
    for i, test_file in enumerate(test_files, 1):
        print(f"\n[{i}/{len(test_files)}] Running: {test_file}")
        
        success, duration, stdout, stderr = run_test(test_file)
        
        if success:
            print(f" PASSED in {duration:.2f}s")
            passed += 1
        else:
            print(f" FAILED in {duration:.2f}s")
            failed += 1
            if stderr:
                print(f"Error output:\n{stderr}")
    
    # Summary
    total_duration = time.time() - total_start_time
    print("\n" + "=" * 80)
    print(f"Test Summary:")
    print(f"  Total files: {len(test_files)}")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Total runtime: {total_duration:.2f}s")
    print(f"  Average per file: {total_duration/len(test_files):.2f}s")
    
    # Exit with non-zero if any tests failed
    if failed > 0:
        exit(1)


if __name__ == "__main__":
    main()