# Fuzzy Covert Time-Lock Puzzles (FCTLP)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24380778.svg)](https://doi.org/10.5281/zenodo.24380778)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Magma Compatible](https://img.shields.io/badge/Language-Magma%20V2.29--10-blue.svg)](http://magma.maths.usyd.edu.au/calc/)
[![Code Rate](https://img.shields.io/badge/Code%20Rate-R%3D0.75-green.svg)]()

This repository contains the proof-of-concept (PoC) implementation and cryptanalytic verification suite for **Fuzzy Covert Time-Lock Puzzles via Sequential Noise Stripping (FCTLP)**—a hybrid cryptographic primitive unifying sequential time-delay release, fuzzy attribute-based access control, and zero-metadata steganographic transport.

## Architectural Overview

Classical Time-Lock Puzzles (TLPs) bind decryption solely to elapsed sequential computation (<i>T</i> steps), leaving unlocked payloads publicly readable, incompatible with fuzzy attribute matching without key explosion, and trivially fingerprintable by passive Deep Packet Inspection (DPI).

The **FCTLP** resolves these limitations by decoupling the temporal barrier from the fuzzy metric and covert transport layers via **Time-Locked Noise Stripping**:

1. **Layer 1 — Sequential Time-Lock Core:** Uses repeated squaring <i>y</i> = <i>a</i><sup>2<sup><i>T</i></sup></sup> mod <i>N</i> in an unknown-order group (2048-bit RSW modulus with &#119978;(log <i>T</i>) trapdoor generation, or trustless imaginary quadratic class groups Cl(Δ<sub><i>K</i></sub>)) to derive a release seed <i>s</i><sub>lock</sub> = HKDF-Extract(<i>σ</i><sub>lock</sub>, <i>y</i>).
2. **Layer 2 — Dual-Noise Scrambled A-Scheme:** Encodes the 192-byte monolithic payload <b><i>κ</i></b><sub><i>i</i></sub> under a scrambled non-systematic Reed–Solomon code <i>C</i><sub>RS</sub>[256, 192, 65]<sub>256</sub> (cyclic 255-byte core with <i>d</i><sub>min</sub> = 64, unique Berlekamp–Massey radius ℵ = 31, Johnson bound <i>J</i>(255, 192) = 34, and secret scrambling matrix <b>S</b> ∈ GL(192, GF(256))). The sender superimposes a time-locked noise vector <b><i>ξ</i></b><sub>lock</sub> (either **Dense OTP Mode** in GF(256)<sup>255</sup> or **Sparse Mode** with weight <i>w</i><sub>lock</sub> = 52) on top of the persistent ephemeral half-radius blind noise <b><i>ξ</i></b><sub><i>i</i></sub> (<i>w</i><sub><i>ξ</i></sub> = 23).
3. **Layer 3 — &#119978;(1) Broadcast Encryption & Local Pairing Evaluation in &#120126;<sub><i>T</i></sub>:** Adopts the Type-3 bilinear pairing broadcast architecture of *Stealth ABBE* over **BLS12-381** (<i>e</i> : &#120126;<sub>1</sub> × &#120126;<sub>2</sub> → &#120126;<sub><i>T</i></sub>). A single &#119978;(1) broadcast ciphertext is forwarded unmodified by relays (zero per-user server overhead), while each authorized receiver locally decrypts via its split key (&#120310;<sub><i>U<sub>R</sub></i></sub> + &#120299;<sub><i>R</i></sub> = [<i>α</i>]&#120298;<sub>2</sub>), evaluates carry-free **Base-3 Packing** (<i>η</i> = 8, max sum 6560) in &#120126;<sub><i>T</i></sub> via an L1/L2-resident 64-bit prefix lookup table, and strips <b><i>ξ</i></b><sub>lock</sub> in GF(256)<sup>255</sup> after unpacking.
4. **Layer 4 — Zero-Metadata Uniform Wire Encoding:** Maps &#120126;<sub>1</sub> ciphertext points to uniform strings via **Elligator Squared** (using explicit constant-time inverse 11-isogenies <i>ϕ</i><sup>−1</sup> on BLS12-381) and serializes the TLP base <i>a</i> ∈ &#8484;<sub><i>N</i></sub> via constant-time wide-word **Inverse Range Sampling**, achieving statistical indistinguishability Δ(<i>P</i><sub>Π</sub>, U) ≤ 2<sup>−<i>λ</i></sup>.

## Repository Contents

- **`fctlp_bls12_381_poc.m`**: Self-contained Magma verification script executing end-to-end 2048-bit RSW locking, BLS12-381 Type-3 pairing broadcast encapsulation, 64-bit prefix-LUT resolution in &#120126;<sub><i>T</i></sub>, carry-free post-unpacking noise stripping, and four adversarial security scenarios (Dense pre-release blocking, Sparse rank-barrier & symbol-grinding bounds, out-of-cohort isolation at <i>d</i><sub>H</sub> = 64, and Base-3 carry avalanche for <i>m</i> = 3 colluding operands).

## Empirical Verification & Benchmark (`fctlp_bls12_381_poc.m`)

The complete proof-of-concept and cryptanalytic test suite runs directly in the **Magma Online Calculator** (`http://magma.maths.usyd.edu.au/calc/`) in **7.370 seconds** (well within the 60-second web sandbox limit).

### Console Output (`Magma V2.29`)

```text
=== 1. SETUP: RS[255,192,64]_256 + RSW 2048-BIT + BLS12-381 ===
  RS[255, 192, 64]_256 & Secret S in GL(192, F_256) ready.
  RSW 2048-bit Modulus N generated in 5.900 sec (Delay T = 5000).
  BLS12-381 Setup & 6561-entry G_T Prefix-LUT built in 0.330 sec.

=== 2. LAYER 1: RSW TRAPDOOR GENERATION vs. SEQUENTIAL SOLVING ===
  [Sender] Trapdoor y = a^(2^T mod phi(N)) mod N: 0.0100 sec
  [Relay]  Sequential 5000 squarings completed in:  0.0100 sec | Match: true

=== 3. SCENARIO 1: DENSE MODE (OTP) + BLS12-381 G_T BROADCAST ===
  [BLS12-381] Local Split-Key Pairing + 255B G_T LUT Unpack: 0.330 sec
  [t < T, Dense]  Residual wt = 254 (>> 63) | RS Decode: false -> BLOCKED!
  [t >= T, Dense] Residual wt = 29 (<= 31) | RS Decode: true | Payload Match: true (0.0100 sec)

=== 4. SCENARIO 2: SPARSE MODE (w_lock = 52) & THEOREM 1 BARRIER ===
  [t < T, Sparse] W = wt(xi_i + xi_lock) = 73 (>= d_min = 64 -> Erasure-Only IMPOSSIBLE)
  [Theorem 1]     Symbol-Cancellation Grinding Bound: Pr <= 1.377E-129 (~ 2^-428.1)
  [Sparse Decode] Before T: false | After Stripping xi_lock: true

=== 5. SCENARIO 3: OUT-OF-COHORT ISOLATION (d_H = 64, t >= T) ===
  [Out-of-Cohort] Post-Strip wt = 81 (>> J = 34) | RS Decode: false -> ISOLATED!

=== 6. SCENARIO 4: BASE-3 CARRY AVALANCHE (m = 3 OPERANDS) ===
  [Coalition m=3] Corrupted Weight = 254 / 255 | RS Decode: false -> AVALANCHE!

=== ALL FCTLP VERIFICATION SCENARIOS PASSED IN 7.370 SEC ===
```

### Verification Summary Table

| Scenario | Operational / Adversarial Test Case | Observed Weight `wt(e)` | Bound (ℵ = 31, <i>J</i> = 34, <i>d</i><sub>min</sub> = 64) | RS Decode | Security Verdict |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Sc. 1A** | Pre-Release Authorized Node (<i>t</i> &lt; <i>T</i>, Dense OTP <b><i>ξ</i></b><sub>lock</sub>) | `254 / 255` | `>> 63` | `false` | 🛡️ Blocked (Sequential <i>T</i> + OTP) |
| **Sc. 1B** | Post-Release In-Cohort Receiver (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub>(<b><i>r</i></b><sub><i>S</i></sub>, <b><i>r</i></b><sub><i>R</i></sub>) = 8) | `29` (`6 + 23`) | `<= 31` | `true` | ✅ Valid Blind Decode (<b><i>κ</i></b>' = <b><i>κ</i></b>) |
| **Sc. 2A** | Pre-Release Sparse Mode (<i>t</i> &lt; <i>T</i>, <i>w</i><sub>lock</sub> = 52, Theorem 1) | `73` | `>= 64` | `false` | 🛡️ No Erasures &amp; Pr ≤ 2<sup>−428.1</sup> |
| **Sc. 2B** | Post-Release Sparse Mode after Stripping <b><i>ξ</i></b><sub>lock</sub> | `23` (`0 + 23`) | `<= 31` | `true` | ✅ Valid Multi-Stage Release |
| **Sc. 3** | Out-of-Cohort Solver after Release (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub> = 64) | `81` | `>> 34` | `false` | 🛡️ Isolated (&gt; 312-Bit Barrier) |
| **Sc. 4** | Homomorphic Coalition Attack (<i>m</i> = 3 Operands in &#120126;<sub><i>T</i></sub>) | `254 / 255` | `>> 34` | `false` | 🛡️ Base-3 Carry Avalanche |

## Related Research Series

- **The A-Scheme for Information-Theoretic Covert Transport:** [DOI: 10.5281/zenodo.23574958](https://doi.org/10.5281/zenodo.23574958)
- **Stealth ABBE: Carry-Free Homomorphic Packing and Blind Reed–Solomon Decoding:** [DOI: 10.5281/zenodo.23677113](https://doi.org/10.5281/zenodo.23677113)
- **Steganographic Point Obfuscation via Explicit Inverse Isogenies for *j* ∈ {0, 1728}:** [DOI: 10.5281/zenodo.23301009](https://doi.org/10.5281/zenodo.23301009)
- **Post-Quantum Stateless Steganography:** [DOI: 10.5281/zenodo.23437773](https://doi.org/10.5281/zenodo.23437773)
- **The Invariant Boundary Theorem:** [DOI: 10.5281/zenodo.23194114](https://doi.org/10.5281/zenodo.23194114)

## 📚 Academic Citation

If you utilize these constructions or Magma benchmarks in your research, please cite:

```bibtex
@misc{chmora2026fctlp,
  author       = {Andrey L. Chmora},
  title        = {Fuzzy Covert Time-Lock Puzzles via Sequential Noise Stripping},
  month        = nov,
  year         = {2026},
  publisher    = {Zenodo}
}
```
