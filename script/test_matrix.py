import sh
import os
import sys
import re

# line buffer for output
sys.stdout.reconfigure(line_buffering=True)

RESULTS_1 = {}

# 1 to 12 threads
THREAD_COUNTS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
INPUT_TRACE = "fib4_trace.bin"
# INPUT_TRACE = "fib3_trace.bin"

#   analysis time:            24.39s
TIME_REGEX = re.compile(
    # r"(?:time: )(\d+\.\d+)"
    r"(?:analysis time:\s+)(\d+\.\d+)"
)

runift = sh.Command("./src/irretool/irretool")

for thread_count in THREAD_COUNTS:
    print(f"running tests with {thread_count} threads")

    print(f"running ift threads={thread_count}")
    # h2_out = h2(f"{BIN_COUNT}", "0", "1000000", f"{DATA_N}", f"{thread_count}")
    # match2rt = TIME_REGEX.search(h2_out.stdout.decode("utf-8"))
    # --ift --pl --pl-threads 4 --ift-graph --ift-graph-analysis fib4_trace.bin
    run_cmd = runift.bake("analyze", "--ift", "--pl", f"--pl-threads={thread_count}", "--ift-graph", "--ift-graph-analysis", INPUT_TRACE)
    print(f" running: {run_cmd}")
    ift_out = run_cmd()
    outmatch = TIME_REGEX.search(ift_out.stdout.decode("utf-8"))

    # print('stdout: ', ift_out.stdout.decode("utf-8"))
    if not outmatch:
        assert False, "no match for time"
    
    # save results
    RESULTS_1[thread_count] = [
        float(outmatch.group(1)),
    ]

print("\n")
print("\n")

print("THREADS vs TIME")

# column labels: threads, time
print("threads\ttime")
for thread_count in THREAD_COUNTS:
    print(f"{thread_count}\t{RESULTS_1[thread_count][0]:.3f}")
