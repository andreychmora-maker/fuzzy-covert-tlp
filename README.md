# Fuzzy Covert Time-Lock Puzzles (FCTLP)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24382646.svg)](https://doi.org/10.5281/zenodo.24382646)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Magma Compatible](https://img.shields.io/badge/Language-Magma%20V2.29--10-blue.svg)](http://magma.maths.usyd.edu.au/calc/)
[![Code Rate](https://img.shields.io/badge/Code%20Rate-R%3D0.75-green.svg)]()

This repository contains the proof-of-concept (PoC) implementation and cryptanalytic verification suite for **Fuzzy Covert Time-Lock Puzzles via Sequential Noise Stripping (FCTLP)**—a hybrid cryptographic primitive unifying sequential time-delay release, fuzzy attribute-based access control, and zero-metadata steganographic transport.

## Architectural Overview

Classical Time-Lock Puzzles (TLPs) bind decryption solely to elapsed sequential computation (<i>T</i> steps), leaving unlocked payloads publicly readable, incompatible with fuzzy attribute matching without key explosion, and trivially fingerprintable by passive Deep Packet Inspection (DPI).

The **FCTLP** resolves these limitations by decoupling the temporal barrier from the fuzzy metric and covert transport layers via **Time-Locked Noise Stripping**:

1. **Layer 1 — Sequential Time-Lock Core:** Uses repeated squaring <i>y</i> = <i>a</i><sup>2<sup><i>T</i></sup></sup> mod <i>N</i> in an unknown-order group (2048-bit RSW modulus with &#119978;(log <i>T</i>) trapdoor generation, or trustless imaginary quadratic class groups Cl(Δ<sub><i>K</i></sub>)) to derive a release seed <i>s</i><sub>lock</sub> = HKDF-Extract(<i>σ</i><sub>lock</sub>, <i>y</i>).
2. **Layer 2 — Dual-Noise Scrambled A-Scheme:** Encodes the 192-byte monolithic payload <b><i>κ</i></b><sub><i>i</i></sub> under a scrambled non-systematic Reed–Solomon code <i>C</i><sub>RS</sub>[256, 192, 65]<sub>256</sub> over the polynomial-basis field GF(256) ≅ GF(2)[<i>θ</i>]/(<i>f</i>(<i>θ</i>)) (cyclic 255-byte core with <i>d</i><sub>min</sub> = 64, unique Berlekamp–Massey radius ℵ = 31, Johnson bound <i>J</i>(255, 192) = 34, and secret scrambling matrix <b>S</b> ∈ GL(192, GF(256))). The sender superimposes a time-locked noise vector <b><i>ξ</i></b><sub>lock</sub> (either **Dense OTP Mode** in GF(256)<sup>255</sup> or **Sparse Mode** with weight <i>w</i><sub>lock</sub> = 52) on top of the persistent ephemeral half-radius blind noise <b><i>ξ</i></b><sub><i>i</i></sub> (<i>w</i><sub><i>ξ</i></sub> = 23).
3. **Layer 3 — &#119978;(1) Broadcast Encapsulation & Split-Key Helper/MPC Evaluation in &#120126;<sub><i>T</i></sub>:** Adopts the Type-3 bilinear pairing broadcast architecture of *Stealth ABBE* over **BLS12-381** (<i>e</i> : &#120126;<sub>1</sub> × &#120126;<sub>2</sub> → &#120126;<sub><i>T</i></sub>) with a strict split-key separation (&#120310;<sub><i>U<sub>R</sub></i></sub> + &#120299;<sub><i>R</i></sub> = [<i>α</i>]&#120298;<sub>2</sub>). The sender emits a single &#119978;(1) broadcast frame (with independent per-coordinate ephemeral scalars <i>k</i><sub><i>j</i></sub>) forwarded unmodified across the P2P overlay. Each receiver holds *only* its personal share &#120310;<sub><i>U<sub>R</sub></i></sub> (never seeing &#120299;<sub><i>R</i></sub> or plaintext <b><i>M</i></b><sub><i>R</i></sub>), while the Helper/MPC committee holds &#120299;<sub><i>R</i></sub>, <i>h</i><sub><i>U<sub>R</sub></i></sub> = <i>e</i>(&#120298;<sub>1</sub>, &#120310;<sub><i>U<sub>R</sub></i></sub>), and the Dealer-encrypted Access Code AC<sub><i>R</i></sub>. The Helper blindly fuses the broadcast with AC<sub><i>R</i></sub> under fresh re-randomization <i>v</i><sub><i>j</i></sub>; the receiver then runs a single-pairing decryption with −&#120310;<sub><i>U<sub>R</sub></i></sub>, unpacks carry-free **Base-3 Packing** (<i>η</i> = 8, max sum 6560) directly into GF(2)[<i>θ</i>]/(<i>f</i>(<i>θ</i>)) via an L1/L2-resident 64-bit prefix lookup table in &#120126;<sub><i>T</i></sub>, and locally strips <b><i>ξ</i></b><sub>lock</sub> in GF(256)<sup>255</sup>.
4. **Layer 4 — Zero-Metadata Uniform Wire Encoding:** Maps transmitted &#120126;<sub>1</sub> ciphertext points (both broadcast <b>C</b><sub>1,<i>j</i></sub> and helper-transformed <b>C̃</b><sub>1,<i>j</i></sub>) to uniform strings via **Elligator Squared** (using explicit constant-time inverse 11-isogenies <i>ϕ</i><sup>−1</sup> on BLS12-381) and serializes the TLP base <i>a</i> ∈ &#8484;<sub><i>N</i></sub> via constant-time wide-word **Inverse Range Sampling**, achieving statistical indistinguishability Δ(<i>P</i><sub>Π</sub>, U) ≤ 2<sup>−<i>λ</i></sup>.

## Repository Contents

- **`fctlp_bls12_381_poc.m`**: Self-contained Magma verification script executing end-to-end 2048-bit RSW locking, per-coordinate &#119978;(1) BLS12-381 broadcast encapsulation, split-key Helper/MPC blind fusion using precomputed-&#120126;<sub>2</sub> Optimal Ate pairings, single-pairing receiver decryption with 64-bit prefix-LUT polynomial-basis unpacking in &#120126;<sub><i>T</i></sub>, carry-free post-unpacking noise stripping, and four adversarial security scenarios (Dense pre-release blocking, Sparse rank-barrier & symbol-grinding bounds, out-of-cohort isolation at <i>d</i><sub>H</sub> = 64, and protocol-level Base-3 carry avalanche for <i>m</i> = 3 operands in &#120126;<sub><i>T</i></sub>).

## Empirical Verification & Benchmark (`fctlp_bls12_381_poc.m`)

The complete proof-of-concept and cryptanalytic test suite runs directly in the **Magma Online Calculator** (`http://magma.maths.usyd.edu.au/calc/`) in **15.570 seconds** (well within the 60-second web sandbox limit).

### Console Output (`Magma V2.29`)

```text
=== 1. SETUP: RS[255,192,64]_256 + RSW 2048-BIT + BLS12-381 ===
  RS[255, 192, 64]_256 & Secret S in GL(192, F_256) ready.
  RSW 2048-bit Modulus N generated in 0.240 sec (Delay T = 5000).
  BLS12-381 Setup, OptAte Precomp & G_T LUT built in 0.980 sec.
  [Dealer] Encrypted 255B Access Code AC_R provisioned to Helper in 1.200 sec.

=== 2. LAYER 1: RSW TRAPDOOR GENERATION vs. SEQUENTIAL SOLVING ===
  [Sender] Trapdoor y = a^(2^T mod phi(N)) mod N: 0.0100 sec
  [Relay]  Sequential 5000 squarings completed in:  0.0200 sec | Match: true

=== 3. SCENARIO 1: DENSE MODE (OTP) + SPLIT-KEY HELPER/MPC BROADCAST ===
  [Sender]   255B O(1) Broadcast Encapsulation (per-byte k_j): 1.200 sec
  [Helper]   255B Blind Split-Key Fusion in G_T:               4.390 sec
  [Receiver] 255B Single-Pairing Decrypt + G_T LUT Unpack:     3.080 sec
  [t < T, Dense]  Residual wt = 254 (>> 63) | RS Decode: false -> BLOCKED!
  [t >= T, Dense] Residual wt = 29 (<= 31) | RS Decode: true | Payload Match: true (0.0100 sec)

=== 4. SCENARIO 2: SPARSE MODE (w_lock = 52) & THEOREM 1 BARRIER ===
  [t < T, Sparse] W = wt(xi_i + xi_lock) = 69 (>= d_min = 64 -> Erasure-Only IMPOSSIBLE)
  [Theorem 1]     Symbol-Cancellation Grinding Bound: Pr <= 4.808E-118 (~ 2^-389.7)
  [Sparse Decode] Before T: false | After Stripping xi_lock: true

=== 5. SCENARIO 3: OUT-OF-COHORT ISOLATION (d_H = 64, t >= T) ===
  [Out-of-Cohort] Post-Strip wt = 81 (>> J = 34) | RS Decode: false -> ISOLATED!

=== 6. SCENARIO 4: PROTOCOL-LEVEL BASE-3 CARRY AVALANCHE (m = 3 IN G_T) ===
  [Coalition m=3] Std LUT Misses (Z>6560): 37 / 255 | Direct Carry Flips: 152 / 255
  [Coalition m=3] Post-Strip Corrupted Wt = 252 / 255 | RS Decode: false -> AVALANCHE! (4.380 sec)

=== ALL FCTLP VERIFICATION SCENARIOS PASSED IN 15.570 SEC ===
```

### Verification Summary Table

| Scenario | Operational / Adversarial Test Case | Observed Weight `wt(e)` | Bound (ℵ = 31, <i>J</i> = 34, <i>d</i><sub>min</sub> = 64) | RS Decode | Security Verdict |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Sc. 1A** | Pre-Release Authorized Node (<i>t</i> &lt; <i>T</i>, Dense OTP <b><i>ξ</i></b><sub>lock</sub>) | `254 / 255` | `>> 63` | `false` | 🛡️ Blocked (Sequential <i>T</i> + OTP) |
| **Sc. 1B** | Post-Release In-Cohort Receiver (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub>(<b><i>r</i></b><sub><i>S</i></sub>, <b><i>r</i></b><sub><i>R</i></sub>) = 8) | `29` | `<= 31` | `true` | ✅ Valid Blind Decode (<b><i>κ</i></b>' = <b><i>κ</i></b>) |
| **Sc. 2A** | Pre-Release Sparse Mode (<i>t</i> &lt; <i>T</i>, <i>w</i><sub>lock</sub> = 52, Theorem 1) | `69` | `>= 64` | `false` | 🛡️ No Erasure Bypass &amp; Pr ≤ 2<sup>−389.7</sup> |
| **Sc. 2B** | Post-Release Sparse Mode after Stripping <b><i>ξ</i></b><sub>lock</sub> (<i>d</i><sub>H</sub> = 8) | `29` | `<= 31` | `true` | ✅ Valid Multi-Stage Release |
| **Sc. 3** | Out-of-Cohort Solver after Release (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub> = 64) | `81` | `>> 34` | `false` | 🛡️ Isolated (&gt; 312-Bit Barrier) |
| **Sc. 4** | Protocol-Level Coalition (<i>m</i> = 3 in &#120126;<sub><i>T</i></sub>: `37` LUT misses, `152` carry flips) | `252 / 255` | `>> 34` | `false` | 🛡️ Base-3 Carry Avalanche |

## Related Research Series

- **The A-Scheme for Information-Theoretic Covert Transport:** [DOI: 10.5281/zenodo.23574958](https://doi.org/10.5281/zenodo.23574958)
- **Stealth ABBE: Carry-Free Homomorphic Packing and Blind Reed–Solomon Decoding:** [DOI: 10.5281/zenodo.23677113](https://doi.org/10.5281/zenodo.23677113)
- **Steganographic Point Obfuscation via Explicit Inverse Isogenies for *j* ∈ {0, 1728}:** [DOI: 10.5281/zenodo.23301009](https://doi.org/10.5281/zenodo.23301009)
- **Post-Quantum Stateless Steganography:** [DOI: 10.5281/zenodo.23437773](https://doi.org/10.5281/zenodo.23437773)
- **The Invariant Boundary Theorem:** [DOI: 10.5281/zenodo.23194114](https://doi.org/10.5281/zenodo.23194114)

## 📚 Academic Citation

If you utilize these constructions or Magma benchmarks in your research, please cite:

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24380778.svg)](https://doi.org/10.5281/zenodo.24380778)

```bibtex
@misc{chmora2026fctlp,
  author       = {Andrey L. Chmora},
  title        = {Fuzzy Covert Time-Lock Puzzles via Sequential Noise Stripping},
  month        = nov,
  year         = 2026,
  publisher    = {Zenodo},
  doi          = {10.5281/zenodo.24380778},
  url          = {[https://doi.org/10.5281/zenodo.24380778](https://doi.org/10.5281/zenodo.24380778)}
}
```
