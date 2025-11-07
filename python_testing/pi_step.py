def keccak_pi(state):
    """
    Perform the π step mapping on a 5x5 array of 64-bit integers.
    The π step rearranges the lanes of the state.
    state: list of 5 lists, each with 5 64-bit integers.
    Returns a new 5x5 list after π step.
    """

    result = [[0]*5 for _ in range(5)]

    for x in range(5):
        for y in range(5):
            # Mapping: B[y][(2x + 3y) mod 5] = A[x][y]
            result[y][(2*x + 3*y) % 5] = state[x][y]

    return result


def print_state_fips(state):
    """
    Prints the 5x5 Keccak state with (0,0) at the center (bottom middle),
    as specified by FIPS 202, using 16 hex digits per lane.
    """
    print("Keccak state (FIPS 202 coordinates):\n")
    for y in range(4, -1, -1):  # print y = 4 down to 0 (top to bottom)
        row = []
        for x in range(5):
            row.append(f"0x{state[x][y]:016x}")
        print(f"y={y}: " + "  ".join(row))
    print("     x=0                 x=1                 x=2                 x=3                 x=4\n")


# Example test: single-bit input state
state = [[0]*5 for _ in range(5)]
state[1][0] = 0x1  # single bit set in lane (1,0)

print("Starting State: One bit set at (1,0):")
print_state_fips(state)
after_pi = keccak_pi(state)
print("After π step: Lane permutation applied:")
print_state_fips(after_pi)

print("Starting State: All lanes set to 0x1")
state = [[1 for _ in range(5)] for _ in range(5)]
print_state_fips(state)
print("After π step: All lanes set to 0x1:")
after_pi = keccak_pi(state)
print_state_fips(after_pi)

# ==========================================================
# Test 3: Sequential pattern for visual verification
# ==========================================================
state = [[0]*5 for _ in range(5)]
count = 0
for x in range(5):
    for y in range(5):
        state[x][y] = count
        count += 1

print("==== Initial State (Sequential Pattern) ====")
print_state_fips(state)

after_pi = keccak_pi(state)

print("==== After π Step ====")
print_state_fips(after_pi)
