use dep::std;
use dep::aztec::context::{ PrivateContext, PublicContext };
use dep::aztec::protocol_types::{
    address::AztecAddress,
    constants::RETURN_VALUES_LENGTH,
    abis::function_selector::FunctionSelector,
};

// Interface for calling Token functions from a private context
struct CallbackInterface {
  address: Field,
}

impl CallbackInterface {
  pub fn at(address: Field) -> Self {
      Self {
          address,
      }
  }
  
  pub fn callback(
    self,
    context: &mut PrivateContext,
    caller: AztecAddress
    data: Field,
  ) -> [Field; RETURN_VALUES_LENGTH] {
    let mut serialized_args = [0; 2];
    
    serialized_args[0] = data;
    serialized_args[1] = caller.to_field();

    let selector = FunctionSelector::from_signature("callback(Field,Field");
    context.call_private_function(AztecAddress::from_field(self.address), selector, serialized_args)
  }
}