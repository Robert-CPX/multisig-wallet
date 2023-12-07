import { expect } from "chai";
import { ethers } from "hardhat";

describe("MultisigWallet", function () {
  async function deployMultisigWallet() {
    const signers = await ethers.getSigners();

    const account1 = await signers[0].getAddress();
    const account2 = await signers[1].getAddress();

    const amount = ethers.parseEther("10");

    const Contract = await ethers.getContractFactory(
      "MultisigWallet",
      signers[0]
    );
    const multisigContract = await Contract.deploy([account1, account2], {
      value: amount,
    });

    await multisigContract.deployed();

    const contract = multisigContract;
    const contractAddress = multisigContract.address;

    return { contract, contractAddress, account1, account2 };
  }

  describe("Constructor", function () {
    it("Should add the owners to the contract", async function () {
      const {
        contract,
        contractAddress,
        account1,
        account2,
      } = await deployMultisigWallet();

      const owners = await contract.getOwners();

      expect(account1, account2).to.equal(owners[0], owners[1]);
    });

    it("Should add the number of confimations successfully", async function () {
      const {
        contract,
        contractAddress,
        account1,
        account2,
      } = await deployMultisigWallet();

      const confirmations = await contract.getNumberOfConfimationsRequired();
      expect(Number(confirmations.toString())).to.equal(2);
    });
  });

  describe("SubmitTx", function () {
    it("Should successfully submit a transaction", async function () {
      const {
        contract,
        contractAddress,
        account1,
        account2,
      } = await deployMultisigWallet();

      const amount = ethers.parseEther("1");

      const reason = "Payment for stuff";
      await contract.submitTransaction(account2, amount, reason, {
        from: account1,
      });

      const txs = await contract.getTransactions();

      expect(txs.length).to.be.greaterThan(0);
    });
  });

  describe("ConfirmTx", function () {
    it("Should fail when a non owner tries to confirm the transaction", async function () {
      const { contract } = await deployMultisigWallet();

      // const signers = await ethers.getSigners()
      const [deployer, otherAccount, thirdAccount] = await ethers.getSigners();

      const localContract = await contract.connect(thirdAccount);

      await expect(localContract.confirmTransaction(0)).to.be
        .revertedWithCustomError;
    });

    it("Should fail when a transaction entered does not exist", async function () {
      const { contract, account1, account2 } = await deployMultisigWallet();

      const amount = ethers.parseEther("1");
      const reason = "Payments for stuff";

      // Add a new transaction
      await contract.submitTransaction(account2, amount, reason, {
        from: account1,
      });

      await expect(contract.confirmTransaction(100)).to.be
        .revertedWithCustomError;
    });
  });

  it("Should successfully confirm the transaction", async function () {
    const { contract, account1, account2 } = await deployMultisigWallet();

    const amount = ethers.parseEther("1");
    const reason = "Payments for stuff";

    // Add a new transaction
    await contract.submitTransaction(account2, amount, reason, {
      from: account1,
    });

    // Confirm the Tx
    await contract.confirmTransaction(0);

    // Check to see if it was confirmed
    const txStatus = await contract.getTransactions();

    expect(Number(txStatus[0].confirmations.toString())).to.equal(1);
  });

  describe("ExecuteTx", function () {
    it("Should fail when the transaction has less confirmations", async function () {
      const { contract, account1, account2 } = await deployMultisigWallet();

      const amount = ethers.parseEther("1");
      const reason = "Payments for stuff";

      // Add a new transaction
      await contract.submitTransaction(account2, amount, reason, {
        from: account1,
      });

      // Confirm the Tx
      await contract.confirmTransaction(0);

      await expect(contract.executeTransaction(0)).to.be
        .revertedWithCustomError;
    });

    it("Should successfully execute the transaction and transfer the balance", async function () {
      const { contract, account1, account2 } = await deployMultisigWallet();

      const [deployer, otherAccount, thirdAccount] = await ethers.getSigners();

      const localContract = await contract.connect(otherAccount);

      const amount = ethers.parseEther("1");
      const reason = "Payments for stuff";

      // Add a new transaction
      await contract.submitTransaction(account2, amount, reason, {
        from: account1,
      });

      // Confirm the Tx
      await contract.confirmTransaction(0);

      await localContract.confirmTransaction(0);

      // Execute the tx
      await contract.executeTransaction(0);

      const tx = await contract.getTransactions();

      expect(tx[0].executed).to.be.true;
    });
  });
});