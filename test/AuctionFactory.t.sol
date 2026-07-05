// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import { AuctionFactory } from "../src/factory/AuctionFactory.sol";
import { AuctionFactoryV2 } from "../src/factory/AuctionFactoryV2.sol";
import { NFTMarket } from "../src/nft/NFTMarket.sol";

contract MockV3Aggregator is AggregatorV3Interface {
    uint8 private immutable _decimals;
    int256 private _answer;
    uint256 private _updatedAt;

    constructor(uint8 decimals_, int256 answer_) {
        _decimals = decimals_;
        _answer = answer_;
        _updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external pure returns (string memory) {
        return "mock feed";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 roundId) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, _answer, _updatedAt, _updatedAt, roundId);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, _answer, _updatedAt, _updatedAt, 1);
    }

    function setAnswer(int256 answer_) external {
        _answer = answer_;
        _updatedAt = block.timestamp;
    }
}

contract MockERC20 is ERC20 {
    uint8 private immutable _tokenDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _tokenDecimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AuctionFactoryTest is Test {
    AuctionFactory internal factory;
    NFTMarket internal nft;
    MockERC20 internal bidToken;
    MockV3Aggregator internal ethUsdFeed;
    MockV3Aggregator internal tokenUsdFeed;

    address internal owner = address(0xA11CE);
    address internal feeRecipient = address(0xFEE);
    address internal seller = address(0x5E11);
    address internal bidder1 = address(0xB1);
    address internal bidder2 = address(0xB2);

    function setUp() public {
        ethUsdFeed = new MockV3Aggregator(8, 2000e8);
        tokenUsdFeed = new MockV3Aggregator(8, 1e8);
        bidToken = new MockERC20("Mock USD", "MUSD", 18);

        vm.startPrank(owner);
        AuctionFactory implementation = new AuctionFactory();
        bytes memory initData = abi.encodeCall(AuctionFactory.initialize, (feeRecipient, address(ethUsdFeed)));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        factory = AuctionFactory(payable(address(proxy)));

        factory.setERC20Feed(address(bidToken), address(tokenUsdFeed));

        nft = new NFTMarket("Demo NFT", "DNFT");
        vm.stopPrank();

        vm.deal(bidder1, 100 ether);
        vm.deal(bidder2, 100 ether);
        vm.deal(seller, 1 ether);

        bidToken.mint(bidder1, 10_000 ether);
        bidToken.mint(bidder2, 10_000 ether);
    }

    function testCreateAuctionTransfersNftToFactory() public {
        uint256 tokenId = _mintToSeller();

        vm.prank(seller);
        nft.approve(address(factory), tokenId);

        vm.prank(seller);
        uint256 auctionId = factory.createAuction(address(nft), tokenId, 1, 1000e6, address(0));

        assertEq(auctionId, 1);
        assertEq(nft.ownerOf(tokenId), address(factory));
    }

    function testBidETHRefundsPreviousBidderAndEndsAuction() public {
        uint256 auctionId = _createEthAuction(1000e6);

        vm.prank(bidder1);
        factory.bidETH{ value: 1 ether }(auctionId);

        uint256 bidder1BalanceBeforeOutbid = bidder1.balance;

        vm.prank(bidder2);
        factory.bidETH{ value: 2 ether }(auctionId);

        assertEq(bidder1.balance, bidder1BalanceBeforeOutbid + 1 ether);
        assertEq(factory.getUserBid(auctionId, bidder1), 0);
        assertEq(factory.getUserBid(auctionId, bidder2), 2 ether);

        vm.warp(block.timestamp + 2 hours);
        uint256 sellerBalanceBefore = seller.balance;
        uint256 feeBalanceBefore = feeRecipient.balance;

        factory.endAuction(auctionId);

        assertEq(nft.ownerOf(1), bidder2);
        assertEq(feeRecipient.balance - feeBalanceBefore, 0.05 ether);
        assertEq(seller.balance - sellerBalanceBefore, 1.95 ether);
    }

    function testBidETHRevertsBelowReserve() public {
        uint256 auctionId = _createEthAuction(3000e6);

        vm.prank(bidder1);
        vm.expectRevert("Below reserve price");
        factory.bidETH{ value: 1 ether }(auctionId);
    }

    function testBidERC20RefundsPreviousBidderAndEndsAuction() public {
        uint256 auctionId = _createERC20Auction(1000e6);

        vm.startPrank(bidder1);
        bidToken.approve(address(factory), 1000 ether);
        factory.bidERC20(auctionId, 1000 ether);
        vm.stopPrank();

        vm.startPrank(bidder2);
        bidToken.approve(address(factory), 2000 ether);
        factory.bidERC20(auctionId, 2000 ether);
        vm.stopPrank();

        assertEq(bidToken.balanceOf(bidder1), 10_000 ether);
        assertEq(factory.getUserBid(auctionId, bidder1), 0);
        assertEq(factory.getUserBid(auctionId, bidder2), 2000 ether);

        vm.warp(block.timestamp + 2 hours);
        factory.endAuction(auctionId);

        assertEq(nft.ownerOf(1), bidder2);
        assertEq(bidToken.balanceOf(feeRecipient), 50 ether);
        assertEq(bidToken.balanceOf(seller), 1950 ether);
    }

    function testEndAuctionWithoutBidsReturnsNftToSeller() public {
        uint256 auctionId = _createEthAuction(1000e6);

        vm.warp(block.timestamp + 2 hours);
        factory.endAuction(auctionId);

        assertEq(nft.ownerOf(1), seller);
    }

    function testSellerCannotBid() public {
        uint256 auctionId = _createEthAuction(1000e6);

        vm.prank(seller);
        vm.expectRevert("Seller cannot bid");
        factory.bidETH{ value: 1 ether }(auctionId);
    }

    function testOwnerCanUpgradeToV2AndInitialize() public {
        uint256 auctionId = _createEthAuction(1000e6);
        AuctionFactoryV2 implementationV2 = new AuctionFactoryV2();

        vm.prank(owner);
        factory.upgradeToAndCall(address(implementationV2), abi.encodeCall(AuctionFactoryV2.initializeV2, (2)));

        AuctionFactoryV2 factoryV2 = AuctionFactoryV2(payable(address(factory)));
        assertEq(factoryV2.version(), 2);
        assertEq(factoryV2.owner(), owner);
        assertEq(factoryV2.nextAuctionId(), auctionId);
    }

    function testNonOwnerCannotUpgradeToV2() public {
        AuctionFactoryV2 implementationV2 = new AuctionFactoryV2();

        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bidder1));
        factory.upgradeToAndCall(address(implementationV2), abi.encodeCall(AuctionFactoryV2.initializeV2, (2)));
    }

    function _mintToSeller() internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = nft.mint(seller, "ipfs://token");
    }

    function _createEthAuction(uint256 reservePriceUSD) internal returns (uint256 auctionId) {
        uint256 tokenId = _mintToSeller();
        vm.startPrank(seller);
        nft.approve(address(factory), tokenId);
        auctionId = factory.createAuction(address(nft), tokenId, 1, reservePriceUSD, address(0));
        vm.stopPrank();
    }

    function _createERC20Auction(uint256 reservePriceUSD) internal returns (uint256 auctionId) {
        uint256 tokenId = _mintToSeller();
        vm.startPrank(seller);
        nft.approve(address(factory), tokenId);
        auctionId = factory.createAuction(address(nft), tokenId, 1, reservePriceUSD, address(bidToken));
        vm.stopPrank();
    }
}
