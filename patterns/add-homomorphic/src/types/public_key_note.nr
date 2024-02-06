 use dep::aztec::{
    context::PrivateContext,
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
    },
};

use dep::std::ec::tecurve::affine::Point;

use crate::types::{
    affine_point::AffinePoint,
};
 
/// @title PublicKeyNote
/// @member bjj_public_key The BabyJubJub public key to be associated with this note.
/// @member header The NoteHeader of the PublicKeyNote.
struct PublicKeyNote {
    bjj_public_key: AffinePoint,
    header: NoteHeader
}

global PUBLIC_KEY_NOTE_SERIALIZED_LEN: Field = 2;

impl PublicKeyNote {
    
    /// @notice Creates a new PublicKeyNote instance.
    /// @param _bjj_public_key The BabyJubJub public key to be associated with this note.
    /// @return A new instance of PublicKeyNote.
    pub fn new(_bjj_public_key: AffinePoint) -> Self {
        PublicKeyNote {
            bjj_public_key: _bjj_public_key,
            header: NoteHeader::empty(),
        }
    }

    /// @notice Serializes the PublicKeyNote into a fixed-size array.
    /// @return An array representing the serialized PublicKeyNote.
    fn serialize(self) -> [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN] {
        [self.bjj_public_key.point.x, self.bjj_public_key.point.y]
    }

    /// @notice Deserializes a fixed-size array into a PublicKeyNote.
    /// @param preimage The array to deserialize from.
    /// @return A new instance of PublicKeyNote.
    fn deserialize(preimage: [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN]) -> Self {
        PublicKeyNote {
            bjj_public_key: AffinePoint::new(Point::new(preimage[0], preimage[1])),
            header: NoteHeader::empty(), 
        }
    }

    /// @notice Computes the hash of the PublicKeyNote.
    /// @return The computed hash as a Field element.
    fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash([
            self.bjj_public_key.point.x,
            self.bjj_public_key.point.y
        ])
    }

    /// @notice Computes the nullifier of the PublicKeyNote.
    /// @dev This note isn't nullifiable, hence it returns 0.
    /// @param _context The private context (unused).
    /// @return Always returns 0.
    fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice Computes the nullifier of the PublicKeyNote without a context.
    /// @dev This note isn't nullifiable, hence it returns 0.
    /// @return Always returns 0.
    fn compute_nullifier_without_context(self) -> Field {
         let _ = self; // Avoid compiler warning (same # acir opcodes and backend size)
         0
    }

    /// @notice Sets the header of the PublicKeyNote.
    /// @param header The new NoteHeader to be set.
    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice Broadcasts the PublicKeyNote.
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
 
fn deserialize(preimage: [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN]) -> PublicKeyNote {
    PublicKeyNote::deserialize(preimage)
}
 
fn serialize(note: PublicKeyNote) -> [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN] {
    note.serialize()
}
 
fn compute_note_hash(note: PublicKeyNote) -> Field {
    note.compute_note_hash()
}
 
fn compute_nullifier(note: PublicKeyNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}
 
fn compute_nullifier_without_context(note: PublicKeyNote) -> Field {
    note.compute_nullifier_without_context()
}
 
fn get_header(note: PublicKeyNote) -> NoteHeader {
    note.header
}
 
fn set_header(note: &mut PublicKeyNote, header: NoteHeader) {
    note.set_header(header)
}
 
fn broadcast(context: &mut PrivateContext, slot: Field, note: PublicKeyNote) {
    note.broadcast(context, slot);
}

global PublicKeyNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast,
};