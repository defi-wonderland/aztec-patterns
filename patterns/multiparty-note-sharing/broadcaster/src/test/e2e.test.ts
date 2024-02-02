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
  import { createAccount, getInitialTestAccountsWallets } from "@aztec/accounts/testing";
  
  // Global variables
  let pxe: PXE;
  let broadcaster: BroadcasterContract;
  let sharedKey: Fr;
  
  let user: AccountWalletWithPrivateKey;
  let user1: AccountWalletWithPrivateKey;
  let user2: AccountWalletWithPrivateKey;
  let user3: AccountWalletWithPrivateKey;
  let user4: AccountWalletWithPrivateKey;
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
    user4 = await createAccount(pxe);
    }, 120_000);

  
  describe("E2E Shared Nullifier", () => {
    beforeAll(async () => {
      const broadcasterContract = await BroadcasterContract.deploy(deployer)
        .send()
        .wait();
  
      broadcaster = broadcasterContract.contract;

      wallets = [user1, user2, user3, user4];
      // Exclude user as he will be the owner due to him creating the note
      accounts = [user1.getAddress(), user2.getAddress(), user3.getAddress(), user4.getAddress()];
    }, 200_000);

    // Note, in this test suite we can only test this function case and the nullifying as owner case
    // given that Aztec currently does not support broadcasting in different transaction than creation
    // The correct working of broadcast_note_for and nullify_note will be tested in the integration-contract
    // test suite.
    describe("create_note(...)", () => {
        let sharedNotes: ExtendedNote[]; 

        it("should not revert", async () => {
            const txReceipt = await broadcaster
            .withWallet(user)
            .methods.create_note()
            .send()
            .wait({debug: true});

            const { visibleNotes } = txReceipt.debugInfo!;
            sharedNotes = visibleNotes

            expect(txReceipt.status).toBe("mined");
        })
        
        it("should create one note", async () => {
            expect(sharedNotes.length).toBe(1);
        })

        it("should create a note for the caller with the correct parameters", async () => {
            const ownerParam = sharedNotes[0].note.items[0];
            const noteOwner = sharedNotes[0].owner;
            
            const userAddress = user.getAddress();
            
            expect(ownerParam).toEqual(userAddress);
            expect(noteOwner).toEqual(userAddress);

            sharedKey = sharedNotes[0].note.items[1];
        })        
    })
  });


  const createNullifyNoteAuthWit = async (
    broadcaster: BroadcasterContract,
    from: AccountWalletWithPrivateKey,
    agent: AztecAddress,
    shared_key: any
  ) => {
    const nonce = Fr.random();
  
    // We need to compute the message we want to sign and add it to the wallet as approved
    const action = broadcaster.methods.nullify_note(shared_key, nonce);
    const messageHash = await computeAuthWitMessageHash(agent, action.request());
  
    // Both wallets are connected to same node and PXE so we could just insert directly using
    // await wallet.signAndAddAuthWitness(messageHash, );
    // But doing it in two actions to show the flow.
    const witness = await from.createAuthWitness(messageHash);
    await from.addAuthWitness(witness);

    return nonce;
  };