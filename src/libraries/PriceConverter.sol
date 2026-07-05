// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title PriceConverter
 * @dev 将 ETH/ERC20 金额统一换算为 6 位精度 USD。
 */
library PriceConverter {
    /**
     * @dev 项目内部统一 USD 精度：1 USD = 1,000,000
     */
    uint256 public constant USD_PRECISION = 1e6;

    /**
     * @dev 原生 ETH 固定 18 位小数
     */
    uint8 public constant ETH_DECIMALS = 18;

    /**
     * @dev 将 ETH 金额换算为 USD（6 位精度）。
     * @param ethAmount ETH 数量，单位 wei
     * @param ethUsdFeed ETH/USD 价格喂价
     */
    function convertETHToUSD(uint256 ethAmount, AggregatorV3Interface ethUsdFeed) internal view returns (uint256) {
        return convertTokenToUSD(ethAmount, ETH_DECIMALS, ethUsdFeed);
    }

    /**
     * @dev 将 ERC20 金额换算为 USD（6 位精度）。
     * @param tokenAmount ERC20 原始单位金额
     * @param feed ERC20/USD 价格喂价
     * @param tokenDecimals ERC20 自身 decimals
     */
    function convertERC20ToUSD(uint256 tokenAmount, AggregatorV3Interface feed, uint8 tokenDecimals)
        internal
        view
        returns (uint256)
    {
        return convertTokenToUSD(tokenAmount, tokenDecimals, feed);
    }

    /**
     * @dev 通用换算函数，动态读取 feed decimals
     */
    function convertTokenToUSD(uint256 tokenAmount, uint8 tokenDecimals, AggregatorV3Interface feed)
        internal
        view
        returns (uint256)
    {
        (, int256 price,, uint256 updatedAt,) = feed.latestRoundData();
        require(price > 0, "Price feed returned invalid price");
        require(updatedAt != 0, "Price feed incomplete");

        uint8 feedDecimals = feed.decimals();
        uint256 denominator = (10 ** tokenDecimals) * (10 ** feedDecimals);

        uint256 priceUint = SafeCast.toUint256(price);
        return (tokenAmount * priceUint * USD_PRECISION) / denominator;
    }

    /**
     * @dev 安全获取价格，失败时返回0（不revert）。
     * @param feed Chainlink喂价合约
     * @return 价格（原始精度），失败返回0
     */
    function getPriceSafe(AggregatorV3Interface feed) internal view returns (uint256) {
        try feed.latestRoundData() returns (uint80, int256 price, uint256, uint256, uint80) {
            if (price <= 0) return 0;
            return SafeCast.toUint256(price);
        } catch {
            return 0;
        }
    }
}
