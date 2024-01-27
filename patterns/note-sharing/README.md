Note sharing involves emitting the same note with a shared nullifier key to multiple participants. This may seem counterintuitive, given that by doing this we are essentially sharing private information, however, this is not something undesirable in certain situations as it can allow us to coordinate different parties that may not know each other.

To make the benefit more clear, let's imagine we have Alice and Bob. They don't know each other, but Alice communicates her desire to know the price of tulips in the Netherlands over the internet. Bob sees her message and tells her that he can provide that information, in exchange for a fee. Alice agrees, but wants the option to cancel her request because a friend's of her may be able to provide the information for free.

With a shared note between Alice and Bob, a contract can make use of it so that if Alice cancels her request before Bob fulfills his side of the agreement, the note gets nullified, and if she doesn't and Bob provides the price of tulips, Bob gets the fee, Alice gets the answer, and the note gets nullified.

The shared nullifier key is necessary so any party can nullify the note after performing their action. If we were to use one of the participants private key as nullifier, only that participant would be able to nullify it.
### Two-Party Implementation
The great thing about this pattern is that its implementation is simple. All we need to do is emit an encrypted log to both Alice and Bob, using their respective public keys and have a shared nullifier for the note.

In most cases, notes have a `broadcast` method that look like this:

```rust
pub fn broadcast(self, context: &mut PrivateContext, slot: Field) {
	// we get alice's public key, so we can emit it to her
	let encryption_pub_key = get_public_key(self.alice);
	
	emit_encrypted_log(
		context, // context
		(*context).this_address(), // address of contract emitting this
		slot, // slot where this note is stored
		encryption_pub_key, // the pub key of the party we are emitting it to 
		self.serialize(), // the contents of the note, serialized
	);
}
```

And we can set the `compute_nullifier` and `compute_nullifier_without_context` methods to look like this:
```rust
pub fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
	self.compute_nullifier_without_context()
}

pub fn compute_nullifier_without_context(self) -> Field {
	let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(RequestNote, self);
	let nullifier_key = self.shared_nullifier_key;

	dep::std::hash::pedersen_hash([
		note_hash_for_nullify,
		nullifier_key,
	])
}
```

When we `insert` a note in storage, the second argument is a boolean that tells the contract whether to call broadcast or not. In our case, we will want to set this to `true` so that the note gets emitted to Alice. Once that's done, we will also want to emit the note to Bob, and for this one, we have to manually emit the encrypted log. It would look like this:

```rust
fn create_request(question: Field, bob_address: AztecAddress) {
	// assume alice is the caller
	let alice_address = context.msg_sender();
	
	// create random shared nullifier key, this can also be done
	// in the logic of the note's new fn
	let shared_nullifier_key = rand();

	let mut alice_request: RequestNote = RequestNote::new(
		question, // what she wants to know
		alice_address, // from 
		bob_address, // to
		shared_nullifier_key, // shared nullifier key
	);

	// We insert the request into the data tree, and broadcast it to Alice
	storage.requests.insert(&mut alice_request, true);

	// We then emit the note to Bob
	emit_encrypted_log(
		&mut context, // context
		address_this, // the address of this contract
		REQUEST_SET_SLOT, // the storage slot where requests are stored
		get_public_key(bob_address), // Bob's pub key to encrypt the contents
		alice_request.serialize(), // the contents of the note, serialized
	);
}
```

And that would be it!

### Multiparty Implementation
If we wanted to extend this pattern to more than two participants, we would need to loop over each participant and emit an encrypted log with their respective public key. This has some issues:
- Aztec has circuit limits, so we can't actually do this for a large amount of participants. See [Circuit Limitations](https://docs.aztec.network/dev_docs/limitations/main#circuit-limitations)
- It would require to know all participants beforehand to be able to loop over them, which may result in an awkward implementation.
In the **Real Examples** section, there's a repository with a function emitting the note to up to four participants.

### Real Examples
- [Private Oracle](https://github.com/defi-wonderland/aztec-private-oracle): This repository displays a similar yet more complex and complete implementation to the one described above. In it, a requester can asks a question to a divinity (a chosen address), which will later answer that question and trigger a callback in exchange of a fee. The note sharing pattern can be seen in the `submit_question` function. It uses it twice. First it takes advantage of the `broadcast_escrow_note_for` function of the token escrow contract to share that contract's note with the requester and the divinity, and then it shares the question note with both of them.  
- [Token Escrow](https://github.com/defi-wonderland/aztec-token): This one contains the `broadcast_escrow_note_for` which emits a note to up to four participants. 