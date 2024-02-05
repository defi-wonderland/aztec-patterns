mod types;
mod interfaces;

/*
    Callback pattern
    =====================
    This is an example of callback patterns in Aztec.

    In this example, the callback effect is to set a value note for the original sender.

    Two types of callbacks are demonstrated: atomic and async.

    There are 2 contracts and 2 parties involved:
    - Alice: initiate the flow and receive the effect of the callback
    - Bob: trigger the logic on the Callbacker contract, if the callback is async (see below)
    - CallMeBack contract: initiate the flow, calls Callbacker and receive the callback
    - Callbacker contract: either store a pending callback (later resolved by bob) or trigger the callback immediately (if the callback is atomic)

    The atomic callback flow is as follow:
    1. Alice calls `new_atomic_call(..)` on the `CallMeBack` contract
    2. `new_atomic_call(..)` calls `calls call_me_now(..)` on the `Callbacker` contract
    3. `call_me_now(..)` calls the `callback(..)` function on the `CallMeBack` contract.

    The async callback flow is as follow:
    - First transaction:
    1. Alice calls `new_async_call(..)` on the `CallMeBack` contract,
    2. `new_async_call(..)` calls `queue_new_call(..)` on the `Callbacker` contract and stores the pending callback (in a note for Bob).
    - Second transaction:
    1. Bob calls `resolve()` on the `Callbacker` contract
    2. `resolve()` calls the `callback(..)` function on the `CallMeBack` contract.
*/
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
        note::{
            note_header::NoteHeader,
            note_interface::NoteInterface,
            note_viewer_options::NoteViewerOptions,
            utils as note_utils,  
        }
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

    /// @notice Resolves the next pending callback, for async callbacks
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
                1337
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
            1337
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