 use dep::aztec::{
    context::PrivateContext,
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify,
    },
    oracle::{
        get_public_key::get_public_key,
        nullifier_key::get_nullifier_secret_key,
    },
    protocol_types::{
        address::AztecAddress,
    },
    log::emit_encrypted_log,
    hash::pedersen_hash,
};
 
/// @title PrivateVariableNote
/// @member my_variable the value stored
/// @member owner the note owner
/// @member header The NoteHeader of the PrivateVariableNote.
struct PrivateVariableNote {
    my_variable: Field,
    owner: AztecAddress,
    header: NoteHeader
}

global PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN: Field = 2;

impl PrivateVariableNote {
    
    /// @notice Creates a new PrivateVariableNote instance.
    /// @param my_variable the value
    /// @param owner the note owner
    /// @return A new instance of PrivateVariableNote.
    pub fn new(my_variable: Field, owner: AztecAddress) -> Self {
        PrivateVariableNote {
            my_variable,
            owner,
            header: NoteHeader::empty(),
        }
    }

    /// @notice Serializes the PrivateVariableNote into a fixed-size array.
    /// @return An array representing the serialized PrivateVariableNote.
    fn serialize(self) -> [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN] {
        [self.my_variable, self.owner.to_field()]
    }

    /// @notice Deserializes a fixed-size array into a PrivateVariableNote.
    /// @param preimage The array to deserialize from.
    /// @return A new instance of PrivateVariableNote.
    fn deserialize(preimage: [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN]) -> Self {
        PrivateVariableNote {
            my_variable: preimage[0],
            owner: AztecAddress::from_field(preimage[1]),
            header: NoteHeader::empty(), 
        }
    }

    /// @notice Computes the hash of the PrivateVariableNote.
    /// @return The computed hash as a Field element.
    fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash([
            self.my_variable,
            self.owner.to_field()
        ])
    }

    /// @notice compute a nullifier
    /// @param context
    /// @return the nullifier
    fn compute_nullifier(self, context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(PrivateVariableNoteMethods, self);
        let secret = get_nullifier_secret_key(self.owner);
        pedersen_hash([
            note_hash_for_nullify,
            secret.high,
            secret.low,
        ],0)
    }

    /// @notice Sets the header of the PrivateVariableNote.
    /// @param header The new NoteHeader to be set.
    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice Broadcasts the PrivateVariableNote.
    /// @param context The private context
    /// @param slot The slot
    fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        let encryption_pub_key = get_public_key(self.owner);

        emit_encrypted_log(
            context,
            (*context).this_address(),
            slot,
            encryption_pub_key,
            self.serialize(),
        );
    }
}
 
fn deserialize(preimage: [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN]) -> PrivateVariableNote {
    PrivateVariableNote::deserialize(preimage)
}
 
fn serialize(note: PrivateVariableNote) -> [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN] {
    note.serialize()
}
 
fn compute_note_hash(note: PrivateVariableNote) -> Field {
    note.compute_note_hash()
}
 
fn compute_nullifier(note: PrivateVariableNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}
 
fn compute_nullifier_without_context(note: PrivateVariableNote) -> Field {
    note.compute_nullifier_without_context()
}
 
fn get_header(note: PrivateVariableNote) -> NoteHeader {
    note.header
}
 
fn set_header(note: &mut PrivateVariableNote, header: NoteHeader) {
    note.set_header(header)
}
 
fn broadcast(context: &mut PrivateContext, slot: Field, note: PrivateVariableNote) {
    note.broadcast(context, slot);
}

global PrivateVariableNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast,
};