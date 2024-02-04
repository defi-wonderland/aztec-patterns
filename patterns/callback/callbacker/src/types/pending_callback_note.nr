use dep::aztec::{
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify,
    },
    oracle::{
        nullifier_key::get_nullifier_secret_key,
        get_public_key::get_public_key,
    },
    log::emit_encrypted_log,
    context::PrivateContext,
    protocol_types::{
        address::AztecAddress
    },
    hash::pedersen_hash
};

/// @member owner: The address of the note owner, who can settle it (Bob)
/// @member sender: The address which created this pending callback (the CallMeBack contract)
/// @member beneficiary: The address of the callback beneficiary (Alice)
/// @member data: The data associated to use for the callback
/// @member header: The note header.
struct PendingCallbackNote {
    owner: AztecAddress,
    sender: AztecAddress,
    beneficiary: AztecAddress,
    data: Field,
    header: NoteHeader
}

/// @notice The length of the pending callback note excluding the header
global PENDING_CALLBACK_NOTE_LEN: Field = 4;

/// @notice Implements the methods of the PendingCallbackNote
impl PendingCallbackNote {
    /// @notice Creates a new PendingCallbackNote
    /// @param owner The address of the note owner
    /// @param sender The address of the callback request sender
    /// @param beneficiary The address of the beneficiary
    /// @param data The data associated with the note
    /// @return A new instance of PendingCallbackNote
    pub fn new(
            owner: AztecAddress,
            sender: AztecAddress,
            beneficiary: AztecAddress,
            data: Field,
        ) -> Self {

        PendingCallbackNote {
            owner,
            sender,
            beneficiary,
            data,
            header: NoteHeader::empty(),
        }

    }

    /// @notice Serializes the note into a preimage.
    /// @return An array of fields representing the serialized note.
    pub fn serialize(self) -> [Field; PENDING_CALLBACK_NOTE_LEN] {
        [
            self.owner.to_field(),
            self.sender.to_field(),
            self.beneficiary.to_field(),
            self.data,
        ]
    }

    /// @notice Deserializes a note from a preimage.
    /// @param preimage An array of fields representing the serialized note.
    /// @return A new instance of PendingCallbackNote based on the provided preimage.
    pub fn deserialize(preimage: [Field; PENDING_CALLBACK_NOTE_LEN]) -> Self {
        PendingCallbackNote {
            owner: AztecAddress::from_field(preimage[0]),
            sender: AztecAddress::from_field(preimage[1]),
            beneficiary: AztecAddress::from_field(preimage[2]),
            data: preimage[3],
            header: NoteHeader::empty(),
        }
    }

    /// @notice Computes the hash of the note.
    /// @dev Utilizes the Pedersen hash function to compute the hash of the serialized note.
    /// @return The computed hash of the note.
    pub fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash(serialize(self))
    }
    
    /// @notice Computes the nullifier of the note with context.
    /// @dev Placeholder for computing the nullifier with context, currently returns the result of `compute_nullifier_without_context`
    /// @return The computed nullifier of the note.
    fn compute_nullifier(self, context: &mut PrivateContext) -> Field {
        self.compute_nullifier_without_context()
    }

    /// @notice Computes the nullifier of the note without context.
    /// @return The default nullifier value.
    fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(PendingCallbackNoteMethods, self);
        let secret = get_nullifier_secret_key(self.owner);
        // TODO(#1205) Should use a non-zero generator index.
        pedersen_hash([
            note_hash_for_nullify,
            secret.low,
            secret.high,
        ],0)
    }

    /// @notice Sets the header of the note.
    /// @param header The new header to be set for the note.
    pub fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    /// @notice Broadcasts the note to its owner.
    /// @param context The private context of the contract.
    /// @param slot The storage slot where the note is stored.
    /// @dev Encrypts and emits a log containing the serialized note, intended for the note's owner.
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