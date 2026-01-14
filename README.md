# Advent Of FPGA 2025 (Day 3)

This repository contains my solution for [Advent Of FPGA 2025](https://blog.janestreet.com/advent-of-fpga-challenge-2025/). I choose to solve [day 3](https://adventofcode.com/2025/day/3), and wrote my solution in Ocaml with the Hardcaml library.


## Requirements

You need the following tools installed:

- `opam` (≥ 2.5)
- `dune` (installed with `opam install dune`)


## Project Setup

From the project root, run:

```sh
opam switch create . ocaml.5.3.0
eval $(opam env)
opam install . --deps-only
dune build
```


## Running The Solution

After seting up the project, running
```sh
dune exec bin/day3.exe
```
should print:

```
172740584266849
```


## Algorithm Overview
The core problem in Day 3 (Part Two) is:
- Given a sequence of digits, select exactly K = 12 digits, in order, such that the resulting number is as large as possible.

### Reference Software Algorithm (Python)

The algorithm below implements a greedy, stack-based solution that constructs the optimal number incrementally as the input is scanned from left to right.

```py
def max_number_k_digits(s: str, K: int) -> int:
    stack = []
    n = len(s)

    for i, c in enumerate(s):
        d = int(c)
        remaining = n - i

        while (
            stack and
            stack[-1] < d and
            len(stack) - 1 + remaining >= K
        ):
            stack.pop()

        if len(stack) < K:
            stack.append(d)

    return int("".join(map(str, stack)))
```

- Scan digits left to right
- Maintain the lexicographically largest subsequence from the digits seen so far.
- If a new digit is larger than the previous one, try to replace it
- Only pop digits if we are guaranteed to still be able to reach K digits total

A more hardware friendly python implementation of this algorithm can be found in [python_reference/solve_hardware_friendly.py](python_reference/solve_hardware_friendly.py)


## Key Hardware Design Decisions


### Single-Cycle Stack Pointer Pruning

In the software reference implementation, the stack is pruned using a while loop that repeatedly pops elements until the greedy condition is satisfied. This form of control flow does not map well to hardware as it would have to stall the pipeline.

Instead, the hardware design computes the new stack pointer in a single clock cycle, using combinational logic.

For each stack index i, three conditions are evaluated in parallel:
- 1. **Digit comparison**:  
    Whether the incoming digit is strictly greater than the stored digit:
    ```ml
    stack[i] < data_in
    ```

- 2. **Space constraint**:  
    Whether enough input remains to still reach K = depth digits if this entry is removed:
    ```ml
    remaining >= depth - i
    ```

- 3. **Index contrains**:  
    Any index at or above the current stack pointer is always considered valid:
    ```ml
    i >= sp
    ```

These conditions are combined into a bit vector:
```ml
let valid_pop = (gt_data_in &: space_ok) |: idx_gte_sp
```

The new stack pointer is then computed by counting the number of trailing 1s in this vector:
```ml
let trailing_ones =
  Aofpga.Count_trailing_ones.create (uresize valid_pop 16)
```

The trailing_ones count subtracted from K = depth yields the lowest index that must be preserved, allowing the stack pointer to be updated without iterative popping.

### End-of-Line Detection and Pipeline Decoupling

The end of an input line is detected when the remaining-input counter reaches zero:
```ml
let end_of_line = (remaining ==:. 0) &: ~:(stack.empty)
```

At this point:
- The stack contains the final 12-digit result for the line
- The stack pointer is reset for the next line
- A conversion from BCD digits to binary is triggered

This conversion does not stall input processing.

### Parallel BCD-to-Binary Conversion

The selected digits are stored in BCD form. Converting a 12-digit BCD number to binary is implemented as a multi-cycle pipeline:
```ml
let line_ans = Aofpga.Bcd_to_binary.create
  ~clock
  ~digits:stack.mem
  ~start:end_of_line
```

- Conversion starts when end_of_line is asserted
- One digit is processed per clock cycle
- The conversion runs in parallel with processing of the next input line

This allows the design to maintain a throughput of one input digit per cycle, even though BCD-to-binary conversion itself is sequential.

### Accumulation of Results

Once the conversion finishes, the resulting binary value is accumulated into the final answer:
```ml
let ans =
  reg_fb
    spec
    ~enable:accumelate_ans
    ~width:ans_width
    ~f:(fun q ->
      q +: (uresize line_ans.result ans_width)
    )
```

