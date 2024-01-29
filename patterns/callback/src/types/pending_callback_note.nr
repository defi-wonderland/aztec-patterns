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

/// @member 
struct PendingCallbackNote {
    owner: AztecAddress,
    sender: AztecAddress,
    origin: AztecAddress,
    data: Field,
    header: NoteHeader
}

/// @notice Declare the length of the note (excl header).
global PENDING_CALLBACK_NOTE_LEN: Field = 4;

/// @notice Declare the methods of the note.
impl PendingCallbackNote {
    /// @notice Creates a new note.
    /// @param 
    pub fn new(
            owner: AztecAddress,
            sender: AztecAddress,
            origin: AztecAddress,
            data: Field,
        ) -> Self {

        PendingCallbackNote {
            owner,
            sender,
            origin,
            data,
            header: NoteHeader::empty(),
        }

    }

    /// @notice Serializes a note into a preimage.
    pub fn serialize(self) -> [Field; PENDING_CALLBACK_NOTE_LEN] {
        [
            self.owner.to_field(),
            self.sender.to_field(),
            self.origin.to_field(),
            self.data,
        ]
    }

    /// @notice Deserializes a note from a preimage.
    pub fn deserialize(preimage: [Field; PENDING_CALLBACK_NOTE_LEN]) -> Self {
        PendingCallbackNote {
            owner: AztecAddress::from_field(preimage[0]),
            sender: AztecAddress::from_field(preimage[1]),
            origin: AztecAddress::from_field(preimage[2]),
            data: preimage[3],
            header: NoteHeader::empty(),
        }
    }

    /// @notice Computes the note hash.
    pub fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash(serialize(self))
    }
    
    /// @notice Computes the nullifier of the note
    pub fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        0
    }

    /// @notice Immutable here, for the example
    pub fn compute_nullifier_without_context(self) -> Field {
        0
    }

    /// @notice Sets the note header.
    pub fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    // Broadcasts the note to owner.
    pub fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        let encryption_pub_key = get_public_key(self.owner);

        emit_encrypted_log(
            context, // context
            (*context).this_address(), // the address of the contract calling this function
            slot, // the slot the note is stored in
            encryption_pub_key, // the encryption key of the owner
            self.serialize(), // the contents of the note, serialized
        );
    }
}

fn deserialize(preimage: [Field; PENDING_CALLBACK_NOTE_LEN]) -> PendingCallbackNote {
    PendingCallbackNote::deserialize(preimage)
}

fn serialize(note: PendingCallbackNote) -> [Field; PENDING_CALLBACK_NOTE_LEN] {
    note.serialize()
}

fn compute_note_hash(note: PendingCallbackNote) -> Field {
    note.compute_note_hash()
}

fn compute_nullifier(note: PendingCallbackNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}

fn compute_nullifier_without_context(note: PendingCallbackNote) -> Field {
    note.compute_nullifier_without_context()
}

fn get_header(note: PendingCallbackNote) -> NoteHeader {
    note.header
}

fn set_header(note: &mut PendingCallbackNote, header: NoteHeader) {
    note.set_header(header)
}

fn broadcast(context: &mut PrivateContext, slot: Field, note: PendingCallbackNote) {
    note.broadcast(context, slot);
}

global PendingCallbackNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast
};