
/* Autogenerated file, do not edit! */

/* eslint-disable */
import {
  AztecAddress,
  AztecAddressLike,
  CompleteAddress,
  Contract,
  ContractArtifact,
  ContractBase,
  ContractFunctionInteraction,
  ContractMethod,
  DeployMethod,
  EthAddress,
  EthAddressLike,
  FieldLike,
  Fr,
  FunctionSelectorLike,
  loadContractArtifact,
  NoirCompiledContract,
  Point,
  PublicKey,
  Wallet,
} from '@aztec/aztec.js';
import SharedNoteContractArtifactJson from '../../target/note_sharing_pattern-SharedNote.json' assert { type: 'json' };
export const SharedNoteContractArtifact = loadContractArtifact(SharedNoteContractArtifactJson as NoirCompiledContract);

/**
 * Type-safe interface for contract SharedNote;
 */
export class SharedNoteContract extends ContractBase {
  
  private constructor(
    completeAddress: CompleteAddress,
    wallet: Wallet,
    portalContract = EthAddress.ZERO
  ) {
    super(completeAddress, SharedNoteContractArtifact, wallet, portalContract);
  }
  

  
  /**
   * Creates a contract instance.
   * @param address - The deployed contract's address.
   * @param wallet - The wallet to use when interacting with the contract.
   * @returns A promise that resolves to a new Contract instance.
   */
  public static async at(
    address: AztecAddress,
    wallet: Wallet,
  ) {
    return Contract.at(address, SharedNoteContract.artifact, wallet) as Promise<SharedNoteContract>;
  }

  
  /**
   * Creates a tx to deploy a new instance of this contract.
   */
  public static deploy(wallet: Wallet, ) {
    return new DeployMethod<SharedNoteContract>(Point.ZERO, wallet, SharedNoteContractArtifact, SharedNoteContract.at, Array.from(arguments).slice(1));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified public key to derive the address.
   */
  public static deployWithPublicKey(publicKey: PublicKey, wallet: Wallet, ) {
    return new DeployMethod<SharedNoteContract>(publicKey, wallet, SharedNoteContractArtifact, SharedNoteContract.at, Array.from(arguments).slice(2));
  }
  

  
  /**
   * Returns this contract's artifact.
   */
  public static get artifact(): ContractArtifact {
    return SharedNoteContractArtifact;
  }
  

  /** Type-safe wrappers for the public methods exposed by the contract. */
  public methods!: {
    
    /** compute_note_hash_and_nullifier(contract_address: struct, nonce: field, storage_slot: field, preimage: array) */
    compute_note_hash_and_nullifier: ((contract_address: AztecAddressLike, nonce: FieldLike, storage_slot: FieldLike, preimage: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** create_and_share_note(bob: struct) */
    create_and_share_note: ((bob: AztecAddressLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** bob_action(alice: struct) */
    bob_action: ((alice: AztecAddressLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** alice_action(bob: struct) */
    alice_action: ((bob: AztecAddressLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;
  };
}
