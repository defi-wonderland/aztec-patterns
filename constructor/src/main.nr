contract Constructor {

    use dep::aztec::{
        context::Context,
        note::{
            note_getter_options::NoteGetterOptions,
            note_header::NoteHeader,
            note_viewer_options::NoteViewerOptions,
            utils as note_utils
        },
        protocol_types::{
            abis::function_selector::FunctionSelector,
            address::AztecAddress,
        },
        state_vars::{
            immutable_singleton::ImmutableSingleton,
            public_state::PublicState
        },
        types::type_serialization::field_serialization::{FieldSerializationMethods, FIELD_SERIALIZED_LEN},
    };
    use dep::field_note::field_note::{FieldNote, FIELD_NOTE_LEN, FieldNoteMethods};
    use dep::std::option::Option;

    global PUBLIC_IMMUTABLE_SLOT = 1;
    global PRIVATE_IMMUTABLE_SLOT = 2;

    struct Storage {
        public_immutable: PublicState<Field, FIELD_SERIALIZED_LEN>,
        private_immutable: ImmutableSingleton<FieldNote, FIELD_NOTE_LEN>
    }

    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                public_immutable: PublicState::new(context, PUBLIC_IMMUTABLE_SLOT, FieldSerializationMethods),
                private_immutable: ImmutableSingleton::new(context, PRIVATE_IMMUTABLE_SLOT, FieldNoteMethods)
            }
        }
    }

    #[aztec(private)]
    fn constructor(public_value: Field, private_value: Field) {
        let mut _value = FieldNote::new(private_value);
        storage.private_immutable.initialize(&mut _value, Option::none(), false); // create a note without owner and without broadcasting it

        // This is the only call to _initialize
        context.call_public_function(
            context.this_address(),
            FunctionSelector::from_signature("_initialize(Field)"),
            [public_value]
        );
    }

    #[aztec(public)]
    internal fn _initialize(public_value: Field) { // Internal prevents being called by anyone other than the contract itself
        storage.public_immutable.write(public_value);
    }

    // no nullifier used here
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; FIELD_NOTE_LEN]) -> pub [Field; 4] {
        [0, 0, 0, 0]
    }
}