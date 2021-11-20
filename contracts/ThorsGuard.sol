/* pragma solidity ^0.8.0; */

/* import "@openzeppelin/contracts/utils/Strings.sol"; */
/* import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; */
/* import "@openzeppelin/contracts/access/Ownable.sol"; */
/* import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; */
/* import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol"; */

contract ThorGuards is Ownable, ERC721, ERC721Enumerable, ReentrancyGuard {
    using Strings for uint256;

    uint256 public constant MINT_COST = 0.08 ether;
    uint256 public immutable AVAILABLE_SUPPLY;
    uint256 public MINT_PRE_START_TIME;
    uint256 public MINT_START_TIME;
    uint256 public MINT_END_TIME;

    mapping(address => uint256) public whitelistPre;
    mapping(address => uint256) public whitelist;
    mapping(address => uint256) public entriesPerAddressPre;
    mapping(address => uint256) public entriesPerAddress;
    string public uri;
    string public provenance;
    bool public locked;
    bool public mintOpen;
    uint256 public entropy;
    uint256 public nftCount;

    event WhitelistedPre(address indexed user, uint256 entries);
    event Whitelisted(address indexed user, uint256 entries);
    event MintedPre(address indexed user, uint256 entries);
    event Minted(address indexed user, uint256 entries);
    event Claimed(address indexed owner, uint256 amount);
    event SetBaseURI(string baseUri);
    event SetProvenance(string provenance);
    event SetTimes(uint256 startPre, uint256 start, uint256 end);
    event Locked();
    event ToggleOpen();

    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        uint256 _AVAILABLE_SUPPLY,
        uint256 _MINT_PRE_START_TIME,
        uint256 _MINT_START_TIME,
        uint256 _MINT_END_TIME
    ) ERC721(_NFT_NAME, _NFT_SYMBOL) Ownable() {
        AVAILABLE_SUPPLY = _AVAILABLE_SUPPLY;
        MINT_PRE_START_TIME = _MINT_PRE_START_TIME;
        MINT_START_TIME = _MINT_START_TIME;
        MINT_END_TIME = _MINT_END_TIME;
        emit SetTimes(_MINT_PRE_START_TIME, _MINT_START_TIME, _MINT_END_TIME);
    }

    function setBaseURI(string calldata _uri) public onlyOwner {
        require(!locked, "Metadata locked");
        uri = _uri;
        emit SetBaseURI(_uri);
    }

    function setProvenance(string calldata _provenance) public onlyOwner {
        require(!locked, "Metadata locked");
        provenance = _provenance;
        emit SetProvenance(_provenance);
    }

    function setMintTimes(uint256 _MINT_PRE_START_TIME, uint256 _MINT_START_TIME, uint256 _MINT_END_TIME) public onlyOwner {
        MINT_PRE_START_TIME = _MINT_PRE_START_TIME;
        MINT_START_TIME = _MINT_START_TIME;
        MINT_END_TIME = _MINT_END_TIME;
        emit SetTimes(_MINT_PRE_START_TIME, _MINT_START_TIME, _MINT_END_TIME);
    }

    function lockMetadata() public onlyOwner {
        locked = true;
        emit Locked();
    }

    function setWhitelistPre(address[] calldata addresses, uint256[] calldata entries) public onlyOwner {
        require(addresses.length == entries.length, "Addresses length != entries length");
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "zero");
            whitelistPre[addresses[i]] = entries[i];
            emit WhitelistedPre(addresses[i], entries[i]);
        }
    }

    function setWhitelist(address[] calldata addresses, uint256[] calldata entries) public onlyOwner {
        require(addresses.length == entries.length, "Addresses length != entries length");
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Zero");
            whitelist[addresses[i]] = entries[i];
            emit Whitelisted(addresses[i], entries[i]);
        }
    }

    function toggleOpen() public onlyOwner {
        mintOpen = !mintOpen;
        emit ToggleOpen();
    }

    function _checkedMint(address to) internal {
        require(nftCount < AVAILABLE_SUPPLY, "Available supply reached");
        _safeMint(msg.sender, nftCount + 1);
        nftCount++;
    }

    function mintPre(uint256 count) external payable nonReentrant {
        require(block.timestamp >= MINT_PRE_START_TIME, "Pre-Mint not started");
        require(block.timestamp < MINT_START_TIME, "Pre-Mint ended");
        require(count <= whitelistPre[msg.sender], "Max mints for address reached");
        if (msg.sender != owner()) {
            require(msg.value == count * MINT_COST, "Incorrect payment");
        }

        whitelistPre[msg.sender] -= count;
        entriesPerAddressPre[msg.sender] += count;
        entropy = block.number;

        for (uint256 i = 0; i < count; i++) {
            _checkedMint(msg.sender);
        }
        emit MintedPre(msg.sender, count);
    }

    function mint(uint256 count) external payable nonReentrant {
        require(block.timestamp >= MINT_START_TIME, "Mint not started");
        if (!mintOpen) {
            require(block.timestamp < MINT_END_TIME, "Mint ended");
            require(count <= whitelist[msg.sender], "Max mints for address reached");
            whitelist[msg.sender] -= count;
        }
        if (msg.sender != owner()) {
            require(msg.value == count * MINT_COST, "Incorrect payment");
        }

        entriesPerAddress[msg.sender] += count;
        entropy = block.number;

        for (uint256 i = 0; i < count; i++) {
            _checkedMint(msg.sender);
        }
        emit Minted(msg.sender, count);
    }

    function claimProceeds() external onlyOwner {
        require(block.timestamp >= MINT_END_TIME, "Mint has not ended");
        uint256 proceeds = address(this).balance;
        (bool sent,) = msg.sender.call{value: proceeds}("");
        require(sent, "Could not send proceeds");
        emit Claimed(msg.sender, proceeds);
    }

    function startingIndex() public view returns (uint256) {
        return entropy % AVAILABLE_SUPPLY;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(uri, tokenId.toString(), ".json"));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}