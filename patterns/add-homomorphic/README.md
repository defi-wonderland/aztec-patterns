# Additive homomorphic encryption

    This demonstrate the use of additive homomorphic encryption using exponential ElGamal (credit to Bank of BabyJubjub).
    A detailed description of the ElGamal algorithm can be found here: https://en.wikipedia.org/wiki/ElGamal_encryption
    as well as as the additive homormophic property of its exponential variant here:https://crypto.stackexchange.com/q/3626

    This implementation uses the noir_elgamal library, which is an exponential ElGamal over the BabyJubjub curve.

    This example demonstrates the use a few concepts:
    - The obvious use of exponential ElGamal to have a public variable holding a counter that can be incremented by anyone,
      without revealing the value of the counter.
    - A pattern to initialize a public immutable variable mirroring a private variable (here, the public key of the counter,
      allowing users to encrypt their values locally before sending them)
    - Struct compositioning, to implement new point-related types, friendlier with notes (AffinePoint, ElgamalAffinePoints)
