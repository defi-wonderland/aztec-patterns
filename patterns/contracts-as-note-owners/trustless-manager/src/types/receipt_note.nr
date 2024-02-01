/////////////////////////////////////////////////////////////////////
//                             Imports                             //
/////////////////////////////////////////////////////////////////////

use dep::aztec::{
    context::PrivateContext,
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify,
    },
    hash::pedersen_hash,
    protocol_types::address::AztecAddress,
    oracle::{
        get_public_key::get_public_key,
    },
    log::emit_encrypted_log,
};

/////////////////////////////////////////////////////////////////////
//                              Class                              //
/////////////////////////////////////////////////////////////////////

/// @notice A note that represents the receipt for an escrowed token
/// @member owner the owner of the note
/// @member from the user that escrows the tokens
/// @member to the user that will receive the escrowed tokens
/// @member random_id the id given by the escrow contract after escrowing the tokens
/// @member shared_nullifier the nullifier shared between the from and to
/// @member payment_token the token escrowed
/// @member escrow the address of the escrow contract
/// @member amount the amount of tokens escrowed
/// @member header The note header
struct ReceiptNote {
    owner: AztecAddress,
    from: AztecAddress,
    to: AztecAddress,
    random_id: Field,
    shared_nullifier: Field,
    payment_token: AztecAddress,
    escrow: AztecAddress,
    amount: Field,
    header: NoteHeader
}

global RECEIPT_NOTE_LEN: Field = 8;

impl ReceiptNote {

    /// @notice creates a new ReceiptNote
    /// @param owner the owner of the note
    /// @param from the user that escrows the tokens
    /// @param to the user that will receive the escrowed tokens
    /// @param random_id the id given by the escrow contract after escrowing the tokens
    /// @param shared_nullifier the nullifier shared between the from and to
    /// @param payment_token the token escrowed
    /// @param escrow the address of the escrow contract
    /// @param amount the amount of tokens escrowed
    /// @param header The note header
    pub fn new(owner: AztecAddress, from: AztecAddress, to: AztecAddress, random_id: Field, shared_nullifier: Field, payment_token: AztecAddress, escrow: AztecAddress, amount: Field) -> Self {
        ReceiptNote {
            owner,
            from,
            to,
            random_id,
            shared_nullifier,
            payment_token,
            escrow,
            amount,
            header: NoteHeader::empty(),
        }
    }

    /// @notice serializes the note
    fn serialize(self) -> [Field; RECEIPT_NOTE_LEN] {
        [self.owner.to_field(), self.from.to_field(), self.to.to_field(), self.random_id, self.shared_nullifier, self.payment_token.to_field(), self.escrow.to_field(), self.amount]
    }

    /// @notice deserialize the note
    /// @param preimage the preimage of the note
    fn deserialize(preimage: [Field; RECEIPT_NOTE_LEN]) -> Self {
        ReceiptNote {
            owner: AztecAddress::from_field(preimage[0]),
            from: AztecAddress::from_field(preimage[1]),
            to: AztecAddress::from_field(preimage[2]),
            random_id: preimage[3],
            shared_nullifier: preimage[4],
            payment_token: AztecAddress::from_field(preimage[5]),
            escrow: AztecAddress::from_field(preimage[6]),
            amount: preimage[7],
            header: NoteHeader::empty(),
        }
    }

    /// @notice compute the note hash
    fn compute_note_hash(self) -> Field {
        // TODO(#1205) Should use a non-zero generator index.
        pedersen_hash(self.serialize(),0)
    }

    /// @notice computes the nullifier using the shared nullifier
    /// @param context the private context
    fn compute_nullifier(self, _context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice computes the nullifier using the shared nullifier
    fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(ReceiptNoteMethods, self);
        let nullifier_key = self.shared_nullifier;

        pedersen_hash([
            note_hash_for_nullify,
            nullifier_key,
        ], 0)
    }

    /// @notice gets the note header
    /// @param header the note header
    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice emits the note to the user that escrowed the tokens
    /// @param context the private context
    /// @param slot the slot where the note is stored in the contract
    fn broadcast(self, context: &mut PrivateContext, slot: Field) {
        let encryption_pub_key = get_public_key(self.from);

        emit_encrypted_log(
            context,
            (*context).this_address(),
            slot,
            encryption_pub_key,
            self.serialize(),
        );
    }
}

/////////////////////////////////////////////////////////////////////
//                         Global methods                          //
/////////////////////////////////////////////////////////////////////

fn deserialize(preimage: [Field; RECEIPT_NOTE_LEN]) -> ReceiptNote {
    ReceiptNote::deserialize(preimage)
}

fn serialize(note: ReceiptNote) -> [Field; RECEIPT_NOTE_LEN] {
    note.serialize()
}

fn compute_note_hash(note: ReceiptNote) -> Field {
    note.compute_note_hash()
}

fn compute_nullifier(note: ReceiptNote, context: &mut PrivateContext) -> Field {
    note.compute_nullifier(context)
}

fn compute_nullifier_without_context(note: ReceiptNote) -> Field {
    note.compute_nullifier_without_context()
}

fn get_header(note: ReceiptNote) -> NoteHeader {
    note.header
}

fn set_header(note: &mut ReceiptNote, header: NoteHeader) {
    note.set_header(header)
}

fn broadcast(context: &mut PrivateContext, slot: Field, note: ReceiptNote) {
    note.broadcast(context, slot);
}

global ReceiptNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    compute_nullifier_without_context,
    get_header,
    set_header,
    broadcast,
};