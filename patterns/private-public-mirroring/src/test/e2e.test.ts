import {
  AccountWalletWithPrivateKey,
  createPXEClient,
  ExtendedNote,
  Fr,
  Note,
  PXE,
  waitForPXE,
} from "@aztec/aztec.js";

import { PrivatePublicMirroringContract } from "../../../../artifacts/private-public-mirroring/PrivatePublicMirroring.js";
import { getInitialTestAccountsWallets } from "@aztec/accounts/testing";

// Global variables
let pxe: PXE;
let mirror: PrivatePublicMirroringContract;
let deployer: AccountWalletWithPrivateKey;

const VALUE = 1337n;

const { PXE_URL = "http://localhost:8080" } = process.env;

const setupSandbox = async () => {
  const pxe = createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};

// Setup: Set the sandbox
beforeAll(async () => {
  pxe = await setupSandbox();
  [deployer] = await getInitialTestAccountsWallets(pxe);
}, 120_000);

describe("E2E private public mirror", () => {
  let notesCreated: ExtendedNote[];

  beforeAll(async () => {
    // Deploy the contract
    const txReceipt = await PrivatePublicMirroringContract.deploy(deployer)
      .send()
      .wait({ debug: true });

    mirror = txReceipt.contract;

    await mirror.withWallet(deployer).methods.init().send().wait();
  }, 200_000);

  it("transaction is mined", async () => {
    const txReceipt = await mirror
      .withWallet(deployer)
      .methods.update_private(VALUE)
      .send()
      .wait({ debug: true });

    const { visibleNotes } = txReceipt.debugInfo!;
    notesCreated = visibleNotes;

    expect(txReceipt.status).toBe("mined");
  });

  it("note is stored", async () => {
    expect(notesCreated.length).toBe(1);

    const valueParam = notesCreated[0].note.items[0];

    expect(valueParam.toBigInt()).toBe(VALUE);
  });

  it("public variable is stored", async () => {
    const publicValue = await mirror.methods.get_public_variable_value().view();

    expect(publicValue).toBe(VALUE);
  });

  it("values stay synced", async () => {
    const NEW_VALUE = VALUE + 1n;

    const txReceipt = await mirror
      .withWallet(deployer)
      .methods.update_private(NEW_VALUE)
      .send()
      .wait({ debug: true });

    const { visibleNotes } = txReceipt.debugInfo!;
    notesCreated = visibleNotes;

    expect(txReceipt.status).toBe("mined");

    const valueParam = notesCreated[0].note.items[0];

    expect(valueParam.toBigInt()).toBe(NEW_VALUE);

    const publicValue = await mirror.methods.get_public_variable_value().view();

    expect(publicValue).toBe(NEW_VALUE);
  });
});
