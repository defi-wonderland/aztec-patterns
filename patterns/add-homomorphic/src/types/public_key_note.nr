/////////////////////////////////////////////////////////////////////
//                             Imports                             //
/////////////////////////////////////////////////////////////////////

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

/////////////////////////////////////////////////////////////////////
//                              Class                              //
/////////////////////////////////////////////////////////////////////

/// @notice a note containing the (immutable) game configuration
/// @member divinity the address of the divinity used by the oracle
/// @member private_oracle the address of the private oracle contract
/// @member token the address of the token used for betting
/// @member bet_amount the amount of tokens to bet
/// @member header the note header
struct PublicKeyNote {
    bjj_public_key: AffinePoint,
    header: NoteHeader
}

global PUBLIC_KEY_NOTE_SERIALIZED_LEN: Field = 2;

impl PublicKeyNote {
    
    /////////////////////////////////////////////////////////////////////
    //                         Public methods                          //
    /////////////////////////////////////////////////////////////////////

    /// @notice create a new config note
    pub fn new(_bjj_public_key: AffinePoint) -> Self {
        PublicKeyNote {
            bjj_public_key: _bjj_public_key,
            header: NoteHeader::empty(),
        }
    }

    /////////////////////////////////////////////////////////////////////
    //                        Internal methods                         //
    /////////////////////////////////////////////////////////////////////

    /// @notice serialize the note
    fn serialize(self) -> [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN] {
        [self.bjj_public_key.point.x, self.bjj_public_key.point.y]
    }

    /// @notice deserialize the note
    fn deserialize(preimage: [Field; PUBLIC_KEY_NOTE_SERIALIZED_LEN]) -> Self {
        PublicKeyNote {
            bjj_public_key: AffinePoint::new(Point::new(preimage[0], preimage[1])),
            header: NoteHeader::empty(), 
        }
    }

    /// @notice compute the note hash
    fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash([
            self.bjj_public_key.point.x,
            self.bjj_public_key.point.y
        ])
    }

    /// @notice this note isn't nullifiable, returns 0
    fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice this note isn't nullifiable, returns 0
    fn compute_nullifier_without_context(self) -> Field {
         let _ = self; // Avoid compiler warning (same # acir opcodes and backend size)
         0
    }

    /// @notice get the note header
    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice this notes isn't private, no owner to emit to
    fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        // no owner == no broadcast
        let _ = self; // Avoid compiler warning (same # acir opcodes and backend size)
        let __ = context;
        let ___ = slot;
    }
}

/////////////////////////////////////////////////////////////////////
//                         Global methods                          //
/////////////////////////////////////////////////////////////////////

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