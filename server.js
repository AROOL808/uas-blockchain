import { createRequire } from 'module';
const require = createRequire(import.meta.url);
require('dotenv').config();
const express = require('express');
const { ethers } = require('ethers');
const path = require('path');
const abi = require('./abi.json');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const provider = new ethers.JsonRpcProvider(process.env.ARC_TESTNET_RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contract = new ethers.Contract(process.env.CONTRACT_ADDRESS, abi, wallet);

// --- SISTEM PENCEGAHAN DOUBLE-SPEND FEE ---
// Catatan: Dalam produksi nyata, simpan data ini di Database (MySQL/MongoDB/PostgreSQL) 
// agar riwayat tidak hilang ketika server direstart.
const usedFeeHashes = new Set(); 

// Fitur Admin: Menambahkan Issuer Baru
app.post('/api/add-issuer', async (req, res) => {
    try {
        const { issuerAddress } = req.body;
        if (!ethers.isAddress(issuerAddress)) {
            return res.status(400).json({ success: false, error: 'Alamat wallet tidak valid' });
        }
        const tx = await contract.addIssuer(issuerAddress);
        await tx.wait();
        res.json({ success: true, txHash: tx.hash });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Fitur Issuer: Penerbitan Ijazah dengan Verifikasi Fee Ketat
app.post('/api/issue', async (req, res) => {
    try {
        const { id, docHash, feeTxHash } = req.body;

        if (!feeTxHash) {
            return res.status(400).json({ success: false, error: 'Transaksi fee wajib disertakan!' });
        }

        // 1. CEK PENGGUNAAN GANDA: Tolak jika feeTxHash sudah pernah dipakai
        if (usedFeeHashes.has(feeTxHash)) {
            return res.status(400).json({ success: false, error: 'Hash Fee ini SUDAH PERNAH DIGUNAKAN untuk menerbitkan ijazah lain!' });
        }

        // 2. Ambil detail transaksi dari blockchain
        const txDetail = await provider.getTransaction(feeTxHash);
        const txReceipt = await provider.getTransactionReceipt(feeTxHash);

        if (!txReceipt || txReceipt.status !== 1) {
            return res.status(400).json({ success: false, error: 'Transaksi fee belum terkonfirmasi/gagal di blockchain.' });
        }

        // 3. Validasi Penerima (Harus dompet Admin)
        if (txDetail.to.toLowerCase() !== process.env.ADMIN_WALLET_ADDRESS.toLowerCase()) {
            return res.status(400).json({ success: false, error: 'Fee tidak dikirim ke alamat wallet Admin yang benar!' });
        }

        // 4. Validasi Nominal (Minimum sesuai .env, default 0.01)
        const minFeeInWei = ethers.parseEther(process.env.FEE_AMOUNT || "0.01");
        if (txDetail.value < minFeeInWei) {
            return res.status(400).json({ success: false, error: `Jumlah fee kurang! Minimum fee adalah ${process.env.FEE_AMOUNT} token.` });
        }

        // 5. Eksekusi ke Smart Contract
        const tx = await contract.issue(id, docHash);
        await tx.wait();

        // 6. SIMPAN HASH FEE: Tandai bahwa hash ini telah sukses digunakan
        usedFeeHashes.add(feeTxHash);

        res.json({ success: true, txHash: tx.hash });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Fitur Issuer: Mencabut (Revoke) Ijazah
app.post('/api/revoke', async (req, res) => {
    try {
        const { id, reasonCode } = req.body;
        const tx = await contract.revoke(id, reasonCode);
        await tx.wait();
        res.json({ success: true, txHash: tx.hash });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Fitur Publik: Verifikasi
app.get('/api/verify', async (req, res) => {
    try {
        const { id, docHash } = req.query;
        const result = await contract.verify(id, docHash);
        
        res.json({
            success: true,
            data: {
                valid: result.valid,
                status: Number(result.status),
                issuer: result.issuer,
                issuedAt: Number(result.issuedAt)
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.listen(process.env.PORT, () => {
    console.log(`Server berjalan di http://localhost:${process.env.PORT}`);
});