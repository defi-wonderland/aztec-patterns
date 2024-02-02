import {
  AccountWalletWithPrivateKey,
  createPXEClient,
  ExtendedNote,
  Fr,
  PXE,
  waitForPXE,
} from "@aztec/aztec.js";

import { CallMeBackContract } from "../../../../artifacts/callback/CallMeBack.js";
import { CallbackerContract } from "../../../../artifacts/callback/Callbacker.js";
import {
  createAccount,
  getInitialTestAccountsWallets,
} from "@aztec/accounts/testing";

// Global variables
let pxe: PXE;
let callbacker: CallbackerContract;
let callMeBack: CallMeBackContract;

let alice: AccountWalletWithPrivateKey;
let bob: AccountWalletWithPrivateKey;
let deployer: AccountWalletWithPrivateKey;
let randomAccount: AccountWalletWithPrivateKey;

const AMOUNT = 6969n;

const { PXE_URL = "http://localhost:8080" } = process.env;

const setupSandbox = async () => {
  const pxe = createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};

// Setup: Set the sandbox
beforeAll(async () => {
  pxe = await setupSandbox();
  [alice, bob, deployer] = await getInitialTestAccountsWallets(pxe);
  randomAccount = await createAccount(pxe);
}, 120_000);

describe("E2E Callback", () => {
  beforeAll(async () => {
    const callbackerReceipt = await CallbackerContract.deploy(deployer)
      .send()
      .wait();
    const callMeBackReceipt = await CallMeBackContract.deploy(deployer)
      .send()
      .wait();

    callbacker = callbackerReceipt.contract;
    callMeBack = callMeBackReceipt.contract;
  }, 200_000);

  describe("Atomic Callback", () => {
    let valueNote: ExtendedNote[];

    it("should mine the transaction", async () => {
      const txReceipt = await callMeBack
        .withWallet(alice)
        .methods.new_atomic_call(AMOUNT, callbacker.address)
        .send()
        .wait({ debug: true });

      const { visibleNotes } = txReceipt.debugInfo!;
      valueNote = visibleNotes;

      expect(txReceipt.status).toBe("mined");
    });

    it("should create a new value note", async () => {
      expect(valueNote.length).toBe(1);
    });

    it("should create the note for alice with the correct value", async () => {
      const valueParam = valueNote[0].note.items[0];
      const ownerParam = valueNote[0].note.items[1];
      const noteOwner = valueNote[0].owner;

      const aliceAddress = alice.getAddress();

      expect(valueParam.toBigInt()).toEqual(AMOUNT);
      expect(ownerParam).toEqual(aliceAddress);
      expect(noteOwner).toEqual(aliceAddress);
    });
  });

  describe("Async Callback", () => {
    let pendingCallbackNote: ExtendedNote[];
    let callMeBackNote: ExtendedNote[];

    describe("queue_new_call(...)", () => {
      it("should mine the transaction", async () => {
        const txReceipt = await callMeBack
          .withWallet(alice)
          .methods.new_async_call(AMOUNT, callbacker.address, bob.getAddress())
          .send()
          .wait({ debug: true });

        const { visibleNotes } = txReceipt.debugInfo!;
        pendingCallbackNote = visibleNotes;

        expect(txReceipt.status).toBe("mined");
      });

      it("should create a new pending callback note", async () => {
        expect(pendingCallbackNote.length).toBe(1);
      });

      it("should create the note for bob with the correct value", async () => {
        const allowdResolverParam = pendingCallbackNote[0].note.items[0];
        const addressToCallbackParam = pendingCallbackNote[0].note.items[1];
        const beneficiaryParam = pendingCallbackNote[0].note.items[2];
        const valueParam = pendingCallbackNote[0].note.items[3];
        const noteOwner = pendingCallbackNote[0].owner;

        const aliceAddress = alice.getAddress();
        const bobAddress = bob.getAddress();

        expect(allowdResolverParam).toEqual(bobAddress);
        expect(addressToCallbackParam).toEqual(callMeBack.address);
        expect(beneficiaryParam).toEqual(alice.getAddress());
        expect(valueParam.toBigInt()).toEqual(AMOUNT);
        expect(noteOwner).toEqual(bobAddress);
      });
    });

    describe("resolve()", () => {
      it("should mine the transaction", async () => {
        const txReceipt = await callbacker
          .withWallet(bob)
          .methods.resolve()
          .send()
          .wait({ debug: true });

        const { visibleNotes } = txReceipt.debugInfo!;
        callMeBackNote = visibleNotes;

        expect(txReceipt.status).toBe("mined");
      });

      it("should create a new value note", async () => {
        expect(callMeBackNote.length).toBe(1);
      });

      it("should create the note for alice with the correct value", async () => {
        const valueParam = callMeBackNote[0].note.items[0];
        const ownerParam = callMeBackNote[0].note.items[1];
        const noteOwner = callMeBackNote[0].owner;

        const aliceAddress = alice.getAddress();

        expect(valueParam.toBigInt()).toEqual(AMOUNT);
        expect(ownerParam).toEqual(aliceAddress);
        expect(noteOwner).toEqual(aliceAddress);
      });
    });
  });
});
