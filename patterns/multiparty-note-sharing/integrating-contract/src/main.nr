mod broadcaster_interface;
 
contract IntegratingContract { 
    use crate::broadcaster_interface::Broadcaster;

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
    Multiparty Note Sharing
    =======================
    This file showcases the shared multiparty note-sharing pattern. Please refer to the README.md for a detailed explanation.
    In the example code, we will show a note with a shared nullifier where the broadcast of the note to the accounts happens not in this contract, but in the contracts
    integrating with it.

    To show this pattern we will create two contracts:
    - Broadcaster: It will be the one creating the notes, broadcasting them, and nullifying them.
    - Integrating contract: The one shown in this file. Will be the one integrating with the Broadcaster to receive the notes and use them.

    We will create two functions:

    1) get_and_broadcast_note(): which will get the note from the Broadcast contract and broadcast it to a number of accounts.
    2) nullify_note(): which will nullify the note. In the tests we will show all accounts with the note can nullify the note.

    Please note: 
    - The asynchronous benefit of this pattern is not currently supported.
    - The code shown here is a toy example made with the objective of fully isolating the pattern from any specific business logic.
*/

    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}

    /// @notice Prompts the creation of the SharedNote and broacasts it to the passed in accounts.
    /// @param accounts the accounts to broadcast the notes to.
    /// @param broadcaster The address of the broadcaster contract.
    #[aztec(private)]
    fn get_and_broadcast_note(accounts: [AztecAddress;4], broadcaster: AztecAddress) {
        // Instantiate the contract that will broadcast the note
        let broadcaster_contract = Broadcaster::at(broadcaster);

        // Create the note
        let shared_nullifier = broadcaster_contract.create_note(&mut context);

        // Broadcast the note to all accounts.
        broadcaster_contract.broadcast_note_for(
            &mut context,
            accounts,
            shared_nullifier
        );
    }

    /// @notice Nullifies a note emitted by the Broadcaster.
    /// @param random_id The random_id used when creating the note.
    /// @param broadcaster The address of the broadcaster contract.
    #[aztec(private)]
    fn nullify_note(random_id: Field, broadcaster: AztecAddress) {
        // Set the sender for readability.
        let sender = context.msg_sender();

        // Instantiate the Broadcaster contract
        let broadcaster_contract = Broadcaster::at(broadcaster);

        // Nullify the note
        broadcaster_contract.nullify_note(&mut context, random_id, 0);
    }
}

