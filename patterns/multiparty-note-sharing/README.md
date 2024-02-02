# Multiparty Note-Sharing Pattern

**Important Note:** The asynchronous feature of this pattern currently doesn't work due to how [Aztec's PXE currently works](https://github.com/AztecProtocol/aztec-packages/issues/3511). But it's worth reading nevertheless, both for being aware of the current capabilities and limitations and in case in the future the PXE allows for asynchronous sharing.

The multiparty note-sharing pattern involves emitting the same note to more than two accounts while increasing composability and flexibility. It's an extension to the note sharing pattern, so if you haven't read it, do so as we will be building up from that one.

In the note sharing pattern we showed how it enables coordination between two accounts that may not know each other. A question that may immediately popup is: can't we just do the same we did in the note sharing pattern but looping over more accounts to achieve this so-called multiparty sharing pattern?

The answer is yes, we can do that, and we will, but in a slightly different way to enable flexible integrations. This is why we showcase this in its own file.

If we were to simply loop over multiple accounts and emit it to them when the note is created, we will run into some issues: 
- We may want to share the note _after_ its creation because we may not know exactly who we want to share the note with at that point in time. **Note**: See important note above. This is currently not possible.
- Aztec has [Circuit Limitations](https://docs.aztec.network/dev_docs/limitations/main#circuit-limitations) per call and per transaction. One of them is related to the number of `encrypted_logs` we emit.

With this in mind, we see the first point requires at least a second call or transaction in order to share after the note's creation while the second point requires also a call to happen in a different transaction to avoid the limitations. We come to the conclusion then, that a possible solution is having a dedicated function encrypting logs to a set of recipients. Something like this:

```rust
#[aztec(private)]
fn broadcast_note_for(
	accounts: [AztecAddress; 4],
	randomness: Field
) {
	// Filter to find the note with the unique randomness
	let options = NoteGetterOptions::new().select(1, randomness).set_limit(1);
	// Apply the filter to fetch the notes
	let notes = storage.shareable_note.get_notes(options);
	// If the note exists, loop over the accounts and emit the notes to them.
	if(notes[0].is_some()) {
		let note = notes[0].unwrap_unchecked();

		for i in 0..accounts.len() {
			// If the account is empty, skip the emission.
			if(accounts[i].to_field() != 0) {
				// Get the respective account public key. Used for encryption.
				let encryption_pub_key = get_public_key(accounts[i]);
				// Emit encrypted log
				emit_encrypted_log(
					&mut context, // The context
					context.this_address(), // The address of this contract
					SHAREABLE_NOTE_SLOT, // The slot where the notes are stored
					encryption_pub_key, // The public key of the account
					note.serialize(), // The note, serialized.
				);
			}
		}
	} else {
		// Revert if the note doesn't exist.
		assert(false, "shareable note does not exist");
	}
}
```

There's an extra benefit to having a function like this in a contract: it allows a contract to delegate the sharing of its notes to the contract integrating with it. For example, when the note is created, the contract adds it to its storage and returns an identifier to the caller but doesn't emit the note. The contract integrating with it can call `broadcast_note_for` and choose who to broadcast the note to. It would look something like this:

```rust
// Perform an action on the other contract
randomness = shareable_note_contract.create_note(
	&mut context,
)[0];

// Broadcast the note to Alice and Bob
let _ = shareable_note_contract.broadcast_escrow_note_for(
	&mut context,
	[alice bob, 0, 0],
	randomness
);
```

The question then becomes what contracts should incorporate this function. The answer, as always, will depend on how the contract plans to interact with others. However, if a contract acts as an entry and exit point for other contracts or accounts in the sense that its note flow involves only creation and nullification of that said note, then it may be a good candidate.
### Real Examples
-  [Token Escrow](https://github.com/defi-wonderland/aztec-token) : This contract has the function mentioned above. The flow of the `EscrowNote` involves creation, sharing, and destruction. However, because the asynchronous sharing currently is not supported, we can only see it in action in the `submit_question` function of the [Private Oracle](https://github.com/defi-wonderland/aztec-private-oracle), where it's used to broadcast the `EscrowNote` to the `requester` and `divinity`.