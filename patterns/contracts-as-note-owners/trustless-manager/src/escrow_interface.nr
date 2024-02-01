use dep::aztec::{
  context::{ PrivateContext, PublicContext, Context },
  protocol_types::{
    address::AztecAddress,
    abis::function_selector::FunctionSelector,
  }
};

struct Escrow {
  address: AztecAddress,
}

impl Escrow {
  pub fn at(address: AztecAddress) -> Self {
    Self { address }
  }

  pub fn escrow(self: Self, context: &mut PrivateContext, from: Field, owner: Field, fee: Field, payment_token: Field, nonce: Field, recipients: [AztecAddress; 4]) -> Field {
    let _return_values = context.call_private_function(
      self.address,
      FunctionSelector::from_signature("escrow((Field),(Field),Field,(Field),Field,[(Field);4])"),
      [from, owner, fee, payment_token, nonce, recipients[0].to_field(), recipients[1].to_field(), recipients[2].to_field(), recipients[3].to_field()]
    );
    _return_values[0]
  }

  pub fn release_escrow(self: Self, context: &mut PrivateContext, random_id: Field, to: Field, nonce: Field) {
    let _return_values = context.call_private_function(
      self.address,
      FunctionSelector::from_signature("release_escrow(Field,(Field),Field)"),
      [random_id, to, nonce]
    );
  }
}