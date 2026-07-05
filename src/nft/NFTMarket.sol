// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC4906.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title NFTMarket
 * @dev ERC721 NFT 合约
 *
 *
 */
contract NFTMarket is ERC721, IERC4906, Ownable {
    using Strings for uint256;

    /**
     * @dev 下一个可用的 Token ID
     */
    uint256 private _nextTokenId;

    /**
     * @dev Token ID 到 URI 的映射
     */
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev 批量铸造上限
     */
    uint256 public constant MAX_BATCH_MINT = 100;

    // 铸造价格
    uint256 public mintPrice = 0.01 ether;

    /**
     * @dev 基础 URI（用于未设置单独 URI 的 Token）
     */
    string private _baseURIStorage;

    // ============================================================
    // 事件
    // ============================================================

    /**
     * @dev 批量铸造事件
     */
    event BatchMinted(address indexed to, uint256 startTokenId, uint256 count);

    /**
     * @dev ERC4906 接口 ID，仅由事件定义
     */
    bytes4 private constant _ERC4906_INTERFACE_ID = bytes4(0x49064906);

    /**
     * @dev 构造函数
     * @param name NFT 名称
     * @param symbol NFT 符号
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {
        _nextTokenId = 1;
    }

    /**
     * @dev 铸造单个 NFT（仅 Owner）
     * @param to 接收地址
     * @param uri Token URI（元数据地址）
     * @return tokenId 新铸造的 Token ID
     */
    function mint(address to, string calldata uri) external onlyOwner returns (uint256) {
        require(to != address(0), "Invalid address");
        require(bytes(uri).length > 0, "Invalid URI");

        uint256 tokenId = _nextTokenId;
        unchecked {
            _nextTokenId = tokenId + 1;
        }

        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = uri;

        return tokenId;
    }

    /**
     * @dev 批量铸造 NFT（仅 Owner）
     * @param to 接收地址
     * @param uris Token URI 数组
     * @return startTokenId 起始 Token ID
     *
     */
    function mintBatch(address to, string[] calldata uris) external onlyOwner returns (uint256 startTokenId) {
        require(to != address(0), "Invalid address");
        require(uris.length > 0, "Empty array");
        require(uris.length <= MAX_BATCH_MINT, "Exceeds max batch");

        startTokenId = _nextTokenId;
        uint256 endTokenId = startTokenId + uris.length;

        unchecked {
            _nextTokenId = endTokenId;
        }

        uint256 length = uris.length;
        for (uint256 i = 0; i < length;) {
            require(bytes(uris[i]).length > 0, "Invalid URI");
            uint256 tokenId = startTokenId + i;
            _safeMint(to, tokenId);
            _tokenURIs[tokenId] = uris[i];
            unchecked {
                ++i;
            }
        }

        emit BatchMinted(to, startTokenId, uris.length);
    }

    /**
     * @dev 获取 Token URI
     * @param tokenId Token ID
     * @return 元数据 URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        string memory uri = _tokenURIs[tokenId];
        if (bytes(uri).length > 0) {
            return uri;
        }

        string memory base = _baseURIStorage;
        if (bytes(base).length > 0) {
            return string(abi.encodePacked(base, tokenId.toString()));
        }

        return "";
    }

    /**
     * @dev 获取当前总供应量
     * @return 已铸造的 NFT 数量
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    /**
     * @dev 获取下一个 Token ID（预判）
     * @return 下一个可用的 Token ID
     */
    function getNextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev 更新 Token URI（仅 Owner）
     * @param tokenId Token ID
     * @param uri 新的 URI
     */
    function setTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(bytes(uri).length > 0, "Invalid URI");
        _tokenURIs[tokenId] = uri;
        emit MetadataUpdate(tokenId);
    }

    /**
     * @dev 设置基础 URI（仅 Owner）
     * @param newURI 新的基础 URI
     */
    function setBaseURI(string calldata newURI) external onlyOwner {
        _baseURIStorage = newURI;
        if (_nextTokenId > 1) {
            emit BatchMetadataUpdate(1, _nextTokenId - 1);
        }
    }

    /**
     * @dev 获取基础 URI
     * @return 基础 URI
     */
    function baseURI() external view returns (string memory) {
        return _baseURIStorage;
    }

    /**
     * @dev 批量转移 NFT（Gas 优化）
     * @param to 接收地址
     * @param tokenIds Token ID 数组
     */
    function transferBatch(address to, uint256[] calldata tokenIds) external {
        require(to != address(0), "Invalid address");
        uint256 length = tokenIds.length;
        require(length > 0, "Empty array");
        for (uint256 i = 0; i < length;) {
            transferFrom(msg.sender, to, tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev 提取铸造费用
     * @notice 只有合约所有者可以调用
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success,) = payable(owner()).call{ value: balance }("");
        require(success, "ETH transfer failed");
    }

    /**
     * @dev 设置铸造价格
     * @param newPrice 新的铸造价格（wei）
     * @notice 只有合约所有者可以调用
     */
    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == _ERC4906_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    // ============================================================
    // 内部函数
    // ============================================================

    /**
     * @dev 重写 _baseURI 函数
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURIStorage;
    }
}
