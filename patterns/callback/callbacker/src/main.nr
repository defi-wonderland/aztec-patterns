mod types;
mod interfaces;

/// @title Callbacker Contract
/// @notice This contract handles the callback logic for both atomic and async callbacks.
contract Callbacker {

    use crate::interfaces::CallMeBack::{CallMeBackPrivateContextInterface, OriginalCallerCallbackStruct, ResolverNewAsyncCallStruct, AllowedAddressNewAsyncCallStruct};
    use crate::types::pending_callback_note::{PendingCallbackNote, PendingCallbackNoteMethods, PENDING_CALLBACK_NOTE_LEN};

    use dep::aztec::{
        context::Context,
        note::note_getter_options::NoteGetterOptions,
        protocol_types::address::AztecAddress,
        state_vars::set::Set,
        log::emit_encrypted_log,
        oracle::{
            nullifier_key::get_nullifier_secret_key,
            get_public_key::get_public_key,
        },
    };

    use dep::aztec::note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        note_viewer_options::NoteViewerOptions,
        utils as note_utils,

    };

    use dep::std::option::Option;
    
    global PENDING_CALLBACK_NOTE_SLOT = 1;

    /// @notice Storage struct for pending callback notes
    struct Storage {
        pending_callback_notes: Set<PendingCallbackNote, PENDING_CALLBACK_NOTE_LEN>,
    }

    /// @notice Initializes the storage with a new set of pending callback notes
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {   
                pending_callback_notes: Set::new(context, PENDING_CALLBACK_NOTE_SLOT, PendingCallbackNoteMethods),
            }
        }
    }
 
    /// @notice Constructor function, currently empty
    #[aztec(private)]
    fn constructor() {}

    /// @notice Queues a new call for async callbacks
    /// @param allowed_address The address allowed to resolve the callback (Bob in this case)
    /// @param beneficiary The beneficiary of the callback (Alice in this case)
    /// @param value The value associated with the callback
    #[aztec(private)]
    fn queue_new_call(allowed_address: AztecAddress, beneficiary: AztecAddress, value: Field) {
        
        // Create the new pending callback note, with the sender (call_me_back) as original caller
        let mut new_pending_callback = PendingCallbackNote::new(allowed_address, context.msg_sender(), beneficiary, value);

        storage.pending_callback_notes.insert(&mut new_pending_callback, false); // No broadcast for Alice needed, this is for Bob

        // Broadcast to Bob:
        let encryption_pub_key = get_public_key(allowed_address);

        emit_encrypted_log(
            &mut context, // context
            context.this_address(), // the address of the contract calling this function
            PENDING_CALLBACK_NOTE_SLOT, // the slot the note is stored in
            encryption_pub_key, // the encryption key of the owner
            new_pending_callback.serialize(), // the contents of the note, serialized
        );
    }

    /// @notice Resolves the next pending callback
    #[aztec(private)]
    fn resolve() {

        /* Insert whatever logic here */

        let caller = context.msg_sender();

        let next_callback_filter = NoteGetterOptions::new()
            .select(0, caller.to_field())
            .set_limit(1);

        let next_callback = storage.pending_callback_notes.get_notes(next_callback_filter)[0];

        if(next_callback.is_some()){
            let _ = CallMeBackPrivateContextInterface::at(next_callback.unwrap_unchecked().sender).callback(
                &mut context,  
                OriginalCallerCallbackStruct { inner: next_callback.unwrap_unchecked().beneficiary.to_field() },
                6969
            );

            storage.pending_callback_notes.remove(next_callback.unwrap_unchecked());
        }
    }

    /// @notice Immediately calls back the beneficiary for atomic callbacks
    /// @param beneficiary The beneficiary of the callback
    /// @param value The value associated with the callback
    #[aztec(private)]
    fn call_me_now(beneficiary: AztecAddress, value: Field) {

        /* Insert some logic here */

        let _ = CallMeBackPrivateContextInterface::at(context.msg_sender()).callback(
            &mut context,  
            OriginalCallerCallbackStruct { inner: beneficiary.to_field() },
            6969
        );
    }
    
    /// @notice Computes the note hash and nullifier for a given note
    /// @param contract_address The address of the contract
    /// @param nonce The nonce of the note
    /// @param storage_slot The storage slot of the note
    /// @param preimage The preimage of the note
    /// @return The computed note hash and nullifier
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; PENDING_CALLBACK_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);

        note_utils::compute_note_hash_and_nullifier(PendingCallbackNoteMethods, note_header, preimage)
    }
}