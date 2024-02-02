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
  
  import { EscrowContract } from "../../../../../artifacts/contracts-as-note-owners/escrow/Escrow.js";
  import { TokenContract } from "../../../../../artifacts/standard-token/Token.js";
  import { createAccount, getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
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

  
  describe("E2E Escrow", () => {
    beforeAll(async () => {
        const escrowReceipt = await EscrowContract.deploy(deployer)
        .send()
        .wait();

        escrow = escrowReceipt.contract;

        // Set Alice at admin to easily mint tokens to her
        token = await TokenContract.deploy(deployer, tokenAdmin.getCompleteAddress()).send().deployed();

        // Mint tokens to Alice
        await mintTokenFor(alice, tokenAdmin, MINT_AMOUNT);

        // Register manager
        await pxe.registerRecipient(escrow.completeAddress);
    }, 200_000);

    describe("escrow(...)", () => {
        let notes: ExtendedNote[];
        let randomIdAlice: Fr;
        let randomIdBob: Fr;
        let recipients: AztecAddress[];

        it("should revert if Alice does not authorize the transfer", async () => {
            const nonce = Fr.random();
            recipients = [alice.getAddress(), bob.getAddress(), AztecAddress.fromBigInt(0n), AztecAddress.fromBigInt(0n)];
            const txReceipt = escrow
            .withWallet(alice)
            .methods.escrow(alice.getAddress(), alice.getAddress(), FEE, token.address, nonce, recipients)
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
            const txReceipt = await escrow
            .withWallet(alice)
            .methods.escrow(alice.getAddress(), alice.getAddress(), FEE, token.address, nonce, recipients)
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            notes = visibleNotes

            expect(txReceipt.status).toBe("mined");
        })
        
        it("should create 3 notes", async () => {
            // Note1: EscrowNote: Alice
            // Note2: ValueNote: Alice (due to initial mint)
            // Note3: EscrowNote: Bob
            expect(notes.length).toBe(3);
        })

        it("should create a note for alice with the correct parameters", async () => {
            // Note1: EscrowNote: Alice
            // Note2: ValueNote: Alice
            // Note3: EscrowNote: Bob
            const amountParam = notes[0].note.items[0];
            const ownerParam = notes[0].note.items[1];
            const tokenParam = notes[0].note.items[3];
            const noteOwner = notes[0].owner;
            
            expect(amountParam.toBigInt()).toEqual(FEE);
            expect(ownerParam).toEqual(alice.getAddress());
            expect(tokenParam).toEqual(token.address);
            expect(noteOwner).toEqual(alice.getAddress());

            randomIdAlice = notes[0].note.items[2];
        })

        it("should create a note for bob with the correct parameters", async () => {
            // Note1: EscrowNote: Alice
            // Note2: ValueNote: Alice
            // Note3: EscrowNote: Bob
            const amountParam = notes[2].note.items[0];
            const ownerParam = notes[2].note.items[1];
            const tokenParam = notes[2].note.items[3];
            const noteOwner = notes[2].owner;
            
            expect(amountParam.toBigInt()).toEqual(FEE);
            expect(ownerParam).toEqual(alice.getAddress());
            expect(tokenParam).toEqual(token.address);
            expect(noteOwner).toEqual(bob.getAddress());

            randomIdBob = notes[2].note.items[2];
        })

        it("should have the same randomId for both escrow notes", async () => {
            expect(randomIdAlice).toEqual(randomIdBob);
            randomId = randomIdAlice;
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
            let randomNonce = Fr.random();
            const txReceipt = escrow
            .withWallet(alice)
            .methods.release_escrow(badRandomness, bob.getAddress(), randomNonce)
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note doesnt exist '!escrow_note.is_none()'"
            );
        })

        it("should notrevert", async () => {
            const zeroNonce = 0n;
            const txReceipt = await escrow
            .withWallet(alice)
            .methods.release_escrow(
                randomId,
                bob.getAddress(),
                zeroNonce
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