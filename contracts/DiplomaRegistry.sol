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

    // ---- Fungsi ADMIN ----
    function addIssuer(address issuer) external onlyAdmin {
        if (issuer == address(0)) revert InvalidInput();
        _grantRole(ISSUER_ROLE, issuer);
        emit IssuerAdded(issuer, msg.sender);
    }

    function removeIssuer(address issuer) external onlyAdmin {
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

    function revoke(bytes32 id, bytes32 reasonCode) external onlyIssuer whenNotPaused {
        Credential storage c = credentials[id];
        if (c.status == Status.NONE) revert NotFound();
        if (c.issuer != msg.sender) revert NotCredentialIssuer();
        if (c.status != Status.ACTIVE) revert AlreadyRevoked();
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
        if (credentials[id].status != Status.NONE || hashToId[docHash] != bytes32(0)) revert AlreadyIssued();
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
