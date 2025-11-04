def keccak_theta(state):
    """
    Perform the θ step mapping on a 5x5 array of 64-bit integers.
    state: list of 5 lists, each with 5 64-bit integers.
    Returns a new 5x5 list after θ step.
    """

    # Compute the parity of each column
    C = [state[x][0] ^ state[x][1] ^ state[x][2] ^ state[x][3] ^ state[x][4] for x in range(5)]

    # Compute the D[x] values (with 64-bit rotation)
    D = [0]*5
    for x in range(5):
        xm1 = (x - 1) % 5
        xp1 = (x + 1) % 5
        # Rotate left 1 bit in 64-bit space
        rot = ((C[xp1] << 1) & 0xFFFFFFFFFFFFFFFF) | (C[xp1] >> (64 - 1))
        D[x] = C[xm1] ^ rot

    # Apply D[x] to every lane in column x
    result = [[0]*5 for _ in range(5)]
    for x in range(5):
        for y in range(5):
            result[x][y] = state[x][y] ^ D[x]

    return result

def print_state_fips(state):
    """
    Prints the 5x5 Keccak state with (0,0) at the center (bottom middle),
    as specified by FIPS 202.
    """
    print("Keccak state (FIPS 202 coordinates):\n")
    for y in range(4, -1, -1):  # print y = 4 down to 0 (top to bottom)
        row = []
        for x in range(5):
            row.append(f"{state[x][y]:#04x}")
        print(f"y={y}: " + "  ".join(row))
    print("     x=0   x=1   x=2   x=3   x=4\n")

# Example: initialize with 1600-bit zero state, except one bit
state = [[0]*5 for _ in range(5)]
state[0][0] = 0x1  # single bit

after_theta = keccak_theta(state)

print_state_fips(after_theta)
