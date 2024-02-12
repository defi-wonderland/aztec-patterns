 use dep::aztec::{
    context::PrivateContext,
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
    },
};
 
/// @title PrivateVariableNote
/// @member my_variable The BabyJubJub public key to be associated with this note.
/// @member header The NoteHeader of the PrivateVariableNote.
struct PrivateVariableNote {
    my_variable: Field,
    header: NoteHeader
}

global PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN: Field = 1;

impl PrivateVariableNote {
    
    /// @notice Creates a new PrivateVariableNote instance.
    /// @param _my_variable The BabyJubJub public key to be associated with this note.
    /// @return A new instance of PrivateVariableNote.
    pub fn new(my_variable: Field) -> Self {
        PrivateVariableNote {
            my_variable,
            header: NoteHeader::empty(),
        }
    }

    /// @notice Serializes the PrivateVariableNote into a fixed-size array.
    /// @return An array representing the serialized PrivateVariableNote.
    fn serialize(self) -> [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN] {
        [self.my_variable]
    }

    /// @notice Deserializes a fixed-size array into a PrivateVariableNote.
    /// @param preimage The array to deserialize from.
    /// @return A new instance of PrivateVariableNote.
    fn deserialize(preimage: [Field; PRIVATE_VARIABLE_NOTE_SERIALIZED_LEN]) -> Self {
        PrivateVariableNote {
            my_variable: preimage[0],
            header: NoteHeader::empty(), 
        }
    }

    /// @notice Computes the hash of the PrivateVariableNote.
    /// @return The computed hash as a Field element.
    fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash([
            self.my_variable
        ])
    }
    /// @notice Computes the nullifier of the PrivateVariableNote.
    /// @dev This note isn't nullifiable, hence it returns 0.
    /// @param _context The private context (unused).
    /// @return Always returns 0.
    fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice Computes the nullifier of the PrivateVariableNote without a context.
    /// @dev This note isn't nullifiable, hence it returns 0.
    /// @return Always returns 0.
    fn compute_nullifier_without_context(self) -> Field {
         let _ = self; // Avoid compiler warning (same # acir opcodes and backend size)
         0
    }

    /// @notice Sets the header of the PrivateVariableNote.
    /// @param header The new NoteHeader to be set.
    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice Broadcasts the PrivateVariableNote.
    /// @dev This note isn't private, hence there's no owner to broadcast to.
    /// @param context The private context (unused).
    /// @param slot The slot (unused).
    fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        // no owner == no broadcast
        let _ = self; // Avoid compiler warning (same # acir opcodes and backend size)
        let __ = context;
        let ___ = slot;
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