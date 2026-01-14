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


with open("day3.txt") as f:
    K = 12

    ans = 0
    for line in f.readlines():
        line = line.rstrip()
        ans += max_number_k_digits(line, K)

    print(ans)
