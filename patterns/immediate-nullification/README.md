# Immediate Note Nullification

There exist certain instances where we want to forbid the creation of a note with a parameter or a combination of parameters that were previously used. A simple example is ensuring uniqueness for our notes without using a sequential nonce or sequential id. Ideally, the note is successfully created the first time the id is used, but if somewhere were to try to use that id again, the transaction would revert.

We should keep in mind that if we were to do a check using a filter for the id in order to retrieve if a note with that id exists from storage and revert based on that, it wouldn't work given that we won't have all existing notes in our PXE.

However, what if we pushed a nullifier to the nullifier tree upon creating a note? This is exactly what `ImmutableSingleton` and `Singleton` notes do when `initialize` is called in order to nullify the storage slot, but not the note itself.

We can apply this same pattern to our custom notes.

Before diving deeper, a word of caution: because the membership check of the nullifier is done by the [Base Rollup Circuit](https://docs.aztec.network/learn/concepts/circuits/rollup_circuits/main#base-rollup-circuit) users may not be aware that they are sending a wrong parameter - which can lead to accidental reverts. This pattern, therefore, should be used when we want to absolutely ensure a certain parameter or combination of parameters is not repeated.

## Implementation
To implement this we have to keep in mind want we want to accomplish upon the creation of the note:
1. We want to nullify a parameter or a combination of parameters 
2. We **don't** want to nullify the contents of the note so it can be properly consumed later on

The usual `new` function of a note looks like this:
```rust
/// @member id: the unique identifier of the note
/// @member other_member: placeholder for a note with more members
/// @member other_member_2: placeholder for a note with more members
/// @member header: the note header
struct ExampleNote {
    id: Field,
    other_member: Field,
    other_member_2: AztecAddress,
    header: NoteHeader
}

impl ExampleNote {
    pub fn new(
	    id: Field, 
	    other_member: Field, 
	    other_member_2: AztecAddress
    ) -> Self {
        ExampleNote {
            id,
            other_member,
            other_member_2,
            header: NoteHeader::empty(),
        }
    }


```

Now, to nullify the parameters we simply have to push a new nullifier to the tree, and then create the note. We will follow the pattern `ImmutableSingleton` and `Singleton` uses.

```rust
/// @member id: the unique identifier of the note
/// @member other_member: placeholder to illustrate a note with more members
/// @member other_member_2: placeholder to illustrate a note with more members
/// @member header: the note header
struct ExampleNote {
    id: Field,
    other_member: Field,
    other_member_2: AztecAddress,
    header: NoteHeader
}

impl ExampleNote {
    /// @notice Creates a new note.
    /// @param  _context: the context. It's necessary to push the nullifier to the tree.
    /// @param  id the unique identifier of the note
    /// @param  other_member: placeholder to illustrate a note with more members
    /// @param  other_member_2: placeholder to illustrate a note with more members
    pub fn new(
        _context: &mut PrivateContext,
	    id: Field, 
	    other_member: Field, 
	    other_member_2: AztecAddress
    ) -> Self {
	    // Store the function to generate the nullifier in a variable
        let compute_initialization_nullifier = ExampleNote::generate_id_nullifier;

		// Call the function to generate the nullifier
        let nullifier = compute_initialization_nullifier(id);

		// Push the nullifier to the nullifier tree
        _context.push_new_nullifier(nullifier, 0);

		// Create the note
        ExampleNote {
            id,
            other_member,
            other_member_2,
            header: NoteHeader::empty(),
        }
    }

	/// @notice Nullifying hash generator
    /// @param _id_ The id to nullify
    pub fn generate_id_nullifier(_id: Field) -> Field {
	    // hash the id
        dep::std::hash::pedersen_hash([id])
    }

	// Other methods
}
```

That's all. When an `ExampleNote` is created, no other note will be able to have the same `id`, not even after the `ExampleNote` was consumed. We could have also nullified the combination of `id` and `other_member`, or whatever combination of parameters we needed to satisfy our use case.

A last note is that this may be hard to test. To facilitate this, an unconstrained function can be added to the `ExampleNote`. It would look like this:
```rust
    /// @notice ExampleNote id initialization checker. Checks whether the id was added to the nullifying tree
    /// @param _id The id to check for nullification status
    unconstrained pub fn is_id_nullified(_id: Field) -> bool {
        let compute_initialization_nullifier = ExampleNote::generate_id_nullifier;
        let nullifier = compute_initialization_nullifier(_id);
        check_nullifier_exists(nullifier)
    }
```

## Real Examples
- [Coin Toss](https://github.com/defi-wonderland/aztec-coin-toss-pvp): This contract allows players to bet on the outcome of a coin toss. The pattern is used for its bet notes, which are declared in `bet_note.nr`. The immediate nullifier push is required so bettors aren't able to use the same `randomness` twice in the same round. To achieve this, it nullifies the combination of `randomness` and `round_id`. The exact reasoning behind implementing this constraint is due to the usage of ElGamal's additive homomorphic encryption to privately store how many people bet on tails on each round, as this scheme requires `randomness` to not be repeated.      