import {
    AccountWalletWithPrivateKey,
    createPXEClient,
    ExtendedNote,
    Fr,
    PXE,
    waitForPXE,
  } from "@aztec/aztec.js";
  
  import { ExampleNoteContract } from "../../../../artifacts/immediate-nullification/ExampleNote.js";
  import { getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
  let exampleNote: ExampleNoteContract;
  
  let user: AccountWalletWithPrivateKey;
  let deployer: AccountWalletWithPrivateKey;
  
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  
  const setupSandbox = async () => {
    const pxe = createPXEClient(PXE_URL);
    await waitForPXE(pxe);
    return pxe;
  };
  
  // Setup: Set the sandbox
  beforeAll(async () => {
    pxe = await setupSandbox();
    [user, deployer] = await getInitialTestAccountsWallets(pxe);

    }, 120_000);

  
  describe("E2E Example Note", () => {
    let randomness: Fr;
    beforeAll(async () => {
      const exampleNoteReceipt = await ExampleNoteContract.deploy(deployer)
        .send()
        .wait();
  
      exampleNote = exampleNoteReceipt.contract;
    }, 200_000);

    describe("create_note(...)", () => {
        let exampleNotes: ExtendedNote[];

        it("should mine the transaction", async () => {
            randomness = Fr.random();
            const txReceipt = await exampleNote
            .withWallet(user)
            .methods.create_note(randomness)
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            exampleNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");
        })
        
        it("should create one note", async () => {
            expect(exampleNotes.length).toBe(1);
        })

        it("should create a note for the user with the correct parameters", async () => {
            const ownerParam = exampleNotes[0].note.items[0];
            const randomnessParam = exampleNotes[0].note.items[1];
            const noteOwner = exampleNotes[0].owner;

            const userAddress = user.getAddress();

            expect(ownerParam).toEqual(userAddress);
            expect(randomnessParam).toEqual(randomness);
            expect(noteOwner).toEqual(userAddress);
        })
        
        it("should nullify the randomness and owner parameter combination", async () => {
            const result = await exampleNote
            .withWallet(user)
            .methods.are_parameters_nullified(
                user.getAddress(),
                randomness
            )
            .view({ from: user.getAddress() });
            expect(result).toBe(true);
        })

        it("should drop the transaction if the user tries to create a note with the same parameters", async () => {
            // Transaction gets dropped
            await expect(
                exampleNote
                    .withWallet(user)
                    .methods.create_note(randomness)
                    .send()
                    .wait()
            ).rejects.toThrow();
        })
    })

    describe("consume_note(...)", () => {
        let exampleNotes: ExtendedNote[]; 

        it("should revert if the note doesnt exist", async () => {
            let newRandomness = Fr.random();
            const txReceipt = exampleNote
            .withWallet(user)
            .methods.consume_note(newRandomness)
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note doesnt exist '!example_note.is_none()'"
            );
        })

        it("should mine the transaction", async () => {
            const txReceipt = await exampleNote
            .withWallet(user)
            .methods.consume_note(
                randomness,
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            exampleNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");        
        })

        it("should nullify the note", async () => {
           expect(exampleNotes.length).toBe(0);
        })
    })
  });