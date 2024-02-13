mod interfaces;

/*
    Callback pattern
    =====================
    This is an example of callback patterns in Aztec.

    In this example, the callback effect is to set a value note for the original sender.s
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
contract CallMeBack {
    use crate::interfaces::Callbacker::{CallbackerPrivateContextInterface, AllowedAddressQueueNewCallStruct, BeneficiaryQueueNewCallStruct, BeneficiaryCallMeNowStruct};
    
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
        protocol_types::address::AztecAddress,
        state_vars::set::Set,
    };

    use dep::std::option::Option;

    use dep::value_note::{
        value_note::{ValueNote, ValueNoteMethods, VALUE_NOTE_LEN},
        balance_utils::get_balance
    };

    // Declaring the slots for the notes
    global CALLBACK_RESULT_NOTE_SLOT = 1;

    // Declaring storage
    struct Storage {
        callback_result_notes: Set<ValueNote, VALUE_NOTE_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {   
                callback_result_notes: Set::new(context, VALUE_NOTE_LEN, ValueNoteMethods),
            }
        }
    }
 
    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}
    
    /// @notice Queues a new callback, triggerable by the given allowed address, in the Callbacker contract
    /// @param data The data to be passed to the callback.
    /// @param resolver The address of the resolver contract.
    /// @param allowed_address The address allowed to trigger the async callback.
    #[aztec(private)]
    fn new_async_call(data: Field, resolver: AztecAddress, allowed_address: AztecAddress) {

        /* Insert whatever logic here */

        // Get Alice address
        let sender = context.msg_sender();

        // Queue the new call in the Callbacker contract
        let _ = CallbackerPrivateContextInterface::at(resolver).queue_new_call(
            &mut context,
            AllowedAddressQueueNewCallStruct { inner: allowed_address.to_field() },
            BeneficiaryQueueNewCallStruct { inner: sender.to_field() },
            data
        );
    }

    /// @notice Conduct an atomic callback.
    /// @param data The data to be passed to the callback.
    /// @param resolver The address of the resolver contract.
    #[aztec(private)]
    fn new_atomic_call(data: Field, resolver: AztecAddress) {

        /* Insert whatever logic here */

        // Get Alice address
        let sender = context.msg_sender();

        // Call the immediate callback in the Callbacker contract
        let _ = CallbackerPrivateContextInterface::at(resolver).call_me_now(
            &mut context,
            BeneficiaryCallMeNowStruct { inner: sender.to_field() },
            data
        );

        /* More logic here */
        // The note created in the callback is *not* accessible yet (see the readme for further details)
    }

    /// @notice Handles the callback from the resolver contract, by creating a new value note for the original caller.
    /// @param original_caller The address of the original caller of the callback.
    /// @param value The value to be set in the callback result note.
    #[aztec(private)]
    fn callback(original_caller: AztecAddress, value: Field) {  
        let mut new_value = ValueNote::new(value, original_caller);
        storage.callback_result_notes.insert(&mut new_value, true);
    }
    
    /// @notice Computes note hash and nullifier for a given note.
    /// @param contract_address The address of the contract associated with the note.
    /// @param nonce The nonce of the note.
    /// @param storage_slot The storage slot of the note.
    /// @param preimage The preimage of the note.
    /// @return The computed note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; VALUE_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);

        note_utils::compute_note_hash_and_nullifier(ValueNoteMethods, note_header, preimage)
    }
}