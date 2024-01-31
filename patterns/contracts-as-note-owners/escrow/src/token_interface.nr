use dep::aztec::{
  context::{ PrivateContext, PublicContext, Context },
  protocol_types::{
    address::AztecAddress,
    abis::function_selector::FunctionSelector,
  }
};

/*
    Minimal Token interface to facilitate the call to the transfer function
*/

struct Token {
  address: AztecAddress,
}

impl Token {
  pub fn at(address: AztecAddress) -> Self {
    Self { address }
  }

  pub fn unshield(self: Self, context: &mut PrivateContext, from: Field, to: Field, amount: Field, nonce: Field) {
    let _return_values = context.call_private_function(
      self.address,
      FunctionSelector::from_signature("unshield((Field),(Field),Field,Field)"),
      [from, to, amount, nonce]
    );
  }

  pub fn transfer_public(self: Self, context: &mut PublicContext, from: Field, to: Field, amount: Field, nonce: Field) {
    let _return_values = context.call_public_function(
      self.address,
      FunctionSelector::from_signature("transfer_public((Field),(Field),Field,Field)"),
      [from, to, amount, nonce]
    );
  }
}