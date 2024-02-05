import {
    AccountWalletWithPrivateKey,
    createPXEClient,
    ExtendedNote,
    Fr,
    PXE,
    waitForPXE,
  } from "@aztec/aztec.js";
  
  import { SharedNullifierKeyContract } from "../../../../artifacts/shared-nullifier-key/SharedNullifierKey.js";
  import { getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
  let sharedNullifier: SharedNullifierKeyContract;
  let sharedKey: Fr;
  
  let alice: AccountWalletWithPrivateKey;
  let bob: AccountWalletWithPrivateKey;
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
    [alice, bob, deployer] = await getInitialTestAccountsWallets(pxe);

    }, 120_000);

  
  describe("E2E Shared Nullifier", () => {
    beforeAll(async () => {
      const sharedNullifierKeyContract = await SharedNullifierKeyContract.deploy(deployer)
        .send()
        .wait();
  
      sharedNullifier = sharedNullifierKeyContract.contract;
    }, 200_000);

    describe("create_note(...)", () => {
        let shared_key_nullifier_alice: Fr;
        let shared_key_nullifier_bob: Fr;
        let sharedNotes: ExtendedNote[]; 

        it("should not revert", async () => {
            const txReceipt = await sharedNullifier
            .withWallet(alice)
            .methods.create_note(
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
            const ownerParam = sharedNotes[0].note.items[0];
            const noteOwner = sharedNotes[0].owner;
            
            const aliceAddress = alice.getAddress();
            
            expect(ownerParam).toEqual(aliceAddress);
            expect(noteOwner).toEqual(aliceAddress);
            
            shared_key_nullifier_alice = sharedNotes[0].note.items[1];
        })
        
        it("should create a note for bob with the correct parameters", async () => {
            const ownerParam = sharedNotes[1].note.items[0];
            const noteOwner = sharedNotes[1].owner;

            expect(ownerParam).toEqual(alice.getAddress());
            expect(noteOwner).toEqual(bob.getAddress());

            shared_key_nullifier_bob = sharedNotes[1].note.items[1];
        })

        it("nullifier key is the same between the 2 notes", async () => {
            expect(shared_key_nullifier_alice).toEqual(
                shared_key_nullifier_bob
            );
            sharedKey = shared_key_nullifier_alice;
        });

    })

    describe("nullify_note_owner", () => {
        let sharedNotes: ExtendedNote[]; 

        it("should revert if the note doesnt exist", async () => {
            let randomNullifier = Fr.random();
            const txReceipt = sharedNullifier
            .withWallet(alice)
            .methods.nullify_note(randomNullifier)
            .simulate();

            await expect(txReceipt).rejects.toThrow(
                "(JSON-RPC PROPAGATED) Assertion failed: Note doesnt exist '!shared_note.is_none()'"
            );
        })

        it("should not revert when the owner tries to nullify the note", async () => {
            const txReceipt = await sharedNullifier
            .withWallet(alice)
            .methods.nullify_note(
                sharedKey
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
    

    // Test that the recipient can also nullify the note despite the caller being the owner
    describe("nullify_note_recipient", () => {
        let sharedNotes: ExtendedNote[];
        let nullifierKey: Fr;

        // we have to create a new set of notes because the previous one was nullified by the owner 
        beforeAll(async () => {
            const txReceipt = await sharedNullifier
            .withWallet(alice)
            .methods.create_note(
                bob.getAddress(),
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes
            
            expect(txReceipt.status).toBe("mined");

            nullifierKey = sharedNotes[0].note.items[1];
        })

        it("should create two notes", async () => {
            expect(sharedNotes.length).toBe(2);
        })

        it("should not revert when the recipient tries to nullify the note", async () => {
            const txReceipt = await sharedNullifier
            .withWallet(bob)
            .methods.nullify_note(
                nullifierKey
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
  });
