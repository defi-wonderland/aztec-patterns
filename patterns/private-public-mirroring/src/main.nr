mod types;

contract PrivatePublicMirroring { 
    use crate::types::{
        private_variable_note::{PrivateVariableNote, PrivateVariableNoteMethods, PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN}
    };
        
    use dep::std::option::Option;

    use dep::aztec::{
        context::Context,
        types::type_serialization::{
            field_serialization::{FieldSerializationMethods, FIELD_SERIALIZED_LEN},
            bool_serialization::{BoolSerializationMethods, BOOL_SERIALIZED_LEN},
            address_serialization::{AddressSerializationMethods, AZTEC_ADDRESS_SERIALIZED_LEN},
        },
        note::{
            note_getter_options::NoteGetterOptions,
            note_header::NoteHeader,
            note_viewer_options::NoteViewerOptions,
            utils as note_utils
        },
        oracle::{
            get_public_key::get_public_key,
            rand::rand
        },
        state_vars::{
            singleton::Singleton,
            public_state::PublicState
        },
        protocol_types::{
            address::AztecAddress,
            abis::function_selector::FunctionSelector,
        }
    };
    
/*
    Private-public mirroring
    =====================
    This demonstrate the use of a pattern where a private variable is mirrored into the public (single-sided mirroring).
    This is, by design, leaking privacy and should therefore be carefully assessed prior to use (including "secondary" privacy leaks, eg the total
    supply of a token secondary exposes mint/burn calls and associated values).

    This example demonstrate this pattern in the context of a constructor which sets the private side then calls the internal public function to initialize
    the public side of an immutable variable.
    The public function is internal, preventing any furtheruncontrolled access.

*/

    // Declaring the storage slots
    global PUBLIC_VARIABLE_SLOT = 1;
    global PRIVATE_VARIABLE_SLOT = 2;

    // Declaring storage
    struct Storage {
        ////////////////////////////// public //////////////////////////
        public_variable: PublicState<Field, FIELD_SERIALIZED_LEN>,

        ////////////////////////////// private //////////////////////////
        private_variable: Singleton<PrivateVariableNote, PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                 ////////////////////////////// public //////////////////////////
                public_variable: PublicState::new(
                            context,
                            PUBLIC_VARIABLE_SLOT,
                            FieldSerializationMethods
                        ),
                ////////////////////////////// private //////////////////////////
                private_variable: Singleton::new(
                    context,
                    PRIVATE_VARIABLE_SLOT,
                    PrivateVariableNoteMethods,
                )
            }
        }
    }

    /////////////////////////////////////////////////////////////////////
    //                        Constructor/init                         //
    /////////////////////////////////////////////////////////////////////

    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor() {
    }

    /// @notice sender is address 0 when deploying, use this helper to set the initial correct note owner
    #[aztec(private)]
    fn init() {
        let mut var_note = PrivateVariableNote::new(0, context.msg_sender());
        storage.private_variable.initialize(&mut var_note, Option::none(), true);
    }

    /// @notice update the private/public variables
    /// @params variable_value the new value
    #[aztec(private)]
    fn update_private(variable_value: Field) {
        // store the variable in private
        let mut var_note = PrivateVariableNote::new(variable_value, context.msg_sender());
        storage.private_variable.replace(&mut var_note, true);

        // Store the variable in public
        let selector = FunctionSelector::from_signature("_init_public(Field)");
        let serialized_calldata = [
            variable_value
        ];
        context.call_public_function(context.this_address(), selector, serialized_calldata);
    }

    /// @notice Initializes the value
    /// @dev    Internal, preventing other calls than from `update_private`
    /// @params variable_value the new value
    #[aztec(public)]
    internal fn _init_public(variable_value: Field) {
        storage.public_variable.write(variable_value);
    }

    /////////////////////////////////////////////////////////////////////
    //                      Unconstrained public                       //
    /////////////////////////////////////////////////////////////////////
    
    /// @notice getter for the public value
    unconstrained fn get_public_variable_value() -> pub Field {
        storage.public_variable.read()
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(PrivateVariableNoteMethods, note_header, preimage)
    }
}

