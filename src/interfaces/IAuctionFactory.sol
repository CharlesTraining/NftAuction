// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAuctionFactory
 * @dev 拍卖工厂接口，定义Factory对外提供的所有功能
 *
 */
interface IAuctionFactory {
    /**
     * @dev 创建新的拍卖实例
     * @param nftContract NFT合约地址
     * @param tokenId NFT编号
     * @param duration 拍卖持续时长（秒）
     * @param reservePriceUSD 保留价（美元，6位精度）
     * @param bidToken 接受的代币地址（address(0)=ETH）
     * @return auction 新创建的拍卖实例地址
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 duration,
        uint256 reservePriceUSD,
        address bidToken
    ) external returns (uint256);

    /**
     * @dev 使用ETH出价
     * @param auctionId 拍卖实例Id
     */
    function bidETH(uint256 auctionId) external payable;

    /**
     * @dev 使用ERC20代币出价
     * @param auctionId 拍卖实例Id
     * @param amount 出价数量
     */
    function bidERC20(uint256 auctionId, uint256 amount) external;

    /**
     * @dev 结束拍卖，将NFT转给出价最高者
     * @param auctionId 拍卖实例Id
     */
    function endAuction(uint256 auctionId) external;

    /**
     * @dev 提取未中标的出价（拍卖结束后）
     * @param auctionId 拍卖实例Id
     */
    function withdrawBid(uint256 auctionId) external;

    /**
     * @dev 查询用户在某个拍卖中的出价
     * @param auctionId 拍卖实例
     * @param bidder 用户地址
     * @return 出价金额
     */
    function getUserBid(uint256 auctionId, address bidder) external view returns (uint256);

    /**
     * @dev 创建拍卖事件
     */
    event AuctionCreated(
        uint256 indexed auctionId, address indexed seller, address indexed nftContract, uint256 tokenId
    );

    /**
     * @dev 出价事件
     */
    event NewBid(address indexed bidder, uint256 amount);

    /**
     * @dev 拍卖结束事件
     */
    event AuctionEnded(address winner, uint256 winningBid);

    /**
     * @dev 提取出价事件
     */
    event BidWithdrawn(address indexed bidder, uint256 amount);

    /**
     * @dev 更新平台手续费
     */
    event PlatformFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);

    /**
     * @dev 更新手续费接收地址
     */
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    /**
     * @dev 记录平台手续费
     */
    event PlatformFeeCollected(address indexed token, uint256 amount, address indexed auction);
}
