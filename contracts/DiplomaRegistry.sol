// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title DiplomaRegistry
 * @notice Prototype minimal registri ijazah. HANYA menyimpan hash dokumen, status,
 *         alamat penerbit, dan waktu. Tidak ada nama, NIM, NIK, atau PII lain.
 * @dev    DEFAULT_ADMIN_ROLE mensimulasikan multisig konsorsium (di prototype: satu akun).
 *         Kontrak sengaja TIDAK upgradeable.
 *         Seluruh alamat, ID, dan data pada test bersifat dummy.
 */
contract DiplomaRegistry is AccessControl {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant REASON_AMENDMENT = keccak256("AMENDMENT");

    enum Status { NONE, ACTIVE, REVOKED }

    struct Credential {
        bytes32 docHash;      // SHA-256 dokumen (dihitung off-chain)
        address issuer;       // akun penerbit (kampus)
        uint64 issuedAt;
        uint64 revokedAt;
        Status status;
        bytes32 reasonCode;   // kode alasan pencabutan (bukan teks bebas / PII)
        bytes32 supersededBy; // id ijazah pengganti jika diamandemen
    }

    mapping(bytes32 => Credential) private credentials;
    mapping(bytes32 => bytes32) private hashToId;
    mapping(bytes32 => uint64) private hashBlock; // blok saat docHash pertama terdaftar (SC-11)
    bool public paused;

    // ---- Event ----
    event CredentialIssued(bytes32 indexed id, bytes32 docHash, address indexed issuer, uint64 issuedAt);
    event CredentialRevoked(bytes32 indexed id, bytes32 reasonCode, address indexed by, uint64 revokedAt);
    event CredentialAmended(bytes32 indexed oldId, bytes32 indexed newId, bytes32 newDocHash, address indexed by);
    event IssuerAdded(address indexed issuer, address indexed by);
    event IssuerRemoved(address indexed issuer, address indexed by);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // ---- Error ----
    error NotAdmin();
    error NotIssuer();
    error NotCredentialIssuer();
    error AlreadyIssued();
    error NotFound();
    error AlreadyRevoked();
    error InvalidInput();
    error ContractPaused();

    constructor(address admin) {
        if (admin == address(0)) revert InvalidInput();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert NotAdmin();
        _;
    }

    modifier onlyIssuer() {
        if (!hasRole(ISSUER_ROLE, msg.sender)) revert NotIssuer();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ---- Override AccessControl (audit & anti-lockout) ----
    /// @dev SC-09: prototype hanya punya satu admin dan tidak ada transfer 2 langkah,
    ///      sehingga renounce DEFAULT_ADMIN_ROLE akan mengunci kontrak selamanya.
    function renounceRole(bytes32 role, address account) public override {
        if (role == DEFAULT_ADMIN_ROLE) revert InvalidInput();
        super.renounceRole(role, account);
    }

    /// @dev SC-08: perubahan ISSUER_ROLE lewat grantRole/revokeRole bawaan AccessControl
    ///      juga harus memancarkan event audit IssuerAdded/IssuerRemoved.
    function grantRole(bytes32 role, address account) public override {
        bool had = hasRole(role, account);
        super.grantRole(role, account);
        if (role == ISSUER_ROLE && !had) emit IssuerAdded(account, msg.sender);
    }

    function revokeRole(bytes32 role, address account) public override {
        bool had = hasRole(role, account);
        super.revokeRole(role, account);
        if (role == ISSUER_ROLE && had) emit IssuerRemoved(account, msg.sender);
    }

    // ---- Fungsi ADMIN ----
    function addIssuer(address issuer) external onlyAdmin {
        if (issuer == address(0)) revert InvalidInput();
        if (hasRole(ISSUER_ROLE, issuer)) return; // SC-27: idempoten, tanpa event palsu
        _grantRole(ISSUER_ROLE, issuer);
        emit IssuerAdded(issuer, msg.sender);
    }

    function removeIssuer(address issuer) external onlyAdmin {
        if (!hasRole(ISSUER_ROLE, issuer)) return; // SC-27: idempoten, tanpa event palsu
        _revokeRole(ISSUER_ROLE, issuer);
        emit IssuerRemoved(issuer, msg.sender);
    }

    function pause() external onlyAdmin {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyAdmin {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ---- Fungsi ISSUER ----
    function issue(bytes32 id, bytes32 docHash) external onlyIssuer whenNotPaused {
        _create(id, docHash);
    }

    /// @dev SC-10: DEFAULT_ADMIN_ROLE boleh mencabut ijazah siapa pun sebagai jalur
    ///      darurat, termasuk ijazah milik issuer yang rolenya sudah dicabut.
    function revoke(bytes32 id, bytes32 reasonCode) external {
        bool isAdmin = hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
        if (!isAdmin && !hasRole(ISSUER_ROLE, msg.sender)) revert NotIssuer();
        Credential storage c = credentials[id];
        if (c.status == Status.NONE) revert NotFound();
        if (!isAdmin && c.issuer != msg.sender) revert NotCredentialIssuer();
        if (c.status != Status.ACTIVE) revert AlreadyRevoked();
        // SC-14: reasonCode kosong tidak boleh dipakai (mengaburkan audit).
        // SC-15: REASON_AMENDMENT hanya boleh dipakai oleh amend(), bukan revoke().
        if (reasonCode == bytes32(0) || reasonCode == REASON_AMENDMENT) revert InvalidInput();
        _markRevoked(id, c, reasonCode);
    }

    function amend(bytes32 oldId, bytes32 newId, bytes32 newDocHash) external onlyIssuer whenNotPaused {
        Credential storage c = credentials[oldId];
        if (c.status == Status.NONE) revert NotFound();
        if (c.issuer != msg.sender) revert NotCredentialIssuer();
        if (c.status != Status.ACTIVE) revert AlreadyRevoked();
        _create(newId, newDocHash);
        c.supersededBy = newId;
        _markRevoked(oldId, c, REASON_AMENDMENT);
        emit CredentialAmended(oldId, newId, newDocHash, msg.sender);
    }

    // ---- Fungsi PUBLIK (baca, tanpa transaksi) ----
    function verify(bytes32 id, bytes32 docHash)
        external
        view
        returns (bool valid, Status status, address issuer, uint64 issuedAt)
    {
        Credential storage c = credentials[id];
        valid = (c.status == Status.ACTIVE && c.docHash == docHash);
        return (valid, c.status, c.issuer, c.issuedAt);
    }

    function getCredential(bytes32 id) external view returns (Credential memory) {
        return credentials[id];
    }

    // ---- Internal ----
    function _create(bytes32 id, bytes32 docHash) private {
        if (id == bytes32(0) || docHash == bytes32(0)) revert InvalidInput();
        if (credentials[id].status != Status.NONE) revert AlreadyIssued();

        bytes32 existingId = hashToId[docHash];
        if (existingId != bytes32(0)) {
            // SC-11: tolak duplikasi docHash, KECUALI balapan dalam blok yang sama oleh
            // issuer berbeda. Tanpa pengecualian ini, tx sah dengan fee lebih rendah bisa
            // digagalkan front-runner yang mendaftarkan docHash lebih dulu di blok yang sama.
            if (credentials[existingId].issuer == msg.sender || hashBlock[docHash] != uint64(block.number)) {
                revert AlreadyIssued();
            }
        } else {
            hashToId[docHash] = id;
        }
        hashBlock[docHash] = uint64(block.number);

        credentials[id] = Credential({
            docHash: docHash,
            issuer: msg.sender,
            issuedAt: uint64(block.timestamp),
            revokedAt: 0,
            status: Status.ACTIVE,
            reasonCode: bytes32(0),
            supersededBy: bytes32(0)
        });
        hashToId[docHash] = id;
        emit CredentialIssued(id, docHash, msg.sender, uint64(block.timestamp));
    }

    function _markRevoked(bytes32 id, Credential storage c, bytes32 reasonCode) private {
        c.status = Status.REVOKED;
        c.revokedAt = uint64(block.timestamp);
        c.reasonCode = reasonCode;
        emit CredentialRevoked(id, reasonCode, msg.sender, uint64(block.timestamp));
    }
}
