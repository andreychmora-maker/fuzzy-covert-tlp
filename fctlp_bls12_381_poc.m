/*==============================================================================
  Fuzzy Covert Time-Lock Puzzle (FCTLP) — End-to-End PoC & Benchmark
  Architecture: RSW Sequential Core + Scrambled RS[255,192,64]_256 +
                Split-Key Helper/MPC O(1) Broadcast over BLS12-381
                (Precomputed-Q Optimal Ate Pairing + Fast FinalExp + G_T LUT)
  Compatible with: Magma V2.29+ / Magma Online Calculator (< 60s timeout)
==============================================================================*/

t_global := Cputime();

/*------------------------------------------------------------------------------
  0. DETERMINISTIC PRG & POLYNOMIAL-BASIS BASE-3 PACKING HELPERS
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

// Base-3 Packing in polynomial basis F_256 = F_2[theta]/(f(theta)):
// x = sum_{b=0}^7 x_b * theta^b  |-->  sum_{b=0}^7 x_b * 3^b in [0, 3280]
Pack3 := function(x, F256)
    coeffs := ElementToSequence(x);
    z := 0;
    p3 := 1;
    for b in [1..8] do
        if coeffs[b] eq GF(2)!1 then
            z +:= p3;
        end if;
        p3 *:= 3;
    end for;
    return z;
end function;

// Base-3 Unpacking directly into polynomial basis F_256:
// Z |--> sum_{b=0}^7 (((Z div 3^b) mod 3) mod 2) * theta^b
Unpack3 := function(Z, F256)
    theta := Generator(F256);
    res := F256!0;
    tmp := Z;
    p_theta := F256!1;
    for b in [0..7] do
        if ((tmp mod 3) mod 2) eq 1 then
            res +:= p_theta;
        end if;
        tmp := tmp div 3;
        p_theta *:= theta;
    end for;
    return res;
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

// 1A. Reed-Solomon [255, 192, 64] over GF(256) = F_2[theta]/(f(theta)) + S
F256<theta> := GF(2^8);
assert Unpack3(Pack3(theta^5 + theta^2 + 1, F256) + Pack3(theta^5 + theta, F256), F256)
       eq (theta^2 + theta + 1);

n_rs := 255; k_rs := 192; d_min := 64; aleph := 31; J_bound := 34;
C_rs := ReedSolomonCode(F256, d_min);
G_rs := GeneratorMatrix(C_rs);

repeat
    S_mat := RandomMatrix(F256, k_rs, k_rs);
until Determinant(S_mat) ne 0;
S_inv := S_mat^-1;
printf "  RS[255, 192, 64]_256 & Secret S in GL(192, F_256) ready.\n";

// 1B. RSW Unknown-Order Group (2048-bit RSA modulus, fast BPSW primality)
t0 := Cputime();
p_rsa := NextPrime(Random(2^1023, 2^1024 - 1) : Proof := false);
q_rsa := NextPrime(Random(2^1023, 2^1024 - 1) : Proof := false);
N_rsa := p_rsa * q_rsa;
phi_N := (p_rsa - 1) * (q_rsa - 1);
T_delay := 5000;
printf "  RSW 2048-bit Modulus N generated in %.3o sec (Delay T = %o).\n", Cputime(t0), T_delay;

// 1C. BLS12-381 Type-3 Optimal Ate Pairing Setup (G1 on E1/Fp, G2 on E2_twist/Fp2)
t0 := Cputime();
x_bls := -0xd201000000010000;
u0    := -x_bls; // 64-bit, Hamming weight 6
u0_bits := Reverse(Intseq(u0, 2)); // MSB first

p_bls := (x_bls - 1)^2 * (x_bls^4 - x_bls^2 + 1) div 3 + x_bls;
r_bls := x_bls^4 - x_bls^2 + 1;
assert (p_bls - 1) mod 6 eq 0;

Fp := GF(p_bls);
Fp2<u> := ext<Fp | Polynomial([Fp | 1, 0, 1])>;
Fp12<w> := ext<Fp2 | Polynomial([Fp2 | -(1 + u), 0, 0, 0, 0, 0, 1])>;

E1 := EllipticCurve([Fp | 0, 4]);
E2_twist := EllipticCurve([Fp2 | 0, 4*(1 + u)]);

h1 := #E1 div r_bls;
repeat
    G1_E1 := h1 * Random(E1);
until not IsZero(G1_E1);

h2 := #E2_twist div r_bls;
repeat
    G2_E2 := h2 * Random(E2_twist);
until not IsZero(G2_E2);

// Frobenius endomorphisms on Fp2 and Fp12
ConjFp2 := function(z)
    c := Eltseq(z);
    return Fp2![c[1], -c[2]];
end function;

gamma_p       := (1 + u)^((p_bls - 1) div 6);
gamma_p_pows  := [gamma_p^i : i in [0..5]];
gamma_p2      := (1 + u)^((p_bls^2 - 1) div 6);
gamma_p2_pows := [gamma_p2^i : i in [0..5]];

FrobP := function(f)
    c := Eltseq(f);
    return Fp12![ConjFp2(c[i]) * gamma_p_pows[i] : i in [1..6]];
end function;

FrobP2 := function(f)
    c := Eltseq(f);
    return Fp12![c[i] * gamma_p2_pows[i] : i in [1..6]];
end function;

FrobP6 := function(f)
    c := Eltseq(f);
    return Fp12![c[1], -c[2], c[3], -c[4], c[5], -c[6]];
end function;

// Self-check Frobenius maps
f_chk := Random(Fp12);
assert FrobP(f_chk)  eq f_chk^p_bls;
assert FrobP2(f_chk) eq f_chk^(p_bls^2);
assert FrobP6(f_chk) eq f_chk^(p_bls^6);

// Precompute doubling & addition line coefficients for a fixed Q in E2_twist[r]
PrecomputeQ := function(Q)
    XQ := Q[1]; YQ := Q[2];
    XT := XQ;   YT := YQ;
    dbl_lines := [];
    add_lines := [];
    for i in [2..#u0_bits] do
        lam := (3 * XT^2) / (2 * YT);
        c0  := lam * XT - YT;
        Append(~dbl_lines, <c0, -lam>);
        X_new := lam^2 - 2 * XT;
        Y_new := lam * (XT - X_new) - YT;
        XT := X_new; YT := Y_new;
        if u0_bits[i] eq 1 then
            lam := (YQ - YT) / (XQ - XT);
            c0  := lam * XT - YT;
            Append(~add_lines, <c0, -lam>);
            X_new := lam^2 - XT - XQ;
            Y_new := lam * (XT - X_new) - YT;
            XT := X_new; YT := Y_new;
        end if;
    end for;
    return <dbl_lines, add_lines>;
end function;

// Optimal Ate Pairing e(P, Q) with precomputed Q_pre and fast BLS12 hard-part
// Final exponent: (p^6 - 1)*(p^2 + 1) * (3*(p^4 - p^2 + 1)/r)
// where 3*(p^4 - p^2 + 1)/r = (x - 1)^2*(p + x)*(p^2 + x^2 - 1) + 3
PairPre := function(P, Q_pre)
    if IsZero(P) then return Fp12!1; end if;
    xP := Fp2!P[1];
    yP := Fp2!P[2];
    dbl_lines := Q_pre[1];
    add_lines := Q_pre[2];

    f := Fp12!1;
    add_idx := 1;
    for i in [2..#u0_bits] do
        d := dbl_lines[i - 1];
        f := f^2 * Fp12![d[1], 0, d[2] * xP, yP, 0, 0];
        if u0_bits[i] eq 1 then
            a := add_lines[add_idx];
            add_idx +:= 1;
            f *:= Fp12![a[1], 0, a[2] * xP, yP, 0, 0];
        end if;
    end for;

    // Easy part: f2 = f^((p^6 - 1)*(p^2 + 1)) in cyclotomic subgroup G_{Phi_6}
    f1 := FrobP6(f) * f^-1;
    f2 := FrobP2(f1) * f1;

    // Hard part: 5 exponentiations by 64-bit u0 (weight 6)
    t0 := f2^u0;
    t1 := t0 * f2;                     // (u0 + 1)
    t2 := (t1^u0) * t1;                // (u0 + 1)^2 = (x - 1)^2
    t3 := FrobP(t2) * FrobP6(t2^u0);   // (x - 1)^2 * (p + x)
    t4 := t3^u0;
    t5 := t4^u0;                       // (x - 1)^2 * (p + x) * x^2
    t6 := FrobP2(t3) * t5 * FrobP6(t3);// (x - 1)^2 * (p + x) * (p^2 + x^2 - 1)
    return t6 * (f2^2 * f2);           // + 3
end function;

// 4-bit fixed-base exponentiation table in G_T
BuildPowTable := function(base, nbits)
    nwin := (nbits + 3) div 4;
    tbl := [];
    cur_base := base;
    for w_idx in [1..nwin] do
        row := [cur_base];
        for d in [2..15] do
            Append(~row, row[d - 1] * cur_base);
        end for;
        Append(~tbl, row);
        cur_base := row[15] * cur_base;
    end for;
    return tbl;
end function;

FastPow := function(tbl, e)
    if e eq 0 then return Fp12!1; end if;
    digs := Intseq(e, 16);
    res := Fp12!1;
    for i in [1..#digs] do
        d := digs[i];
        if d ne 0 then
            res *:= tbl[i][d];
        end if;
    end for;
    return res;
end function;

// Self-check non-degeneracy, order, and bilinearity of PairPre
pre_G2 := PrecomputeQ(G2_E2);
g_T    := PairPre(G1_E1, pre_G2);
assert (g_T ne Fp12!1) and (g_T^r_bls eq Fp12!1);
chk_a := Random(1, r_bls - 1);
chk_b := Random(1, r_bls - 1);
assert PairPre(chk_a * G1_E1, PrecomputeQ(chk_b * G2_E2)) eq g_T^((chk_a * chk_b) mod r_bls);

alpha_msk := Random(1, r_bls - 1);
P_pub_E1  := alpha_msk * G1_E1;
pair_pub  := PairPre(P_pub_E1, pre_G2);

// True Split-Key Provisioning for Receiver U_R:
//   - Receiver U_R holds ONLY S_UR (never sees H_R or plaintext M_R)
//   - Helper / MPC holds ONLY H_R, h_UR = e(G1, S_UR), and encrypted AC_R
s_share  := Random(1, r_bls - 1);
S_UR     := s_share * G2_E2;
neg_S_UR := -S_UR;
H_R      := ((alpha_msk - s_share) mod r_bls) * G2_E2;
neg_H_R  := -H_R;
assert S_UR + H_R eq alpha_msk * G2_E2;

pre_S_UR     := PrecomputeQ(S_UR);
pre_neg_S_UR := PrecomputeQ(neg_S_UR);
pre_neg_H_R  := PrecomputeQ(neg_H_R);
h_UR         := PairPre(G1_E1, pre_S_UR);
assert pair_pub * PairPre(G1_E1, pre_neg_H_R) eq h_UR;

pair_pub_tbl := BuildPowTable(pair_pub, 256);
h_UR_tbl     := BuildPowTable(h_UR, 256);
assert FastPow(h_UR_tbl, chk_a) eq h_UR^chk_a;

// Build 64-bit Prefix-LUT in G_T for protocol [0..6560], precomputed gT_pow [0..3280],
// and extended LUT_ext [0..9840] solely for Scenario 4 carry-avalanche analysis
t_lut := Cputime();
LUT := AssociativeArray();
LUT_ext := AssociativeArray();
gT_pow := [];
cur := Fp12!1;
for Z in [0..9840] do
    if Z le 3280 then Append(~gT_pow, cur); end if;
    tag := PrefixTag64(cur);
    if Z le 6560 then LUT[tag] := Z; end if;
    LUT_ext[tag] := Z;
    cur *:= g_T;
end for;
printf "  BLS12-381 Setup, OptAte Precomp & G_T LUT built in %.3o sec.\n", Cputime(t0);

/*------------------------------------------------------------------------------
  2. COHORT PROVISIONING, ENCRYPTED ACCESS CODE AC_R & MONOLITHIC PAYLOAD
------------------------------------------------------------------------------*/
// Instance-specific blinding factor m in F_256^255 (wt(m) > aleph)
// Cohort-isolating blocker w in F_256^127 (active slice of w in F_256^128 on
// the punctured 255B cyclic RS core; wt(w) > aleph)
w_len  := n_rs - 128; // 127 bytes
w_mask := ExpandPRG_Dense(1001, F256, w_len);
w_out  := ExpandPRG_Dense(1002, F256, w_len); // differing-cohort blocker
m_mask := ExpandPRG_Dense(2002, F256, n_rs);
assert (Weight(w_mask) gt aleph) and (Weight(w_out) gt aleph) and (Weight(m_mask) gt aleph);

// Sender attributes r_S, In-cohort r_R (d_H = 8), Out-of-cohort r_Out (d_H = 64)
r_S := ExpandPRG_Dense(3003, F256, 128);
delta_in  := ExpandPRG_Sparse(4004, F256, 128, 8);
delta_out := ExpandPRG_Sparse(5005, F256, 128, 64);
r_R   := r_S + delta_in;
r_Out := r_S + delta_out;

// Concatenation (w || r) in F_256^255 and zero-padded attribute diff (0_127 || dr)
ConcatWR := func<w_vec, r_vec | Vector(F256, Eltseq(w_vec) cat Eltseq(r_vec))>;
PadAttr  := func<r_vec | Vector(F256, [F256!0 : i in [1..w_len]] cat Eltseq(r_vec))>;

// M = m + (w || r): same-cohort cancels both m and w -> (0_127 || delta_r)
M_S        := m_mask + ConcatWR(w_mask, r_S);
M_R        := m_mask + ConcatWR(w_mask, r_R);
M_Out_cons := m_mask + ConcatWR(w_mask, r_Out); // conservative (neglecting Delta w)
M_Out_full := m_mask + ConcatWR(w_out,  r_Out); // full differing cohort (Delta w + Delta r)
assert (M_S + M_R) eq PadAttr(delta_in);
assert (M_S + M_Out_cons) eq PadAttr(delta_out);

// Dealer encrypts M_R into AC_R under h_UR = e(G1, S_UR) and provisions Helper
t0 := Cputime();
AC_A1_E1 := [];
AC_A2    := [];
for j in [1..n_rs] do
    u_j  := Random(1, r_bls - 1);
    z_Rj := Pack3(M_R[j], F256);
    Append(~AC_A1_E1, u_j * G1_E1);
    Append(~AC_A2, gT_pow[z_Rj + 1] * FastPow(h_UR_tbl, u_j));
end for;
printf "  [Dealer] Encrypted 255B Access Code AC_R provisioned to Helper in %.3o sec.\n", Cputime(t0);

// 192-byte monolithic payload kappa & scrambled codeword c = kappa * S * G_rs
kappa  := ExpandPRG_Dense(7777, F256, k_rs);
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
  4. SCENARIO 1: DENSE MODE xi_lock + PER-COORDINATE SPLIT-KEY BLS12-381
------------------------------------------------------------------------------*/
print "\n=== 3. SCENARIO 1: DENSE MODE (OTP) + SPLIT-KEY HELPER/MPC BROADCAST ===";
xi_lock_dense := ExpandPRG_Dense(s_lock, F256, n_rs);
c_prime_dense := c_code + M_S + xi_i + xi_lock_dense;

// Step 4A: Sender O(1) broadcast encapsulation (independent k_j per coordinate)
t0 := Cputime();
C1_E1  := [];
C2_vec := [];
for j in [1..n_rs] do
    k_j  := Random(1, r_bls - 1);
    z_Sj := Pack3(c_prime_dense[j], F256);
    Append(~C1_E1, k_j * G1_E1);
    Append(~C2_vec, gT_pow[z_Sj + 1] * FastPow(pair_pub_tbl, k_j));
end for;
t_enc := Cputime(t0);
printf "  [Sender]   255B O(1) Broadcast Encapsulation (per-byte k_j): %.3o sec\n", t_enc;

// Step 4B: Helper / MPC blind split-key fusion (re-randomized via v_j)
// Helper knows ONLY (pre_neg_H_R, h_UR, AC_R) — learns neither z_S nor z_R
t0 := Cputime();
C1_tilde_E1 := [];
C2_tilde    := [];
for j in [1..n_rs] do
    v_j  := Random(1, r_bls - 1);
    c1_t := C1_E1[j] + AC_A1_E1[j] + v_j * G1_E1;
    c2_t := C2_vec[j] * AC_A2[j] * PairPre(C1_E1[j], pre_neg_H_R) * FastPow(h_UR_tbl, v_j);
    Append(~C1_tilde_E1, c1_t);
    Append(~C2_tilde, c2_t);
end for;
t_helper := Cputime(t0);
printf "  [Helper]   255B Blind Split-Key Fusion in G_T:               %.3o sec\n", t_helper;

// Step 4C: Receiver single-pairing decryption (uses ONLY pre_neg_S_UR) + Prefix-LUT
t0 := Cputime();
c_pre_seq := [];
for j in [1..n_rs] do
    Pj := C2_tilde[j] * PairPre(C1_tilde_E1[j], pre_neg_S_UR);
    ok_lut, Zj := IsDefined(LUT, PrefixTag64(Pj));
    assert ok_lut;
    Append(~c_pre_seq, Unpack3(Zj, F256));
end for;
c_pre := Vector(F256, c_pre_seq);
t_recv := Cputime(t0);
printf "  [Receiver] 255B Single-Pairing Decrypt + G_T LUT Unpack:     %.3o sec\n", t_recv;
assert c_pre eq (c_prime_dense + M_R);

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

c_pre_sp := c_code + (M_S + M_R) + e_pre_sparse;
ok_sp_pre, _ := BoundedRSDecode(C_rs, c_pre_sp, aleph);
ok_sp_post, cw_sp := BoundedRSDecode(C_rs, c_pre_sp + xi_lock_sparse, aleph);
printf "  [Sparse Decode] Before T: %o | After Stripping xi_lock: %o\n", ok_sp_pre, ok_sp_post;
assert (not ok_sp_pre) and ok_sp_post and (cw_sp eq c_code);

/*------------------------------------------------------------------------------
  6. SCENARIO 3: OUT-OF-COHORT SOLVER (d_H = 64) AFTER RELEASE (t >= T)
------------------------------------------------------------------------------*/
print "\n=== 5. SCENARIO 3: OUT-OF-COHORT ISOLATION (d_H = 64, t >= T) ===";
// Conservative bound (neglecting Delta w, Proposition 1): M_S + M_Out_cons = (0 || delta_out)
c_out_cons := c_code + (M_S + M_Out_cons) + xi_i;
ok_out_cons, _ := BoundedRSDecode(C_rs, c_out_cons, aleph);
printf "  [Out-of-Cohort, Delta_w=0] Post-Strip wt = %o (>> J = 34) | RS Decode: %o -> ISOLATED!\n",
       Weight(c_out_cons - c_code), ok_out_cons;
assert not ok_out_cons;

// Full differing cohort (Delta w != 0 and Delta r): M_S + M_Out_full = (Delta w || delta_out)
c_out_full := c_code + (M_S + M_Out_full) + xi_i;
ok_out_full, _ := BoundedRSDecode(C_rs, c_out_full, aleph);
printf "  [Out-of-Cohort, Full]      Post-Strip wt = %o (>> J = 34) | RS Decode: %o -> ISOLATED!\n",
       Weight(c_out_full - c_code), ok_out_full;
assert not ok_out_full;

/*------------------------------------------------------------------------------
  7. SCENARIO 4: PROTOCOL-LEVEL BASE-3 CARRY AVALANCHE (m = 3 IN G_T)
------------------------------------------------------------------------------*/
print "\n=== 6. SCENARIO 4: PROTOCOL-LEVEL BASE-3 CARRY AVALANCHE (m = 3 IN G_T) ===";
M_3 := ExpandPRG_Dense(9090, F256, n_rs);

// Colluding Helper fuses a 3rd encrypted Access Code AC_3 (under h_UR) into CT_tilde
t0 := Cputime();
lut_misses  := 0;
carry_flips := 0;
avalanche_seq := [];
for j in [1..n_rs] do
    u3_j := Random(1, r_bls - 1);
    z_3j := Pack3(M_3[j], F256);
    c1_coal := C1_tilde_E1[j] + u3_j * G1_E1;
    c2_coal := C2_tilde[j] * gT_pow[z_3j + 1] * FastPow(h_UR_tbl, u3_j);

    // Receiver decrypts fused 3-operand ciphertext with pre_neg_S_UR
    P_coal := c2_coal * PairPre(c1_coal, pre_neg_S_UR);
    tag := PrefixTag64(P_coal);
    ok_std, _ := IsDefined(LUT, tag);
    if not ok_std then lut_misses +:= 1; end if;

    // Even with an adversary-expanded LUT [0..9840], ternary carries corrupt XOR
    ok_ext, Z3 := IsDefined(LUT_ext, tag);
    assert ok_ext;
    unpacked := Unpack3(Z3, F256);
    if unpacked ne (c_prime_dense[j] + M_R[j] + M_3[j]) then
        carry_flips +:= 1;
    end if;
    Append(~avalanche_seq, unpacked);
end for;
c_aval := Vector(F256, avalanche_seq);
c_aval_stripped := c_aval + xi_lock_dense;
ok_aval, _ := BoundedRSDecode(C_rs, c_aval_stripped, aleph);

printf "  [Coalition m=3] Std LUT Misses (Z>6560): %o / 255 | Direct Carry Flips: %o / 255\n",
       lut_misses, carry_flips;
printf "  [Coalition m=3] Post-Strip Corrupted Wt = %o / 255 | RS Decode: %o -> AVALANCHE! (%.3o sec)\n",
       Weight(c_aval_stripped - c_code), ok_aval, Cputime(t0);
assert (lut_misses gt 0) and (carry_flips gt 0) and (not ok_aval);

printf "\n=== ALL FCTLP VERIFICATION SCENARIOS PASSED IN %.3o SEC ===\n", Cputime(t_global);
