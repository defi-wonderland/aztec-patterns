mod types;
 
contract SharedNote {
    
    use crate::types::shared_note:: {SharedNote, SharedNoteMethods, SHARED_NOTE_LEN};

    use dep::std::option::Option;

    use dep::aztec::context::Context;
    use dep::aztec::log::emit_encrypted_log;
    
    use dep::aztec::note::{
        note_getter_options::NoteGetterOptions,
        note_header::NoteHeader,
        note_interface::NoteInterface,
        note_viewer_options::NoteViewerOptions,
        utils as note_utils
    };

    use dep::aztec::oracle::{
        get_public_key::get_public_key,
        rand::rand,
    };
    use dep::aztec::state_vars::{
        set::Set,
    };

    use dep::aztec::protocol_types::{
        address::AztecAddress,
    };
    
/*
    Note sharing pattern
    =====================
    This file showcases the note sharing pattern. The pattern is as isolated from protocol-specific logic as possible.
    Refer to the README.md for a description of the note sharing pattern as well as links to real code where the pattern is implemented.

    The main thing to take away from this pattern is that it allows for coordination between parties that don't know each other. 
    Some simple examples of what this pattern can accomplish:

    1) In the most simple case, sharing a note with a shared nullifier key allows any of the parties to nullify the note. Which is a way to trust another party to call a function that performs some action and nullifies the note.
       It can be thought as, perhaps, an authorization of sorts. 
       A simple example would be a game where Alice and Bob play against each other. Alice can share a note with Bob indicating the start of the game, and any of the two can nullify it at any time to stop it.

    2) If Alice needs something, and Bob can provide it, she can share a note with Bob, constituting an agreement of sorts. Because the note is shared, Alice can cancel the note if Bob doesn't provide what she needs 
       or if she changes her mind before Bob provided it. Bob, in turn, can forbid Alice from cancelling the note if he has already provided what she needed.
*/

    // Declaring the slots for the notes
    global SHARED_NOTE_SLOT = 1;

    // Declaring storage
    struct Storage {
        shared_notes: Set<SharedNote, SHARED_NOTE_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                shared_notes: Set::new(context, SHARED_NOTE_SLOT, SharedNoteMethods),
            }
        }
    }
 
    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}

    /// @notice Shares a note with another user.
    /// @param  Bob The address to share the note with.
    #[aztec(private)]
    fn create_and_share_note(bob: AztecAddress) {
        // Store the sender as Alice for readability.
        let alice = context.msg_sender();

        // Store the address of this contract for readability.
        let address_this = context.this_address();

        // Create a filter to ensure the note is not already created.
        let shared_note_filter = NoteGetterOptions::new().select(0, alice.to_field()).select(1, bob.to_field()).set_limit(1);

        // Get the shared note. If it exists, we revert.
        let mut shared_note = storage.shared_notes.get_notes(shared_note_filter)[0];

        // Ensure the note does not exist. 
        assert(shared_note.is_none(), "Note already exists");

        // Create the shared nullifier key so that any of the players can nullify the note. See the compute nullifier function in the note file.
        let shared_nullifier_key = rand(); 

        // Create the note
        let mut shared_note = SharedNote::new(alice, bob, shared_nullifier_key);

        // Insert it into storage and broadcast it to Alice. The broadcast gets triggered due to the "true" in the second argument. See broadcast function in the note file.
        storage.shared_notes.insert(&mut shared_note, true);

        // Emit the note to the "to" address.
        emit_encrypted_log(
            &mut context, // context
            address_this, // the address of this contract
            SHARED_NOTE_SLOT, // the slot where the note is stored
            get_public_key(bob), // the public key of Bob, this allows him to decrypt the note with his private key
            shared_note.serialize(), // the contents of the note, serialized
        );
    }

    /// @notice Executes the action of the user we shared the note with. This will nullify the note at the end.
    /// @param  alice the address of the user who shared the note, used to find the note in storage.
    #[aztec(private)]
    fn bob_action(alice: AztecAddress) {
        // Set Bob as the sender for readability. This also acts as an implicit check that the caller is Bob. Otherwise, the note won't be found.
        let bob = context.msg_sender();

        // Create a filter to ensure the note is not already created.
        let shared_note_filter = NoteGetterOptions::new().select(0, alice.to_field()).select(1, bob.to_field()).set_limit(1);

        // Get the note.
        let mut shared_note = storage.shared_notes.get_notes(shared_note_filter)[0];

        // Ensure the note exists.
        assert(!shared_note.is_none(), "Note doesnt exist");

        /* 
            Here Bob would perform a piece of logic, like updating state or creating a new note, or executing a callback.
            To showcase the pattern as isolated as possible, we exclude this logic from the example.
        */ 

        // Now that Bob action took place, we nullify the note.
        storage.shared_notes.remove(shared_note.unwrap_unchecked());
    }

    /// @notice Executes the action of the user who shared the note. This will nullify the note at the end.
    /// @param  alice the address of the user who alice shared the note with, used to find the note in storage.
    #[aztec(private)]
    fn alice_action(bob: AztecAddress) {
        // Set Alice as the sender for readability. This also acts as an implicit check that the caller is Alice. Otherwise, the note won't be found.
        let alice = context.msg_sender();

        // Create a filter to ensure the note is not already created.
        let shared_note_filter = NoteGetterOptions::new().select(0, alice.to_field()).select(1, bob.to_field()).set_limit(1);

        // Get the note.
        let mut shared_note = storage.shared_notes.get_notes(shared_note_filter)[0];

        // Ensure the note exists.
        assert(!shared_note.is_none(), "Note doesnt exist");

        // We assume in this case Alice action was to nullify the shared note to cancel her agreement with Bob.
        storage.shared_notes.remove(shared_note.unwrap_unchecked());
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; SHARED_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(SharedNoteMethods, note_header, preimage)
    }
}

