use dep::aztec::{
  context::{ PrivateContext, PublicContext, Context },
  protocol_types::{
    address::AztecAddress,
    abis::function_selector::FunctionSelector,
  }
};

struct Broadcaster {
  address: AztecAddress,
}

impl Broadcaster {
  pub fn at(address: AztecAddress) -> Self {
    Self { address }
  }

pub fn create_note(self: Self, context: &mut PrivateContext) -> Field {
    let _return_values = context.call_private_function(
      self.address,
      FunctionSelector::from_signature("create_note()"),
      []
    );
    _return_values[0]

  }

pub fn nullify_note(self: Self, context: &mut PrivateContext, shared_key: Field, nonce: Field) {
    let _return_values = context.call_private_function(
      self.address,
      FunctionSelector::from_signature("nullify_note(Field,Field)"),
      [shared_key, nonce]
    );
  }

  pub fn broadcast_note_for(self: Self, context: &mut PrivateContext, accounts: [AztecAddress; 4], shared_key: Field) {
    let _return_values = context.call_private_function(
      self.address,
      FunctionSelector::from_signature("broadcast_note_for([(Field);4],Field)"),
      [accounts[0].to_field(), accounts[1].to_field(), accounts[2].to_field(), accounts[3].to_field(), shared_key]
    );
  }
}