mod types;
 
contract Broadcaster { 
    use crate::types::shared_note::{SharedNote, SharedNoteMethods, SHARED_NOTE_LEN};

    use dep::authwit::auth::assert_current_call_valid_authwit;
    use dep::std::option::Option;

    use dep::aztec::{
        context::Context,
        log::emit_encrypted_log,
        note::{
            note_getter_options::NoteGetterOptions,
            note_header::NoteHeader,
            note_interface::NoteInterface,
            note_viewer_options::NoteViewerOptions,
            utils as note_utils
        },
        oracle::{
            get_public_key::get_public_key,
            rand::rand,
        },
        protocol_types::{
            address::AztecAddress,
        },
        state_vars::{
            set::Set,
        },
    };

/*
    Multiparty Note Sharing
    =======================
    This file showcases the multiparty note-sharing pattern. Please refer to the README.md for a detailed explanation.
    In the example code, we will show a note with a shared nullifier where the broadcast of the note to the accounts happens not in this contract, but in the contracts
    integrating it.

    For this pattern we will create two contracts:
    - Broadcaster: The one shown in this file. It will be the one creating the notes, broadcasting them, and nullifying them.
    - Integrating contract: Will be the one integrating with the Broadcaster to receive the notes and use them.

    We will create three functions:

    1) create_note(): which will simply create the note for the caller, store it in storage and broadcast to a owner, if the owner is not a contract.
    2) nullify_note(): which will nullify the note. In the tests we will show all accounts with the note can nullify the note.
    3) broadcast_note_for(): will take recipients, an id to identify a note, and will broadcast it to the recipients.

    Please note: 
    - The asynchronous benefit of this pattern is not currently supported.
    - The code shown here is a toy example made with the objective of fully isolating the pattern from any specific business logic.
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

    /// @notice Creates a SharedNote.
    #[aztec(private)]
    fn create_note() -> Field {
        // Store the sender for readability.
        let sender = context.msg_sender();

        // Create a random shared nullifier key
        let shared_nullifier = rand();

        // Create the note.
        let mut shared_note = SharedNote::new(sender, shared_nullifier);

        // Insert it into storage and broadcast it to the owner.
        storage.shared_notes.insert(&mut shared_note, true);

        // Return the shared nullifier
        shared_nullifier
    }

    /// @notice Consumes a SharedNote.
    /// @param shared_nullifier The shared_nullifier used when creating the note.
    /// @param nonce The authwit nonce.
    #[aztec(private)]
    fn nullify_note(shared_nullifier: Field, nonce: Field) {
        // Set the sender for readability.
        let sender = context.msg_sender();

        // Create a filter to fetch the note.
        let shared_note_filter = NoteGetterOptions::new().select(1, shared_nullifier).set_limit(1);

        // Get the note.
        let mut shared_note = storage.shared_notes.get_notes(shared_note_filter)[0];

        // Ensure the note exists.
        assert(!shared_note.is_none(), "Note doesnt exist");

        let shared_note = shared_note.unwrap_unchecked();

        // If the sender is not the owner, ensure the caller is authorized to call this contract.
        // For users that have notes where the owner is a contract, this forces to go through the contract to nullify the note.
        if(!sender.eq(shared_note.owner)) {
            assert_current_call_valid_authwit(&mut context, shared_note.owner);
        } else {
            assert(nonce == 0, "Invalid nonce");
        }

        // This extra constraint is needed to avoid a current compiler error [dynamic flatten array]
        if (!shared_note.owner.eq(AztecAddress::from_field(0))) {
            // Nullify the note.
            storage.shared_notes.remove(shared_note);
        } else {
            assert(false, "shared note does not exist");
        }
    }

    /// @notice broadcasts a given note to the passed in accounts
    /// @param accounts The accounts to broadcast the note to.
    /// @param shared_nullifier The shared_nullifier used when creating the note. This works as an id as well.
    #[aztec(private)]
    fn broadcast_note_for(
        accounts: [AztecAddress; 4],
        shared_nullifier: Field
    ) {
        // There could be checks here, perhaps only allowing the owner to call this function.

        // Filter to find the note with the unique randomness
        let options = NoteGetterOptions::new().select(1, shared_nullifier).set_limit(1);
        // Apply the filter to fetch the notes
        let notes = storage.shared_notes.get_notes(options);
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
                        SHARED_NOTE_SLOT, // The slot where the notes are stored
                        encryption_pub_key, // The public key of the account
                        note.serialize(), // The note, serialized.
                    );
                }
            }
        } else {
            // Revert if the note doesn't exist.
            assert(false, "shared note does not exist");
        }
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; SHARED_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(SharedNoteMethods, note_header, preimage)
    }
}

