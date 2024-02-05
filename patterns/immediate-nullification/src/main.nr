mod types;
 
contract ImmediateNoteNullification { 
    use crate::types::example_note:: {ExampleNote, ExampleNoteMethods, EXAMPLE_NOTE_LEN};

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
    Immediate Note Nullification
    =====================
    This file showcases the immediate note nullification pattern. Please refer to the README.md for a detailed explanation.
    This pattern consists of nullifying a note's parameters or combination of parameters upon creation. This forbids a future note to be created with the nullified parameters
    while allowing the note's contents to be consumed.

    The example code shown here is a toy contract made with the objective of fully isolating the pattern from any specific business logic. However, it's important to keep in mind
    the main logic of this pattern happens in the note file (./types/example_note.nr).

    We will create two functions:

    1) create_note(): which will simply create the note for the caller and store it in storage.
    2) consume_note(): which will consume/nullify the note. This is to show the note can be consumed despite the nullification of its parameters.

    For this note in particular, we will nullify a combination of two parameters: the owner and a random number (randomness). This means the owner can create other notes as long as a different
    random number is used, and that other users can create notes with that same randomness.
*/

    // Declaring the slots for the notes
    global EXAMPLE_NOTE_SLOT = 1;

    // Declaring storage
    struct Storage {
        example_notes: Set<ExampleNote, EXAMPLE_NOTE_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                example_notes: Set::new(context, EXAMPLE_NOTE_SLOT, ExampleNoteMethods),
            }
        }
    }
 
    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}

    /// @notice Creates an ExampleNote.
    /// @param randomness A random Field used to nullify the note.
    #[aztec(private)]
    fn create_note(randomness: Field) {
        // Store the sender for readability.
        let sender = context.msg_sender();

        // Create the note. We need the context to be able to push to the nullifier tree.
        let mut example_note = ExampleNote::new(&mut context, sender, randomness);

        // Insert it into storage and broadcast it to the sender.
        storage.example_notes.insert(&mut example_note, true);
    }

    /// @notice Consumes an ExampleNote.
    /// @param randomness The randomness used when creating the note.
    #[aztec(private)]
    fn consume_note(randomness: Field) {
        // Set the sender for readability.
        let sender = context.msg_sender();

        // Create a filter to ensure the note is not already created.
        let example_note_filter = NoteGetterOptions::new().select(0, sender.to_field()).select(1, randomness).set_limit(1);

        // Get the note.
        let mut example_note = storage.example_notes.get_notes(example_note_filter)[0];

        // Ensure the note exists.
        assert(!example_note.is_none(), "Note doesnt exist");

        // We consume the note.
        storage.example_notes.remove(example_note.unwrap_unchecked());
    }

    /// @notice Checks whether the parameters were added to the nullifying tree
    /// @param _owner The owner of the note.
    /// @param _randomness The random parameter provided by the note's creator.
    unconstrained fn are_parameters_nullified(owner: AztecAddress, randomness: Field) -> pub bool {
        ExampleNote::are_parameters_nullified(owner, randomness)
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; EXAMPLE_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(ExampleNoteMethods, note_header, preimage)
    }
}

