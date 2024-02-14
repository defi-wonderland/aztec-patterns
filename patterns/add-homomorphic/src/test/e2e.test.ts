import {
  AccountWalletWithPrivateKey,
  createPXEClient,
  ExtendedNote,
  Fr,
  Note,
  PXE,
  waitForPXE,
} from "@aztec/aztec.js";

import { AdditiveHomomorphicEncryptionContract } from "../../../../artifacts/add-he/add-he/AdditiveHomomorphicEncryption.js";
import {
  createAccount,
  getInitialTestAccountsWallets,
} from "@aztec/accounts/testing";

// Global variables
let pxe: PXE;
let counter: AdditiveHomomorphicEncryptionContract;

let user1: AccountWalletWithPrivateKey;
let user2: AccountWalletWithPrivateKey;
let user3: AccountWalletWithPrivateKey;
let deployer: AccountWalletWithPrivateKey;

const BJJ_PRIVATE_KEY =
  2360067582289791756090345803415031600606727745697750731963540090262281758098n;

// Resulting public key on the BJJ curve when deriving from the BJJ_PRIVATE_KEY declared above
// Use https://github.com/jat9292/babyjubjub-utils to generate new ones
const PUBLIC_KEY_BJJ_X =
  17330617431291011652840919965771789495411317073490913928764661286424537084069n;
const PUBLIC_KEY_BJJ_Y =
  12743939760321333065626220799160222400501486578575623324257991029865760346009n;
const PUBLIC_KEY_BJJ = {
  point: { x: PUBLIC_KEY_BJJ_X, y: PUBLIC_KEY_BJJ_Y },
};

// Randomness have been generated using a modified babyjubjub-utils that prints the randomness used when encrypting.
const RANDOMNESS_INITIAL_ENCRYPTION =
  2127434375679321579932213798607732554355166199806066497941655719367141499766n;
const RANDOMNESS_USER_1 =
  1438319796528918033583393704730685046956217498280656265812575377511832574392n;
const RANDOMNESS_USER_2 =
  1048079536491508724972388093791272936112538204421938605612284921668780878715n;
const RANDOMNESS_USER_3 =
  2115925703451186072229956066949536779308650088120047035594563780397884741597n;

const FINAL_CUM_SUM_C1_X =
  3919606867997237668040567668233747244452711745206604584349608308343594620673n;
const FINAL_CUM_SUM_C1_Y =
  14742875759735887788510420745824939173336243957508133148437004653480301110834n;
const FINAL_CUM_SUM_C2_X =
  521687571595162779479180406855798846599524023215386831438765875476136529268n;
const FINAL_CUM_SUM_C2_Y =
  6438471728501791047453348744695539915081915500069492754704209849111324891174n;
const ENCRYPTED_SUM = {
  C1: {
    point: {
      x: FINAL_CUM_SUM_C1_X,
      y: FINAL_CUM_SUM_C1_Y,
    },
  },
  C2: {
    point: {
      x: FINAL_CUM_SUM_C2_X,
      y: FINAL_CUM_SUM_C2_Y,
    },
  },
};

const { PXE_URL = "http://localhost:8080" } = process.env;

const setupSandbox = async () => {
  const pxe = createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};

// Setup: Set the sandbox
beforeAll(async () => {
  pxe = await setupSandbox();
  [user1, user2, user3] = await getInitialTestAccountsWallets(pxe);
  deployer = await createAccount(pxe);
}, 120_000);

describe("E2E additive homomorphic encryption", () => {
  beforeAll(async () => {
    // Deploy the contract
    const counterReceipt = await AdditiveHomomorphicEncryptionContract.deploy(
      deployer,
      PUBLIC_KEY_BJJ,
      RANDOMNESS_INITIAL_ENCRYPTION
    )
      .send()
      .wait();

    counter = counterReceipt.contract;

    // Add the note with the public key to the pxe - only for user1 as the same pxe is used by all
    await pxe.addNote(
      new ExtendedNote(
        new Note([
          new Fr(PUBLIC_KEY_BJJ.point.x),
          new Fr(PUBLIC_KEY_BJJ.point.y),
        ]),
        user1.getAddress(),
        counter.address,
        new Fr(2),
        counterReceipt.txHash
      )
    );
  }, 200_000);

  describe("increment(...)", () => {
    it("user1 adds 1", async () => {
      const txReceipt = await counter
        .withWallet(user1)
        .methods.increment(1n, RANDOMNESS_USER_1)
        .send()
        .wait();

      expect(txReceipt.status).toBe("mined");
    });

    it("user2 adds 1", async () => {
      const txReceipt = await counter
        .withWallet(user2)
        .methods.increment(1n, RANDOMNESS_USER_2)
        .send()
        .wait();

      expect(txReceipt.status).toBe("mined");
    });

    it("user3 adds 0", async () => {
      const txReceipt = await counter
        .withWallet(user3)
        .methods.increment(0n, RANDOMNESS_USER_3)
        .send()
        .wait();

      expect(txReceipt.status).toBe("mined");
    });
  });

  describe("get_encrypted_counter()", () => {
    it("should return the correct encrypted sum", async () => {
      const encrypted_counter = await counter.methods
        .get_encrypted_counter()
        .view();

      expect(encrypted_counter).toStrictEqual(ENCRYPTED_SUM);
    });
  });
});