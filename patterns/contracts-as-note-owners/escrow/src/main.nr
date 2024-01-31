mod types;
mod token_interface;
 
contract Escrow { 
    use crate::types::escrow_note:: {EscrowNote, EscrowNoteMethods, ESCROW_NOTE_LEN};
    use crate::token_interface::Token;

    use dep::std::option::Option;
    use dep::safe_math::SafeU120;

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

    use dep::authwit::{
        auth::{
            assert_current_call_valid_authwit, 
        },
    };

    use dep::aztec::protocol_types::{
        address::AztecAddress,
        abis::function_selector::FunctionSelector,
    };

    use dep::aztec::oracle::debug_log::{ debug_log, debug_log_field, debug_log_format };


    
/*
    Contracts as Note Owners
    ========================
    This file showcases one of the escrow contract involved in the contracts as note owners pattern. Please refer to the README.md for a detailed explanation.
    We will be building the example showcased in the diagram of the README.md. The logic will be simplified to focus on the pattern itself.
    For this particular pattern we will write two contracts:
    1- TrustlessManager: This will be an intermediary contract between Alice and Bob which will manage the escrow of the fee and its release according to certain conditions. In the example case,
                         for simplicity, there will be no conditions to release the escrow. Alice and Bob will have to go through this contract to perform the escrow and release.
    2- Escrow: This will be the contract that actually escrows the fee and releases it to Bob when the conditions are met. It will also enforce that they go through the TrustlessManager contract
                by ensuring only the owner of the note can call the release function, which in this case will be the TrustlessManager contract.
    In this case, this file will contain the code for the Escrow.
    Note: This is a simplified example. In a real world scenario, this would have more checks, conditions to be met, a way for Alice to cancel the escrow if Bob didn't meet the conditions, etc.
*/

    // Declaring the slots for the notes
    global ESCROW_NOTE_SLOT = 1;

    // Declaring storage
    struct Storage {
        escrow_notes: Set<EscrowNote, ESCROW_NOTE_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                escrow_notes: Set::new(context, ESCROW_NOTE_SLOT, EscrowNoteMethods),
            }
        }
    }
 
    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}

    /// @notice Escrows an amount of tokens.
    /// @param from The address whose tokens will be escrowed.
    /// @param owner The address that will own the escrow note.
    /// @param payment_token The address of the token to escrow.
    /// @param nonce A nonce for the authwit check.
    /// @param recipients Addresses that the caller can conditionally emit the escrow note to.
    #[aztec(private)]
    fn escrow(from: AztecAddress, owner: AztecAddress, amount: Field, payment_token: AztecAddress, nonce: Field, recipients: [AztecAddress; 4]) -> Field {
        // Save for readability
        let address_this = context.this_address();

        // Instantiate the payment token contract
        let token = Token::at(payment_token);

        // Transfer the tokens to this contract. This requires a previous authwit from Alice to this contract. We won't focus on privacy here, to keep things simple.
        token.unshield(&mut context, from.to_field(), address_this.to_field(), amount, nonce);
        // let selector = FunctionSelector::from_signature("transfer_public((Field),(Field),Field,Field)");
        // context.call_public_function(payment_token, selector, [from.to_field(), address_this.to_field(), amount, nonce]);

        // Create random_id for the note
        let random_id = rand();

        // Create escrow note
        let mut escrow_note = EscrowNote::new(SafeU120::new(amount), owner, random_id, payment_token);
        
        // Insert it into storage and broadcast it to the owner.
        storage.escrow_notes.insert(&mut escrow_note, true);

        /*
            In the case where the caller is a contract, we need to emit the encrypted log to selected recipients so they can add the escrow note to their PXEs.
            If this is not done, when they try to call release_escrow(), the escrow note won't be found and therefore the function will revert.
            Aztec has limitations on the amount of emitted encrypted logs you can do per call, this is why we limit recipients to four. Technically, we could have
            set it to two, because we only need to share it to Alice and Bob, as they will call the release function. But we set it to four to showcase the multisharing pattern.
            Check the README.md of that pattern for more information.
        */
        for i in 0..recipients.len() {
            if(recipients[i].to_field() != 0) {
                let encryption_pub_key = get_public_key(recipients[i]);
                emit_encrypted_log(
                    &mut context,
                    address_this,
                    ESCROW_NOTE_SLOT,
                    encryption_pub_key,
                    escrow_note.serialize(),
                );
            }
        }

        random_id
    }

    /// @notice Releases escrowed tokens.
    /// @param random_id The id of the escrow note to consume.
    /// @param to The recipient of the escrowed tokens.
    /// @param nonce A nonce for the authwit check.
    #[aztec(private)]
    fn release_escrow(random_id: Field, to: AztecAddress, nonce: Field) {
        // Store sender for readability
        let sender = context.msg_sender();

        // Save contract address for readability
        let address_this = context.this_address();

        // Create escrow note filter
        let escrow_note_filter = NoteGetterOptions::new().select(2, random_id).set_limit(1);

        // Get the escrow note
        let escrow_note = storage.escrow_notes.get_notes(escrow_note_filter)[0];

        // Ensure the note exists.
        assert(!escrow_note.is_none(), "Note doesnt exist");

        // Unwrap the note
        let escrow_note = escrow_note.unwrap_unchecked();

        // If the sender is not the owner, ensure the caller is authorized to call this contract.
        // This can take place if a regular user escrowed the funds instead of a contract and the user wants to authorize other people to perform calls. 
        if(sender != escrow_note.owner) {
            assert_current_call_valid_authwit(&mut context, escrow_note.owner);
        } else {
            assert(nonce == 0, "Invalid nonce");
        }

        // This is an extra constraint necessary to compile the contract.
        if (escrow_note.payment_token.to_field() != 0) {
            // Instantiate token
            let token = Token::at(escrow_note.payment_token);

            // Transfer the tokens to the recipient (bob). As this is a call to a public function, this will get executed after the private call stack is exhausted.
            let selector = FunctionSelector::from_signature("transfer_public((Field),(Field),Field,Field)");
            context.call_public_function(escrow_note.payment_token, selector, [address_this.to_field(), to.to_field(), escrow_note.amount.value as Field, 0]);

            // Nullify the note
            storage.escrow_notes.remove(escrow_note);
        } else {
            assert(false, "Invalid payment token");
        }

    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; ESCROW_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(EscrowNoteMethods, note_header, preimage)
    }
}

