def keccak_chi(state):
    """
    Perform the χ step mapping on a 5x5 array of 64-bit integers.
    Each row is transformed non-linearly using:
        A'[x][y] = A[x][y] ^ ((~A[x+1 mod 5][y]) & A[x+2 mod 5][y])
    state: list of 5 lists, each with 5 64-bit integers.
    Returns a new 5x5 list after χ step.
    """
    result = [[0]*5 for _ in range(5)]
    for y in range(5):
        for x in range(5):
            a = state[x][y]
            b = state[(x+1) % 5][y]
            c = state[(x+2) % 5][y]
            result[x][y] = a ^ ((~b) & c)
    return result


# Keep the same print_state_fips function from your example
def print_state_fips(state):
    print("Keccak state (FIPS 202 coordinates):\n")
    for y in range(4, -1, -1):
        row = []
        for x in range(5):
            row.append(f"0x{state[x][y]:016x}")
        print(f"y={y}: " + "  ".join(row))
    print("     x=0                 x=1                 x=2                 x=3                 x=4\n")


# Example tests
state = [[0]*5 for _ in range(5)]
state[1][0] = 0x1  # single bit set in lane (1,0)

print("Starting State: One bit set at (1,0):")
print_state_fips(state)
after_chi = keccak_chi(state)
print("After χ step: Non-linear row transformation applied:")
print_state_fips(after_chi)

state = [[1 for _ in range(5)] for _ in range(5)]
print("Starting State: All lanes set to 0x1")
print_state_fips(state)
after_chi = keccak_chi(state)
print("After χ step: All lanes set to 0x1:")
print_state_fips(after_chi)

# Sequential pattern test
state = [[x + 5*y for y in range(5)] for x in range(5)]
print("==== Initial State (Sequential Pattern) ====")
print_state_fips(state)
after_chi = keccak_chi(state)
print("==== After χ Step ====")
print_state_fips(after_chi)
