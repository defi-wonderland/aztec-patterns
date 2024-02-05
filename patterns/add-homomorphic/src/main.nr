mod types;


contract AdditiveHomomorphicEncryption { 
    use crate::types::{
        affine_point::{AffinePoint, AffinePointSerializationMethods, AFFINE_POINT_SERIALIZED_LEN},
        elgamal_affine_points::{ElgamalAffinePoints, ElgamalAffinePointsSerializationMethods, ELGAMAL_AFFINE_POINTS_SERIALIZED_LEN},
        public_key_note::{PublicKeyNote, PublicKeyNoteMethods, PUBLIC_KEY_NOTE_SERIALIZED_LEN}
    };

    use dep::noir_elgamal;
        
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
            immutable_singleton::ImmutableSingleton,
            set::Set,
            map::Map, 
            public_state::PublicState
        },
        protocol_types::{
            address::AztecAddress,
            abis::function_selector::FunctionSelector,
        }
    };
    
/*
    Additive Homomorphic Encryption
    =====================
    This demonstrate the use of additive homomorphic encryption using exponential ElGamal (credit to Bank of BabyJubjub).
    A detailed description of the ElGamal algorithm can be found here: https://en.wikipedia.org/wiki/ElGamal_encryption
    as well as as the additive homormophic property of its exponential variant here:https://crypto.stackexchange.com/q/3626

    This implementation uses the noir_elgamal library, which is an exponential ElGamal over the BabyJubjub curve.

    This example demonstrates the use a few concepts:
    - The obvious use of exponential ElGamal to have a public variable holding a counter that can be incremented by anyone,
      without revealing the value of the counter.
    - A pattern to initialize a public immutable variable mirroring a private variable (here, the public key of the counter,
      allowing users to encrypt their values locally before sending them)
    - Struct compositioning, to implement new point-related types, friendlier with notes (AffinePoint, ElgamalAffinePoints)

*/

    // Declaring the storage slots
    global PUBLIC_ENCRYPTED_SUM_SLOT = 1;
    global PUBLIC_KEY_PUBLIC_SLOT = 2;
    global PUBLIC_KEY_PRIVATE_SLOT = 3;

    // Declaring storage
    struct Storage {
        ////////////////////////////// public //////////////////////////
        public_encrypted_sum: PublicState<ElgamalAffinePoints, ELGAMAL_AFFINE_POINTS_SERIALIZED_LEN>,
        public_bjj_public_key: PublicState<AffinePoint, AFFINE_POINT_SERIALIZED_LEN>,

        ////////////////////////////// private //////////////////////////
        private_bjj_public_key: ImmutableSingleton<PublicKeyNote, PUBLIC_KEY_NOTE_SERIALIZED_LEN>,
    }

    // Declaring storage implementation
    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                 ////////////////////////////// public //////////////////////////
                public_encrypted_sum: PublicState::new(
                            context,
                            PUBLIC_ENCRYPTED_SUM_SLOT,
                            ElgamalAffinePointsSerializationMethods
                        ),
                public_bjj_public_key: PublicState::new( 
                    context,
                    PUBLIC_KEY_PUBLIC_SLOT,
                    AffinePointSerializationMethods,
                ),
                ////////////////////////////// private //////////////////////////
                private_bjj_public_key: ImmutableSingleton::new(
                    context,
                    PUBLIC_KEY_PRIVATE_SLOT,
                    PublicKeyNoteMethods,
                )
            }
        }
    }

    /////////////////////////////////////////////////////////////////////
    //                        Constructor/init                         //
    /////////////////////////////////////////////////////////////////////

    /// @notice Constructor for the contract.
    #[aztec(private)]
    fn constructor(bjj_public_key: AffinePoint) {
        // Sanity check: is the public key in the bjj field?
        assert(noir_elgamal::is_valid_subgroup(bjj_public_key.point), "Invalid public key");

        // store the public key in private
        let mut key_note = PublicKeyNote::new(bjj_public_key);
        storage.private_bjj_public_key.initialize(&mut key_note, Option::none(), false);

        // Store the public key in public and initialize the encrypted sum
        let selector = FunctionSelector::from_signature("_init_public([Field;2],Field)");
        let serialized_calldata = [
            bjj_public_key.point.x,
            bjj_public_key.point.y,
            rand()
        ];
        context.call_public_function(context.this_address(), selector, serialized_calldata);
    }

    /// @notice Initializes the public key variable and the encrypted sum
    #[aztec(public)]
    internal fn _init_public(bjj_public_key_serialized: [Field; 2], randomness: Field) {
        let bjj_public_key = AffinePoint::deserialize(bjj_public_key_serialized);

        // store the public key in public
        storage.public_bjj_public_key.write(bjj_public_key);

        // encrypt "0"
        let (c1, c2) = noir_elgamal::exp_elgamal_encrypt(bjj_public_key.point, 0 as u40, randomness);

        let encrypted_initial_counter= ElgamalAffinePoints::new(
            AffinePoint::new(c1),
            AffinePoint::new(c2)
        );

        // store the encrypted 0
        storage.public_encrypted_sum.write(encrypted_initial_counter);
    }

    /////////////////////////////////////////////////////////////////////
    //                             Private                             //
    /////////////////////////////////////////////////////////////////////

    /// @notice Increments the counter by the given step
    #[aztec(private)]
    fn increment(step: Field) {
        
        // get the public key
        let public_key = storage.private_bjj_public_key.get_note();

        // encrypt the step
        let (c1, c2) = noir_elgamal::exp_elgamal_encrypt(public_key.bjj_public_key.point, step as u40, rand());

        let serialized_calldata = [
            c1.x,
            c1.y,
            c2.x,
            c2.y
        ];

        // call the public function which will add the encrypted step to the encrypted sum
        let selector_update_bet_stats = FunctionSelector::from_signature("_update_cumsum([Field;2],[Field;2])");
        context.call_public_function(context.this_address(), selector_update_bet_stats, serialized_calldata);
    }

    /////////////////////////////////////////////////////////////////////
    //                             Public                              //
    /////////////////////////////////////////////////////////////////////

    /// @notice Increments the counter by a given step, the ElGamal encryption happening offchain
    #[aztec(public)]
    fn increment_public(C1_serialized: [Field;2], C2_serialized: [Field;2]) {
        let serialized_calldata = [
            c1.x,
            c1.y,
            c2.x,
            c2.y
        ];

        // call the public function which will add the encrypted step to the encrypted sum
        let selector_update_bet_stats = FunctionSelector::from_signature("_update_cumsum([Field;2],[Field;2])");
        context.call_public_function(context.this_address(), selector_update_bet_stats, serialized_calldata);
    }

    /////////////////////////////////////////////////////////////////////
    //                         Internal Public                         //
    /////////////////////////////////////////////////////////////////////

    /// @notice Add encrypted steps to the encrypted counter
    #[aztec(public)]
    internal fn _update_cumsum(C1_serialized: [Field;2], C2_serialized: [Field;2]) {
        let encrypted_value_to_add = ElgamalAffinePoints::new(
            AffinePoint::deserialize(C1_serialized),
            AffinePoint::deserialize(C2_serialized)
        );

        let current_encrypted_sum = storage.public_encrypted_sum.read();    

        let new_encrypted_sum = current_encrypted_sum.add(encrypted_value_to_add);

        storage.public_encrypted_sum.write(new_encrypted_sum);
    }

    ///@notice Computes note hash and nullifier.
    unconstrained fn compute_note_hash_and_nullifier(contract_address: AztecAddress, nonce: Field, storage_slot: Field, preimage: [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN]) -> pub [Field; 4] {
        let note_header = NoteHeader::new(contract_address, nonce, storage_slot);
        note_utils::compute_note_hash_and_nullifier(PublicKeyNoteMethods, note_header, preimage)
    }
}

