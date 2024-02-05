use dep::aztec::{
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify,
    },
    hash::pedersen_hash,
    context::PrivateContext,
    state_vars::set::Set,
    log::emit_encrypted_log,
};

use dep::aztec::protocol_types::{
    address::AztecAddress,
};

use dep::aztec::oracle::{
    rand::rand,
    get_public_key::get_public_key,
};

use dep::safe_math::SafeU120;
use dep::std::option::Option;

global ESCROW_NOTE_LEN: Field = 4;


/// @notice a note that represents an escrowed token
/// @member amount the amount escrowed
/// @member owner the owner of the note
/// @member random_id the id of the note
/// @member payment_token the token escrowed
/// @member header the note header
struct EscrowNote {
    amount: SafeU120,
    owner: AztecAddress,
    random_id: Field,
    payment_token: AztecAddress,
    header: NoteHeader,
}

impl EscrowNote {
    /// @notice creates an EscrowNote
    /// @param amount the amount escrowed
    /// @param owner the owner of the note
    /// @param random_id the id of the note
    /// @param payment_token the token escrowed
    pub fn new(amount: SafeU120, owner: AztecAddress, random_id: Field, payment_token: AztecAddress) -> Self {
        Self {
            amount,
            owner,
            random_id,
            payment_token,
            header: NoteHeader::empty(),
        }
    }

    /// @notice serializes an EscrowNote
    pub fn serialize(self) -> [Field; ESCROW_NOTE_LEN] {
        [self.amount.value as Field, self.owner.to_field(), self.random_id, self.payment_token.to_field()]
    }

    /// @notice deserializes an EscrowNote
    /// @param preimage the serialized EscrowNote
    pub fn deserialize(preimage: [Field; ESCROW_NOTE_LEN]) -> Self {
        Self {
            amount: SafeU120::new(preimage[0]),
            owner: AztecAddress::from_field(preimage[1]),
            random_id: preimage[2],
            payment_token: AztecAddress::from_field(preimage[3]),
            header: NoteHeader::empty(),
        }
    }

    /// @notice computes the note hash
    pub fn compute_note_hash(self) -> Field {
        // TODO(#1205) Should use a non-zero generator index.
        pedersen_hash(self.serialize(),0)
    }

    /// @notice computes the note's nullifier using its random_id
    /// @param context the private context
    fn compute_nullifier(self, context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice computes the note's nullifier using it's random_id
    pub fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(EscrowNoteMethods, self);
        let nullifier_key = self.random_id;

        pedersen_hash([
            note_hash_for_nullify,
            nullifier_key,
        ], 0)
    }

    /// @notice sets the note header
    /// @param header the note header
    pub fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice broadcasts the note to the owner as long as the owner is not a contract.
    /// @dev    it's not emitted to contracts as they don't have encryption keys.
    /// @param context the private context
    /// @param slot the slot where the note is stored in the contract
    pub fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        if !self.amount.is_zero() {
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
}

fn deserialize(serialized_note: [Field; ESCROW_NOTE_LEN]) -> EscrowNote {
    EscrowNote::deserialize(serialized_note)
}

fn serialize(note: EscrowNote) -> [Field; ESCROW_NOTE_LEN] {
    note.serialize()
}

fn compute_note_hash(note: EscrowNote) -> Field {
    note.compute_note_hash()
}

fn compute_nullifier(note: EscrowNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}

fn compute_nullifier_without_context(note: EscrowNote) -> Field {
    note.compute_nullifier_without_context()
}

fn get_header(note: EscrowNote) -> NoteHeader {
    note.header
}

fn set_header(note: &mut EscrowNote, header: NoteHeader) {
    note.set_header(header)
}

fn broadcast(context: &mut PrivateContext, slot: Field, note: EscrowNote) {
    note.broadcast(context, slot);
}

global EscrowNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast,
};