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
2. **Layer 2 — Dual-Noise Scrambled A-Scheme:** Encodes the 192-byte monolithic payload <b><i>κ</i></b><sub><i>i</i></sub> under a scrambled non-systematic Reed–Solomon code <i>C</i><sub>RS</sub>[256, 192, 65]<sub>256</sub> over the polynomial-basis field GF(256) ≅ GF(2)[<i>θ</i>]/(<i>f</i>(<i>θ</i>)) (cyclic 255-byte core with <i>d</i><sub>min</sub> = 64, unique Berlekamp–Massey radius ℵ = 31, Johnson bound <i>J</i>(255, 192) = 34, and secret scrambling matrix <b>S</b> ∈ GL(192, GF(256))). Codewords are masked via <b>M</b> = <b>m</b> ⊕ (<b>w</b> ‖ <b>r</b>) together with the persistent ephemeral half-radius blind noise <b><i>ξ</i></b><sub><i>i</i></sub> (<i>w</i><sub><i>ξ</i></sub> = 23) and the time-locked noise vector <b><i>ξ</i></b><sub>lock</sub> (either **Dense OTP Mode** in GF(256)<sup>255</sup> or **Sparse Mode** with weight <i>w</i><sub>lock</sub> = 52).
3. **Layer 3 — Zero-RTT &#119978;(1) Broadcast Encapsulation & Local Pairing Decryption:** Adopts the native Type-3 pairing broadcast architecture of *Stealth ABBE* over **BLS12-381** (<i>e</i> : &#120126;<sub>1</sub> × &#120126;<sub>2</sub> → &#120126;<sub><i>T</i></sub>, prime order ℓ). The sender emits a single &#119978;(1) ElGamal broadcast frame strictly in &#120126;<sub>1</sub> × &#120126;<sub>1</sub> (independent per-coordinate ephemeral scalars <i>k</i><sub><i>j</i></sub>, requiring zero pairings or &#120126;<sub><i>T</i></sub> exponentiations at the sender) that P2P relays forward unmodified with zero online helper interaction. During one-time cohort provisioning, each receiver obtains its encrypted Access Code AC<sub><i>R</i></sub> ∈ (&#120126;<sub>1</sub> × &#120126;<sub>1</sub>)<sup>256</sup> over <b>M</b><sub><i>R</i></sub> = <b>m</b> ⊕ (<b>w</b> ‖ <b>r</b><sub><i>R</i></sub>) and split key pair (&#120310;<sub><i>U<sub>R</sub></i></sub>, &#120299;<sub><i>R</i></sub>) satisfying &#120310;<sub><i>U<sub>R</sub></i></sub> + &#120299;<sub><i>R</i></sub> = [<i>α</i>]&#120298;<sub>2</sub>. Passively (0-RTT), the receiver computes local homomorphic addition CT̂<sub><i>R</i></sub> = CT<sub><i>S</i></sub> + AC<sub><i>R</i></sub> in &#120126;<sub>1</sub> × &#120126;<sub>1</sub>, projects into &#120126;<sub><i>T</i></sub> via a dual-pairing product sharing a single final exponentiation, unpacks carry-free **Base-3 Packing** (<i>η</i> = 8, max sum 6560) directly into GF(2)[<i>θ</i>]/(<i>f</i>(<i>θ</i>)) via an L1/L2-resident 64-bit prefix lookup table in &#120126;<sub><i>T</i></sub>, and locally strips <b><i>ξ</i></b><sub>lock</sub> in GF(256)<sup>255</sup>.
4. **Layer 4 — Zero-Metadata Uniform Wire Encoding:** Because every broadcast ciphertext block resides strictly in &#120126;<sub>1</sub> × &#120126;<sub>1</sub> (with no cyclotomic &#120126;<sub><i>T</i></sub> ⊂ &#120125;<sub><i>p</i><sup>12</sup></sub><sup>*</sup> elements ever traversing the wire), both transmitted points <b>C</b><sub>1,<i>j</i></sub>, <b>C</b><sub>2,<i>j</i></sub> ∈ &#120126;<sub>1</sub> are mapped to uniform strings via **Elligator Squared** (using explicit constant-time inverse 11-isogenies <i>ϕ</i><sup>−1</sup> on BLS12-381), while the TLP base <i>a</i> ∈ &#8484;<sub><i>N</i></sub> is serialized via constant-time wide-word **Inverse Range Sampling**, achieving statistical indistinguishability Δ(<i>P</i><sub>Π</sub>, U) ≤ 2<sup>−<i>λ</i></sup>.

## Repository Contents

- **`fctlp_bls12_381_poc.m`**: Self-contained Magma verification script executing end-to-end 2048-bit RSW locking, per-coordinate &#119978;(1) zero-RTT BLS12-381 broadcast encapsulation in &#120126;<sub>1</sub> × &#120126;<sub>1</sub>, exact cohort-blocker masking <b>m</b> ⊕ (<b>w</b> ‖ <b>r</b>), local homomorphic addition in &#120126;<sub>1</sub> × &#120126;<sub>1</sub>, dual-pairing Optimal Ate projection with shared final exponentiation and 64-bit prefix-LUT polynomial-basis unpacking in &#120126;<sub><i>T</i></sub>, carry-free post-unpacking noise stripping, and four adversarial security scenarios (Dense pre-release blocking, Sparse rank-barrier & symbol-grinding bounds, conservative and full out-of-cohort isolation at <i>d</i><sub>H</sub> = 64, and protocol-level Base-3 carry avalanche for <i>m</i> = 3 operands in &#120126;<sub>1</sub> × &#120126;<sub>1</sub>).

## Empirical Verification & Benchmark (`fctlp_bls12_381_poc.m`)

### Console Output (`Magma V2.29`)

```text
=== 1. SETUP: RS[255,192,64]_256 + RSW 2048-BIT + BLS12-381 ===
  RS[255, 192, 64]_256 & Secret S in GL(192, F_256) ready.
  RSW 2048-bit Modulus N generated in 0.190 sec (Delay T = 5000).
  BLS12-381 Setup, OptAte Precomp & G_T LUT built in 0.850 sec.
  [Dealer] 255B Encrypted Access Code AC_R (G_1 x G_1) built in 1.200 sec.

=== 2. LAYER 1: RSW TRAPDOOR GENERATION vs. SEQUENTIAL SOLVING ===
  [Sender] Trapdoor y = a^(2^T mod phi(N)) mod N: 0.0100 sec
  [Relay]  Sequential 5000 squarings completed in:  0.0200 sec | Match: true

=== 3. SCENARIO 1: DENSE MODE (OTP) + 0-RTT G_1 x G_1 BROADCAST ===
  [Sender]   255B O(1) 0-RTT Broadcast (G_1 x G_1):             1.200 sec
  [Receiver] 255B Local 0-RTT Homomorphic Add (G_1 x G_1):      0.0100 sec
  [Receiver] 255B Dual-Pairing Decrypt (Shared FE) + LUT:       3.680 sec
  [t < T, Dense]  Residual wt = 254 (>> 63) | RS Decode: false -> BLOCKED!
  [t >= T, Dense] Residual wt = 29 (<= 31) | RS Decode: true | Payload Match: true (0.0100 sec)

=== 4. SCENARIO 2: SPARSE MODE (w_lock = 52) & THEOREM 1 BARRIER ===
  [t < T, Sparse] W = wt(xi_i + xi_lock) = 71 (>= d_min = 64 -> Erasure-Only IMPOSSIBLE)
  [Theorem 1]     Symbol-Cancellation Grinding Bound: Pr <= 7.840E-124 (~ 2^-408.9)
  [Sparse Decode] Before T: false | After Stripping xi_lock: true

=== 5. SCENARIO 3: OUT-OF-COHORT ISOLATION (d_H = 64, t >= T) ===
  [Out-of-Cohort, Delta_w=0] Post-Strip wt = 81 (>> J = 34) | RS Decode: false -> ISOLATED!
  [Out-of-Cohort, Full]      Post-Strip wt = 193 (>> J = 34) | RS Decode: false -> ISOLATED!

=== 6. SCENARIO 4: PROTOCOL-LEVEL BASE-3 CARRY AVALANCHE (m = 3 IN G_1 x G_1) ===
  [Coalition m=3] Std LUT Misses (Z>6560): 52 / 255 | Direct Carry Flips: 154 / 255
  [Coalition m=3] Post-Strip Corrupted Wt = 252 / 255 | RS Decode: false -> AVALANCHE! (4.900 sec)

=== ALL FCTLP VERIFICATION SCENARIOS PASSED IN 12.120 SEC ===
```

## Benchmark & Verification Summary (`Magma V2.29`)

Executed end-to-end in **12.120 sec** (`RSW 2048-bit`: `0.190 s` modulus setup, `0.010 s` trapdoor vs. `0.020 s` for 5,000 sequential squarings; `BLS12-381`: `0.850 s` setup & LUT, `1.200 s` one-time Dealer AC<sub><i>R</i></sub>, `1.200 s` Sender &#119978;(1) 0-RTT broadcast in &#120126;<sub>1</sub> × &#120126;<sub>1</sub>, `0.010 s` Receiver local 0-RTT add, `3.680 s` Receiver dual-pairing decrypt with shared final exponentiation + LUT unpack, `0.010 s` RS decode + <b>S</b><sup>−1</sup> recovery):

| Scenario | Operational / Adversarial Test Case | Observed Weight `wt(e)` | Bound (ℵ = 31, <i>J</i> = 34, <i>d</i><sub>min</sub> = 64) | RS Decode | Verdict |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Sc. 1A** | Pre-Release Authorized Node (<i>t</i> &lt; <i>T</i>, Dense OTP <b><i>ξ</i></b><sub>lock</sub>) | `254 / 255` | `>> 63` | `false` | 🛡️ Blocked (Sequential <i>T</i> + OTP) |
| **Sc. 1B** | Post-Release In-Cohort Receiver (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub> = 8) | `29` | `<= 31` | `true` | ✅ Exact Payload Match (<b><i>κ</i></b>' = <b><i>κ</i></b>) |
| **Sc. 2A** | Pre-Release Sparse Mode (<i>t</i> &lt; <i>T</i>, <i>w</i><sub>lock</sub> = 52, Theorem 1) | `71` | `>= 64` | `false` | 🛡️ No Erasure Bypass &amp; Pr ≤ 2<sup>−408.9</sup> |
| **Sc. 2B** | Post-Release Sparse Mode after Stripping <b><i>ξ</i></b><sub>lock</sub> (<i>d</i><sub>H</sub> = 8) | `29` | `<= 31` | `true` | ✅ Valid Multi-Stage Release |
| **Sc. 3A** | Out-of-Cohort Solver after Release (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub> = 64, Δ<b>w</b> = <b>0</b>) | `81` | `>> 34` | `false` | 🛡️ Isolated (&gt; 312-Bit Barrier) |
| **Sc. 3B** | Full Differing Cohort after Release (<i>t</i> ≥ <i>T</i>, <i>d</i><sub>H</sub> = 64, Δ<b>w</b> ≠ <b>0</b>) | `193` | `>> 34` | `false` | 🛡️ Isolated (Δ<b>w</b> ‖ Δ<b>r</b> Barrier) |
| **Sc. 4** | Protocol-Level Coalition (<i>m</i> = 3 in &#120126;<sub>1</sub> × &#120126;<sub>1</sub>: `52` LUT misses, `154` carry flips) | `252 / 255` | `>> 34` | `false` | 🛡️ Base-3 Carry Avalanche |

## Related Research Series

- **The A-Scheme for Information-Theoretic Covert Transport:** [DOI: 10.5281/zenodo.23574958](https://doi.org/10.5281/zenodo.23574958)
- **Stealth ABBE: Carry-Free Homomorphic Packing and Blind Reed–Solomon Decoding:** [DOI: 10.5281/zenodo.23677113](https://doi.org/10.5281/zenodo.23677113)
- **Steganographic Point Obfuscation via Explicit Inverse Isogenies for *j* ∈ {0, 1728}:** [DOI: 10.5281/zenodo.23301009](https://doi.org/10.5281/zenodo.23301009)
- **Post-Quantum Stateless Steganography:** [DOI: 10.5281/zenodo.23437773](https://doi.org/10.5281/zenodo.23437773)
- **The Invariant Boundary Theorem:** [DOI: 10.5281/zenodo.23194114](https://doi.org/10.5281/zenodo.23194114)

## 📚 Academic Citation

If you utilize these constructions or Magma benchmarks in your research, please cite:

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24382646.svg)](https://doi.org/10.5281/zenodo.24382646)

```bibtex
@misc{chmora2026fctlp,
  author       = {Andrey L. Chmora},
  title        = {Fuzzy Covert Time-Lock Puzzles via Sequential Noise Stripping},
  month        = nov,
  year         = 2026,
  publisher    = {Zenodo},
  doi          = {10.5281/zenodo.24382646},
  url          = {[https://doi.org/10.5281/zenodo.24382646](https://doi.org/10.5281/zenodo.24382646)}
}
```
