# Additive homomorphic encryption

  This demonstrate the use of additive homomorphic encryption using exponential ElGamal (credit to Bank of BabyJubjub).

  Having a public encrypted value is, for instance, relevant for value frequently updated (avoiding repetitive note creation/nullification) and
  for which having a privacy leak to some degree isn't too detrimental (as a public value changes, one can trace back which address has been
  updating this variable, but cannot know what the exact change was).
 
  A detailed description of the ElGamal algorithm can be found [here](https://en.wikipedia.org/wiki/ElGamal_encryption)
  as well as as the additive homormophic property of its exponential variant [here](https://crypto.stackexchange.com/q/3626)

  This implementation uses the [noir_elgamal library](https://github.com/jat9292/noir-elgamal), which is an exponential ElGamal over the BabyJubjub curve.

  This example demonstrates the use a few concepts:
  - The obvious use of exponential ElGamal to have a public variable holding a counter that can be incremented by anyone,
    without revealing the value of the counter.
  - Struct compositioning, to implement new point-related types, friendlier with notes (AffinePoint, ElgamalAffinePoints)

  ## Exponential ElGamal
  Without diving into the details, ElGamal encryption is an asymmetric encryption algorithm, based on the difficulty of the discrete logarithm problem.
  It is here applied over an elliptic curve, the BabyJubjub curve. The actual implementation is deffered to the noir_elgamal library, only the following exposed api are relevants:
  - onchain: `is_valid_subgroup(point)` verify if a point is part of the curve's subgroup
  - onchain: `exp_elgamal_encrypt(public_key, message, random)` encrypt a message using the public key (the random value *must* be unique)

  The decryption requires solving a discrete logarithm problem (to retrieve the encrypted message from c2), see the noir_elgamal repository for multiple implementations of such.

  ## Structure composition
  This pattern allows extending the functions implementing a class, in a way similar to extending a class in obect-oriented languages.
  For instance, elgamal_affine_point composes over affine_point, which in turn composes over Point:

  ```rust
  /// @notice A struct composing over the Point struct
/// @member point<Point> An element representing a point on the Baby Jubjub curve.
struct AffinePoint {
    point: Point
}

/// @notice A struct representing the resulting ElGamal-encrypted points on the Baby Jubjub curve after performing encryption
///         on a value
/// @member C1 The point yielded by multiplying the base point of the Baby Jubjub curve by a provided randomness.
/// @member C2 The point yielded by adding the resulting plain_embedded (plaintext * base point) to the shared_secret (randomness * public key)
struct ElgamalAffinePoints {
    C1: AffinePoint,
    C2: AffinePoint
}
```
The `eq` impl is then composed over:

- in elgamal_affine_point
```rust
/// @notice Checks whether two ElgamalAffinePoints are equal (in the Baby Jubjub curve)
/// @param second The second ElgamalAffinePoints to check
fn eq(self, second: ElgamalAffinePoints) -> bool {
    self.C1.eq(second.C1) * self.C2.eq(second.C2)
}
```
- in affine_point
```rust
/// @notice Checks whether two AffinePoints are equal (in the Baby Jubjub curve)
/// @param other The other AffinePoint to be compared
fn eq(self, other: Self) -> bool {
    self.point.eq(other.point)
}
```

### Real Examples
- [Coin Toss](https://github.com/defi-wonderland/aztec-coin-toss-pvp): This contract allows players to bet on the outcome of a coin toss. The pattern is used to count the number of tails without having the players knowing the current sum. Once the bet is settled (ie a third party "declares" the result of the coin flip), this number of tails is then decrypted and used to compute the number of winners, sharing the pot.