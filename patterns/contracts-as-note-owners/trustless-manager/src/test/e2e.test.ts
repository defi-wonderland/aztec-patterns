import {
    AccountWalletWithPrivateKey,
    AztecAddress,
    computeAuthWitMessageHash,
    computeMessageSecretHash,
    createPXEClient,
    ExtendedNote,
    Fr,
    Note,
    PXE,
    TxHash,
    waitForPXE,
  } from "@aztec/aztec.js";
  
  import { TrustlessManagerContract } from "../../../../../artifacts/contracts-as-note-owners/trustless-manager/TrustlessManager.js";
  import { EscrowContract } from "../../../../../artifacts/contracts-as-note-owners/escrow/Escrow.js";
  import { TokenContract } from "../../../../../artifacts/standard-token/Token.js";
  import { createAccount, getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
  let trustlessManager: TrustlessManagerContract;
  let escrow: EscrowContract;
  let token: TokenContract;
  let randomId: Fr;
  
  let alice: AccountWalletWithPrivateKey;
  let bob: AccountWalletWithPrivateKey;
  let tokenAdmin: AccountWalletWithPrivateKey;
  let deployer: AccountWalletWithPrivateKey;
  
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  const MINT_AMOUNT = 100000000n;
  const FEE = 100000n;
  
  const setupSandbox = async () => {
    const pxe = createPXEClient(PXE_URL);
    await waitForPXE(pxe);
    return pxe;
  };
  
  // Setup: Set the sandbox
  beforeAll(async () => {
    pxe = await setupSandbox();
    [alice, bob, deployer] = await getInitialTestAccountsWallets(pxe);
    // Declare an admin to facilitate minting tokens for testing
    tokenAdmin = await createAccount(pxe)
  }, 120_000);

  
  describe("E2E Trustless Manager", () => {
    beforeAll(async () => {
        const trustlessManagerReceipt = await TrustlessManagerContract.deploy(deployer)
        .send()
        .wait();

        trustlessManager = trustlessManagerReceipt.contract;
        escrow = await EscrowContract.deploy(deployer).send().deployed();

        // Set Alice at admin to easily mint tokens to her
        token = await TokenContract.deploy(deployer, tokenAdmin.getCompleteAddress()).send().deployed();

        // Register manager
        await pxe.registerRecipient(escrow.completeAddress);
        await pxe.registerRecipient(token.completeAddress);
        await pxe.registerRecipient(trustlessManager.completeAddress);

        // Mint tokens to Alice
        await mintTokenFor(alice, tokenAdmin, MINT_AMOUNT);
        
    }, 200_000);

    describe("deposit_fee(...)", () => {
        let notes: ExtendedNote[];
        let aliceRandomId: Fr;
        let bobRandomId: Fr;
        let aliceEscrowRandomId: Fr;
        let bobEscrowRandomId: Fr;
        let aliceSharedNullifier: Fr;
        let bobSharedNullifier: Fr;

        it("should revert if Alice does not authorize the transfer", async () => {
            const nonce = Fr.random();
            const txReceipt = trustlessManager
            .withWallet(alice)
            .methods.deposit_fee(bob.getAddress(), FEE, escrow.address, token.address, nonce)
            .simulate();

            await expect(txReceipt).rejects.toThrow();
        })

        it("should not revert", async () => {
            const nonce = await createAuthEscrowMessage(
                token,
                alice,
                escrow.address,
                FEE
            );
            const txReceipt = await trustlessManager
            .withWallet(alice)
            .methods.deposit_fee(bob.getAddress(), FEE, escrow.address, token.address, nonce)
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            notes = visibleNotes

            expect(txReceipt.status).toBe("mined");
        })
        
        it("should create five notes", async () => {
            // Note 1: ReceiptNote to Alice
            // Note 2: EscrowNote to Alice
            // Note 3: BalanceMap to Alice
            // Note 4: ReceiptNote to Bob
            // Note 5: EscrowNote to Bob
            expect(notes.length).toBe(5);
        })

        it("should create a receipt note for alice with the correct parameters", async () => {
            // Note 1: ReceiptNote to Alice
            // Note 2: EscrowNote to Alice
            // Note 3: BalancesMap to Alice
            // Note 4: ReceiptNote to Bob
            // Note 5: EscrowNote to Bob
            const ownerParam = notes[0].note.items[0];
            const fromParam = notes[0].note.items[1];
            const toParam = notes[0].note.items[2];
            const tokenParam = notes[0].note.items[5];
            const escrowParam = notes[0].note.items[6];
            const fee = notes[0].note.items[7];
            const noteOwner = notes[0].owner;
            
            expect(ownerParam).toEqual(trustlessManager.address);
            expect(fromParam).toEqual(alice.getAddress());
            expect(toParam).toEqual(bob.getAddress());
            expect(tokenParam).toEqual(token.address);
            expect(escrowParam).toEqual(escrow.address);
            expect(fee.toBigInt()).toEqual(FEE);
            expect(noteOwner).toEqual(alice.getAddress());

            aliceRandomId = notes[0].note.items[3];
            aliceSharedNullifier = notes[0].note.items[4];
        })

        it("should create an escrow note for alice with the correct parameters", async () => {
            // Note 1: ReceiptNote to Alice
            // Note 2: EscrowNote to Alice
            // Note 3: BalancesMap to Alice
            // Note 4: ReceiptNote to Bob
            // Note 5: EscrowNote to Bob
            const amountParam = notes[1].note.items[0];
            const ownerParam = notes[1].note.items[1];
            const tokenParam = notes[1].note.items[3];
            const noteOwner = notes[1].owner;
            
            expect(ownerParam).toEqual(trustlessManager.address);
            expect(tokenParam).toEqual(token.address);
            expect(amountParam.toBigInt()).toEqual(FEE);
            expect(noteOwner).toEqual(alice.getAddress());

            aliceEscrowRandomId = notes[1].note.items[2];
        })

        it("should create a note for bob with the correct parameters", async () => {
            // Note 1: ReceiptNote to Alice
            // Note 2: EscrowNote
            // Note 3: ReceiptNote to Bob
            const ownerParam = notes[3].note.items[0];
            const fromParam = notes[3].note.items[1];
            const toParam = notes[3].note.items[2];
            const tokenParam = notes[3].note.items[5];
            const escrowParam = notes[3].note.items[6];
            const fee = notes[3].note.items[7];
            const noteOwner = notes[3].owner;

            expect(ownerParam).toEqual(trustlessManager.address);
            expect(fromParam).toEqual(alice.getAddress());
            expect(toParam).toEqual(bob.getAddress());
            expect(tokenParam).toEqual(token.address);
            expect(escrowParam).toEqual(escrow.address);
            expect(fee.toBigInt()).toEqual(FEE);
            expect(noteOwner).toEqual(bob.getAddress());

            bobRandomId = notes[3].note.items[3];
            bobSharedNullifier = notes[3].note.items[4];
        })

        it("should create an escrow note for bob with the correct parameters", async () => {
          // Note 1: ReceiptNote to Alice
          // Note 2: EscrowNote to Alice
          // Note 3: BalancesMap to Alice
          // Note 4: ReceiptNote to Bob
          // Note 5: EscrowNote to Bob
          const amountParam = notes[4].note.items[0];
          const ownerParam = notes[4].note.items[1];
          const tokenParam = notes[4].note.items[3];
          const noteOwner = notes[4].owner;
          
          expect(ownerParam).toEqual(trustlessManager.address);
          expect(tokenParam).toEqual(token.address);
          expect(amountParam.toBigInt()).toEqual(FEE);
          expect(noteOwner).toEqual(bob.getAddress());

          bobEscrowRandomId = notes[4].note.items[2];

      })
        
        it("should have share the same nullifier for both receipt notes", async () => {
            expect(aliceSharedNullifier).toEqual(bobSharedNullifier);
        })

        it("should have share the same random id across notes", async () => {
            expect(aliceRandomId).toEqual(bobRandomId);
            expect(aliceRandomId).toEqual(aliceEscrowRandomId);
            expect(aliceEscrowRandomId).toEqual(bobEscrowRandomId);
            expect(aliceRandomId).not.toEqual(0);
            randomId = aliceRandomId;
        })

        it("should decrease Alice's token balance", async () => {
          const aliceBalance = await token
          .withWallet(bob)
          .methods.balance_of_private(
              alice.getAddress(),
          )
          .view({from: alice.getAddress()});

          expect(aliceBalance).toEqual(MINT_AMOUNT - FEE);
          
        })
    })

    describe("settle(...)", () => {
        let notes: ExtendedNote[];

        it("should revert if the note doesnt exist", async () => {
            let badRandomness = Fr.random();
            const txReceipt = trustlessManager
            .withWallet(alice)
            .methods.settle(badRandomness)
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note doesnt exist '!receipt_note.is_none()'"
            );
        })

        it("should not revert", async () => {
            const txReceipt = await trustlessManager
            .withWallet(bob)
            .methods.settle(
              randomId,
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            notes = visibleNotes

            expect(txReceipt.status).toBe("mined");        
        })

        it("should should increase Bob's token balance", async () => {
            const bobBalance = await token
            .withWallet(bob)
            .methods.balance_of_public(
                bob.getAddress(),
            )
            .view({from: bob.getAddress()});

            expect(bobBalance).toEqual(FEE);        
        })

        it("should nullify the notes", async () => {
           expect(notes.length).toBe(0);
        })
    })
  });

  const mintTokenFor = async (
    account: AccountWalletWithPrivateKey,
    minter: AccountWalletWithPrivateKey,
    amount: bigint
  ) => {
    // Mint private tokens
    const secret = Fr.random();
    const secretHash = await computeMessageSecretHash(secret);
  
    const receipt = await token
      .withWallet(minter)
      .methods.mint_private(amount, secretHash)
      .send()
      .wait();
  
    await addPendingShieldNoteToPXE(minter, amount, secretHash, receipt.txHash);
  
    await token
      .withWallet(minter)
      .methods.redeem_shield(account.getAddress(), amount, secret)
      .send()
      .wait();
  };

  const addPendingShieldNoteToPXE = async (
    account: AccountWalletWithPrivateKey,
    amount: bigint,
    secretHash: Fr,
    txHash: TxHash
  ) => {
    const storageSlot = new Fr(5); // The storage slot of `pending_shields` is 5.
  
    await pxe.addNote(
      new ExtendedNote(
        new Note([new Fr(amount), secretHash]),
        account.getAddress(),
        token.address,
        storageSlot,
        txHash
      )
    );
  };

  const createAuthEscrowMessage = async (
    token: TokenContract,
    from: AccountWalletWithPrivateKey,
    agent: AztecAddress,
    amount: any
  ) => {
    const nonce = Fr.random();
  
    // We need to compute the message we want to sign and add it to the wallet as approved
    const action = token.methods.unshield(from.getAddress(), agent, amount, nonce);
    const messageHash = await computeAuthWitMessageHash(agent, action.request());
  
    // Both wallets are connected to same node and PXE so we could just insert directly using
    // await wallet.signAndAddAuthWitness(messageHash, );
    // But doing it in two actions to show the flow.
    const witness = await from.createAuthWitness(messageHash);
    await from.addAuthWitness(witness);

    return nonce;
  };