import {
    AccountWalletWithPrivateKey,
    createPXEClient,
    ExtendedNote,
    Fr,
    PXE,
    waitForPXE,
  } from "@aztec/aztec.js";
  
  import { SharedNoteContract } from "../../../../artifacts/note-sharing/SharedNote.js";
  import { createAccount, getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
  let sharedNote: SharedNoteContract;
  
  let alice: AccountWalletWithPrivateKey;
  let bob: AccountWalletWithPrivateKey;
  let deployer: AccountWalletWithPrivateKey;
  let randomAccount: AccountWalletWithPrivateKey;
  
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  
  const setupSandbox = async () => {
    const pxe = createPXEClient(PXE_URL);
    await waitForPXE(pxe);
    return pxe;
  };
  
  // Setup: Set the sandbox
  beforeAll(async () => {
    pxe = await setupSandbox();
    [alice, bob, deployer] = await getInitialTestAccountsWallets(pxe);
    randomAccount = await createAccount(pxe)

    }, 120_000);

  
  describe("E2E Shared Note", () => {
    beforeAll(async () => {
      const sharedNoteReceipt = await SharedNoteContract.deploy(deployer)
        .send()
        .wait();
  
      sharedNote = sharedNoteReceipt.contract;
    }, 200_000);

    describe("create_and_share_note(...)", () => {
        let shared_key_nullifier_alice: Fr;
        let shared_key_nullifier_bob: Fr;
        let sharedNotes: ExtendedNote[]; 

        it("should not revert", async () => {
            const txReceipt = await sharedNote
            .withWallet(alice)
            .methods.create_and_share_note(
                bob.getAddress(),
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");
        })
        
        it("should create two notes", async () => {
            expect(sharedNotes.length).toBe(2);
        })

        it("should create a note for alice with the correct parameters", async () => {
            const aliceParam = sharedNotes[0].note.items[0];
            const bobParam = sharedNotes[0].note.items[1];
            const noteOwner = sharedNotes[0].owner;

            const aliceAddress = alice.getAddress();

            expect(aliceParam).toEqual(aliceAddress);
            expect(bobParam).toEqual(bob.getAddress());
            expect(noteOwner).toEqual(aliceAddress);
            
            shared_key_nullifier_alice = sharedNotes[0].note.items[2];
        })
        
        it("should create a note for bob with the correct parameters", async () => {
            const aliceParam = sharedNotes[1].note.items[0];
            const bobParam = sharedNotes[1].note.items[1];
            const noteOwner = sharedNotes[1].owner;

            const bobAddress = bob.getAddress();

            expect(aliceParam).toEqual(alice.getAddress());
            expect(bobParam).toEqual(bob.getAddress());
            expect(noteOwner).toEqual(bobAddress);

            shared_key_nullifier_bob = sharedNotes[1].note.items[2];
        })

        it("nullifier key is the same between the 2 notes", async () => {
            expect(shared_key_nullifier_alice).toEqual(
                shared_key_nullifier_bob
            );
        });
        
        it("should revert if the note already exists", async () => {
            const txReceipt = sharedNote
            .withWallet(alice)
            .methods.create_and_share_note(bob.getAddress())
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note already exists 'shared_note.is_none()'"
            );
        })
    })

    describe("bob_action", () => {
        let sharedNotes: ExtendedNote[]; 

        it("should revert if the note doesnt exist", async () => {
            const txReceipt = sharedNote
            .withWallet(bob)
            .methods.bob_action(randomAccount.getAddress())
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note doesnt exist '!shared_note.is_none()'"
            );
        })

        it("should not revert", async () => {
            const txReceipt = await sharedNote
            .withWallet(bob)
            .methods.bob_action(
                alice.getAddress(),
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");        
        })

        it("should nullify the note", async () => {
           expect(sharedNotes.length).toBe(0);
        })
    })

    describe("alice_action", () => {
        let sharedNotes: ExtendedNote[]; 
        let sharedNotesAfterNullification: ExtendedNote[];

        beforeAll(async () => {
            // Because we nullified the note in the previous test, we need to create a new one.
            const txReceipt = await sharedNote
            .withWallet(alice)
            .methods.create_and_share_note(
                bob.getAddress(),
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes
        }, 200_000);

        it("should have existing notes", async () => {
            expect(sharedNotes.length).toBe(2);
        })

        it("should revert if the note doesnt exist", async () => {
            const txReceipt = sharedNote
            .withWallet(alice)
            .methods.alice_action(randomAccount.getAddress())
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note doesnt exist '!shared_note.is_none()'"
            );
        })

        it("should not revert", async () => {
            const txReceipt = await sharedNote
            .withWallet(alice)
            .methods.alice_action(
                bob.getAddress(),
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotesAfterNullification = visibleNotes

            expect(txReceipt.status).toBe("mined");  
        })

        it("should nullify the note", async () => {
            expect(sharedNotesAfterNullification.length).toBe(0);
        })
    })
  });