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

// Fitur Issuer: Penerbitan Ijazah dengan Verifikasi Fee
app.post('/api/issue', async (req, res) => {
    try {
        const { id, docHash, feeTxHash } = req.body;

        if (!feeTxHash) {
            return res.status(400).json({ success: false, error: 'Transaksi fee wajib disertakan!' });
        }

        // 1. Ambil detail data transaksi dari blockchain
        const tx = await provider.getTransaction(feeTxHash);
        const txReceipt = await provider.getTransactionReceipt(feeTxHash);

        if (!txReceipt || txReceipt.status !== 1) {
            return res.status(400).json({ success: false, error: 'Transaksi fee belum terkonfirmasi/gagal.' });
        }

        // 2. Validasi apakah penerima transfer adalah wallet Admin
        if (tx.to.toLowerCase() !== process.env.ADMIN_WALLET_ADDRESS.toLowerCase()) {
            return res.status(400).json({ success: false, error: 'Fee tidak dikirim ke alamat wallet Admin yang benar!' });
        }

        // 3. Validasi apakah nominal transfer cukup (Sesuai FEE_AMOUNT di .env)
        const minFeeInWei = ethers.parseEther(process.env.FEE_AMOUNT || "0.01");
        if (tx.value < minFeeInWei) {
            return res.status(400).json({ success: false, error: `Jumlah fee kurang! Minimum fee adalah ${process.env.FEE_AMOUNT} token.` });
        }

        // Jika semua validasi lulus, eksekusi issue di smart contract
        const contractTx = await contract.issue(id, docHash);
        await contractTx.wait();

        res.json({ success: true, txHash: contractTx.hash });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

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