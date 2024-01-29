use dep::aztec::{
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify,
    },
    oracle::{
        get_public_key::get_public_key,
        notes::check_nullifier_exists,
    },
    log::emit_encrypted_log,
    context::PrivateContext,
    protocol_types::{
        address::AztecAddress
    }
};

/// @member owner: the user who owns the note
/// @member randomness: a random, user-provided Field, will be used for nullification of the note.
/// @member header: the note header
struct ExampleNote {
    owner: AztecAddress,
    randomness: Field,
    header: NoteHeader
}

/// @notice Declare the length of the note.
global EXAMPLE_NOTE_LEN: Field = 2;

/// @notice Declare the methods of the note.
impl ExampleNote {
    /// @notice Creates a new note.
    /// @param  _context: the context. It's necessary to push the nullifier to the tree.
    /// @param  owner: the user who owns the note
    /// @param  randomness: a random, user-provided Field, will be used for nullification of the note.
    pub fn new(
            _context: &mut PrivateContext,
            _owner: AztecAddress,
            _randomness: Field,
        ) -> Self {
        // Store the function to generate the nullifier in a variable
        let compute_initialization_nullifier = ExampleNote::generate_round_randomness_nullifier;

		// Call the function to generate the nullifier
        let nullifier = compute_initialization_nullifier(_owner, _randomness);

		// Push the nullifier to the nullifier tree
        _context.push_new_nullifier(nullifier, 0);

        ExampleNote {
            owner: _owner,
            randomness: _randomness,
            header: NoteHeader::empty(),
        }
    }

    /// @notice Parameter-nullifying hash generator
    /// @param _owner The owner of the note to nullify
    /// @param _randomness The random parameter provided by the note's creator
    pub fn generate_round_randomness_nullifier(_owner: AztecAddress, _randomness: Field) -> Field {
	    // Generate the nullifier hash
        dep::std::hash::pedersen_hash([_owner.to_field(), _randomness])
    }

    /// @notice ExampleNote initialization checker. Checks whether the parameters were added to the nullifying tree
    /// @param _owner The owner of the note. Required to check for nullification status
    /// @param _randomness The random parameter provided by the note's creator. Required to check for nullification status
    unconstrained pub fn are_parameters_nullified(_owner: AztecAddress, _randomness: Field) -> bool {
        let compute_initialization_nullifier = ExampleNote::generate_round_randomness_nullifier;
        let nullifier = compute_initialization_nullifier(_owner, _randomness);
        check_nullifier_exists(nullifier)
    }

    /// @notice Serializes a note into a preimage.
    pub fn serialize(self) -> [Field; EXAMPLE_NOTE_LEN] {
        [self.owner.to_field(), self.randomness]
    }

    /// @notice Deserializes a note from a preimage.
    pub fn deserialize(preimage: [Field; EXAMPLE_NOTE_LEN]) -> Self {
        ExampleNote {
            owner: AztecAddress::from_field(preimage[0]),
            randomness: preimage[1],
            header: NoteHeader::empty(),
        }
    }

    /// @notice Computes the note hash.
    pub fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash(serialize(self))
    }
    
    /// @notice Computes the nullifier of the note using the randomness.
    pub fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice Computes the nullifier of the note using the randomness.
    pub fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(ExampleNoteMethods, self);
        let nullifier_key = self.randomness;

        dep::std::hash::pedersen_hash([
            note_hash_for_nullify,
            nullifier_key,
        ])
    }

    /// @notice Sets the note header.
    pub fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    // Broadcasts the note to alice.
    pub fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        let encryption_pub_key = get_public_key(self.owner);

        emit_encrypted_log(
            context, // context
            (*context).this_address(), // the address of the contract calling this function
            slot, // the slot the note is stored in
            encryption_pub_key, // the encryption key of the alice
            self.serialize(), // the contents of the note, serialized
        );
    }
}

fn deserialize(preimage: [Field; EXAMPLE_NOTE_LEN]) -> ExampleNote {
    ExampleNote::deserialize(preimage)
}

fn serialize(note: ExampleNote) -> [Field; EXAMPLE_NOTE_LEN] {
    note.serialize()
}

fn compute_note_hash(note: ExampleNote) -> Field {
    note.compute_note_hash()
}

fn compute_nullifier(note: ExampleNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}

fn compute_nullifier_without_context(note: ExampleNote) -> Field {
    note.compute_nullifier_without_context()
}

fn get_header(note: ExampleNote) -> NoteHeader {
    note.header
}

fn set_header(note: &mut ExampleNote, header: NoteHeader) {
    note.set_header(header)
}

fn broadcast(context: &mut PrivateContext, slot: Field, note: ExampleNote) {
    note.broadcast(context, slot);
}

global ExampleNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast
};