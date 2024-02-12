# Private-public mirroring
  This demonstrate the use of a pattern where a private variable is mirrored into the public (single-sided mirroring).
  This is, by design, leaking privacy and should therefore be carefully assessed prior to use (including "secondary" privacy leaks, eg the total
  supply of a token secondary exposes mint/burn calls and associated values).

  This example demonstrate this pattern in the context of a constructor which sets the private side then calls the internal public function to initialize
  the public side of an immutable variable.
  The public function is internal, preventing any further uncontrolled access.

### Real Examples
- [Coin Toss](https://github.com/defi-wonderland/aztec-coin-toss-pvp): This contract allows players to bet on the outcome of a coin toss. The pattern is used to set the public key used in an homomorphic encryption scheme used to track the total number of "tails" bet.

