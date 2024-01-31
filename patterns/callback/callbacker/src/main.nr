mod types;
mod interfaces;

contract Callback {
    use crate::interfaces::callback::CallMeBackInterface;
    use crate::types::pending_callback_note::{PendingCallbackNote, PendingCallbackNoteMethods, PENDING_CALLBACK_NOTE_LEN};

    use dep::aztec::{
        context::Context,
        note::note_getter_options::NoteGetterOptions,
        protocol_types::address::AztecAddress,
        state_vars::set::Set
    }

    use dep::std::option::Option;

    use dep::value_note::value_note::{ValueNote, ValueNoteMethods, VALUE_NOTE_LEN};
    
    global CALLBACK_RESULT_NOTE_SLOT = 1;

    struct Storage {
        pending_callback_notes: Set<PendingCallbackNote, PENDING_CALLBACK_NOTE_LEN>,
    }

    impl Storage {
        fn init(context: Context) -> Self {
            Storage {   
                pending_callback_notes: Set::new(context, PENDING_CALLBACK_NOTE_LEN, PendingCallbackNoteMethods),
            }
        }
    }
 
    #[aztec(private)]
    fn constructor() {}

    #[aztec(private)]
    fn queue_new_call(allowed_address: AztecAddress, beneficiary: AztecAddress, value: Field) {
        let mut new_pending_callback = PendingCallbackNote::new(allowed_address, context.msg_sender(), beneficiary, value);
        storage.pending_callback_notes.insert(&mut new_pending_callback, true);
    }

    #[aztec(private)]
    fn resolve() {
        let caller = context.msg_sender();

        let next_callback_filter = NoteGetterOptions::new()
            .select(0, caller.to_field())
            .set_limit(1);

        let next_callback = storage.pending_callback_notes.get_notes(next_callback_filter)[0];

        if(next_callback.is_some()){
            let _ = CallMeBackInterface::at(next_callback.unwrap_unchecked().beneficiary.to_field()).callback(&mut context, next_callback.unwrap_unchecked().beneficiary, 6969);
        }
    }
    
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; VALUE_NOTE_LEN]) -> pub [Field; 4] {
        [0,0,0,0]
    }
}