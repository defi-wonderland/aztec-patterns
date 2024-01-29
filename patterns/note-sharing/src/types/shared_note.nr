use dep::aztec::{
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify,
    },
    oracle::{
        get_public_key::get_public_key,
    },
    log::emit_encrypted_log,
    context::PrivateContext,
    protocol_types::{
        address::AztecAddress
    }
};

/// @member alice: the user who shares the note
/// @member bob: the user who the note is shared with
/// @member shared_nullifier_key: the key used to nullify the note
/// @member header: the note header
struct SharedNote {
    alice: AztecAddress,
    bob: AztecAddress,
    shared_nullifier_key: Field,
    header: NoteHeader
}

/// @notice Declare the length of the note.
global SHARED_NOTE_LEN: Field = 3;

/// @notice Declare the methods of the note.
impl SharedNote {
    /// @notice Creates a new note.
    /// @param  alice: the user who shares the note
    /// @param  bob: the user who the note is shared with
    /// @param  shared_nullifier_key: the key used to nullify the note
    pub fn new(
            alice: AztecAddress,
            bob: AztecAddress,
            shared_nullifier_key: Field,
        ) -> Self {

        SharedNote {
            alice,
            bob,
            shared_nullifier_key,
            header: NoteHeader::empty(),
        }

    }

    /// @notice Serializes a note into a preimage.
    pub fn serialize(self) -> [Field; SHARED_NOTE_LEN] {
        [self.alice.to_field(), self.bob.to_field(), self.shared_nullifier_key]
    }

    /// @notice Deserializes a note from a preimage.
    pub fn deserialize(preimage: [Field; SHARED_NOTE_LEN]) -> Self {
        SharedNote {
            alice: AztecAddress::from_field(preimage[0]),
            bob: AztecAddress::from_field(preimage[1]),
            shared_nullifier_key: preimage[2],
            header: NoteHeader::empty(),
        }
    }

    /// @notice Computes the note hash.
    pub fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash(serialize(self))
    }
    
    /// @notice Computes the nullifier of the note using the shared_nullifier_key. This allows anyone that knows this key to nullify the note.
    pub fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice Computes the nullifier of the note using the shared_nullifier_key. This allows anyone that knows this key to nullify the note.
    pub fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(SharedNoteMethods, self);
        let nullifier_key = self.shared_nullifier_key;

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
        let encryption_pub_key = get_public_key(self.alice);

        emit_encrypted_log(
            context, // context
            (*context).this_address(), // the address of the contract calling this function
            slot, // the slot the note is stored in
            encryption_pub_key, // the encryption key of the alice
            self.serialize(), // the contents of the note, serialized
        );
    }
}

fn deserialize(preimage: [Field; SHARED_NOTE_LEN]) -> SharedNote {
    SharedNote::deserialize(preimage)
}

fn serialize(note: SharedNote) -> [Field; SHARED_NOTE_LEN] {
    note.serialize()
}

fn compute_note_hash(note: SharedNote) -> Field {
    note.compute_note_hash()
}

fn compute_nullifier(note: SharedNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}

fn compute_nullifier_without_context(note: SharedNote) -> Field {
    note.compute_nullifier_without_context()
}

fn get_header(note: SharedNote) -> NoteHeader {
    note.header
}

fn set_header(note: &mut SharedNote, header: NoteHeader) {
    note.set_header(header)
}

fn broadcast(context: &mut PrivateContext, slot: Field, note: SharedNote) {
    note.broadcast(context, slot);
}

global SharedNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast
};