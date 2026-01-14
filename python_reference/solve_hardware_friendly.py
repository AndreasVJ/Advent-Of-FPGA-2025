def bools_to_int(bits: list[bool]):
    value = 0
    for i, b in enumerate(bits):
        value |= int(b) << i
    return value


def count_trailing_ones(num: int):
    count = 0
    while num & 1:
        count += 1
        num >>= 1
    return count


def compute_pruned_sp(stack, sp, d, remaining_input, K=12):
    # Compute if stack values are greater than d
    gt_d = [stack[i] < d for i in range(K)]

    # Space constraint
    space_ok = [
        remaining_input >= K - i
        for i in range(K)
    ]

    # Check if stack index is greater than or equal to sp
    idx_gte_sp = [i >= sp for i in range(K)]

    # Valid pops
    valid = [
        (gt_d[i] and space_ok[i]) or idx_gte_sp[i]
        for i in range(K)
    ]

    valid.reverse()

    valid_int = bools_to_int(valid)

    trailing_ones = count_trailing_ones(valid_int)

    return K - trailing_ones


with open("day3.txt") as f:
    K = 12

    data = f.read()
    L = data.find("\n")


    stack = [0]*K
    sp = 0

    i = 0

    ans = 0

    for c in data + "0":
        if c == "\n":
            continue

        d = int(c)

        if i == L:
            n = int("".join(str(val) for val in stack))
            ans += n
            sp = 0
            i = 0
            stack[0] = 0


        remaining_input = L - i

        sp = compute_pruned_sp(stack, sp, d, remaining_input, K)

        if sp < K:
            stack[sp] = d
            sp += 1

        i += 1

    print(ans)
