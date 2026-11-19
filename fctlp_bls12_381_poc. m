/*==============================================================================
  Fuzzy Covert Time-Lock Puzzle (FCTLP) — End-to-End PoC & Benchmark
  Architecture: RSW Sequential Core + Scrambled RS[255,192,64]_256 +
                Stealth ABBE O(1) Broadcast over BLS12-381 (G_T Prefix-LUT)
  Compatible with: Magma V2.29+ / Magma Online Calculator
==============================================================================*/

t_global := Cputime();

/*------------------------------------------------------------------------------
  0. DETERMINISTIC PRG & PACKING HELPERS (Self-contained)
------------------------------------------------------------------------------*/
NextWord64 := function(state)
    return (state * 6364136223846793005 + 1442695040888963407) mod 2^64;
end function;

// Dense mode: uniform vector in GF(256)^n
ExpandPRG_Dense := function(seed, F256, n)
    elems := [x : x in F256];
    st := seed mod 2^64;
    vec := [];
    for i in [1..n] do
        st := NextWord64(st);
        idx := (st div 2^32) mod 256;
        Append(~vec, elems[idx + 1]);
    end for;
    return Vector(F256, vec);
end function;

// Sparse mode: exact Hamming weight w over GF(256)^n
ExpandPRG_Sparse := function(seed, F256, n, w)
    nz := [x : x in F256 | x ne F256!0];
    st := seed mod 2^64;
    vec := [F256!0 : i in [1..n]];
    used := {};
    while #used lt w do
        st := NextWord64(st);
        pos := ((st div 2^32) mod n) + 1;
        if pos notin used then
            Include(~used, pos);
            st := NextWord64(st);
            val_idx := ((st div 2^32) mod 255) + 1;
            vec[pos] := nz[val_idx];
        end if;
    end while;
    return Vector(F256, vec);
end function;

// Base-3 Packing: GF(256) -> [0, 3280]
ByteToInt := function(b, F256)
    if b eq F256!0 then return 0; end if;
    seq := ElementToSequence(b);
    val := 0;
    for i in [1..8] do
        if seq[i] eq 1 then val +:= 2^(i-1); end if;
    end for;
    return val;
end function;

IntToByte := function(v, F256)
    bits := Intseq(v, 2);
    while #bits lt 8 do Append(~bits, 0); end while;
    return F256!bits;
end function;

Pack3 := function(b, F256)
    v := ByteToInt(b, F256);
    bits := Intseq(v, 2);
    z := 0;
    for i in [1..#bits] do
        z +:= bits[i] * 3^(i-1);
    end for;
    return z;
end function;

Unpack3 := function(Z, F256)
    trits := Intseq(Z, 3);
    v := 0;
    for i in [1..Min(#trits, 8)] do
        if (trits[i] mod 2) eq 1 then
            v +:= 2^(i-1);
        end if;
    end for;
    return IntToByte(v, F256);
end function;

// Compact 64-bit prefix tag for G_T elements (L1/L2 LUT simulation)
PrefixTag64 := function(gt_elem)
    c := Eltseq(gt_elem);
    c0 := Eltseq(c[1]);
    return (Integers()!c0[1]) mod 2^64;
end function;

// Strict bounded-distance RS decoder (enforces cw in C and wt(v - cw) <= t)
BoundedRSDecode := function(C, v, t)
    ok, cw := Decode(C, v);
    if ok and (cw in C) and (Weight(v - cw) le t) then
        return true, cw;
    end if;
    return false, Zero(AmbientSpace(C));
end function;

print "=== 1. SETUP: RS[255,192,64]_256 + RSW 2048-BIT + BLS12-381 ===";

// 1A. Reed-Solomon [255, 192, 64] over GF(256) + Secret Scrambling Matrix S
F256<alpha_f> := GF(2^8);
n_rs := 255; k_rs := 192; d_min := 64; aleph := 31; J_bound := 34;
C_rs := ReedSolomonCode(F256, d_min);
G_rs := GeneratorMatrix(C_rs);

repeat
    S_mat := RandomMatrix(F256, k_rs, k_rs);
until Determinant(S_mat) ne 0;
S_inv := S_mat^-1;
printf "  RS[255, 192, 64]_256 & Secret S in GL(192, F_256) ready.\n";

// 1B. RSW Unknown-Order Group (2048-bit RSA modulus)
t0 := Cputime();
p_rsa := NextPrime(Random(2^1023, 2^1024 - 1));
q_rsa := NextPrime(Random(2^1023, 2^1024 - 1));
N_rsa := p_rsa * q_rsa;
phi_N := (p_rsa - 1) * (q_rsa - 1);
T_delay := 5000; // Calibrated for fast online PoC verification
printf "  RSW 2048-bit Modulus N generated in %.3o sec (Delay T = %o).\n", Cputime(t0), T_delay;

// 1C. BLS12-381 Type-3 Pairing Setup (G1, G2, GT)
t0 := Cputime();
x_bls := -0xd201000000010000;
p_bls := (x_bls - 1)^2 * (x_bls^4 - x_bls^2 + 1) div 3 + x_bls;
r_bls := x_bls^4 - x_bls^2 + 1;
Fp := GF(p_bls);
Fp2<u> := ext<Fp | Polynomial([Fp | 1, 0, 1])>;
Fp12<w> := ext<Fp2 | Polynomial([Fp2 | -(1 + u), 0, 0, 0, 0, 0, 1])>;

E1 := EllipticCurve([Fp | 0, 4]);
E12 := BaseChange(E1, Fp12);
E2_twist := EllipticCurve([Fp2 | 0, 4*(1 + u)]);

// Generators G1 in E1[r] and G2 in E2[r] mapped to E12 via sextic twist
h1 := #E1 div r_bls;
repeat
    P1_cand := h1 * Random(E1);
until P1_cand ne E1!0;
G1 := E12![Fp12!P1_cand[1], Fp12!P1_cand[2], 1];

h2 := #E2_twist div r_bls;
repeat
    P2_cand := h2 * Random(E2_twist);
until P2_cand ne E2_twist!0;
G2 := E12![(Fp12!P2_cand[1]) / w^2, (Fp12!P2_cand[2]) / w^3, 1];

// Pairing function e(P, Q) = TatePairing(P, Q, r)^((p^12 - 1)/r)
final_exp := (p_bls^12 - 1) div r_bls;
Pair := function(P, Q)
    return TatePairing(P, Q, r_bls)^final_exp;
end function;

g_T := Pair(G1, G2);
alpha_msk := Random(1, r_bls - 1);
P_pub := alpha_msk * G1;

// Split Decryption Key for Receiver U_R: S_UR + H_R = [alpha]G2
s_share := Random(1, r_bls - 1);
S_UR := s_share * G2;
H_R  := ((alpha_msk - s_share) mod r_bls) * G2;
assert S_UR + H_R eq alpha_msk * G2;

// Build 64-bit Prefix-LUT in G_T for Z in [0, 6560]
t_lut := Cputime();
LUT := AssociativeArray();
cur := Fp12!1;
for Z in [0..6560] do
    LUT[PrefixTag64(cur)] := Z;
    cur *:= g_T;
end for;
printf "  BLS12-381 Setup & 6561-entry G_T Prefix-LUT built in %.3o sec.\n", Cputime(t_lut);

/*------------------------------------------------------------------------------
  2. COHORT PROVISIONING & MONOLITHIC PAYLOAD
------------------------------------------------------------------------------*/
w_mask := ExpandPRG_Dense(1001, F256, n_rs);
m_mask := ExpandPRG_Dense(2002, F256, n_rs);

// Sender attributes r_S, In-cohort r_R (d_H = 8), Out-of-cohort r_Out (d_H = 64)
r_S := ExpandPRG_Dense(3003, F256, 128);
delta_in  := ExpandPRG_Sparse(4004, F256, 128, 8);
delta_out := ExpandPRG_Sparse(5005, F256, 128, 64);
r_R   := r_S + delta_in;
r_Out := r_S + delta_out;

// Embed attributes in right half (0_127 || r_128) to fit 255B RS core
PadAttr := func<r | Vector(F256, [F256!0 : i in [1..127]] cat Eltseq(r))>;
M_S   := w_mask + m_mask + PadAttr(r_S);
M_R   := w_mask + m_mask + PadAttr(r_R);
M_Out := w_mask + m_mask + PadAttr(r_Out);

// 192-byte monolithic payload kappa & scrambled codeword c = kappa * S * G_rs
kappa := ExpandPRG_Dense(7777, F256, k_rs);
c_code := (kappa * S_mat) * G_rs;

// Persistent ephemeral half-radius blind noise xi_i (w_xi = 23)
xi_i := ExpandPRG_Sparse(8888, F256, n_rs, 23);

/*------------------------------------------------------------------------------
  3. LAYER 1: RSW SEQUENTIAL LOCKING & OUTSOURCED SOLVING
------------------------------------------------------------------------------*/
print "\n=== 2. LAYER 1: RSW TRAPDOOR GENERATION vs. SEQUENTIAL SOLVING ===";
a_base := Random(2, N_rsa - 2);

// Sender fast trapdoor computation O(log T)
t0 := Cputime();
e_trap := Modexp(2, T_delay, phi_N);
y_trap := Modexp(a_base, e_trap, N_rsa);
printf "  [Sender] Trapdoor y = a^(2^T mod phi(N)) mod N: %.4o sec\n", Cputime(t0);

// Untrusted Relay sequential squaring (T steps)
t0 := Cputime();
y_seq := a_base;
for step in [1..T_delay] do
    y_seq := (y_seq * y_seq) mod N_rsa;
end for;
printf "  [Relay]  Sequential %o squarings completed in:  %.4o sec | Match: %o\n",
       T_delay, Cputime(t0), (y_seq eq y_trap);
assert y_seq eq y_trap;

s_lock := y_seq mod 2^64; // HKDF-Extract simulation

/*------------------------------------------------------------------------------
  4. SCENARIO 1: DENSE MODE xi_lock + O(1) BLS12-381 BROADCAST + FUZZY DECODE
------------------------------------------------------------------------------*/
print "\n=== 3. SCENARIO 1: DENSE MODE (OTP) + BLS12-381 G_T BROADCAST ===";
xi_lock_dense := ExpandPRG_Dense(s_lock, F256, n_rs);
c_prime_dense := c_code + M_S + xi_i + xi_lock_dense;

// Benchmark single BLS12-381 pairing + O(1) broadcast encapsulation
t0 := Cputime();
k_eph := Random(1, r_bls - 1);
C1_frame := k_eph * G1; // Shared ephemeral point per frame (or per-byte)
pair_mask_enc := Pair(P_pub, G2)^k_eph;
t_enc := Cputime(t0);

// Encapsulate all 255 bytes into G_T
C2_vec := [g_T^Pack3(c_prime_dense[j], F256) * pair_mask_enc : j in [1..n_rs]];

// Receiver local split-key decryption + G_T homomorphic combine + Prefix-LUT
t0 := Cputime();
pair_mask_dec := Pair(C1_frame, S_UR + H_R)^-1;
c_pre_seq := [];
for j in [1..n_rs] do
    z_Rj := Pack3(M_R[j], F256);
    Pj := C2_vec[j] * pair_mask_dec * (g_T^z_Rj);
    Zj := LUT[PrefixTag64(Pj)];
    Append(~c_pre_seq, Unpack3(Zj, F256));
end for;
c_pre := Vector(F256, c_pre_seq);
t_dec_gt := Cputime(t0);
printf "  [BLS12-381] Local Split-Key Pairing + 255B G_T LUT Unpack: %.3o sec\n", t_dec_gt;

// Test A: Pre-release (t < T) — Authorized node tries to decode without stripping
err_pre_dense := c_pre - c_code;
ok_pre, _ := BoundedRSDecode(C_rs, c_pre, aleph);
printf "  [t < T, Dense]  Residual wt = %o (>> 63) | RS Decode: %o -> BLOCKED!\n",
       Weight(err_pre_dense), ok_pre;
assert not ok_pre;

// Test B: Post-release (t >= T) — Local carry-free stripping in GF(256)^255
t_bm := Cputime();
c_stripped := c_pre + xi_lock_dense;
ok_post, cw_rec := BoundedRSDecode(C_rs, c_stripped, aleph);
// Recover scrambled payload via linear solve
ok_sol, kappa_S := IsConsistent(G_rs, cw_rec);
kappa_rec := kappa_S * S_inv;
t_bm_elapsed := Cputime(t_bm);

printf "  [t >= T, Dense] Residual wt = %o (<= 31) | RS Decode: %o | Payload Match: %o (%.4o sec)\n",
       Weight(c_stripped - c_code), ok_post, (kappa_rec eq kappa), t_bm_elapsed;
assert ok_post and (kappa_rec eq kappa);

/*------------------------------------------------------------------------------
  5. SCENARIO 2: SPARSE MODE (w_lock = 52) & THEOREM 1 RANK BARRIER
------------------------------------------------------------------------------*/
print "\n=== 4. SCENARIO 2: SPARSE MODE (w_lock = 52) & THEOREM 1 BARRIER ===";
xi_lock_sparse := ExpandPRG_Sparse(s_lock, F256, n_rs, 52);
e_pre_sparse := xi_i + xi_lock_sparse;
W_sp := Weight(e_pre_sparse);
Delta_31 := W_sp - aleph;

// Theorem 1 Part 3 exact upper bound: Binom(W, Delta) / (Binom(255, Delta) * 255^Delta)
prob_grind := RealField(10)!Binomial(W_sp, Delta_31) /
              (RealField(10)!Binomial(n_rs, Delta_31) * (RealField(10)!255)^Delta_31);
bits_grind := -Log(prob_grind) / Log(2.0);

printf "  [t < T, Sparse] W = wt(xi_i + xi_lock) = %o (>= d_min = 64 -> Erasure-Only IMPOSSIBLE)\n", W_sp;
printf "  [Theorem 1]     Symbol-Cancellation Grinding Bound: Pr <= %.3o (~ 2^-%.1o)\n",
       prob_grind, bits_grind;
assert W_sp ge d_min;

c_pre_sp := c_code + PadAttr(delta_in) + e_pre_sparse;
ok_sp_pre, _ := BoundedRSDecode(C_rs, c_pre_sp, aleph);
ok_sp_post, cw_sp := BoundedRSDecode(C_rs, c_pre_sp + xi_lock_sparse, aleph);
printf "  [Sparse Decode] Before T: %o | After Stripping xi_lock: %o\n", ok_sp_pre, ok_sp_post;
assert (not ok_sp_pre) and ok_sp_post and (cw_sp eq c_code);

/*------------------------------------------------------------------------------
  6. SCENARIO 3: OUT-OF-COHORT SOLVER (d_H = 64) AFTER RELEASE (t >= T)
------------------------------------------------------------------------------*/
print "\n=== 5. SCENARIO 3: OUT-OF-COHORT ISOLATION (d_H = 64, t >= T) ===";
c_out_stripped := c_code + PadAttr(delta_out) + xi_i;
ok_out, _ := BoundedRSDecode(C_rs, c_out_stripped, aleph);
printf "  [Out-of-Cohort] Post-Strip wt = %o (>> J = 34) | RS Decode: %o -> ISOLATED!\n",
       Weight(c_out_stripped - c_code), ok_out;
assert not ok_out;

/*------------------------------------------------------------------------------
  7. SCENARIO 4: BASE-3 CARRY AVALANCHE (m = 3 COLLUDING OPERANDS)
------------------------------------------------------------------------------*/
print "\n=== 6. SCENARIO 4: BASE-3 CARRY AVALANCHE (m = 3 OPERANDS) ===";
M_3 := ExpandPRG_Dense(9090, F256, n_rs);
avalanche_seq := [];
for j in [1..n_rs] do
    Z3 := Pack3(c_prime_dense[j], F256) + Pack3(M_R[j], F256) + Pack3(M_3[j], F256);
    Append(~avalanche_seq, Unpack3(Z3, F256));
end for;
c_aval := Vector(F256, avalanche_seq);
ok_aval, _ := BoundedRSDecode(C_rs, c_aval, aleph);
printf "  [Coalition m=3] Corrupted Weight = %o / 255 | RS Decode: %o -> AVALANCHE!\n",
       Weight(c_aval - c_code), ok_aval;
assert not ok_aval;

printf "\n=== ALL FCTLP VERIFICATION SCENARIOS PASSED IN %.3o SEC ===\n", Cputime(t_global);
