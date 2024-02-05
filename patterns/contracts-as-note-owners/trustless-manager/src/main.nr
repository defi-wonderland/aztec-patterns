mod types;
mod escrow_interface;
 
contract TrustlessManager { 
    use crate::types::receipt_note:: {ReceiptNote, ReceiptNoteMethods, RECEIPT_NOTE_LEN};
    use crate::escrow_interface::Escrow;

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
    Contracts as Note Owners
    ========================
    This file showcases one of the two parts involved in the contracts as note owners pattern. Please refer to the README.md for a detailed explanation.
    We will be building the example showcased in the diagram of the README.md. The logic will be simplified to focus on the pattern itself.
    For this particular pattern we will write two contracts:
    1- TrustlessManager: This will be an intermediary contract between Alice and Bob which will manage the escrow of the fee and its release according to certain conditions. In the example case,
                         for simplicity, there will be no conditions to release the escrow. Alice and Bob will have to go through this contract to perform the escrow and release.
    2- Escrow: This will be the contract that actually escrows the fee and releases it to Bob when the conditions are met. It will also enforce that they go through the TrustlessManager contract
                by ensuring only the owner of the note can call the release function, which in this case will be the TrustlessManager contract.
    In this case, this file will contain the code for the TrustlessManager.
    
    Note: This is a simplified example. In a real world scenario, this would have more checks, conditions to be met, a way for Alice to cancel the escrow if Bob didn't meet the conditions, etc.
*/

    // Declaring the slots for the notes
    global RECEIPT_NOTE_SLOT = 1;

    // Declaring storage
    struct Storage {
        receipt_notes: Set<ReceiptNote, RECEIPT_NOTE_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                receipt_notes: Set::new(context, RECEIPT_NOTE_SLOT, ReceiptNoteMethods),
            }
        }
    }
 
    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}

    /// @notice Deposits the fee agreed upon between the parties in the escrow contract and emits a receipt note to the involved parties.
    /// @param bob The address of the user who will receive the escrowed fee if the conditions are met.
    /// @param fee The amount of tokens to pay.
    /// @param escrow The address of the contract used to escrow the fee.
    /// @param payment_token The address of the token Alice will pay the fee with.
    /// @param nonce Alice's authwit nonce.
    #[aztec(private)]
    fn deposit_fee(bob: AztecAddress, fee: Field, escrow: AztecAddress, payment_token: AztecAddress, nonce: Field) {
        // Store the sender as Alice for clarity.
        let alice = context.msg_sender();

        // Store the address of the contract for readability.
        let address_this = context.this_address();

        // Create a shared nullifier for the note
        let shared_nullifier = rand();

        // Create the array containing the recipients that will get the escrow note encrypted to them
        let recipients: [AztecAddress; 4] = [alice, bob, AztecAddress::from_field(0), AztecAddress::from_field(0)];

        // Instantiate the contract that will escrow the fee
        let token_escrow = Escrow::at(escrow);

        // Take the payment from Alice.
        let random_id = token_escrow.escrow(
            &mut context,
            alice.to_field(),
            address_this.to_field(),
            fee,
            payment_token.to_field(),
            nonce,
            recipients
        );

        // Create the note. We need the context to be able to push to the nullifier tree.
        let mut receipt_note = ReceiptNote::new(address_this, alice, bob, random_id, shared_nullifier, payment_token, escrow, fee);

        // Insert it into storage and broadcast it to alice.
        storage.receipt_notes.insert(&mut receipt_note, true);

        // Broadcast it to bob as well, so he can also call settle when the conditions are met
        emit_encrypted_log(
            &mut context,
            address_this,
            RECEIPT_NOTE_SLOT,
            get_public_key(bob),
            receipt_note.serialize(),
        ); 
    }

    /// @notice Consumes an ReceiptNote.
    /// @param random_id The random_id used when creating the note.
    #[aztec(private)]
    fn settle(random_id: Field) {
        // Set the sender for readability.
        let sender = context.msg_sender();

        // Create a filter to ensure the note is not already created.
        let receipt_note_filter = NoteGetterOptions::new().select(3, random_id).set_limit(1);

        // Get the note.
        let receipt_note = storage.receipt_notes.get_notes(receipt_note_filter)[0];

        // Ensure the note exists.
        assert(!receipt_note.is_none(), "Note doesnt exist");

        // Shadow previous declaration and unwrap the note.
        let receipt_note = receipt_note.unwrap_unchecked();

        // Store to as Bob for clarity.
        let bob = receipt_note.to;

        /* 
            At this point, settle, or the function used, should perform checks to ensure the agreement between Alice and Bob was met.
            An example of such a check would be to ensure a certain amount of time has passed since the fee was escrowed. We will avoid adding these
            checks to keep the example as simple as possible.
        */

        // Instantiate the contract that will release the fee to bob
        let token_escrow = Escrow::at(receipt_note.escrow);

        // Release the fee to bob
        token_escrow.release_escrow(&mut context, receipt_note.random_id, bob.to_field(), 0);

        // We nullify the notes.
        storage.receipt_notes.remove(receipt_note);
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; RECEIPT_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(ReceiptNoteMethods, note_header, preimage)
    }
}

