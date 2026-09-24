import { id } from "https://cdn.jsdelivr.net/npm/ethers@6.13.5/+esm";
import { CONTRACTS, SEPOLIA_EXPLORER } from "./config.js";
import { getContract, formatError, getInjectedProvider } from "./contracts.js";
import identityArtifact from "../abi/Identity.json" with { type: "json" };

const identityABI = identityArtifact.abi || identityArtifact;
const walletAddress = document.getElementById("walletAddress");

function result(panelId, message, details = [], hash = "") {
    const panel = document.getElementById(panelId);
    panel.classList.add("is-visible");
    panel.querySelector(".result-message").textContent = message;
    panel.querySelector(".result-data").textContent = details.join("\n");
    const link = panel.querySelector(".result-link");
    link.textContent = hash ? "View on Etherscan" : "";
    link.href = hash ? SEPOLIA_EXPLORER + "/tx/" + hash : "#";
}

async function account() {
    const ethereum = getInjectedProvider();
    if (!ethereum) throw new Error("MetaMask is not detected in this tab.");
    const accounts = await ethereum.request({ method: "eth_requestAccounts" });
    if (!accounts.length) throw new Error("Connect a wallet first.");
    walletAddress.textContent = accounts[0];
    return accounts[0];
}

function addressFrom(idName, fallback) {
    return document.getElementById(idName).value.trim() || fallback;
}

async function readIdentityRecord(contract, address) {
    // The public mapping getter is available on the existing deployment and has no role check.
    return contract.dids(address);
}

async function getIdentity() {
    try {
        const caller = await account();
        const target = addressFrom("readIdentityAddress", caller);
        const contract = await getContract(CONTRACTS.identity, identityABI);
        const record = await readIdentityRecord(contract, target);
        result("getIdentityResult", record[3] ? "Identity found" : "No active identity", [
            "Wallet: " + target,
            "DID: " + (record[0] || "Not registered"),
            "Document hash: " + record[1],
            "Entity type: " + record[2],
            "Active: " + record[3],
            "Registered by: " + (record[5] || "—")
        ]);
    } catch (error) {
        result("getIdentityResult", "Identity read failed", [formatError(error)]);
    }
}

async function createIdentity() {
    const button = document.getElementById("registerIdentity");
    try {
        const caller = await account();
        const did = document.getElementById("createIdentityDid").value.trim();
        const documentText = document.getElementById("createIdentityDocument").value.trim();
        const target = addressFrom("createIdentityAddress", caller);
        if (!did || !documentText || !target) throw new Error("Enter DID, document reference, and wallet address.");
        button.disabled = true;
        result("createIdentityResult", "Waiting for digital signature...");
        const contract = await getContract(CONTRACTS.identity, identityABI);
        const documentHash = id(documentText);
        const tx = await contract.registerIdentities(did, documentHash, document.getElementById("createEntityType").value, Math.floor(Date.now() / 1000), target);
        result("createIdentityResult", "Transaction submitted", ["DID: " + did, "Wallet: " + target, "Transaction: " + tx.hash], tx.hash);
        await tx.wait();
        const record = await readIdentityRecord(contract, target);
        result("createIdentityResult", "DID registered successfully", ["DID: " + record[0], "Document hash: " + record[1], "Entity type: " + record[2], "Wallet: " + target, "Active: " + record[3], "Registered by: " + record[5], "Transaction: " + tx.hash], tx.hash);
    } catch (error) {
        result("createIdentityResult", "Identity creation failed", [formatError(error)]);
    } finally {
        button.disabled = false;
    }
}

async function updateIdentity() {
    const button = document.getElementById("updateIdentityButton");
    try {
        const caller = await account();
        const target = addressFrom("updateIdentityAddress", caller);
        const documentText = document.getElementById("updateIdentityDocument").value.trim();
        if (!documentText || !target) throw new Error("Enter a wallet address and new document reference.");
        button.disabled = true;
        result("updateIdentityResult", "Waiting for digital signature...");
        const contract = await getContract(CONTRACTS.identity, identityABI);
        const documentHash = id(documentText);
        const tx = await contract.updateIdentity(target, documentHash, document.getElementById("updateEntityType").value);
        result("updateIdentityResult", "Update submitted", ["Wallet: " + target, "New document hash: " + documentHash, "Transaction: " + tx.hash], tx.hash);
        await tx.wait();
        const record = await readIdentityRecord(contract, target);
        result("updateIdentityResult", "Identity updated successfully", ["Wallet: " + target, "DID: " + record[0], "Document hash: " + record[1], "Entity type: " + record[2], "Active: " + record[3], "Transaction: " + tx.hash], tx.hash);
    } catch (error) {
        result("updateIdentityResult", "Identity update failed", [formatError(error)]);
    } finally {
        button.disabled = false;
    }
}

async function deactivateIdentity() {
    const button = document.getElementById("deleteIdentityButton");
    try {
        const caller = await account();
        const target = addressFrom("deleteIdentityAddress", caller);
        button.disabled = true;
        result("deleteIdentityResult", "Waiting for digital signature...");
        const contract = await getContract(CONTRACTS.identity, identityABI);
        const tx = await contract.deactivateIdentity(target);
        result("deleteIdentityResult", "Deactivation submitted", ["Wallet: " + target, "Transaction: " + tx.hash], tx.hash);
        await tx.wait();
        const active = await contract.isActive(target);
        result("deleteIdentityResult", "Identity deactivated successfully", ["Wallet: " + target, "Active: " + active, "Transaction: " + tx.hash], tx.hash);
    } catch (error) {
        result("deleteIdentityResult", "Identity deactivation failed", [formatError(error)]);
    } finally {
        button.disabled = false;
    }
}

document.getElementById("getIdentityButton").addEventListener("click", getIdentity);
document.getElementById("registerIdentity").addEventListener("click", createIdentity);
document.getElementById("updateIdentityButton").addEventListener("click", updateIdentity);
document.getElementById("deleteIdentityButton").addEventListener("click", deactivateIdentity);
