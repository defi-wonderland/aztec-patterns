mod types;
 
contract SharedNullifierKey { 
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
    Immediate Note Nullification
    =====================
    This file showcases the shared nullification key. Please refer to the README.md for a detailed explanation.
    This pattern consists of a note with a nullification key that's shared among many users, allowing for the nullification of the note to be done by any of them.

    The example code shown here is a toy contract made with the objective of fully isolating the pattern from any specific business logic. And because this patterns appears
    in many of the other examples with different variations, this contract will show the most basic implementation.

    We will create two functions:

    1) create_note(): which will simply create the note for the caller, store it in storage and broadcast it to a recipient.
    2) nullify_note(): which will nullify the note. In the tests we will show both the caller and a different user can indeed nullify the note.

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

    /// @notice Creates an SharedNote.
    /// @param recipient The other user to broadcast the note to.
    #[aztec(private)]
    fn create_note(recipient: AztecAddress) {
        // Store the sender for readability.
        let sender = context.msg_sender();

        // Store the address of this contract for readability.
        let address_this = context.this_address();

        // Create a random shared nullifier key
        let shared_nullifier = rand();

        // Create the note. We need the context to be able to push to the nullifier tree.
        let mut shared_note = SharedNote::new(&mut context, sender, shared_nullifier);

        // Insert it into storage and broadcast it to the sender.
        storage.shared_notes.insert(&mut shared_note, true);

        // Emit an encrypted log to the recipient.
        emit_encrypted_log(
            &mut context, // context
            address_this, // the address of this contract
            SHARED_NOTE_SLOT, // the slot where the note is stored
            get_public_key(recipient), // the public key of the recipient, this allows him to decrypt the note with his private key
            shared_note.serialize(), // the contents of the note, serialized
        );
    }

    /// @notice Consumes an SharedNote.
    /// @param shared_nullifier The shared_nullifier used when creating the note.
    #[aztec(private)]
    fn nullify_note(shared_nullifier: Field) {
        // Set the sender for readability.
        let sender = context.msg_sender();

        // Create a filter to ensure the note is not already created.
        let example_note_filter = NoteGetterOptions::new().select(1, shared_nullifier).set_limit(1);

        // Get the note.
        let mut shared_note = storage.shared_notes.get_notes(example_note_filter)[0];

        // Ensure the note exists.
        assert(!shared_note.is_none(), "Note doesnt exist");

        // We consume the note.
        storage.shared_notes.remove(shared_note.unwrap_unchecked());
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; SHARED_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(SharedNoteMethods, note_header, preimage)
    }
}

