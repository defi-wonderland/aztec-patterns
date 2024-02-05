import {
    AccountWalletWithPrivateKey,
    AztecAddress,
    computeAuthWitMessageHash,
    createPXEClient,
    ExtendedNote,
    Fr,
    PXE,
    waitForPXE,
  } from "@aztec/aztec.js";
  
  import { BroadcasterContract } from "../../../../../artifacts/multiparty-note-sharing/broadcaster/Broadcaster.js";
  import { IntegratingContractContract as IntegratingContract } from "../../../../../artifacts/multiparty-note-sharing/integrating-contract/IntegratingContract.js";
  import { createAccount, getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
  let broadcaster: BroadcasterContract;
  let integratingContract: IntegratingContract;
  let sharedKey: Fr;
  
  let user: AccountWalletWithPrivateKey;
  let user1: AccountWalletWithPrivateKey;
  let user2: AccountWalletWithPrivateKey;
  let user3: AccountWalletWithPrivateKey;
  let deployer: AccountWalletWithPrivateKey;
  let wallets: AccountWalletWithPrivateKey[];
  let accounts: AztecAddress[];
  
  const { PXE_URL = 'http://localhost:8080' } = process.env;
  
  const setupSandbox = async () => {
    const pxe = createPXEClient(PXE_URL);
    await waitForPXE(pxe);
    return pxe;
  };
  
  // Setup: Set the sandbox
  beforeAll(async () => {
    pxe = await setupSandbox();
    [user, user1, deployer] = await getInitialTestAccountsWallets(pxe);
    user2 = await createAccount(pxe);
    user3 = await createAccount(pxe);
    }, 120_000);

  
  describe("E2E Shared Nullifier", () => {
    beforeAll(async () => {

      const integratingContractDeployment = await IntegratingContract.deploy(deployer)
        .send()
        .wait();

      integratingContract = integratingContractDeployment.contract;

      broadcaster = await BroadcasterContract.deploy(deployer)
        .send()
        .deployed();
        
      // No need for user account as it will be the first to nullify the notes in the test
      wallets = [user1, user2, user3];
      accounts = [user.getAddress(), user1.getAddress(), user2.getAddress(), user3.getAddress()];

      // Register contract
      await pxe.registerRecipient(integratingContract.completeAddress);
    }, 200_000);
    
    // Note, in this test suite we can only test this function case and the nullifying as owner case
    // given that Aztec currently does not support broadcasting in different transaction than creation
    // The correct working of broadcast_note_for and nullify_note will be tested in the integration-contract
    // test suite.
    describe("get_and_broadcast_note(...)", () => {
        let sharedNotes: ExtendedNote[]; 

        it("should not revert", async () => {
            const txReceipt = await integratingContract
            .withWallet(user)
            .methods.get_and_broadcast_note(accounts, broadcaster.address)
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");
        })
        
        it("should create 4 notes", async () => {
            expect(sharedNotes.length).toBe(4);
            sharedKey = sharedNotes[0].note.items[1];
        })

        it("should create the same note for everyone", async () => {
            const sharedKeys = sharedNotes.map((note) => note.note.items[1]);
            const ownerParams = sharedNotes.map(note => note.note.items[0]);
            const noteOwner = sharedNotes.map(note => note.owner);

            sharedKeys.forEach((key) => { expect(key).toEqual(sharedKey) });
            ownerParams.forEach((owner) => { expect(owner).toEqual(integratingContract.address) });
            noteOwner.forEach((owner, i) => { expect(owner).toEqual(accounts[i]) });
        })       
    })

    describe("nullify_note_first_iteration", () => {
        let sharedNotes: ExtendedNote[];

        // For the first iteration the notes are already created
        it("should not revert when the account tries to nullify the note", async () => {
            const txReceipt = await integratingContract
            .withWallet(user)
            .methods.nullify_note(
                sharedKey, broadcaster.address
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");     
        })

        it("should nullify the notes", async () => {
            expect(sharedNotes.length).toBe(0);
        })
    })

    describe(`nullify_note_new_iterations`, () => {
        let sharedNotes: ExtendedNote[];

        // For the second iteration onward, the notes are nullified so we need to create them again
        beforeAll(async () => {
            // Create note and broadcast it to all acounts
            const txReceipt = await integratingContract
            .withWallet(user3)
            .methods.get_and_broadcast_note(accounts, broadcaster.address)
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            sharedKey = sharedNotes[0].note.items[1];
        })

        it("should create 4 notes", async () => {
            expect(sharedNotes.length).toBe(4);
        }) 

        it("should not revert when the account tries to nullify the note", async () => {
            const txReceipt = await integratingContract
            .withWallet(user)
            .methods.nullify_note(
                sharedKey, broadcaster.address
            )
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");     
        })

        it("should nullify the notes", async () => {
            expect(sharedNotes.length).toBe(0);
        })
    })
  });