import { CONTRACTS, SEPOLIA_EXPLORER } from "./config.js";
import { getContract, formatError } from "./contracts.js";
import { apiPost } from "./api.js";
import assetArtifact from "../abi/AssetNFT.json" with { type: "json" };

const assetABI = assetArtifact.abi || assetArtifact;

const status = document.getElementById("assetStatus");

function setStatus(message, hash, panelId = "", details = "") {
    status.innerHTML = hash
        ? `${message} <a href="${SEPOLIA_EXPLORER}/tx/${hash}" target="_blank" rel="noreferrer">View transaction</a>`
        : message;
    if (panelId) {
        const panel = document.getElementById(panelId);
        panel.classList.add("is-visible");
        panel.querySelector(".result-message").textContent = message;
        panel.querySelector(".result-data").textContent = details || (hash ? "Transaction: " + hash : "");
        const link = panel.querySelector(".result-link");
        link.textContent = hash ? "View on Etherscan" : "";
        link.href = hash ? SEPOLIA_EXPLORER + "/tx/" + hash : "#";
    }
}

function formatAsset(asset) {
    return [
        "Token: " + asset[0],
        "Name: " + asset[1],
        "Owned by: " + asset[2],
        "Metadata URI: " + asset[3],
        "Asset type: " + asset[4],
        "State: " + asset[5],
        "Active: " + asset[6],
        "Created by: " + asset[7],
        "DID: " + asset[8],
        "Assigned to: " + asset[9]
    ].join("\n");
}

function mintedTokenId(contract, receipt) {
    for (const log of receipt.logs) {
        try {
            const parsed = contract.interface.parseLog(log);
            if (parsed?.name === "mintedAssets") return parsed.args[0];
        } catch (_) {
            // Ignore logs emitted by other contracts.
        }
    }
    throw new Error("The mint transaction was confirmed but no minted asset event was found.");
}

async function mint() {
    const button = document.getElementById("mintButton");
    try {
        button.disabled = true;
        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
        const name = document.getElementById("assetName").value.trim();
        const metadataURI = document.getElementById("metadataURI").value.trim();
        const assetType = document.getElementById("assetType").value.trim();
        const createdBy = accounts[0];
        if (!name || !assetType) throw new Error("Enter asset name and type.");
        setStatus("Requesting mint signature in MetaMask...", "", "mintResult");
        const contract = await getContract(CONTRACTS.assetNFT, assetABI);
        const tx = await contract.mintAsset(name, metadataURI, assetType, document.getElementById("assetActive").checked);
        setStatus("Mint submitted.", tx.hash, "mintResult");
        const receipt = await tx.wait();
        const tokenId = mintedTokenId(contract, receipt);
        const asset = await contract.assets(tokenId);
        const metadata = await apiPost("/assets/metadata", {
            token_id: Number(tokenId),
            name,
            metadata_uri: metadataURI,
            asset_type: assetType,
            is_active: document.getElementById("assetActive").checked,
            created_by: createdBy,
            transaction_hash: tx.hash
        });
        setStatus("Asset minted and metadata JSON saved.", tx.hash, "mintResult", [
            formatAsset(asset),
            `Metadata file: ${metadata.path}`
        ].join("\n"));
    } catch (error) {
        setStatus(formatError(error), "", "mintResult");
    } finally {
        button.disabled = false;
    }
}

async function enableAssetPermissions() {
    const button = document.getElementById("enableAssetPermissionsButton");
    try {
        button.disabled = true;
        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
        const contract = await getContract(CONTRACTS.assetNFT, assetABI);
        const owner = await contract.OWNER();
        if (owner.toLowerCase() !== accounts[0].toLowerCase()) {
            throw new Error("Connected wallet is not the AssetNFT owner. On-chain owner: " + owner);
        }
        const roleArgs = contract.interface.getFunction("assignRole").inputs.length === 3
            ? [accounts[0], 1, 1]
            : [accounts[0], 1];
        const roleTx = await contract.assignRole(...roleArgs);
        setStatus("Owner role submitted.", roleTx.hash, "mintResult");
        await roleTx.wait();

        for (const permission of [1, 2, 3]) {
            const tx = await contract.grantPermission(accounts[0], permission);
            setStatus(`Permission ${permission} submitted.`, tx.hash, "mintResult");
            await tx.wait();
        }

        setStatus("Owner asset permissions enabled on Sepolia.", "", "mintResult");
    } catch (error) {
        setStatus(formatError(error), "", "mintResult");
    } finally {
        button.disabled = false;
    }
}

async function assign() {
    const button = document.getElementById("assignButton");
    try {
        button.disabled = true;
        const contract = await getContract(CONTRACTS.assetNFT, assetABI);
        const tokenId = document.getElementById("tokenId").value;
        const did = document.getElementById("assetDID").value.trim();
        const owner = document.getElementById("owner").value.trim();
        if (!tokenId || !did || !owner) throw new Error("Enter token ID, recipient DID, and owner address.");
        setStatus("Requesting assignment signature in MetaMask...", "", "assignResult");
        const tx = await contract.assignAsset(tokenId, did, owner);
        setStatus("Assignment submitted.", tx.hash, "assignResult");
        await tx.wait();
        const asset = await contract.assets(tokenId);
        setStatus("Asset assigned successfully on Sepolia.", tx.hash, "assignResult", formatAsset(asset));
    } catch (error) {
        setStatus(formatError(error), "", "assignResult");
    } finally {
        button.disabled = false;
    }
}

async function updateState() {
    const button = document.getElementById("updateStateButton");
    try {
        button.disabled = true;
        const tokenId = document.getElementById("stateTokenId").value;
        const state = document.getElementById("assetState").value;
        if (!tokenId) throw new Error("Enter a token ID.");
        setStatus("Requesting state update signature in MetaMask...", "", "stateResult");
        const contract = await getContract(CONTRACTS.assetNFT, assetABI);
        const tx = await contract.updateAssetState(tokenId, state);
        setStatus("State update submitted.", tx.hash, "stateResult");
        await tx.wait();
        const asset = await contract.assets(tokenId);
        setStatus("Asset state updated successfully on Sepolia.", tx.hash, "stateResult", formatAsset(asset));
    } catch (error) {
        setStatus(formatError(error), "", "stateResult");
    } finally {
        button.disabled = false;
    }
}

async function approveToken() {
    try {
        const address = document.getElementById("approvalAddress").value.trim();
        const tokenId = document.getElementById("approvalTokenId").value;
        if (!address || !tokenId) throw new Error("Enter approval address and token ID.");
        const contract = await getContract(CONTRACTS.assetNFT, assetABI);
        const tx = await contract.approve(address, tokenId);
        setStatus("Approval submitted.", tx.hash, "erc721Result");
        await tx.wait();
        const approved = await contract.getApproved(tokenId);
        setStatus("ERC-721 approval confirmed.", tx.hash, "erc721Result", "Token: " + tokenId + "\nApproved address: " + approved);
    } catch (error) {
        setStatus(formatError(error), "", "erc721Result");
    }
}

async function setOperator() {
    try {
        const operator = document.getElementById("approvalAddress").value.trim();
        if (!operator) throw new Error("Enter an operator address.");
        const contract = await getContract(CONTRACTS.assetNFT, assetABI);
        const tx = await contract.setApprovalForAll(operator, document.getElementById("operatorApproved").checked);
        setStatus("Operator approval submitted.", tx.hash, "erc721Result");
        await tx.wait();
        const approved = await contract.isApprovedForAll((await contract.runner.getAddress()), operator);
        setStatus("Operator approval confirmed.", tx.hash, "erc721Result", "Operator: " + operator + "\nApproved: " + approved);
    } catch (error) {
        setStatus(formatError(error), "", "erc721Result");
    }
}

async function loadAsset() {
    try {
        const contract = await getContract(CONTRACTS.assetNFT, assetABI, false);
        const asset = await contract.assets(document.getElementById("historyToken").value);
        const message = asset[0] === 0n ? "Asset not found" : "Asset loaded successfully";
        const details = asset[0] === 0n ? "" : formatAsset(asset);
        document.getElementById("history").innerText = details;
        setStatus(message, "", "historyResult");
        document.getElementById("historyResult").querySelector(".result-data").textContent = details;
    } catch (error) {
        document.getElementById("history").innerText = formatError(error);
        setStatus("Asset read failed", "", "historyResult");
        document.getElementById("historyResult").querySelector(".result-data").textContent = formatError(error);
    }
}

document.getElementById("mintButton").addEventListener("click", mint);
document.getElementById("enableAssetPermissionsButton").addEventListener("click", enableAssetPermissions);
document.getElementById("assignButton").addEventListener("click", assign);
document.getElementById("updateStateButton").addEventListener("click", updateState);
document.getElementById("approveButton").addEventListener("click", approveToken);
document.getElementById("setOperatorButton").addEventListener("click", setOperator);
document.getElementById("historyButton").addEventListener("click", loadAsset);
