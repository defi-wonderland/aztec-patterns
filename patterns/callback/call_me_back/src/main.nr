mod interfaces;

/*
    Callback pattern
    =====================
    This is an example of a callback pattern in Aztec.

    There are 2 contracts and 2 parties involved:
    - call_me_back contract: initiate the flow and receiving the callback
    - callbacker contract: store the pending callback and, when resolve() is called, process it
    - Alice: calls the call_me_back contract
    - Bob: trigger the logic on the callbacker contract

    alice calls queue_new_call with bob address as the one who needs to resolve it, bob calls resolve on the resolver contract, which calls the callback function.

    this can be fully public - alive private then bob answer isn't private and the callback fn leaks it - fully private and callback effect if accessible for alice only
    
    This example uses a callback to set a value note for the original sender.
*/
contract CallMeBack {
    use crate::interfaces::Callbacker::{CallbackerPrivateContextInterface, AllowedAddressQueueNewCallStruct, BeneficiaryQueueNewCallStruct, BeneficiaryCallMeNowStruct};
    
    use dep::std::option::Option;

    use dep::value_note::value_note::{ValueNote, ValueNoteMethods, VALUE_NOTE_LEN};

    use dep::aztec::context::Context;
    use dep::aztec::log::emit_encrypted_log;
    
    use dep::aztec::note::{
        note_getter_options::NoteGetterOptions,
        note_header::NoteHeader,
        note_interface::NoteInterface,
        note_viewer_options::NoteViewerOptions,
        utils as note_utils
    };

    use dep::aztec::state_vars::{
        set::Set,
    };

    use dep::aztec::protocol_types::{
        address::AztecAddress,
    };




    use dep::aztec::oracle::debug_log::{ debug_log };


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
    
    /// @notice queue a new callback, triggerable by the given allowed address.
    #[aztec(private)]
    fn new_biparty_call(data: Field, resolver: AztecAddress, allowed_address: AztecAddress) {

        /* Insert whatever logic here */

        let sender = context.msg_sender();
        let _ = CallbackerPrivateContextInterface::at(resolver).queue_new_call(
            &mut context,
            AllowedAddressQueueNewCallStruct { inner: allowed_address.to_field() },
            BeneficiaryQueueNewCallStruct { inner: sender.to_field() },
            data
        );
    }

    #[aztec(private)]
    fn new_atomic_call(data: Field, resolver: AztecAddress) {

        /* Insert whatever logic here */

        let sender = context.msg_sender();
        let _ = CallbackerPrivateContextInterface::at(resolver).call_me_now(
            &mut context,
            BeneficiaryCallMeNowStruct { inner: sender.to_field() },
            data
        );
    }

    #[aztec(private)]
    fn callback(original_caller: AztecAddress, value: Field) {  
    debug_log("000000000000000000000000000  CALLBACK CALLBACK CALLBACK CALLBACK CALLBACK CALLBACK CALLBACK CALLBACK CALLBACK  000000000000000000000000");


        let mut new_value = ValueNote::new(value, original_caller);
        storage.callback_result_notes.insert(&mut new_value, true);
    }
    
    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; VALUE_NOTE_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);

        note_utils::compute_note_hash_and_nullifier(ValueNoteMethods, note_header, preimage)
    }
}