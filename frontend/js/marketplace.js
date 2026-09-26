import { CONTRACTS, SEPOLIA_EXPLORER } from "./config.js";
import { connectBlockchainWallet, formatError, getContract } from "./contracts.js";
import marketplaceArtifact from "../abi/AssetMarketplace.json" with { type: "json" };
import erc20Artifact from "../abi/ERC20.json" with { type: "json" };
import assetArtifact from "../abi/AssetNFT.json" with { type: "json" };

const marketplaceABI = marketplaceArtifact.abi || marketplaceArtifact;
const erc20ABI = erc20Artifact.abi || erc20Artifact;
const assetABI = assetArtifact.abi || assetArtifact;
const status = document.getElementById("marketplaceStatus");

function showResult(panelId, message, details = "", hash = "") {
    status.innerHTML = hash
        ? `${message} <a href="${SEPOLIA_EXPLORER}/tx/${hash}" target="_blank" rel="noreferrer">View transaction</a>`
        : message;

    const panel = document.getElementById(panelId);
    panel.classList.add("is-visible");
    panel.querySelector(".result-message").textContent = message;
    panel.querySelector(".result-data").textContent = details;
    const link = panel.querySelector(".result-link");
    link.textContent = hash ? "View on Etherscan" : "";
    link.href = hash ? `${SEPOLIA_EXPLORER}/tx/${hash}` : "#";
}

function parseTokenAmount(value, decimals) {
    const normalized = value.trim();
    if (!normalized) throw new Error("Enter an amount.");
    const [whole, fraction = ""] = normalized.split(".");
    if (!/^\d+$/.test(whole) || !/^\d*$/.test(fraction)) {
        throw new Error("Enter a valid numeric amount.");
    }
    if (fraction.length > decimals) {
        throw new Error(`Amount has more than ${decimals} decimal places.`);
    }
    return BigInt(whole + fraction.padEnd(decimals, "0"));
}

function formatTokenAmount(value, decimals, symbol) {
    const raw = BigInt(value);
    const scale = 10n ** BigInt(decimals);
    const whole = raw / scale;
    const fraction = (raw % scale).toString().padStart(decimals, "0").replace(/0+$/, "");
    return `${whole}${fraction ? "." + fraction : ""} ${symbol}`;
}

function formatListing(listing, decimals = 6, symbol = "USDC") {
    return [
        "Token: " + listing[0],
        "Seller: " + listing[1],
        "Price: " + formatTokenAmount(listing[2], decimals, symbol),
        "Active: " + listing[3],
        "Updated: " + (Number(listing[4]) ? new Date(Number(listing[4]) * 1000).toLocaleString() : "Never")
    ].join("\n");
}

async function tokenInfo() {
    const marketplace = await getContract(CONTRACTS.marketplace, marketplaceABI, false);
    const tokenAddress = await marketplace.usdcToken();
    const token = await getContract(tokenAddress, erc20ABI, false);
    const [decimals, symbol] = await Promise.all([
        token.decimals().catch(() => 6),
        token.symbol().catch(() => "USDC")
    ]);
    return { address: tokenAddress, decimals: Number(decimals), symbol };
}

async function readListing() {
    try {
        const tokenId = document.getElementById("readTokenId").value;
        if (!tokenId) throw new Error("Enter a token ID.");
        const [marketplace, info] = await Promise.all([
            getContract(CONTRACTS.marketplace, marketplaceABI, false),
            tokenInfo()
        ]);
        const listing = await marketplace.assetsForSale(tokenId);
        showResult("readListingResult", listing[3] ? "Listing is active" : "Listing is not active", formatListing(listing, info.decimals, info.symbol));
    } catch (error) {
        showResult("readListingResult", "Listing read failed", formatError(error));
    }
}

async function listAsset() {
    const button = document.getElementById("listAssetButton");
    try {
        button.disabled = true;
        const tokenId = document.getElementById("listTokenId").value;
        if (!tokenId) throw new Error("Enter a token ID.");
        const { address } = await connectBlockchainWallet();
        const info = await tokenInfo();
        const price = parseTokenAmount(document.getElementById("salePrice").value, info.decimals);
        const marketplace = await getContract(CONTRACTS.marketplace, marketplaceABI);
        const assetNFT = await getContract(CONTRACTS.assetNFT, assetABI);
        const owner = await assetNFT.ownerOf(tokenId);
        if (owner.toLowerCase() !== address.toLowerCase()) {
            throw new Error(`Connected wallet does not own token ${tokenId}. Current owner: ${owner}`);
        }
        if (!(await marketplace.hasPermission(address, 3))) {
            throw new Error("Connected wallet lacks TRANSFER_ASSET permission on the marketplace.");
        }
        const approved = await assetNFT.getApproved(tokenId);
        const approvedForAll = await assetNFT.isApprovedForAll(address, CONTRACTS.marketplace);
        if (approved.toLowerCase() !== CONTRACTS.marketplace.toLowerCase() && !approvedForAll) {
            showResult("listAssetResult", "Requesting NFT approval signature...");
            const approvalTx = await assetNFT.approve(CONTRACTS.marketplace, tokenId);
            showResult("listAssetResult", "NFT approval submitted", "Token: " + tokenId, approvalTx.hash);
            await approvalTx.wait();
        }
        showResult("listAssetResult", "Requesting list signature...");
        const tx = await marketplace._putAssetForSale(tokenId, price);
        showResult("listAssetResult", "List transaction submitted", "Token: " + tokenId, tx.hash);
        await tx.wait();
        const listing = await marketplace.assetsForSale(tokenId);
        showResult("listAssetResult", "Asset listed for sale", formatListing(listing, info.decimals, info.symbol), tx.hash);
    } catch (error) {
        showResult("listAssetResult", "Listing failed", formatError(error));
    } finally {
        button.disabled = false;
    }
}

async function checkAllowance() {
    try {
        const { address } = await connectBlockchainWallet();
        const info = await tokenInfo();
        const token = await getContract(info.address, erc20ABI, false);
        const [allowance, balance] = await Promise.all([
            token.allowance(address, CONTRACTS.marketplace),
            token.balanceOf(address)
        ]);
        showResult("allowanceResult", "Stablecoin allowance loaded", [
            "Wallet: " + address,
            "Balance: " + formatTokenAmount(balance, info.decimals, info.symbol),
            "Marketplace allowance: " + formatTokenAmount(allowance, info.decimals, info.symbol)
        ].join("\n"));
    } catch (error) {
        showResult("allowanceResult", "Allowance read failed", formatError(error));
    }
}

async function approveStablecoin() {
    const button = document.getElementById("approveStablecoinButton");
    try {
        button.disabled = true;
        const info = await tokenInfo();
        const amount = parseTokenAmount(document.getElementById("allowanceAmount").value, info.decimals);
        const token = await getContract(info.address, erc20ABI);
        showResult("allowanceResult", "Requesting approval signature...");
        const tx = await token.approve(CONTRACTS.marketplace, amount);
        showResult("allowanceResult", "Approval submitted", "Amount: " + formatTokenAmount(amount, info.decimals, info.symbol), tx.hash);
        await tx.wait();
        showResult("allowanceResult", "Marketplace allowance approved", "Amount: " + formatTokenAmount(amount, info.decimals, info.symbol), tx.hash);
    } catch (error) {
        showResult("allowanceResult", "Approval failed", formatError(error));
    } finally {
        button.disabled = false;
    }
}

async function buyAsset() {
    const button = document.getElementById("buyAssetButton");
    try {
        button.disabled = true;
        const tokenId = document.getElementById("buyTokenId").value;
        if (!tokenId) throw new Error("Enter a token ID.");
        const marketplace = await getContract(CONTRACTS.marketplace, marketplaceABI);
        showResult("buyAssetResult", "Requesting purchase signature...");
        const tx = await marketplace._buyAsset(tokenId);
        showResult("buyAssetResult", "Purchase submitted", "Token: " + tokenId, tx.hash);
        await tx.wait();
        const assetNFT = await getContract(CONTRACTS.assetNFT, assetABI, false);
        const owner = await assetNFT.ownerOf(tokenId);
        showResult("buyAssetResult", "Asset purchased", "Token: " + tokenId + "\nCurrent owner: " + owner, tx.hash);
    } catch (error) {
        showResult("buyAssetResult", "Purchase failed", formatError(error));
    } finally {
        button.disabled = false;
    }
}

async function cancelListing() {
    const button = document.getElementById("cancelListingButton");
    try {
        button.disabled = true;
        const tokenId = document.getElementById("cancelTokenId").value;
        if (!tokenId) throw new Error("Enter a token ID.");
        const marketplace = await getContract(CONTRACTS.marketplace, marketplaceABI);
        showResult("cancelListingResult", "Requesting cancel signature...");
        const tx = await marketplace._removeAssetFromSale(tokenId);
        showResult("cancelListingResult", "Cancel submitted", "Token: " + tokenId, tx.hash);
        await tx.wait();
        const listing = await marketplace.assetsForSale(tokenId);
        showResult("cancelListingResult", "Listing cancelled", "Active: " + listing[3], tx.hash);
    } catch (error) {
        showResult("cancelListingResult", "Cancel failed", formatError(error));
    } finally {
        button.disabled = false;
    }
}

async function checkMarketPermission() {
    try {
        const address = document.getElementById("permissionAddress").value.trim();
        const permission = document.getElementById("marketPermission").value;
        if (!address) throw new Error("Enter a wallet address.");
        const marketplace = await getContract(CONTRACTS.marketplace, marketplaceABI, false);
        const permitted = await marketplace.hasPermission(address, permission);
        showResult("permissionResult", "Marketplace permission loaded", "Wallet: " + address + "\nPermission " + permission + ": " + permitted);
    } catch (error) {
        showResult("permissionResult", "Permission read failed", formatError(error));
    }
}

async function grantMarketPermission() {
    const button = document.getElementById("grantMarketPermissionButton");
    try {
        button.disabled = true;
        const address = document.getElementById("permissionAddress").value.trim();
        const permission = document.getElementById("marketPermission").value;
        if (!address) throw new Error("Enter a wallet address.");
        const marketplace = await getContract(CONTRACTS.marketplace, marketplaceABI);
        showResult("permissionResult", "Requesting permission signature...");
        const tx = await marketplace.grantPermission(address, permission);
        showResult("permissionResult", "Permission grant submitted", "Wallet: " + address + "\nPermission: " + permission, tx.hash);
        await tx.wait();
        const permitted = await marketplace.hasPermission(address, permission);
        showResult("permissionResult", "Marketplace permission granted", "Wallet: " + address + "\nPermission " + permission + ": " + permitted, tx.hash);
    } catch (error) {
        showResult("permissionResult", "Permission grant failed", formatError(error));
    } finally {
        button.disabled = false;
    }
}

document.getElementById("readListingButton").addEventListener("click", readListing);
document.getElementById("listAssetButton").addEventListener("click", listAsset);
document.getElementById("checkAllowanceButton").addEventListener("click", checkAllowance);
document.getElementById("approveStablecoinButton").addEventListener("click", approveStablecoin);
document.getElementById("buyAssetButton").addEventListener("click", buyAsset);
document.getElementById("cancelListingButton").addEventListener("click", cancelListing);
document.getElementById("checkMarketPermissionButton").addEventListener("click", checkMarketPermission);
document.getElementById("grantMarketPermissionButton").addEventListener("click", grantMarketPermission);
