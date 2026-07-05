// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "../interfaces/IAuctionFactory.sol";
import "../libraries/PriceConverter.sol";

/**
 * @title AuctionFactory
 * @dev 拍卖工厂合约，使用 UUPS 代理模式实现可升级
 *
 *
 */
contract AuctionFactory is IAuctionFactory, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @dev 平台手续费（基点，10000 = 100%）
     */
    uint256 public platformFee = 250; // 2.5%

    /**
     * @dev 手续费接收地址
     */
    address public feeRecipient;

    /**
     * @dev 累计平台手续费统计（token地址 => 累计金额）
     */
    mapping(address => uint256) public totalPlatformFeesCollected;

    /**
     * @dev ETH/USD Chainlink价格预言机
     */
    AggregatorV3Interface public ethUsdFeed;

    /**
     * @dev ERC20代币的价格预言机映射
     * token地址 → Chainlink喂价地址
     */
    mapping(address => AggregatorV3Interface) public erc20Feeds;

    /**
     * @dev 设置ERC20喂价事件
     */
    event ERC20FeedSet(address indexed token, address feed);

    /**
     * @dev 更新ETH喂价事件
     */
    event ETHFeedUpdated(address oldFeed, address newFeed);

    struct Auction {
        address nftContract;
        uint256 tokenId;
        address seller;
        uint256 endTime;
        uint256 reservePriceUSD;
        address bidToken;
        address highestBidder;
        uint256 highestBid;
        uint256 ended; // 0 开始 1 结束
    }

    uint256 public nextAuctionId;

    mapping(uint256 => Auction) public auctions;

    mapping(uint256 => mapping(address => uint256)) public userBids;

    // ============================================================
    // 初始化
    // ============================================================

    /**
     * @dev 构造函数，禁用初始化（防止被攻击）
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数（由代理调用）
     * @param _feeRecipient 手续费接收地址
     * @param _ethUsdFeed ETH/USD Chainlink喂价地址
     */
    function initialize(address _feeRecipient, address _ethUsdFeed) public initializer {
        require(_feeRecipient != address(0), "Invalid implementation");
        require(_ethUsdFeed != address(0), "Invalid ETH/USD feed");

        // 初始化Ownable（设置部署者为Owner）
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        platformFee = 250;
        feeRecipient = _feeRecipient;
        ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
    }

    // ============================================================
    // 核心功能：创建拍卖
    // ============================================================

    /**
     *
     * @dev 创建新的拍卖实例
     * @param nftContract NFT合约地址
     * @param tokenId NFT编号
     * @param duration 拍卖持续时长（小时）
     * @param reservePriceUSD 保留价（美元，6位精度）
     * @param bidToken 接受的代币地址（address(0)=ETH）
     * @return auctionId 新创建的拍卖
     *
     *
     * 流程：
     * 1. 验证输入参数
     * 2. 验证NFT所有权和授权
     * 3. 使用Clone复制逻辑合约
     * 4. 初始化新实例
     * 5. 记录到全局列表
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 duration,
        uint256 reservePriceUSD,
        address bidToken
    ) external returns (uint256) {
        // ===== 验证输入 =====
        require(nftContract != address(0), "Invalid NFT contract");
        require(duration > 0, "Duration must > 0");
        require(reservePriceUSD > 0, "Reserve price must > 0");

        // ===== 验证NFT所有权 =====
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");

        // ===== 验证授权（Approval或ApprovalForAll） =====
        bool isApproved = nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this);
        require(isApproved, "NFT not approved");

        // ===== 验证ERC20喂价 =====
        if (bidToken != address(0)) {
            require(address(erc20Feeds[bidToken]) != address(0), "ERC20 feed not set");
        }

        nft.transferFrom(msg.sender, address(this), tokenId);

        uint256 auctionId = ++nextAuctionId;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            reservePriceUSD: reservePriceUSD,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + (duration * 1 hours),
            bidToken: bidToken,
            ended: 0
        });

        emit AuctionCreated(auctionId, msg.sender, nftContract, tokenId);
        return auctionId;
    }

    /**
     * @dev 使用ETH出价
     * @param auctionId 拍卖实例Id
     * @notice 调用时需要附带ETH（msg.value）
     *
     * 流程：
     * 1. 验证拍卖状态（未结束、未过期、接受ETH）
     * 2. 查询ETH的美元价值
     * 3. 比较是否高于当前最高价和保留价
     * 4. 退还最高出价者（如果有）
     * 5. 更新最高出价
     */
    function bidETH(uint256 auctionId) external payable {
        _validateAuctionId(auctionId);
        Auction storage auction = auctions[auctionId];

        require(auction.bidToken == address(0), "Use bidERC20");
        require(msg.value > 0, "Bid must > 0");

        (address previousBidder, uint256 previousBid) = _placeBid(auctionId, auction, msg.value);

        // 退还最高出价者（如果存在）
        if (previousBidder != address(0)) {
            _sendETH(payable(previousBidder), previousBid);
        }

        emit NewBid(msg.sender, msg.value);
    }

    /**
     * @dev 使用ERC20代币出价
     * @param auctionId 拍卖实例Id
     * @param amount 出价数量
     *
     * 流程：
     * 1. 验证拍卖状态（未结束、未过期、接受ERC20）
     * 2. 将ERC20从用户转入本合约
     * 3. 通过Factory查询ERC20的美元价值
     * 4. 比较是否高于当前最高价和保留价
     * 5. 退还最高出价者（如果有）
     * 6. 更新最高出价
     */
    function bidERC20(uint256 auctionId, uint256 amount) external {
        _validateAuctionId(auctionId);
        Auction storage auction = auctions[auctionId];

        address bidToken = auction.bidToken;
        require(bidToken != address(0), "Use bidETH");
        require(amount > 0, "Bid must > 0");

        IERC20 token = IERC20(bidToken);

        // 将ERC20从用户转入本合约（先转账再验证，防止重入）
        token.safeTransferFrom(msg.sender, address(this), amount);
        (address previousBidder, uint256 previousBid) = _placeBid(auctionId, auction, amount);

        // 退还最高出价者（如果存在）
        if (previousBidder != address(0)) {
            token.safeTransfer(previousBidder, previousBid);
        }

        emit NewBid(msg.sender, amount);
    }

    /**
     * @dev 结束拍卖
     * @notice 任何人都可以调用，但必须在拍卖结束后
     * @param auctionId 拍卖实例Id
     * 流程：
     * 1. 验证拍卖状态（未结束、已过期）
     * 2. 如果有最高出价者：NFT转给出价者，扣除平台手续费后资金转给卖家
     * 3. 如果无人出价：NFT退还给卖家
     */
    function endAuction(uint256 auctionId) external {
        _validateAuctionId(auctionId);
        Auction storage auction = auctions[auctionId];

        require(auction.ended == 0, "Auction already ended");
        require(block.timestamp >= auction.endTime, "Auction not ended yet");

        // 标记为已结束（在转账前设置，防止重入攻击）
        auction.ended = 1;

        address winner = auction.highestBidder;
        uint256 winningBid = auction.highestBid;
        address seller = auction.seller;
        address bidToken = auction.bidToken;

        if (winner != address(0)) {
            // 有人出价：NFT转给赢家
            IERC721(auction.nftContract).transferFrom(address(this), winner, auction.tokenId);

            // 计算平台手续费
            address recipient = feeRecipient;
            uint256 feeAmount = recipient == address(0) ? 0 : (winningBid * platformFee) / 10_000;
            uint256 sellerAmount = winningBid - feeAmount;

            // 转账逻辑
            if (bidToken == address(0)) {
                // ETH转账
                if (feeAmount > 0) {
                    _sendETH(payable(recipient), feeAmount);
                    recordPlatformFee(address(0), feeAmount);
                }
                _sendETH(payable(seller), sellerAmount);
            } else {
                // ERC20转账
                IERC20 token = IERC20(bidToken);
                if (feeAmount > 0) {
                    token.safeTransfer(recipient, feeAmount);
                    recordPlatformFee(bidToken, feeAmount);
                }
                token.safeTransfer(seller, sellerAmount);
            }
        } else {
            // 无人出价：NFT退还给卖家
            IERC721(auction.nftContract).safeTransferFrom(address(this), seller, auction.tokenId);
        }

        emit AuctionEnded(winner, winningBid);
    }

    /**
     * @dev 提取未中标的出价（拍卖结束后调用）
     * @notice 只有未中标的出价者可以调用
     * @param auctionId 拍卖实例Id
     *
     * 流程：
     * 1. 验证拍卖已结束
     * 2. 验证调用者不是赢家
     * 3. 从Factory查询调用者的出价
     * 4. 清空记录并退款
     */
    function withdrawBid(uint256 auctionId) external {
        _validateAuctionId(auctionId);
        Auction storage auction = auctions[auctionId];
        require(auction.ended == 1, "Auction not ended");
        require(msg.sender != auction.highestBidder, "Winner cannot withdraw");

        uint256 amount = userBids[auctionId][msg.sender];
        require(amount > 0, "No bid to withdraw");

        recordBid(auctionId, msg.sender, 0);

        // 退款
        if (auction.bidToken == address(0)) {
            _sendETH(payable(msg.sender), amount);
        } else {
            IERC20(auction.bidToken).safeTransfer(msg.sender, amount);
        }

        emit BidWithdrawn(msg.sender, amount);
    }

    // ============================================================
    // 价格查询（供拍卖实例调用）
    // ============================================================

    /**
     * @dev 内部价格获取函数
     * @param token 代币地址
     * @param amount 代币数量
     * @return 美元金额（6位精度）
     */
    function _getPriceInUSD(address token, uint256 amount) internal view returns (uint256) {
        if (token == address(0)) {
            return PriceConverter.convertETHToUSD(amount, ethUsdFeed);
        }

        AggregatorV3Interface feed = erc20Feeds[token];
        require(address(feed) != address(0), "ERC20 feed not set");

        return PriceConverter.convertERC20ToUSD(amount, feed, IERC20Metadata(token).decimals());
    }

    function _placeBid(uint256 auctionId, Auction storage auction, uint256 amount)
        internal
        returns (address previousBidder, uint256 previousBid)
    {
        require(auction.ended == 0, "Auction ended");
        require(block.timestamp < auction.endTime, "Auction expired");
        require(msg.sender != auction.seller, "Seller cannot bid");

        address bidToken = auction.bidToken;
        uint256 bidUSD = _getPriceInUSD(bidToken, amount);

        previousBidder = auction.highestBidder;
        previousBid = auction.highestBid;

        if (previousBid > 0) {
            require(amount > previousBid, "Bid too low");
            userBids[auctionId][previousBidder] = 0;
        }

        require(bidUSD >= auction.reservePriceUSD, "Below reserve price");

        auction.highestBidder = msg.sender;
        auction.highestBid = amount;
        userBids[auctionId][msg.sender] = amount;
    }

    function _validateAuctionId(uint256 auctionId) internal view {
        require(auctionId != 0 && auctionId <= nextAuctionId, "Invalid auctionId");
    }

    function _sendETH(address payable to, uint256 amount) internal {
        (bool success,) = to.call{ value: amount }("");
        require(success, "ETH transfer failed");
    }

    // ============================================================
    // 出价记录管理
    // ============================================================

    /**
     * @dev 记录用户出价
     * @param auctionId 拍卖实例Id
     * @param bidder 出价人地址
     * @param amount 出价金额
     */
    function recordBid(uint256 auctionId, address bidder, uint256 amount) internal virtual {
        _validateAuctionId(auctionId);
        userBids[auctionId][bidder] = amount;
    }

    /**
     * @dev 查询用户在某个拍卖中的出价
     * @param auctionId 拍卖实例Id
     * @param bidder 用户地址
     * @return 出价金额
     */
    function getUserBid(uint256 auctionId, address bidder) external view returns (uint256) {
        _validateAuctionId(auctionId);
        return userBids[auctionId][bidder];
    }

    // ============================================================
    // 管理功能（仅Owner）
    // ============================================================

    /**
     * @dev 记录平台手续费
     * @param token 代币地址（address(0) = ETH）
     * @param amount 手续费金额
     */
    function recordPlatformFee(address token, uint256 amount) internal {
        totalPlatformFeesCollected[token] += amount;
        emit PlatformFeeCollected(token, amount, msg.sender);
    }

    /**
     * @dev 设置平台手续费
     * @param newFee 新的手续费（基点）
     * @notice 只有手续费接收地址可以调用
     */
    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(newFee <= 1000, "Fee too high"); // 最大10%

        uint256 oldFee = platformFee;
        platformFee = newFee;

        emit PlatformFeeUpdated(oldFee, newFee);
    }

    /**
     * @dev 更新手续费接收地址
     * @param newRecipient 新的接收地址
     * @notice 只有当前手续费接收地址可以调用
     */
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(msg.sender == feeRecipient, "Not fee recipient");
        require(newRecipient != address(0), "Invalid address");

        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @dev 设置单个ERC20的Chainlink喂价
     * @param token ERC20代币地址
     * @param feed Chainlink喂价合约地址
     */
    function setERC20Feed(address token, address feed) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(feed != address(0), "Invalid feed");
        erc20Feeds[token] = AggregatorV3Interface(feed);
        emit ERC20FeedSet(token, feed);
    }

    /**
     * @dev 批量设置ERC20喂价
     * @param tokens ERC20代币地址数组
     * @param feeds Chainlink喂价合约地址数组
     */
    function setERC20Feeds(address[] calldata tokens, address[] calldata feeds) external onlyOwner {
        require(tokens.length == feeds.length, "Length mismatch");
        require(tokens.length > 0, "Empty array");

        uint256 len = tokens.length;
        for (uint256 i = 0; i < len;) {
            require(tokens[i] != address(0), "Invalid token");
            require(feeds[i] != address(0), "Invalid feed");
            erc20Feeds[tokens[i]] = AggregatorV3Interface(feeds[i]);
            emit ERC20FeedSet(tokens[i], feeds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev 更新ETH/USD喂价
     * @param newFeed 新的ETH/USD Chainlink喂价地址
     */
    function setETHFeed(address newFeed) external onlyOwner {
        require(newFeed != address(0), "Invalid feed");
        address oldFeed = address(ethUsdFeed);
        ethUsdFeed = AggregatorV3Interface(newFeed);
        emit ETHFeedUpdated(oldFeed, newFeed);
    }

    /**
     * @dev UUPS 升级授权，仅 owner 可升级实现合约。
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    /**
     * @dev 提取意外收到的ETH（安全功能）
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawETH(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(amount <= address(this).balance, "Insufficient balance");
        _sendETH(payable(to), amount);
    }

    /**
     * @dev 提取意外收到的ERC20（安全功能）
     * @param token ERC20代币地址
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(token != address(0), "Invalid token");
        IERC20(token).safeTransfer(to, amount);
    }

    // ============================================================
    // 接收ETH
    // ============================================================

    /**
     * @dev 接收ETH（用于退还出价等）
     */
    receive() external payable { }
}
