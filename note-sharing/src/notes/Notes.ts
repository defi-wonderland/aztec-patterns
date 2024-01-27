import { AztecAddress } from "@aztec/aztec.js";

type AztecAddressWithInner = {
  inner: bigint
}

function containsInner(param: any): param is AztecAddressWithInner {
  return (param as AztecAddressWithInner).inner !== undefined;
}

export class SharedNote {
  alice: AztecAddress;
  bob: AztecAddress;
  shared_nullifier_key: bigint;

  constructor(note: any) {
    this.alice = containsInner(note.alice)
    ? AztecAddress.fromBigInt((note.alice as AztecAddressWithInner).inner)
    : AztecAddress.fromBigInt(note.alice.asBigInt);

    this.bob = containsInner(note.bob)
    ? AztecAddress.fromBigInt((note.bob as AztecAddressWithInner).inner)
    : AztecAddress.fromBigInt(note.bob.asBigInt);

    this.shared_nullifier_key = note.shared_nullifier_key;
  }
}
