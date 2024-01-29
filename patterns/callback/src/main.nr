mod types;

// @dev This is the entry point.
contract Callback {

    use crate::types::pending_callback_note::{PendingCallbackNote, PendingCallbackNoteMethods, PENDING_CALLBACK_NOTE_LEN};
    
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
    
/*
    Callback pattern
    =====================
    This is an example of a callback function in Aztec. 

    alice calls queue call with bob address as resolver, bob calls resolve on the resolver contract, which calls the callback function on this contract.

    this can be fully public - alive private then bob answer isn't private and the callback fn leaks it - fully private and callback effect if accessible for alice only
    
    This example uses a callback to set a value note for the original sender, within the same contract (package being limited to a single contract) while using an external
    interface to showcase an use which is identical as using 2 independents contracts.
*/

    // Declaring the slots for the notes
    global CALLBACK_RESULT_NOTE_SLOT = 1;

    // Declaring storage
    struct Storage {
        pending_callback_notes: Set<PendingCallbackNote, PENDING_CALLBACK_NOTE_LEN>,
        callback_result_notes: Set<ValueNote, VALUE_NOTE_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {   
                pending_callback_notes: Set::new(context, PENDING_CALLBACK_NOTE_LEN, PendingCallbackNoteMethods),
                callback_result_notes: Set::new(context, VALUE_NOTE_LEN, ValueNoteMethods),
            }
        }
    }
 
    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {}

    /// @notice queue a new callback, triggerable by the given allowed address. Here, the resolver address is the address of this same contract.
    #[aztec(private)]
    fn new_call(data: Field, resolver: AztecAddress, allowed_address: AztecAddress) {


    }

    #[aztec(private)]
    fn resolve() {

    }
    
    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; VALUE_NOTE_LEN]) -> pub [Field; 4] {
        [0,0,0,0]
    }
}