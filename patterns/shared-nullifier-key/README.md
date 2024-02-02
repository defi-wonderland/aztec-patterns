# Shared Nullifier Key

This pattern consists of having a note's nullifier key shared among different accounts. It's one of the simplest patterns and used quite a bit on most of the other examples shown this repository.

Most of the times, the nullifier key will be the hash of a `randomness`. To achieve this, we leverage the flexibility Aztec provides at the time of declaring notes to change how the nullifier is computed. Here's a simple example of how a note's `new`, `compute_nullifier`, and `compute_nullifier_without_context` could look like.

```rust
/// @notice creates a new ExampleNote
pub fn new(shared_nullifier: Field) -> Self {
	ExampleNote {
		shared_nullifier,
		// other members
	}
}

/// @notice computes the nullifier using the shared nullifier
fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
	self.compute_nullifier_without_context()
}

/// @notice computes the nullifier using the shared nullifier
fn compute_nullifier_without_context(self) -> Field {
	let nullifier_key = self.shared_nullifier;

	pedersen_hash([
		nullifier_key,
	], 0)
}
```

The great thing about this pattern is its flexibility. Some examples:
- Contracts can use the `shared_nullifier` as an identifier to find a given note. More so if it's randomly calculated.
- Multiple parties with the note can invoke the contract's function that nullifies the note. This removes the trust put on a single account to nullify it, which, as we will see in the other patterns, is something commonly desired and useful.
- Allows for deeper integration with other contracts. If a contract returns the `shared_nullifier` in a function that kickstarts a multi-step process, it allows third-party contracts to build their logic around them.

The last point is quite powerful but at its core it's simple. Here's how it looks like dissected:
1. In the creation function the contract creates a note, inserts it in storage, and returns the nullifier key to the caller.
1. In the final function, the contract receives the nullifying key, fetches the note with it from storage, and nullifies the note.

**The rest is up to the contracts integrating with this one to handle.** 

That's it. As mentioned in the beginning, this particular pattern appears in most of the others if not on all, so you will be seeing it quite a bit.