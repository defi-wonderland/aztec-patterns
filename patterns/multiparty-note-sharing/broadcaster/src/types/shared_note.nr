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

/// @member owner: the owner of the note
/// @member shared_nullifier_key: the key used to nullify the note
/// @member header: the note header
struct SharedNote {
    owner: AztecAddress,
    shared_nullifier_key: Field,
    header: NoteHeader
}

/// @notice Declare the length of the note.
global SHARED_NOTE_LEN: Field = 2;

/// @notice Declare the methods of the note.
impl SharedNote {
    /// @notice Creates a new SharedNote.
    /// @param  owner: the owner of the note
    /// @param  shared_nullifier_key: the key used to nullify the note
    pub fn new(
            owner: AztecAddress,
            shared_nullifier_key: Field,
        ) -> Self {
        SharedNote {
            owner,
            shared_nullifier_key,
            header: NoteHeader::empty(),
        }
    }

    /// @notice Serializes a note into a preimage.
    pub fn serialize(self) -> [Field; SHARED_NOTE_LEN] {
        [self.owner.to_field(), self.shared_nullifier_key]
    }

    /// @notice Deserializes a note from a preimage.
    /// @param  preimage: the preimage to deserialize
    pub fn deserialize(preimage: [Field; SHARED_NOTE_LEN]) -> Self {
        SharedNote {
            owner: AztecAddress::from_field(preimage[0]),
            shared_nullifier_key: preimage[1],
            header: NoteHeader::empty(),
        }
    }

    /// @notice Computes the note hash.
    pub fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash(serialize(self))
    }
    
    /// @notice Computes the nullifier of the note using the shared_nullifier_key. This allows anyone that knows this key to nullify the note.
    /// @param  context: the context of the note
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
    /// @param  header: the header to set
    pub fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice broadcasts the note to the owner as long as the owner is not a contract.
    /// @dev    it's not emitted to contracts as they don't have encryption keys.
    /// @param context the private context
    /// @param slot the slot where the note is stored in the contract
    pub fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        let encryption_pub_key = get_public_key(self.owner);
        if (encryption_pub_key.x + encryption_pub_key.y != 0) {
            emit_encrypted_log(
                context,
                (*context).this_address(),
                slot,
                encryption_pub_key,
                self.serialize(),
            );
        }
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